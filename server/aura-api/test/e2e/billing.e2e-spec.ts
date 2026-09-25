import { generateKeyPairSync, randomUUID } from 'node:crypto';
import { Logger, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { createLocalJWKSet, exportJWK, SignJWT, type JWK } from 'jose';
import type { Pool } from 'pg';
import request from 'supertest';
import { purgeAccount } from '../../src/account/account-purge';
import { PrivateMediaStore } from '../../src/account/private-media';
import { AppModule } from '../../src/app.module';
import { StoreUnavailableError, type AppStoreServerApi } from '../../src/billing/apple/app-store-api';
import type { AppleStatusItem } from '../../src/billing/apple/apple-types';
import { APP_STORE_API, APPLE_JWS_VERIFIER, PLAY_API, PUBSUB_VERIFIER } from '../../src/billing/billing.tokens';
import type { PlayDeveloperApi } from '../../src/billing/google/play-api';
import type { GoogleProductPurchase, GoogleSubscriptionV2, GoogleVoidedPurchase } from '../../src/billing/google/play-types';
import { PubSubPushVerifier } from '../../src/billing/google/pubsub-auth';
import { StoreSync } from '../../src/billing/store-sync.service';
import { claimTrialReminders } from '../../src/billing/trial-reminder';
import { configureApp } from '../../src/bootstrap';
import { uuidv7 } from '../../src/common/uuid';
import { readTrialEndingFacts } from '../../src/notifications/trial-ending';
import { appleRenewal, appleTx, BUNDLE, signApple, testVerifier } from '../fixtures/billing/jws';
import { createUser, dbPool, deleteUser, type TestUser } from './support';

/**
 * F12 Monetization end to end: the real Nest app on the live local Supabase + Redis, with the store boundaries faked
 * (App Store Server API, Play Developer API) and App Store JWS signed by the committed TEST CA (the verifier is built
 * with that root instead of Apple's). Every user, room and store id here is unique; the only global row touched is the
 * `plus_enabled` flag (v1.0 ships it OFF): this suite turns purchases on for its run and puts the row back afterwards.
 * The off state itself is covered in remote-config.e2e-spec.ts.
 */
jest.setTimeout(60_000);

class FakeAppStore implements AppStoreServerApi {
  configured = true;
  down = false;
  readonly statusItems = new Map<string, AppleStatusItem[]>();
  readonly txs = new Map<string, string>();
  async transaction(id: string): Promise<string | null> {
    if (this.down) throw new StoreUnavailableError('network');
    return this.txs.get(id) ?? null;
  }
  async statuses(id: string): Promise<AppleStatusItem[] | null> {
    if (this.down) throw new StoreUnavailableError('network');
    return this.statusItems.get(id) ?? null;
  }
}

class FakePlay implements PlayDeveloperApi {
  configured = true;
  readonly subs = new Map<string, GoogleSubscriptionV2>();
  readonly products = new Map<string, GoogleProductPurchase>();
  readonly acks: string[] = [];
  readonly consumed: string[] = [];
  voidedList: GoogleVoidedPurchase[] = [];
  async subscription(t: string): Promise<GoogleSubscriptionV2 | null> {
    return this.subs.get(t) ?? null;
  }
  async acknowledgeSubscription(_p: string, t: string): Promise<void> {
    this.acks.push(t);
  }
  async product(p: string, t: string): Promise<GoogleProductPurchase | null> {
    return this.products.get(`${p}:${t}`) ?? null;
  }
  async acknowledgeProduct(_p: string, t: string): Promise<void> {
    this.acks.push(t);
  }
  async consumeProduct(_p: string, t: string): Promise<void> {
    this.consumed.push(t);
  }
  async voided(): Promise<GoogleVoidedPurchase[]> {
    return this.voidedList;
  }
}

const DAY = 86_400_000;
const PUSH_AUD = 'https://api.aura.test/v1/billing/webhooks/google';
const PUSH_SA = 'rtdn-push@aura-e2e.iam.gserviceaccount.com';

describe('F12 billing (e2e, live local Supabase + Redis, fake stores)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  const apple = new FakeAppStore();
  const play = new FakePlay();
  const google = generateKeyPairSync('rsa', { modulusLength: 2048 });

  const http = () => request(app.getHttpServer());
  const as = (u: TestUser, r: request.Test): request.Test => r.set('Authorization', `Bearer ${u.token}`);
  const newUser = async (label: string, birthDate = '1999-03-14'): Promise<TestUser> => {
    const u = await createUser(`bill-${label}`);
    users.push(u);
    await as(u, http().post('/v1/profile')).send({ birthDate, uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' }).expect(200);
    return u;
  };
  const ent = async (u: TestUser) => (await as(u, http().get('/v1/billing/entitlement')).expect(200)).body;
  const verify = (u: TestUser, body: Record<string, unknown>) => as(u, http().post('/v1/billing/purchases')).send(body);

  /** An App Store subscription the (fake) App Store knows, signed by the test CA. */
  const appleSub = async (over: Record<string, unknown> = {}, status = 1, renewal: Record<string, unknown> = {}) => {
    const t = appleTx(over);
    const jws = await signApple(t);
    const ren = await signApple(appleRenewal(t.originalTransactionId as string, renewal));
    apple.statusItems.set(t.originalTransactionId as string, [
      { originalTransactionId: t.originalTransactionId as string, status, signedTransactionInfo: jws, signedRenewalInfo: ren },
    ]);
    return { t, jws, ren };
  };
  const notify = async (type: string, t: Record<string, unknown>, extra: Record<string, unknown> = {}, subtype?: string) => {
    const payload = {
      notificationType: type,
      subtype,
      notificationUUID: randomUUID(),
      version: '2.0',
      signedDate: Date.now(),
      data: { bundleId: BUNDLE, environment: 'Sandbox', signedTransactionInfo: await signApple(t), ...extra },
    };
    return { payload, signed: await signApple(payload) };
  };
  const pushToken = (claims: Record<string, unknown> = {}, aud = PUSH_AUD): Promise<string> =>
    new SignJWT({ email: PUSH_SA, email_verified: true, ...claims })
      .setProtectedHeader({ alg: 'RS256', kid: 'g1' })
      .setIssuer('https://accounts.google.com')
      .setAudience(aud)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(google.privateKey);
  const rtdn = async (n: Record<string, unknown>, messageId = randomUUID(), auth?: string) =>
    http()
      .post('/v1/billing/webhooks/google')
      .set('Authorization', auth ?? `Bearer ${await pushToken()}`)
      .send({
        message: { data: Buffer.from(JSON.stringify({ version: '1.0', packageName: BUNDLE, eventTimeMillis: String(Date.now()), ...n })).toString('base64'), messageId },
        subscription: 'projects/aura/subscriptions/rtdn',
      });
  const gsub = (token: string, state: GoogleSubscriptionV2['subscriptionState'], over: Partial<GoogleSubscriptionV2> = {}): GoogleSubscriptionV2 => ({
    subscriptionState: state,
    startTime: new Date().toISOString(),
    latestOrderId: `GPA.${token.slice(0, 4)}-1111-2222-33333`,
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    externalAccountIdentifiers: { obfuscatedExternalAccountId: token },
    testPurchase: {},
    lineItems: [
      {
        productId: 'aura_plus_monthly',
        expiryTime: new Date(Date.now() + 30 * DAY).toISOString(),
        autoRenewingPlan: { autoRenewEnabled: true },
        offerDetails: { basePlanId: 'monthly', offerId: 'first-month-free' },
      },
    ],
    ...over,
  });

  let savedPlus: boolean | null = null;

  beforeAll(async () => {
    Logger.overrideLogger(['error']);
    db = dbPool();
    savedPlus = (await db.query<{ enabled: boolean }>(`select enabled from public.feature_flags where key = 'plus_enabled'`)).rows[0]?.enabled ?? null;
    await db.query(
      `insert into public.feature_flags (key, enabled, description) values ('plus_enabled', true, 'e2e (billing suite)')
       on conflict (key) do update set enabled = true`,
    );
    const jwk = (await exportJWK(google.publicKey)) as JWK;
    const ref = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(APPLE_JWS_VERIFIER)
      .useValue(testVerifier())
      .overrideProvider(APP_STORE_API)
      .useValue(apple)
      .overrideProvider(PLAY_API)
      .useValue(play)
      .overrideProvider(PUBSUB_VERIFIER)
      .useValue(
        new PubSubPushVerifier({ audience: PUSH_AUD, serviceAccountEmail: PUSH_SA }, createLocalJWKSet({ keys: [{ ...jwk, kid: 'g1', alg: 'RS256' }] })),
      )
      .compile();
    app = ref.createNestApplication({ bodyParser: false });
    configureApp(app);
    await app.init();
    await app.listen(0, '127.0.0.1');
  });

  afterAll(async () => {
    for (const u of users) await deleteUser(u.id);
    if (db) {
      if (savedPlus === null) await db.query(`delete from public.feature_flags where key = 'plus_enabled'`);
      else await db.query(`update public.feature_flags set enabled = $1 where key = 'plus_enabled'`, [savedPlus]);
    }
    await db?.end();
    await app?.close();
  });

  // ============================================================================================ entitlement
  it('a new account: Plus off, a UUID store token, the free night sky, no paywall for 24 h after onboarding', async () => {
    const u = await newUser('new');
    const e = await ent(u);
    expect(e.plus).toMatchObject({ active: false, status: 'none', validUntil: null });
    expect(e.accountToken).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(e.accountToken).not.toBe(u.id);
    expect(e.sky).toEqual({ theme: 'night', soundscape: null });
    expect(e.stardust.balance).toBe(0);
    expect(e.cosmetics.available).toEqual(['night']);
    expect(new Date(e.paywall.allowedFrom).getTime()).toBeGreaterThan(Date.now() + 23 * 3600_000); // REQ-PAY-06
    await http().get('/v1/billing/entitlement').expect(401);
  });

  // ============================================================================================ Apple
  it('App Store: trial → paid → cancel → grace → billing retry → expired; duplicates and stale notifications change nothing', async () => {
    const u = await newUser('apple-life');
    const { accountToken } = await ent(u);
    const { t, jws } = await appleSub({ appAccountToken: accountToken });
    const r = await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: jws, priceDisplay: '₹49.00' }).expect(200);
    expect(r.body.status).toBe('granted');
    expect(r.body.entitlement.plus).toMatchObject({ active: true, status: 'trial', store: 'apple', autoRenew: true });
    expect(r.body.entitlement.cosmetics.available).toEqual(expect.arrayContaining(['aurora', 'monsoon_dusk'])); // Plus skies
    // Same purchase again (app retry): same answer, one row.
    await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: jws }).expect(200);
    const rows = await db.query('select state, price_display, environment from public.subscriptions where store = $1 and store_ref = $2', ['apple', t.originalTransactionId]);
    expect(rows.rows).toEqual([{ state: 'trial', price_display: '₹49.00', environment: 'sandbox' }]);

    // Trial → paid (DID_RENEW).
    const paid = { ...t, transactionId: `${t.transactionId}1`, offerType: undefined, offerDiscountType: undefined, price: 49000, purchaseDate: Date.now(), expiresDate: Date.now() + 30 * DAY, signedDate: Date.now() };
    const renew = await notify('DID_RENEW', paid, { status: 1, signedRenewalInfo: await signApple(appleRenewal(t.originalTransactionId as string)) });
    expect((await http().post('/v1/billing/webhooks/apple').send({ signedPayload: renew.signed }).expect(200)).body).toEqual({ status: 'processed' });
    expect((await ent(u)).plus).toMatchObject({ active: true, status: 'active' });
    // Apple retries the same notification: a duplicate.
    expect((await http().post('/v1/billing/webhooks/apple').send({ signedPayload: renew.signed }).expect(200)).body).toEqual({ status: 'duplicate' });

    // An older, delayed EXPIRED snapshot (signed before DID_RENEW) never wins.
    const stale = { ...paid, signedDate: Date.now() - 60_000 };
    const stalePayload = { notificationType: 'EXPIRED', notificationUUID: randomUUID(), signedDate: Date.now() - 60_000, data: { bundleId: BUNDLE, environment: 'Sandbox', status: 2, signedTransactionInfo: await signApple(stale) } };
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: await signApple(stalePayload) }).expect(200);
    expect((await ent(u)).plus.status).toBe('active');

    // Cancel: auto-renew off → "cancelled", Plus stays on until the period ends.
    const off = await notify('DID_CHANGE_RENEWAL_STATUS', paid, { status: 1, signedRenewalInfo: await signApple(appleRenewal(t.originalTransactionId as string, { autoRenewStatus: 0 })) }, 'AUTO_RENEW_DISABLED');
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: off.signed }).expect(200);
    expect((await ent(u)).plus).toMatchObject({ active: true, status: 'cancelled', autoRenew: false });

    // Renewal fails: grace (Plus on, billing-issue banner), then billing retry (off), then expired.
    const lapsed = { ...paid, expiresDate: Date.now() - 1000, signedDate: Date.now() };
    const grace = await notify('DID_FAIL_TO_RENEW', lapsed, { status: 4, signedRenewalInfo: await signApple(appleRenewal(t.originalTransactionId as string, { isInBillingRetryPeriod: true, gracePeriodExpiresDate: Date.now() + 6 * DAY })) }, 'GRACE_PERIOD');
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: grace.signed }).expect(200);
    const g = await ent(u);
    expect(g.plus).toMatchObject({ active: true, status: 'grace' });
    expect(g.notices.map((n: { kind: string }) => n.kind)).toContain('billing_issue');
    const retry = await notify('GRACE_PERIOD_EXPIRED', { ...lapsed, signedDate: Date.now() + 1 }, { status: 3 });
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: retry.signed }).expect(200);
    const b = await ent(u);
    expect(b.plus).toMatchObject({ active: false, status: 'billing_retry' });
    expect(b.notices.map((n: { kind: string }) => n.kind)).toContain('billing_paused');
    const exp = await notify('EXPIRED', { ...lapsed, signedDate: Date.now() + 2 }, { status: 2 }, 'BILLING_RETRY');
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: exp.signed }).expect(200);
    expect((await ent(u)).plus).toMatchObject({ active: false, status: 'expired' });
  });

  it('REQ-PAY-10 Neg: a forged, foreign-signed or client-only receipt grants nothing; a forged webhook is refused', async () => {
    const u = await newUser('forged');
    const t = appleTx();
    // Tampered payload with a genuine signature header.
    const good = await signApple(t);
    const [h, , s] = good.split('.');
    const forged = `${h}.${Buffer.from(JSON.stringify({ ...t, productId: 'aura_plus_annual' })).toString('base64url')}.${s}`;
    expect((await verify(u, { store: 'apple', productId: 'aura_plus_annual', signedTransaction: forged }).expect(422)).body.code).toBe('invalid_purchase');
    // A developer's own Apple certificate, and a look-alike root.
    await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: await signApple(t, 'dev') }).expect(422);
    await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: await signApple(t, 'rogue') }).expect(422);
    // Correctly signed, but the App Store has never heard of it (client-only).
    expect((await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: good }).expect(422)).body.code).toBe('purchase_not_found');
    // Another app's transaction.
    await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: await signApple({ ...t, bundleId: 'com.other.app' }) }).expect(422);
    // Google token the Play API doesn't know.
    expect((await verify(u, { store: 'google', productId: 'aura_plus_monthly', purchaseToken: `nope-${randomUUID()}` }).expect(422)).body.code).toBe('purchase_not_found');
    expect((await ent(u)).plus.active).toBe(false);
    expect((await db.query('select count(*)::int as n from public.subscriptions where owner_user_id = $1', [u.id])).rows[0].n).toBe(0);
    // Webhooks: forged signature → 401, nothing logged.
    const n = await notify('SUBSCRIBED', t, { status: 1 });
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: await signApple(n.payload, 'rogue') }).expect(401);
    await http().post('/v1/billing/webhooks/apple').send({}).expect(400);
    expect((await db.query('select count(*)::int as n from public.store_notifications where notification_id = $1', [n.payload.notificationUUID])).rows[0].n).toBe(0);
  });

  it('REQ-PAY-07: App Store unreachable → "confirming", nothing granted; the store notification later grants it (app closed)', async () => {
    const u = await newUser('confirming');
    const { accountToken } = await ent(u);
    const { t, jws } = await appleSub({ appAccountToken: accountToken });
    apple.down = true;
    try {
      const r = await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: jws }).expect(202);
      expect(r.body.status).toBe('confirming');
      expect(r.body.entitlement.plus.active).toBe(false);
    } finally {
      apple.down = false;
    }
    const n = await notify('SUBSCRIBED', t, { status: 1 }, 'INITIAL_BUY');
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: n.signed }).expect(200);
    expect((await ent(u)).plus).toMatchObject({ active: true, status: 'trial' }); // matched by appAccountToken alone
  });

  it('refund: Plus ends at once; the refunded state and notice show', async () => {
    const u = await newUser('refund');
    const { accountToken } = await ent(u);
    const { t, jws } = await appleSub({ appAccountToken: accountToken, offerType: undefined, offerDiscountType: undefined, price: 49000 });
    await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: jws }).expect(200);
    const n = await notify('REFUND', { ...t, revocationDate: Date.now(), revocationReason: 0, signedDate: Date.now() + 5 }, { status: 2 });
    await http().post('/v1/billing/webhooks/apple').send({ signedPayload: n.signed }).expect(200);
    const e = await ent(u);
    expect(e.plus).toMatchObject({ active: false, status: 'refunded' });
    expect(e.notices.map((x: { kind: string }) => x.kind)).toContain('refunded');
  });

  // ============================================================================================ Google
  it('Play RTDN: only authenticated Pub/Sub pushes are accepted', async () => {
    await rtdn({ testNotification: { version: '1.0' } }, randomUUID(), 'Bearer nope').then((r) => expect(r.status).toBe(401));
    await rtdn({ testNotification: { version: '1.0' } }, randomUUID(), `Bearer ${await pushToken({}, 'https://evil.test')}`).then((r) => expect(r.status).toBe(401));
    await rtdn({ testNotification: { version: '1.0' } }, randomUUID(), `Bearer ${await pushToken({ email: 'x@evil.test' })}`).then((r) => expect(r.status).toBe(401));
    await http().post('/v1/billing/webhooks/google').send({}).expect(401);
    await rtdn({ testNotification: { version: '1.0' } }).then((r) => expect(r.status).toBe(204));
  });

  it('Play: pending UPI mandate grants nothing; RTDN PURCHASED grants it with the app closed; ack once; hold; voided refund', async () => {
    const u = await newUser('google-life');
    const { accountToken } = await ent(u);
    const token = `gtok-${randomUUID()}`;
    play.subs.set(token, gsub(accountToken, 'SUBSCRIPTION_STATE_PENDING'));
    const p = await verify(u, { store: 'google', productId: 'aura_plus_monthly', purchaseToken: token, priceDisplay: '₹49.00' }).expect(200);
    expect(p.body.status).toBe('pending');
    expect(p.body.entitlement.plus.active).toBe(false);
    expect(play.acks).not.toContain(token);

    // Mandate approved while the app is closed: only the RTDN arrives.
    play.subs.set(token, gsub(accountToken, 'SUBSCRIPTION_STATE_ACTIVE'));
    const msg = randomUUID();
    expect((await rtdn({ subscriptionNotification: { version: '1.0', notificationType: 4, purchaseToken: token, subscriptionId: 'aura_plus_monthly' } }, msg)).status).toBe(204);
    expect((await ent(u)).plus).toMatchObject({ active: true, status: 'trial', store: 'google' });
    expect(play.acks.filter((x) => x === token)).toHaveLength(1);
    // Pub/Sub redelivery of the same message: nothing new.
    await rtdn({ subscriptionNotification: { version: '1.0', notificationType: 4, purchaseToken: token, subscriptionId: 'aura_plus_monthly' } }, msg);
    expect(play.acks.filter((x) => x === token)).toHaveLength(1);
    expect((await db.query('select status from public.store_notifications where store = $1 and notification_id = $2', ['google', msg])).rows).toEqual([{ status: 'processed' }]);

    // Account hold → off; recovered → on; voided (refund) → off.
    play.subs.set(token, gsub(accountToken, 'SUBSCRIPTION_STATE_ON_HOLD', { acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' }));
    await rtdn({ subscriptionNotification: { version: '1.0', notificationType: 5, purchaseToken: token } });
    expect((await ent(u)).plus).toMatchObject({ active: false, status: 'billing_retry' });
    play.subs.set(token, gsub(accountToken, 'SUBSCRIPTION_STATE_ACTIVE', { acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED', latestOrderId: 'GPA.1-1-1-1..0' }));
    await rtdn({ subscriptionNotification: { version: '1.0', notificationType: 1, purchaseToken: token } });
    expect((await ent(u)).plus).toMatchObject({ active: true, status: 'active' });
    await rtdn({ voidedPurchaseNotification: { purchaseToken: token, orderId: 'GPA.1', productType: 1, refundType: 1 } });
    expect((await ent(u)).plus).toMatchObject({ active: false, status: 'refunded' });
  });

  it('reconciliation repairs a dropped notification (the store changed, no RTDN arrived)', async () => {
    const u = await newUser('reconcile');
    const { accountToken } = await ent(u);
    const token = `gtok-${randomUUID()}`;
    play.subs.set(token, gsub(accountToken, 'SUBSCRIPTION_STATE_ACTIVE'));
    await verify(u, { store: 'google', productId: 'aura_plus_monthly', purchaseToken: token }).expect(200);
    play.subs.set(token, gsub(accountToken, 'SUBSCRIPTION_STATE_EXPIRED', { acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' }));
    await db.query("update public.subscriptions set verified_at = now() - interval '2 days' where store_ref = $1", [token]);
    const sync = app.get(StoreSync);
    // Only this row is due in the partition we look at: run the reconcile until it has been re-read.
    for (let i = 0; i < 5; i++) {
      await sync.reconcileSubscriptions(new Date(), 500);
      const v = await db.query<{ state: string }>('select state from public.subscriptions where store_ref = $1', [token]);
      if (v.rows[0].state === 'expired') break;
    }
    expect((await ent(u)).plus).toMatchObject({ active: false, status: 'expired' });
  });

  // ============================================================================================ restore
  it('REQ-PAY-08: Restore recovers Plus for its account; another live account can’t take it (owned elsewhere)', async () => {
    const a = await newUser('restore-a');
    const b = await newUser('restore-b');
    const { accountToken } = await ent(a);
    const { jws } = await appleSub({ appAccountToken: accountToken });
    await verify(a, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: jws }).expect(200);
    // New device, same account: restore.
    const ra = await as(a, http().post('/v1/billing/restore')).send({ apple: { signedTransactions: [jws] } }).expect(200);
    expect(ra.body).toMatchObject({ restored: 1, ownedElsewhere: 0, invalid: 0 });
    expect(ra.body.entitlement.plus.active).toBe(true);
    // Another account signed in on the same phone (same Apple ID).
    const rb = await as(b, http().post('/v1/billing/restore')).send({ apple: { signedTransactions: [jws, 'x'.repeat(40)] } }).expect(200);
    expect(rb.body).toMatchObject({ restored: 0, ownedElsewhere: 1, invalid: 1 });
    expect(rb.body.entitlement.plus.active).toBe(false);
    await as(b, http().post('/v1/billing/restore')).send({ nope: 1 }).expect(400);
  });

  // ============================================================================================ cosmetics
  it('cosmetic sky: bought on Play → owned, acknowledged, equipped with a soundscape; refunded → removed, sky back to night', async () => {
    const u = await newUser('cosmetic');
    const { accountToken } = await ent(u);
    const token = `ctok-${randomUUID()}`;
    play.products.set(`sky_deep_ocean:${token}`, { purchaseState: 0, acknowledgementState: 0, orderId: 'GPA.9', obfuscatedExternalAccountId: accountToken, purchaseType: 0 });
    // Not owned yet → can't equip; a Plus sky needs Plus.
    expect((await as(u, http().put('/v1/billing/sky')).send({ theme: 'deep_ocean', soundscape: 'shore' }).expect(409)).body.code).toBe('not_owned');
    expect((await as(u, http().put('/v1/billing/sky')).send({ theme: 'aurora', soundscape: null }).expect(409)).body.code).toBe('plus_required');
    const r = await verify(u, { store: 'google', productId: 'sky_deep_ocean', purchaseToken: token }).expect(200);
    expect(r.body.status).toBe('granted');
    expect(r.body.entitlement.cosmetics.owned).toEqual(['deep_ocean']);
    expect(play.acks).toContain(token);
    const s = await as(u, http().put('/v1/billing/sky')).send({ theme: 'deep_ocean', soundscape: 'shore' }).expect(200);
    expect(s.body.sky).toEqual({ theme: 'deep_ocean', soundscape: 'shore' });
    await as(u, http().put('/v1/billing/sky')).send({ theme: 'deep_ocean', soundscape: 'binaural' }).expect(400);
    // Refund found by the daily Voided Purchases poll.
    play.voidedList = [{ purchaseToken: token, orderId: 'GPA.9', voidedTimeMillis: String(Date.now()) }];
    await app.get(StoreSync).pollVoided(new Date());
    play.voidedList = [];
    const e = await ent(u);
    expect(e.cosmetics.owned).toEqual([]);
    expect(e.sky).toEqual({ theme: 'night', soundscape: null });
  });

  // ============================================================================================ gifts + Stardust
  const room = async (members: TestUser[]): Promise<{ roomId: string; memberIds: string[] }> => {
    const r = await db.query<{ id: string }>(
      `insert into public.rooms (language_pool, quadrant, tz_region, seed_mood_id, theme, joins_close_at, memory_at, purge_at)
       values ('en', 'moonlight', 'south_asia', 'calm', 'midnight_observatory', now() + interval '20 hours', now() + interval '24 hours', now() + interval '8 days')
       returning id`,
    );
    const roomId = r.rows[0].id;
    const names = ['Quiet Heron', 'Gentle Fern', 'Soft Comet', 'Still Lake'];
    const memberIds: string[] = [];
    for (const [i, m] of members.entries()) {
      const x = await db.query<{ member_id: string }>(
        `insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
         values ($1, $2, $3, 'calm', 'moonlight', 'en', 'south_asia', 1, 'spark') returning member_id`,
        [roomId, m.id, names[i]],
      );
      memberIds.push(x.rows[0].member_id);
    }
    return { roomId, memberIds };
  };
  const checkGift = (u: TestUser, roomId: string, memberId: string, kind = 'comfort_lantern', giftId = uuidv7()) =>
    as(u, http().post('/v1/billing/gifts')).send({ giftId, roomId, memberId, kind });
  const buyGift = async (u: TestUser, giftId: string, productId = 'gift_comfort_lantern') => {
    const token = `gift-${randomUUID()}`;
    const { accountToken } = await ent(u);
    play.products.set(`${productId}:${token}`, { purchaseState: 0, acknowledgementState: 0, obfuscatedExternalAccountId: accountToken, purchaseType: 0 });
    const r = await verify(u, { store: 'google', productId, purchaseToken: token, giftId }).expect(200);
    return { token, body: r.body };
  };

  it('REQ-PAY-04/05: pre-checked gift → paid → delivered as Stardust, sender never shown; refund: recipient keeps it, sender count +1', async () => {
    const s = await newUser('gift-sender');
    const r = await newUser('gift-recipient');
    const { roomId, memberIds } = await room([s, r]);
    const c = await checkGift(s, roomId, memberIds[1]).expect(200);
    expect(c.body).toMatchObject({ productId: 'gift_comfort_lantern', kind: 'comfort_lantern' });
    const { token, body } = await buyGift(s, c.body.giftId);
    expect(body).toMatchObject({ status: 'granted', gift: 'delivered' });
    expect(play.consumed).toContain(token);
    const re = await ent(r);
    expect(re.stardust.balance).toBe(30);
    expect(re.giftsUnseen).toBe(1);
    const got = (await as(r, http().get('/v1/billing/gifts/received')).expect(200)).body.gifts;
    expect(got).toHaveLength(1);
    expect(Object.keys(got[0]).sort()).toEqual(['deliveredAt', 'giftId', 'kind', 'roomId', 'stardust']); // no sender, no pseudonym
    expect(JSON.stringify(got)).not.toContain(s.id);
    await as(r, http().post('/v1/billing/gifts/received/seen')).send({ giftIds: [got[0].giftId] }).expect(200, { marked: 1 });
    expect((await ent(r)).giftsUnseen).toBe(0);
    // Same purchase verified again: delivered once.
    await verify(s, { store: 'google', productId: 'gift_comfort_lantern', purchaseToken: token, giftId: c.body.giftId }).expect(200);
    expect((await ent(r)).stardust.balance).toBe(30);

    // Refund (RTDN voided): recipient keeps the Stardust; the sender's refund count grows.
    await rtdn({ voidedPurchaseNotification: { purchaseToken: token, productType: 2, refundType: 1 } });
    expect((await ent(r)).stardust.balance).toBe(30);
    expect((await db.query('select count(*)::int as n from public.gifts where sender_user_id = $1 and refunded_at is not null', [s.id])).rows[0].n).toBe(1);
  });

  it('REQ-PAY-04: blocks either way fail before any charge; never yourself; the 6th gift in a day is refused pre-sheet', async () => {
    const s = await newUser('gift-limits');
    const r = await newUser('gift-limits-r');
    const x = await newUser('gift-blocker');
    const { roomId, memberIds } = await room([s, r, x]);
    await checkGift(s, roomId, memberIds[0]).expect(409); // yourself
    await db.query('insert into public.blocks (blocker_user_id, blocked_user_id) values ($1, $2)', [x.id, s.id]);
    expect((await checkGift(s, roomId, memberIds[2]).expect(409)).body.code).toBe('gift_unavailable'); // they blocked me
    expect((await checkGift(x, roomId, memberIds[0]).expect(409)).body.code).toBe('gift_unavailable'); // I blocked them
    const ids: string[] = [];
    for (let i = 0; i < 5; i++) ids.push((await checkGift(s, roomId, memberIds[1], 'warm_tea').expect(200)).body.giftId);
    expect((await checkGift(s, roomId, memberIds[1], 'warm_tea').expect(429)).body.code).toBe('gift_daily_limit');
    // A dismissed store sheet frees its slot.
    await as(s, http().delete(`/v1/billing/gifts/${ids[0]}`)).expect(204);
    await checkGift(s, roomId, memberIds[1], 'warm_tea').expect(200);
    // Idempotent retry of the same check.
    const again = await checkGift(s, roomId, memberIds[1], 'warm_tea', ids[1]).expect(200);
    expect(again.body.giftId).toBe(ids[1]);
    // Sanctioned sender.
    await db.query(`insert into public.sanctions (user_id, kind, reason_code, source) values ($1, 'gesture_shadow_mute', 'e2e', 'moderator')`, [r.id]);
    expect((await checkGift(r, roomId, memberIds[0]).expect(403)).body.code).toBe('gifting_unavailable');
  });

  it('refunds: 2 refunded gifts in 90 days pause gifting; the recipient keeps the Stardust', async () => {
    const s = await newUser('gift-abuse');
    const r = await newUser('gift-abuse-r');
    const { roomId, memberIds } = await room([s, r]);
    for (let i = 0; i < 2; i++) {
      const c = await checkGift(s, roomId, memberIds[1], 'warm_tea').expect(200);
      const { token } = await buyGift(s, c.body.giftId, 'gift_warm_tea');
      await app.get(StoreSync).refundByRef('google', token, new Date());
    }
    expect((await ent(r)).stardust.balance).toBe(20);
    const e = await ent(s);
    expect(e.gifting.state).toBe('paused');
    expect((await checkGift(s, roomId, memberIds[1], 'warm_tea').expect(403)).body.code).toBe('gifting_paused');
  });

  it('minors: 3 gifts in 7 days from an adult to the same under-18 account still go through and open a Minors & grooming review item', async () => {
    const s = await newUser('gift-adult');
    const minor = await newUser('gift-minor', `${new Date().getUTCFullYear() - 15}-02-10`);
    const { roomId, memberIds } = await room([s, minor]);
    for (let i = 0; i < 3; i++) {
      const c = await checkGift(s, roomId, memberIds[1], 'warm_tea').expect(200);
      expect((await buyGift(s, c.body.giftId, 'gift_warm_tea')).body.gift).toBe('delivered');
    }
    expect((await ent(minor)).stardust.balance).toBe(30);
    const items = await db.query("select lane, involves_minor from public.reports where auto_signal = 'gift_pattern' and target_user_id = $1", [s.id]);
    expect(items.rows).toEqual([{ lane: 'minors_grooming', involves_minor: true }]);
  });

  it('Stardust: redeem a sky (idempotent), never below zero', async () => {
    const s = await newUser('stardust-s');
    const r = await newUser('stardust-r');
    const { roomId, memberIds } = await room([s, r]);
    const c = await checkGift(s, roomId, memberIds[1], 'comfort_lantern').expect(200);
    await buyGift(s, c.body.giftId);
    expect((await as(r, http().post('/v1/billing/stardust/redeem')).send({ cosmeticId: 'deep_ocean', redemptionId: uuidv7() }).expect(409)).body.code).toBe('not_enough_stardust');
    await as(r, http().post('/v1/billing/stardust/redeem')).send({ cosmeticId: 'aurora', redemptionId: uuidv7() }).expect(400); // Plus sky: not sold
    const redemptionId = uuidv7();
    const e = (await as(r, http().post('/v1/billing/stardust/redeem')).send({ cosmeticId: 'lantern_festival', redemptionId }).expect(200)).body;
    expect(e.stardust.balance).toBe(0);
    expect(e.cosmetics.owned).toEqual(['lantern_festival']);
    await as(r, http().post('/v1/billing/stardust/redeem')).send({ cosmeticId: 'lantern_festival', redemptionId }).expect(200);
    expect((await ent(r)).stardust.balance).toBe(0);
  });

  // ============================================================================================ trial reminder
  it('PRD 12: the trial-ending reminder is claimed once per account, 48 h before the end, only while auto-renew is on', async () => {
    const u = await newUser('trial-remind');
    const v = await newUser('trial-remind-off');
    const { accountToken } = await ent(u);
    const { jws } = await appleSub({ appAccountToken: accountToken, expiresDate: Date.now() + 47 * 3600_000 });
    await verify(u, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: jws, priceDisplay: '₹49.00' }).expect(200);
    const tv = (await ent(v)).accountToken;
    const off = await appleSub({ appAccountToken: tv, expiresDate: Date.now() + 47 * 3600_000 }, 1, { autoRenewStatus: 0 });
    await verify(v, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: off.jws }).expect(200);

    const due = (await claimTrialReminders(db, new Date())).filter((d) => d.userId === u.id || d.userId === v.id);
    expect(due.map((d) => d.userId)).toEqual([u.id]);
    expect((await claimTrialReminders(db, new Date())).some((d) => d.userId === u.id)).toBe(false); // once per account
    const facts = await readTrialEndingFacts(db, { userId: u.id, type: 'trial_ending', id: due[0].subscriptionId }, new Date());
    expect(facts).toMatchObject({ stillEnding: true, price: '₹49.00', period: 'month' });
    // The in-app card for the one with auto-renew off: "you won't be charged", never the reminder.
    expect((await ent(v)).notices.map((n: { kind: string }) => n.kind)).toEqual(['trial_cancelled']);
    expect((await ent(u)).notices.map((n: { kind: string }) => n.kind)).toEqual(['trial_ending']);
  });

  // ============================================================================================ purge
  it('account purge: personal billing rows go; purchase records stay without any link to the account', async () => {
    const s = await newUser('purge-s');
    const r = await newUser('purge-r');
    const { accountToken } = await ent(s);
    const { jws } = await appleSub({ appAccountToken: accountToken });
    await verify(s, { store: 'apple', productId: 'aura_plus_monthly', signedTransaction: jws }).expect(200);
    const { roomId, memberIds } = await room([s, r]);
    const c = await checkGift(s, roomId, memberIds[1], 'warm_tea').expect(200);
    await buyGift(s, c.body.giftId, 'gift_warm_tea');
    const back = await checkGift(r, roomId, memberIds[0], 'warm_tea').expect(200);
    await buyGift(r, back.body.giftId, 'gift_warm_tea');
    await as(s, http().put('/v1/billing/sky')).send({ theme: 'aurora', soundscape: 'high_wind' }).expect(200);

    await as(s, http().post('/v1/account/deletion')).expect(202);
    await db.query(`update public.account_deletions set requested_at = now() - interval '8 days', scheduled_for = now() - interval '1 day' where user_id = $1`, [s.id]);
    expect((await purgeAccount(db, app.get(PrivateMediaStore), s.id)).status).toBe('purged');

    for (const t of ['billing_accounts', 'entitlements', 'user_cosmetics', 'sky_preferences', 'stardust_ledger']) {
      expect((await db.query(`select count(*)::int as n from public.${t} where user_id = $1`, [s.id])).rows[0].n).toBe(0);
    }
    for (const [t, cols] of [
      ['subscriptions', ['owner_user_id']],
      ['purchases', ['owner_user_id']],
      ['gifts', ['sender_user_id', 'recipient_user_id']],
    ] as const) {
      for (const col of cols) expect((await db.query(`select count(*)::int as n from public.${t} where ${col} = $1`, [s.id])).rows[0].n).toBe(0);
    }
    // The records themselves are still there (de-identified), and the other person's Stardust is untouched.
    expect((await db.query('select count(*)::int as n from public.gifts where id = any($1::uuid[])', [[c.body.giftId, back.body.giftId]])).rows[0].n).toBe(2);
    expect((await ent(r)).stardust.balance).toBe(10);
    const logs = await db.query("select count(*)::int as n from public.store_notifications where payload ilike '%' || $1 || '%'", [s.id]);
    expect(logs.rows[0].n).toBe(0);
  });
});
