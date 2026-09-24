import { Inject, Injectable, Logger } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { AppConfig } from '../config/app-config';
import { pgCode, type Queryable, type Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { StoreUnavailableError, type AppStoreServerApi } from './apple/app-store-api';
import { isAppleSubscription, type AppleNotification, type AppleRenewalInfo, type AppleTransaction } from './apple/apple-types';
import { AppleJwsError, type AppleJwsVerifier } from './apple/jws';
import { deriveAccountToken, type BillingConfig } from './billing.config';
import {
  ensureBillingAccount,
  finishNotification,
  grantCosmetic,
  isLiveAccount,
  logNotification,
  markAcknowledged,
  markConsumed,
  ownedSubscriptions,
  purchaseByRef,
  removeCosmeticForPurchase,
  retireReplaced,
  setPurchaseOwner,
  setSubscriptionOwner,
  subscriptionByRef,
  upsertPurchase,
  upsertSubscription,
  userForToken,
  writeEntitlement,
  type PurchaseRow,
  type StoredNotification,
  type SubscriptionRow,
} from './billing.repository';
import { APP_STORE_API, APPLE_JWS_VERIFIER, BILLING_CONFIG, PLAY_API } from './billing.tokens';
import { PLUS_PRODUCTS, productInfo, skyByProduct } from './catalogue';
import { deliverGift, refundGift, unrefundGift, type GiftDelivery } from './gifts';
import type { PlayDeveloperApi } from './google/play-api';
import { SUB_NOTIFICATION, type DeveloperNotification } from './google/play-types';
import {
  applePurchaseSnapshot,
  appleSubscriptionSnapshot,
  computePlus,
  googlePurchaseSnapshot,
  googleSubscriptionSnapshot,
  plusUntil,
  type PlusEntitlement,
  type PurchaseSnapshot,
  type SubscriptionSnapshot,
} from './state';

/**
 * The one place store state becomes Aura state (DS-9: NestJS owns `entitlements`). Every path — the app's verify and
 * restore calls, App Store Server Notifications V2, Play RTDN, the daily reconcile — ends in `applySubscription` /
 * `applyPurchase`, which are idempotent (same snapshot twice = no change), ordering-safe (older snapshots never win)
 * and recompute the owner's entitlement in the same transaction. Store calls happen outside transactions.
 * Logs carry counts, types and reason codes only — never tokens, transaction ids, user ids or payloads.
 */

export type VerifyStatus = 'granted' | 'pending' | 'confirming' | 'not_active' | 'refunded' | 'owned_elsewhere';

export interface ApplyResult {
  status: VerifyStatus;
  owner: string | null;
  gift?: GiftDelivery;
}

const LIVE_SUB_STATES = ['pending', 'trial', 'active', 'grace', 'billing_retry', 'paused'];

export const invalidPurchase = (reason: string): ApiError =>
  new ApiError(422, 'invalid_purchase', `The store could not confirm this purchase (${reason}). Nothing was granted.`);
export const purchaseNotFound = (): ApiError =>
  new ApiError(422, 'purchase_not_found', 'The store does not know this purchase. Nothing was granted.');

@Injectable()
export class StoreSync {
  private readonly logger = new Logger('Billing');

  constructor(
    private readonly db: DbService,
    private readonly app: AppConfig,
    @Inject(BILLING_CONFIG) readonly cfg: BillingConfig,
    @Inject(APPLE_JWS_VERIFIER) readonly jws: AppleJwsVerifier,
    @Inject(APP_STORE_API) readonly apple: AppStoreServerApi,
    @Inject(PLAY_API) readonly play: PlayDeveloperApi,
  ) {}

  /** The account's store token (creates the billing_accounts row on first use). */
  async accountToken(userId: string, q: Queryable = this.db): Promise<string> {
    const token = deriveAccountToken(this.app.masterKey, userId);
    await ensureBillingAccount(q, userId, token);
    return token;
  }

  // ============================================================================================ entitlement

  async recompute(q: Queryable, userId: string, now: Date): Promise<PlusEntitlement> {
    const subs = await ownedSubscriptions(q, userId);
    const ent = computePlus(subs, now);
    await writeEntitlement(q, userId, { active: ent.active, sub: ent.subscription, until: ent.until });
    return ent;
  }

  // ============================================================================================ ownership

  /**
   * Who a store purchase belongs to (contracts §2.4): the account it is already linked to; else the account whose
   * store token the store recorded; else whoever verifies it. A purchase linked to another LIVE account is never moved
   * by a restore (`owned_elsewhere`: one Plus = one Aura account); one whose account is gone or being deleted is
   * claimed by the caller.
   */
  private async resolveOwner(
    q: Queryable,
    existingOwner: string | null,
    token: string | null,
    claimant: string | null,
  ): Promise<{ owner: string | null; elsewhere: boolean; previous: string | null }> {
    if (existingOwner) {
      if (claimant && claimant !== existingOwner) {
        if (await isLiveAccount(q, existingOwner)) return { owner: existingOwner, elsewhere: true, previous: null };
        return { owner: claimant, elsewhere: false, previous: existingOwner };
      }
      return { owner: existingOwner, elsewhere: false, previous: null };
    }
    const tokenUser = await userForToken(q, token);
    if (tokenUser && (await isLiveAccount(q, tokenUser))) {
      if (claimant && claimant !== tokenUser) return { owner: tokenUser, elsewhere: true, previous: null };
      return { owner: tokenUser, elsewhere: false, previous: null };
    }
    return { owner: claimant, elsewhere: false, previous: null };
  }

  // ============================================================================================ apply

  async applySubscription(
    snap: SubscriptionSnapshot,
    o: { claimant?: string | null; priceDisplay?: string | null; verified: boolean },
    now: Date,
  ): Promise<ApplyResult & { row: SubscriptionRow }> {
    const claimant = o.claimant ?? null;
    const out = await this.db.withTx(async (tx) => {
      if (claimant) await lockUser(tx, claimant);
      const existing = await subscriptionByRef(tx, snap.store, snap.storeRef, true);
      const who = await this.resolveOwner(tx, existing?.owner_user_id ?? null, snap.accountToken, claimant);
      if (who.owner && who.owner !== claimant) await lockUser(tx, who.owner);
      const { row } = await upsertSubscription(tx, snap, {
        owner: who.owner,
        priceDisplay: who.elsewhere ? null : o.priceDisplay ?? null,
        verified: o.verified,
      });
      const affected = new Set<string>();
      if (who.previous && who.owner) {
        await setSubscriptionOwner(tx, row.id, who.owner);
        row.owner_user_id = who.owner;
        affected.add(who.previous);
      }
      if (row.owner_user_id) affected.add(row.owner_user_id);
      if (snap.linkedStoreRef && snap.store === 'google') {
        const old = await retireReplaced(tx, 'google', snap.linkedStoreRef);
        if (old) affected.add(old);
      }
      for (const u of affected) await this.recompute(tx, u, now);
      return { row, elsewhere: who.elsewhere };
    });
    if (snap.store === 'google' && snap.needsAcknowledge && !out.row.acknowledged_at) {
      try {
        await this.play.acknowledgeSubscription(snap.productId, snap.storeRef);
        await markAcknowledged(this.db, 'subscriptions', out.row.id);
      } catch (err) {
        this.logger.warn(`google acknowledge (subscription) deferred: ${errCode(err)}`); // reconcile retries (3-day limit)
      }
    }
    const r = out.row;
    const status: VerifyStatus = out.elsewhere
      ? 'owned_elsewhere'
      : plusUntil(
            { id: r.id, store: r.store, productId: r.product_id, state: r.state, autoRenew: r.auto_renew, trialEndsAt: r.trial_ends_at, expiresAt: r.expires_at, graceEndsAt: r.grace_ends_at, updatedAt: r.updated_at },
            now,
          )
        ? 'granted'
        : r.state === 'pending'
          ? 'pending'
          : r.state === 'refunded' || r.state === 'revoked'
            ? 'refunded'
            : 'not_active';
    return { status, owner: out.elsewhere ? null : r.owner_user_id, row: r };
  }

  async applyPurchase(
    snap: PurchaseSnapshot,
    o: { claimant?: string | null; giftId?: string | null; reinstate?: boolean },
    now: Date,
  ): Promise<ApplyResult & { row: PurchaseRow }> {
    const info = productInfo(snap.productId);
    if (!info || info.kind === 'plus') throw invalidPurchase('product');
    const kind = info.kind;
    const claimant = o.claimant ?? null;
    const out = await this.db.withTx(async (tx) => {
      if (claimant) await lockUser(tx, claimant);
      const existing = await purchaseByRef(tx, snap.store, snap.storeRef, true);
      const who = await this.resolveOwner(tx, existing?.owner_user_id ?? null, snap.accountToken, claimant);
      if (who.owner && who.owner !== claimant) await lockUser(tx, who.owner);
      const { row, previous } = await upsertPurchase(tx, snap, kind, who.owner, { reinstate: o.reinstate });
      if (who.previous && who.owner) {
        await setPurchaseOwner(tx, row.id, who.owner);
        row.owner_user_id = who.owner;
      }
      let gift: GiftDelivery | undefined;
      const owner = row.owner_user_id;
      const wasOff = previous === 'refunded' || previous === 'revoked';
      if (row.state === 'completed' && owner && !who.elsewhere) {
        if (kind === 'cosmetic') {
          const sky = skyByProduct(row.product_id);
          if (sky) await grantCosmetic(tx, owner, sky.id, row.id);
        } else {
          gift = await deliverGift(tx, row, owner, o.giftId ?? null, now, this.app.masterKey);
          if (wasOff) await unrefundGift(tx, row.id);
        }
      }
      if ((row.state === 'refunded' || row.state === 'revoked') && !wasOff) await this.refundEffects(tx, row, now);
      return { row, elsewhere: who.elsewhere, gift };
    });
    await this.settleGooglePurchase(out.row, snap, out.gift);
    const status: VerifyStatus = out.elsewhere
      ? 'owned_elsewhere'
      : out.row.state === 'completed'
        ? 'granted'
        : out.row.state === 'pending'
          ? 'pending'
          : 'refunded';
    return { status, owner: out.elsewhere ? null : out.row.owner_user_id, row: out.row, gift: out.gift };
  }

  /** Cosmetic refunded → removed. Gift refunded → the recipient keeps the Stardust; the sender's count grows. */
  private async refundEffects(tx: Tx, row: PurchaseRow, now: Date): Promise<void> {
    if (row.kind === 'cosmetic') await removeCosmeticForPurchase(tx, row.id);
    else await refundGift(tx, row.id, now);
  }

  /**
   * Google one-time purchases must be acknowledged within 3 days (else Google refunds them): a cosmetic is
   * acknowledged, a delivered gift is consumed (consuming acknowledges, and lets the person gift it again). A gift
   * paid for but not matched to a check yet is only acknowledged, so a later verify with its gift id can deliver it.
   */
  private async settleGooglePurchase(row: PurchaseRow, snap: PurchaseSnapshot, gift: GiftDelivery | undefined): Promise<void> {
    if (row.store !== 'google' || row.state !== 'completed') return;
    try {
      if (row.kind === 'gift' && (gift === 'delivered' || gift === 'already') && !row.consumed_at && !snap.consumed) {
        await this.play.consumeProduct(row.product_id, row.store_ref);
        await markConsumed(this.db, row.id);
      } else if (!row.acknowledged_at && snap.needsAcknowledge !== false) {
        await this.play.acknowledgeProduct(row.product_id, row.store_ref);
        await markAcknowledged(this.db, 'purchases', row.id);
      }
    } catch (err) {
      this.logger.warn(`google acknowledge/consume deferred: ${errCode(err)}`);
    }
  }

  /** A store refund / revocation found by reference (Play voided purchases, RTDN voided notification). */
  async refundByRef(store: 'apple' | 'google', ref: string, now: Date): Promise<'subscription' | 'purchase' | 'unknown' | 'already'> {
    return this.db.withTx(async (tx) => {
      const sub = await subscriptionByRef(tx, store, ref, true);
      if (sub) {
        if (sub.state === 'refunded' || sub.state === 'revoked') return 'already';
        await tx.query(`update public.subscriptions set state = 'refunded', revoked_at = coalesce(revoked_at, $2), auto_renew = false, updated_at = now() where id = $1`, [
          sub.id,
          now,
        ]);
        if (sub.owner_user_id) await this.recompute(tx, sub.owner_user_id, now);
        return 'subscription';
      }
      const p = await purchaseByRef(tx, store, ref, true);
      if (!p) return 'unknown';
      if (p.state === 'refunded' || p.state === 'revoked') return 'already';
      await tx.query(`update public.purchases set state = 'refunded', refunded_at = $2, updated_at = now() where id = $1`, [p.id, now]);
      await this.refundEffects(tx, p, now);
      return 'purchase';
    });
  }

  // ============================================================================================ store confirmation

  /** App Store: the subscription's current status straight from Apple (null = Apple doesn't know it). */
  async confirmAppleSubscription(originalTransactionId: string, now: Date): Promise<SubscriptionSnapshot | null> {
    const items = await this.apple.statuses(originalTransactionId);
    if (!items || items.length === 0) return null;
    const item = items.find((i) => i.originalTransactionId === originalTransactionId) ?? items[0];
    const tx = await this.jws.verify<AppleTransaction>(item.signedTransactionInfo);
    const renewal = item.signedRenewalInfo ? await this.jws.verify<AppleRenewalInfo>(item.signedRenewalInfo) : null;
    this.checkAppleTransaction(tx);
    return appleSubscriptionSnapshot(tx, renewal, item.status, now, { eventAt: now });
  }

  /** App Store: a one-time transaction straight from Apple. */
  async confirmApplePurchase(transactionId: string): Promise<PurchaseSnapshot | null> {
    const signed = await this.apple.transaction(transactionId);
    if (!signed) return null;
    const tx = await this.jws.verify<AppleTransaction>(signed);
    this.checkAppleTransaction(tx);
    return applePurchaseSnapshot(tx);
  }

  /** Throws invalidPurchase unless the transaction is this app's, in an accepted environment, bought (not shared). */
  checkAppleTransaction(tx: AppleTransaction): void {
    if (tx.bundleId !== this.cfg.appleBundleId) throw invalidPurchase('bundle');
    if (tx.environment !== 'Production' && !(this.cfg.acceptSandbox && tx.environment === 'Sandbox')) throw invalidPurchase('environment');
    if (tx.inAppOwnershipType === 'FAMILY_SHARED') throw invalidPurchase('family_sharing'); // Family Sharing is off
  }

  // ============================================================================================ app verify

  /**
   * `POST /v1/billing/purchases` for the App Store: the StoreKit 2 JWS must verify against Apple's root, then Apple's
   * server confirms it (the client's copy alone never grants: REQ-PAY-10). Apple unreachable → `confirming` (a pending
   * row the worker keeps confirming; the store notification also settles it).
   */
  async verifyApple(
    userId: string,
    input: { productId: string; signedTransaction: string; priceDisplay?: string | null; giftId?: string | null },
    now: Date,
  ): Promise<ApplyResult> {
    let tx: AppleTransaction;
    try {
      tx = await this.jws.verify<AppleTransaction>(input.signedTransaction);
    } catch (err) {
      if (err instanceof AppleJwsError) throw invalidPurchase('signature');
      throw err;
    }
    this.checkAppleTransaction(tx);
    if (tx.productId !== input.productId) throw invalidPurchase('product');
    const info = productInfo(tx.productId);
    if (!info) throw invalidPurchase('product');
    await this.accountToken(userId);

    if (info.kind === 'plus' || isAppleSubscription(tx)) {
      if (info.kind !== 'plus') throw invalidPurchase('product');
      let snap: SubscriptionSnapshot | null;
      try {
        snap = await this.confirmAppleSubscription(tx.originalTransactionId, now);
      } catch (err) {
        if (!(err instanceof StoreUnavailableError)) throw rethrowStore(err);
        await this.recordUnconfirmed(userId, 'apple', tx.originalTransactionId, tx.productId, tx.environment === 'Production' ? 'production' : 'sandbox', tx.appAccountToken ?? null);
        return { status: 'confirming', owner: null };
      }
      if (!snap) throw purchaseNotFound();
      return this.applySubscription(snap, { claimant: userId, priceDisplay: input.priceDisplay, verified: true }, now);
    }
    let snap: PurchaseSnapshot | null;
    try {
      snap = await this.confirmApplePurchase(tx.transactionId);
    } catch (err) {
      if (!(err instanceof StoreUnavailableError)) throw rethrowStore(err);
      return { status: 'confirming', owner: null };
    }
    if (!snap) throw purchaseNotFound();
    return this.applyPurchase(snap, { claimant: userId, giftId: input.giftId }, now);
  }

  /** `POST /v1/billing/purchases` for Google Play: always re-read from the Play Developer API. */
  async verifyGoogle(
    userId: string,
    input: { productId: string; purchaseToken: string; priceDisplay?: string | null; giftId?: string | null },
    now: Date,
  ): Promise<ApplyResult> {
    const info = productInfo(input.productId);
    if (!info) throw invalidPurchase('product');
    await this.accountToken(userId);
    if (info.kind === 'plus') {
      let sub;
      try {
        sub = await this.play.subscription(input.purchaseToken);
      } catch (err) {
        if (!(err instanceof StoreUnavailableError)) throw err;
        await this.recordUnconfirmed(userId, 'google', input.purchaseToken, input.productId, 'production', null);
        return { status: 'confirming', owner: null };
      }
      if (!sub) throw purchaseNotFound();
      const snap = googleSubscriptionSnapshot(sub, input.purchaseToken, now, { eventAt: now });
      if (!(PLUS_PRODUCTS as readonly string[]).includes(snap.productId)) throw invalidPurchase('product');
      if (snap.environment === 'sandbox' && !this.cfg.acceptSandbox) throw invalidPurchase('environment');
      return this.applySubscription(snap, { claimant: userId, priceDisplay: input.priceDisplay, verified: true }, now);
    }
    let p;
    try {
      p = await this.play.product(input.productId, input.purchaseToken);
    } catch (err) {
      if (!(err instanceof StoreUnavailableError)) throw err;
      return { status: 'confirming', owner: null };
    }
    if (!p) throw purchaseNotFound();
    const snap = googlePurchaseSnapshot(p, input.productId, input.purchaseToken);
    if (!snap) return { status: 'not_active', owner: null }; // cancelled before it completed: nothing charged
    if (snap.environment === 'sandbox' && !this.cfg.acceptSandbox) throw invalidPurchase('environment');
    return this.applyPurchase(snap, { claimant: userId, giftId: input.giftId }, now);
  }

  /** A subscription the store couldn't confirm yet: a `pending` row (nothing granted) the worker keeps confirming. */
  private async recordUnconfirmed(
    userId: string,
    store: 'apple' | 'google',
    ref: string,
    productId: string,
    environment: 'production' | 'sandbox',
    storeToken: string | null,
  ): Promise<void> {
    const own = deriveAccountToken(this.app.masterKey, userId);
    const owner = storeToken && storeToken.toLowerCase() !== own ? null : userId;
    await this.db.query(
      `insert into public.subscriptions (owner_user_id, store, store_ref, product_id, environment, state, auto_renew)
       values ($1, $2, $3, $4, $5, 'pending', true) on conflict (store, store_ref) do nothing`,
      [owner, store, ref, productId, environment],
    );
  }

  // ============================================================================================ webhooks

  /**
   * App Store Server Notifications V2 (`POST /v1/billing/webhooks/apple`). The signed payload is verified before
   * anything is read or stored; forged or foreign → refused / ignored. Logged once (notificationUUID), then handled.
   */
  async receiveApple(signedPayload: unknown, now: Date): Promise<'processed' | 'ignored' | 'failed' | 'duplicate'> {
    if (typeof signedPayload !== 'string') throw ApiError.badRequest('invalid_request', 'signedPayload: required');
    let n: AppleNotification;
    try {
      n = await this.jws.verify<AppleNotification>(signedPayload);
    } catch (err) {
      if (err instanceof AppleJwsError) throw new ApiError(401, 'invalid_signature', 'The notification signature did not verify.');
      throw err;
    }
    if (typeof n.notificationUUID !== 'string' || typeof n.notificationType !== 'string') throw ApiError.badRequest('invalid_request', 'not a notification');
    const bundle = n.data?.bundleId ?? n.summary?.bundleId;
    const env = n.data?.environment ?? n.summary?.environment;
    if (bundle !== this.cfg.appleBundleId) return 'ignored';
    if (env === 'Production' && this.cfg.appleAppAppleId !== null && n.data?.appAppleId !== undefined && n.data.appAppleId !== this.cfg.appleAppAppleId) {
      return 'ignored';
    }
    let storeRef: string | null = null;
    if (n.data?.signedTransactionInfo) {
      const tx = await this.jws.verify<AppleTransaction>(n.data.signedTransactionInfo).catch(() => null);
      storeRef = tx ? (isAppleSubscription(tx) ? tx.originalTransactionId : tx.transactionId) : null;
    }
    const { row, inserted } = await logNotification(this.db, {
      store: 'apple',
      notificationId: n.notificationUUID,
      type: n.notificationType,
      subtype: n.subtype ?? null,
      environment: env === 'Production' ? 'production' : env ? 'sandbox' : null,
      signedAt: typeof n.signedDate === 'number' ? new Date(n.signedDate) : null,
      payload: signedPayload,
      storeRef,
    });
    if (!inserted && (row.status === 'processed' || row.status === 'ignored')) return 'duplicate';
    return this.process(row, now);
  }

  /** Play RTDN via authenticated Pub/Sub push (caller verified the OIDC token). Always re-reads the purchase. */
  async receiveGoogle(body: unknown, now: Date): Promise<'processed' | 'ignored' | 'failed' | 'duplicate'> {
    const msg = (body as { message?: { data?: unknown; messageId?: unknown; message_id?: unknown } } | null)?.message;
    const messageId = typeof msg?.messageId === 'string' ? msg.messageId : typeof msg?.message_id === 'string' ? msg.message_id : null;
    if (!msg || typeof msg.data !== 'string' || !messageId) return 'ignored';
    let n: DeveloperNotification;
    let json: string;
    try {
      json = Buffer.from(msg.data, 'base64').toString('utf8');
      n = JSON.parse(json) as DeveloperNotification;
    } catch {
      return 'ignored';
    }
    if (!n || typeof n !== 'object' || n.packageName !== this.cfg.googlePackageName) return 'ignored';
    const type = n.subscriptionNotification
      ? `subscription:${n.subscriptionNotification.notificationType}`
      : n.oneTimeProductNotification
        ? `one_time:${n.oneTimeProductNotification.notificationType}`
        : n.voidedPurchaseNotification
          ? 'voided'
          : n.testNotification
            ? 'test'
            : 'unknown';
    const ref =
      n.subscriptionNotification?.purchaseToken ?? n.oneTimeProductNotification?.purchaseToken ?? n.voidedPurchaseNotification?.purchaseToken ?? null;
    const { row, inserted } = await logNotification(this.db, {
      store: 'google',
      notificationId: messageId.slice(0, 128),
      type,
      subtype: null,
      environment: null,
      signedAt: n.eventTimeMillis && /^\d+$/.test(n.eventTimeMillis) ? new Date(Number(n.eventTimeMillis)) : null,
      payload: json,
      storeRef: ref,
    });
    if (!inserted && (row.status === 'processed' || row.status === 'ignored')) return 'duplicate';
    return this.process(row, now);
  }

  /** Handles one logged notification (webhook, or the worker's retry). Failures are kept for the retry. */
  async process(row: StoredNotification, now: Date): Promise<'processed' | 'ignored' | 'failed'> {
    try {
      const status = row.store === 'apple' ? await this.processApple(row.payload, now) : await this.processGoogle(row.payload, now);
      await finishNotification(this.db, row.id, status);
      return status;
    } catch (err) {
      const code = errCode(err);
      await finishNotification(this.db, row.id, 'failed', code).catch(() => undefined);
      this.logger.warn(`${row.store} notification ${row.notification_type}: failed (${code}); the billing worker retries`);
      return 'failed';
    }
  }

  private async processApple(payload: string, now: Date): Promise<'processed' | 'ignored'> {
    const n = await this.jws.verify<AppleNotification>(payload);
    if (n.notificationType === 'TEST') return 'processed';
    const signedTx = n.data?.signedTransactionInfo;
    if (!signedTx) return 'ignored'; // e.g. RENEWAL_EXTENSION summaries, EXTERNAL_PURCHASE_TOKEN
    const tx = await this.jws.verify<AppleTransaction>(signedTx);
    const renewal = n.data?.signedRenewalInfo ? await this.jws.verify<AppleRenewalInfo>(n.data.signedRenewalInfo) : null;
    try {
      this.checkAppleTransaction(tx);
    } catch {
      return 'ignored';
    }
    const info = productInfo(tx.productId);
    if (!info) return 'ignored';
    const eventAt = typeof n.signedDate === 'number' ? new Date(n.signedDate) : null;
    if (isAppleSubscription(tx)) {
      if (info.kind !== 'plus') return 'ignored';
      const snap = appleSubscriptionSnapshot(tx, renewal, n.data?.status ?? null, now, { notificationType: n.notificationType, eventAt });
      await this.applySubscription(snap, { verified: false }, now);
      return 'processed';
    }
    // CONSUMPTION_REQUEST asks for consumption data on a consumable refund request; Aura doesn't answer it (the
    // gift's Stardust is kept either way) `[ASSUMPTION]`.
    if (n.notificationType === 'CONSUMPTION_REQUEST' || n.notificationType === 'REFUND_DECLINED') return 'ignored';
    const snap = applePurchaseSnapshot(tx, eventAt);
    await this.applyPurchase(snap, { reinstate: n.notificationType === 'REFUND_REVERSED' }, now);
    return 'processed';
  }

  private async processGoogle(payload: string, now: Date): Promise<'processed' | 'ignored'> {
    const n = JSON.parse(payload) as DeveloperNotification;
    const eventAt = n.eventTimeMillis && /^\d+$/.test(n.eventTimeMillis) ? new Date(Number(n.eventTimeMillis)) : null;
    if (n.testNotification) return 'processed';
    if (n.subscriptionNotification) {
      const s = n.subscriptionNotification;
      const sub = await this.play.subscription(s.purchaseToken);
      if (!sub) return 'ignored';
      const snap = googleSubscriptionSnapshot(sub, s.purchaseToken, now, { revoked: s.notificationType === SUB_NOTIFICATION.REVOKED, eventAt });
      if (!(PLUS_PRODUCTS as readonly string[]).includes(snap.productId)) return 'ignored';
      await this.applySubscription(snap, { verified: true }, now);
      return 'processed';
    }
    if (n.oneTimeProductNotification) {
      const o = n.oneTimeProductNotification;
      const info = productInfo(o.sku);
      if (!info || info.kind === 'plus') return 'ignored';
      const p = await this.play.product(o.sku, o.purchaseToken);
      if (!p) return 'ignored';
      const snap = googlePurchaseSnapshot(p, o.sku, o.purchaseToken);
      if (!snap) return 'processed'; // a pending purchase was cancelled: nothing was charged or granted
      // The app passes the gift id as the obfuscated profile id: an RTDN-only purchase still finds its gift.
      await this.applyPurchase(snap, { giftId: isUuid(p.obfuscatedExternalProfileId) ? p.obfuscatedExternalProfileId.toLowerCase() : null }, now);
      return 'processed';
    }
    if (n.voidedPurchaseNotification) {
      const r = await this.refundByRef('google', n.voidedPurchaseNotification.purchaseToken, now);
      return r === 'unknown' ? 'ignored' : 'processed';
    }
    return 'ignored';
  }

  // ============================================================================================ reconcile (worker)

  /**
   * Daily reconcile (REQ-PAY-10 "reconciliation repairs a dropped notification"): every subscription still in a live
   * state that wasn't confirmed in the last 20 h is re-read from its store and re-applied. Pending rows the store
   * never confirms within 3 days lapse to `expired` (nothing was granted).
   */
  async reconcileSubscriptions(now: Date, limit = 500): Promise<{ checked: number; changed: number; failed: number }> {
    const due = await this.db.query<{ store: 'apple' | 'google'; store_ref: string; state: string; created_at: Date }>(
      `select store, store_ref, state, created_at from public.subscriptions
        where state = any($1::text[]) and (verified_at is null or verified_at < $2)
        order by verified_at nulls first limit $3`,
      [LIVE_SUB_STATES, new Date(now.getTime() - 20 * 3600_000), limit],
    );
    const s = { checked: 0, changed: 0, failed: 0 };
    for (const row of due.rows) {
      s.checked += 1;
      try {
        let snap: SubscriptionSnapshot | null;
        if (row.store === 'apple') snap = await this.confirmAppleSubscription(row.store_ref, now);
        else {
          const sub = await this.play.subscription(row.store_ref);
          snap = sub ? googleSubscriptionSnapshot(sub, row.store_ref, now, { eventAt: now }) : null;
        }
        if (!snap) {
          if (row.state === 'pending' && now.getTime() - row.created_at.getTime() > 3 * 86_400_000) {
            await this.db.query(`update public.subscriptions set state = 'expired', updated_at = now() where store = $1 and store_ref = $2`, [row.store, row.store_ref]);
            s.changed += 1;
          }
          continue;
        }
        const r = await this.applySubscription(snap, { verified: true }, now);
        if (r.row.state !== row.state) s.changed += 1;
      } catch (err) {
        s.failed += 1;
        if (s.failed <= 3) this.logger.warn(`reconcile ${row.store}: ${errCode(err)}`);
      }
    }
    return s;
  }

  /** Google one-time purchases still pending, or not yet acknowledged / consumed (3-day rule). */
  async reconcileGooglePurchases(now: Date, limit = 200): Promise<{ checked: number; failed: number }> {
    if (!this.play.configured) return { checked: 0, failed: 0 };
    const due = await this.db.query<{ product_id: string; store_ref: string }>(
      `select product_id, store_ref from public.purchases
        where store = 'google' and (state = 'pending' or (state = 'completed' and (acknowledged_at is null or (kind = 'gift' and consumed_at is null))))
          and created_at > $1 order by created_at limit $2`,
      [new Date(now.getTime() - 14 * 86_400_000), limit],
    );
    const s = { checked: 0, failed: 0 };
    for (const row of due.rows) {
      s.checked += 1;
      try {
        const p = await this.play.product(row.product_id, row.store_ref);
        const snap = p ? googlePurchaseSnapshot(p, row.product_id, row.store_ref) : null;
        const giftId = isUuid(p?.obfuscatedExternalProfileId) ? (p?.obfuscatedExternalProfileId as string).toLowerCase() : null;
        if (snap) await this.applyPurchase(snap, { giftId }, now);
      } catch {
        s.failed += 1;
      }
    }
    return s;
  }

  /** Play Voided Purchases API (daily; RTDN voided notifications are the fast path). Idempotent. */
  async pollVoided(now: Date): Promise<{ voided: number; applied: number }> {
    if (!this.play.configured) return { voided: 0, applied: 0 };
    const list = await this.play.voided(now.getTime() - 3 * 86_400_000);
    let applied = 0;
    for (const v of list) {
      const r = await this.refundByRef('google', v.purchaseToken, now);
      if (r === 'subscription' || r === 'purchase') applied += 1;
    }
    return { voided: list.length, applied };
  }

  /** Notifications that failed (store API down, DB error) or were never handled: retried with the stored payload. */
  async retryNotifications(now: Date, limit = 100): Promise<{ retried: number; failed: number }> {
    const due = await this.db.query<StoredNotification>(
      `select id, store, notification_id, notification_type, payload, status, attempts from public.store_notifications
        where status in ('received','failed') and attempts < 20 and received_at < $1 order by received_at limit $2`,
      [new Date(now.getTime() - 60_000), limit],
    );
    let failed = 0;
    for (const row of due.rows) if ((await this.process(row, now)) === 'failed') failed += 1;
    return { retried: due.rows.length, failed };
  }

  /** Entitlements whose period ran out since they were written (no store event needed for time to pass). */
  async sweepEntitlements(now: Date): Promise<number> {
    const due = await this.db.query<{ user_id: string }>(
      'select user_id from public.entitlements where plus_active and plus_until <= $1 limit 1000',
      [now],
    );
    for (const { user_id } of due.rows) await this.db.withTx(async (tx) => {
      await lockUser(tx, user_id);
      await this.recompute(tx, user_id, now);
    });
    return due.rows.length;
  }
}

/** Reason codes for logs and `store_notifications.last_error` (never messages: they could carry ids). */
export function errCode(err: unknown): string {
  if (err instanceof StoreUnavailableError) return `store_${err.reason}`.replace(/[^a-z0-9_]/g, '_').slice(0, 64);
  if (err instanceof AppleJwsError) return `jws_${err.reason}`;
  if (err instanceof ApiError) return err.code.slice(0, 64);
  const pg = pgCode(err);
  if (pg) return `db_${pg.toLowerCase()}`;
  return 'error';
}

function rethrowStore(err: unknown): unknown {
  if (err instanceof AppleJwsError) return invalidPurchase('signature');
  return err;
}
