import type { AppleTransaction } from '../../src/billing/apple/apple-types';
import type { GoogleSubscriptionV2 } from '../../src/billing/google/play-types';
import {
  appleSubscriptionSnapshot,
  applePurchaseSnapshot,
  computePlus,
  displayStatus,
  googlePurchaseSnapshot,
  googleSubscriptionSnapshot,
  noticesFor,
  plusUntil,
  type SubscriptionFacts,
} from '../../src/billing/state';

const NOW = new Date('2026-10-20T10:00:00Z');
const DAY = 86_400_000;
const at = (days: number): number => NOW.getTime() + days * DAY;

const tx = (over: Partial<AppleTransaction> = {}): AppleTransaction => ({
  transactionId: '2000000001',
  originalTransactionId: '2000000000',
  bundleId: 'com.akvega.aura',
  productId: 'aura_plus_monthly',
  type: 'Auto-Renewable Subscription',
  purchaseDate: at(-5),
  originalPurchaseDate: at(-5),
  expiresDate: at(25),
  environment: 'Sandbox',
  offerType: 1,
  offerDiscountType: 'FREE_TRIAL',
  price: 0,
  signedDate: at(-5),
  appAccountToken: 'a3c0c1a4-51b2-4c3d-9e4f-5a6b7c8d9e0f',
  ...over,
});
const paid = { offerType: undefined, offerDiscountType: undefined, price: 49000 };

describe('Apple subscription → state', () => {
  it('free month: trial, trial end = period end, auto-renew from renewal info', () => {
    const s = appleSubscriptionSnapshot(tx(), { originalTransactionId: '2000000000', autoRenewStatus: 1 }, 1, NOW);
    expect(s).toMatchObject({ state: 'trial', autoRenew: true, storeRef: '2000000000', environment: 'sandbox' });
    expect(s.trialEndsAt?.getTime()).toBe(at(25));
    expect(s.accountToken).toBe('a3c0c1a4-51b2-4c3d-9e4f-5a6b7c8d9e0f');
  });
  it('trial → paid: active (renewal transaction, no offer)', () => {
    expect(appleSubscriptionSnapshot(tx(paid), null, 1, NOW)).toMatchObject({ state: 'active', trialEndsAt: null });
  });
  it('cancel (auto-renew off): still trial/active until the period ends', () => {
    const s = appleSubscriptionSnapshot(tx(), { originalTransactionId: '2000000000', autoRenewStatus: 0 }, 1, NOW);
    expect(s).toMatchObject({ state: 'trial', autoRenew: false });
  });
  it('grace (status 4) keeps the grace end; billing retry (3); expired (2); revoked (5)', () => {
    const r = { originalTransactionId: '2000000000', autoRenewStatus: 1, isInBillingRetryPeriod: true, gracePeriodExpiresDate: at(6) };
    expect(appleSubscriptionSnapshot(tx({ ...paid, expiresDate: at(-1) }), r, 4, NOW)).toMatchObject({ state: 'grace' });
    expect(appleSubscriptionSnapshot(tx({ ...paid, expiresDate: at(-1) }), r, 4, NOW).graceEndsAt?.getTime()).toBe(at(6));
    expect(appleSubscriptionSnapshot(tx({ ...paid, expiresDate: at(-10) }), r, 3, NOW).state).toBe('billing_retry');
    expect(appleSubscriptionSnapshot(tx({ ...paid, expiresDate: at(-10) }), null, 2, NOW).state).toBe('expired');
    expect(appleSubscriptionSnapshot(tx(), null, 5, NOW).state).toBe('revoked');
  });
  it('refund: revocationDate → refunded (REVOKE notification → revoked)', () => {
    const t = tx({ ...paid, revocationDate: at(-1), revocationReason: 0 });
    expect(appleSubscriptionSnapshot(t, null, 2, NOW).state).toBe('refunded');
    expect(appleSubscriptionSnapshot(t, null, 2, NOW, { notificationType: 'REVOKE' }).state).toBe('revoked');
  });
  it('without an App Store status (client copy only), derives from the dates', () => {
    expect(appleSubscriptionSnapshot(tx(), null, null, NOW).state).toBe('trial');
    expect(appleSubscriptionSnapshot(tx({ expiresDate: at(-1) }), null, null, NOW).state).toBe('expired');
    const retry = { originalTransactionId: '2000000000', isInBillingRetryPeriod: true, gracePeriodExpiresDate: at(3) };
    expect(appleSubscriptionSnapshot(tx({ expiresDate: at(-1) }), retry, null, NOW).state).toBe('grace');
  });
  it('one-time purchase: completed, or refunded when revoked', () => {
    const c = tx({ type: 'Non-Consumable', productId: 'sky_deep_ocean', transactionId: '77' });
    expect(applePurchaseSnapshot(c)).toMatchObject({ state: 'completed', storeRef: '77' });
    expect(applePurchaseSnapshot({ ...c, revocationDate: at(0) }).state).toBe('refunded');
  });
});

const gsub = (over: Partial<GoogleSubscriptionV2> = {}, li: Record<string, unknown> = {}): GoogleSubscriptionV2 => ({
  subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
  startTime: new Date(at(-3)).toISOString(),
  latestOrderId: 'GPA.3312-1111-2222-33333',
  acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
  externalAccountIdentifiers: { obfuscatedExternalAccountId: 'tok' },
  lineItems: [
    {
      productId: 'aura_plus_monthly',
      expiryTime: new Date(at(27)).toISOString(),
      autoRenewingPlan: { autoRenewEnabled: true },
      offerDetails: { basePlanId: 'monthly', offerId: 'first-month-free' },
      ...li,
    },
  ],
  ...over,
});

describe('Google subscription → state', () => {
  it('first order on the free-month offer: trial, needs acknowledgement', () => {
    expect(googleSubscriptionSnapshot(gsub(), 'T', NOW)).toMatchObject({ state: 'trial', autoRenew: true, needsAcknowledge: true, accountToken: 'tok' });
  });
  it('renewal order (..0): active; offerPhase wins when present', () => {
    expect(googleSubscriptionSnapshot(gsub({ latestOrderId: 'GPA.3312-1111-2222-33333..0' }), 'T', NOW).state).toBe('active');
    expect(googleSubscriptionSnapshot(gsub({}, { offerPhase: { basePrice: {} } }), 'T', NOW).state).toBe('active');
    expect(googleSubscriptionSnapshot(gsub({}, { offerPhase: { freeTrial: {} }, offerDetails: {} }), 'T', NOW).state).toBe('trial');
  });
  it('pending (UPI mandate): pending, nothing granted', () => {
    expect(googleSubscriptionSnapshot(gsub({ subscriptionState: 'SUBSCRIPTION_STATE_PENDING' }), 'T', NOW)).toMatchObject({
      state: 'pending',
      needsAcknowledge: false,
    });
  });
  it('cancelled: on until expiry with auto-renew off, then expired', () => {
    expect(googleSubscriptionSnapshot(gsub({ subscriptionState: 'SUBSCRIPTION_STATE_CANCELED' }), 'T', NOW)).toMatchObject({ state: 'trial', autoRenew: false });
    expect(
      googleSubscriptionSnapshot(gsub({ subscriptionState: 'SUBSCRIPTION_STATE_CANCELED' }, { expiryTime: new Date(at(-1)).toISOString() }), 'T', NOW).state,
    ).toBe('expired');
  });
  it('grace, account hold, paused, expired, revoked; sandbox for test purchases; upgrade link kept', () => {
    expect(googleSubscriptionSnapshot(gsub({ subscriptionState: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' }), 'T', NOW).state).toBe('grace');
    expect(googleSubscriptionSnapshot(gsub({ subscriptionState: 'SUBSCRIPTION_STATE_ON_HOLD' }), 'T', NOW).state).toBe('billing_retry');
    expect(googleSubscriptionSnapshot(gsub({ subscriptionState: 'SUBSCRIPTION_STATE_PAUSED' }), 'T', NOW).state).toBe('paused');
    expect(googleSubscriptionSnapshot(gsub({ subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED' }), 'T', NOW).state).toBe('expired');
    expect(googleSubscriptionSnapshot(gsub(), 'T', NOW, { revoked: true }).state).toBe('revoked');
    expect(googleSubscriptionSnapshot(gsub({ testPurchase: {} }), 'T', NOW).environment).toBe('sandbox');
    expect(googleSubscriptionSnapshot(gsub({ linkedPurchaseToken: 'OLD' }), 'T', NOW).linkedStoreRef).toBe('OLD');
  });
  it('one-time: purchased / pending / cancelled', () => {
    expect(googlePurchaseSnapshot({ purchaseState: 0, acknowledgementState: 0 }, 'gift_warm_tea', 'T')).toMatchObject({ state: 'completed', needsAcknowledge: true });
    expect(googlePurchaseSnapshot({ purchaseState: 2 }, 'gift_warm_tea', 'T')?.state).toBe('pending');
    expect(googlePurchaseSnapshot({ purchaseState: 1 }, 'gift_warm_tea', 'T')).toBeNull();
  });
});

const facts = (over: Partial<SubscriptionFacts> = {}): SubscriptionFacts => ({
  id: 's1',
  store: 'apple',
  productId: 'aura_plus_monthly',
  state: 'trial',
  autoRenew: true,
  trialEndsAt: new Date(at(25)),
  expiresAt: new Date(at(25)),
  graceEndsAt: null,
  updatedAt: NOW,
  ...over,
});

describe('entitlement', () => {
  it('Plus is on in trial, active and grace; off in billing retry, expired, refunded, revoked, pending, paused', () => {
    expect(plusUntil(facts(), NOW)).not.toBeNull();
    expect(plusUntil(facts({ state: 'active' }), NOW)).not.toBeNull();
    expect(plusUntil(facts({ state: 'grace', expiresAt: new Date(at(-1)), graceEndsAt: new Date(at(5)) }), NOW)?.getTime()).toBe(at(5));
    for (const state of ['billing_retry', 'expired', 'refunded', 'revoked', 'pending', 'paused'] as const) {
      expect(plusUntil(facts({ state }), NOW)).toBeNull();
    }
    // a period that ran out without a store event is off too
    expect(plusUntil(facts({ state: 'active', expiresAt: new Date(at(-1)) }), NOW)).toBeNull();
  });
  it('several subscriptions: the longest-running one wins; none → the latest for the status line', () => {
    const e = computePlus([facts({ id: 'a', expiresAt: new Date(at(3)) }), facts({ id: 'b', state: 'active', expiresAt: new Date(at(300)) })], NOW);
    expect(e).toMatchObject({ active: true, subscription: { id: 'b' } });
    const off = computePlus([facts({ id: 'x', state: 'expired', updatedAt: new Date(at(-9)) }), facts({ id: 'y', state: 'refunded', updatedAt: new Date(at(-1)) })], NOW);
    expect(off).toMatchObject({ active: false, until: null, subscription: { id: 'y' } });
  });
  it('display status: cancelled = on with auto-renew off', () => {
    expect(displayStatus(facts({ autoRenew: false }), NOW)).toBe('cancelled');
    expect(displayStatus(facts({ state: 'active' }), NOW)).toBe('active');
    expect(displayStatus(null, NOW)).toBe('none');
    expect(displayStatus(facts({ expiresAt: new Date(at(-1)) }), NOW)).toBe('expired');
  });
});

describe('in-app notices (PRD 12 / 14-states)', () => {
  it('trial ending: only inside the last 48 h, with the store price', () => {
    expect(noticesFor(facts({ trialEndsAt: new Date(at(3)), expiresAt: new Date(at(3)) }), NOW, '₹49.00')).toEqual([]);
    const n = noticesFor(facts({ trialEndsAt: new Date(at(1.5)), expiresAt: new Date(at(1.5)) }), NOW, '₹49.00');
    expect(n).toHaveLength(1);
    expect(n[0]).toMatchObject({ kind: 'trial_ending', price: '₹49.00' });
  });
  it('auto-renew off in the trial: the "you won’t be charged" note instead, never the reminder', () => {
    const n = noticesFor(facts({ autoRenew: false, trialEndsAt: new Date(at(1)), expiresAt: new Date(at(1)) }), NOW, '₹49.00');
    expect(n.map((x) => x.kind)).toEqual(['trial_cancelled']);
  });
  it('grace → billing issue banner; billing retry → paused; refunded; trial converted → plus_continues', () => {
    expect(noticesFor(facts({ state: 'grace', expiresAt: new Date(at(-1)), graceEndsAt: new Date(at(4)) }), NOW, null)[0].kind).toBe('billing_issue');
    expect(noticesFor(facts({ state: 'billing_retry' }), NOW, null)[0].kind).toBe('billing_paused');
    expect(noticesFor(facts({ state: 'refunded' }), NOW, null)[0].kind).toBe('refunded');
    expect(noticesFor(facts({ state: 'active', trialEndsAt: new Date(at(-2)), expiresAt: new Date(at(28)) }), NOW, null)[0].kind).toBe('plus_continues');
  });
});
