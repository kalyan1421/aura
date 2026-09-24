import type { AppleRenewalInfo, AppleTransaction } from './apple/apple-types';
import { GOOGLE_TRIAL_OFFER_ID } from './catalogue';
import type { GoogleProductPurchase, GoogleSubscriptionV2 } from './google/play-types';

/**
 * Subscription states (PRD 10-data-model `subscriptions.state`, 14-states "Paywall, trial and store") as pure
 * functions of what the store says, so every transition is unit-tested without a store or a DB:
 *   pending        — bought, not confirmed yet (UPI mandate / Ask to Buy / Play pending): nothing granted;
 *   trial          — the introductory free month: Plus on until the store converts or lapses it;
 *   active         — paid period;
 *   grace          — renewal failed, the store's grace period: Plus stays on until `graceEndsAt`;
 *   billing_retry  — after grace (Apple billing retry / Play account hold): Plus paused until the store renews;
 *   paused         — Play "pause" (not offered by Aura, handled anyway): off;
 *   expired        — lapsed or cancelled and past the period end: off, nothing made is lost;
 *   refunded       — refunded by the store: off;
 *   revoked        — revoked by the store (family sharing removed, Play revocation): off.
 * "Cancelled" is not a state: it is trial/active with `autoRenew = false` — Plus stays on until the period ends
 * (`displayStatus` → `cancelled`).
 */
export const SUB_STATES = ['pending', 'trial', 'active', 'grace', 'billing_retry', 'paused', 'expired', 'refunded', 'revoked'] as const;
export type SubState = (typeof SUB_STATES)[number];
export type Store = 'apple' | 'google';
export type Environment = 'production' | 'sandbox';

/** What one store says about one subscription right now. */
export interface SubscriptionSnapshot {
  store: Store;
  /** Apple originalTransactionId · Google purchaseToken. */
  storeRef: string;
  productId: string;
  environment: Environment;
  state: SubState;
  autoRenew: boolean;
  startedAt: Date | null;
  trialEndsAt: Date | null;
  expiresAt: Date | null;
  graceEndsAt: Date | null;
  revokedAt: Date | null;
  latestTransactionId: string | null;
  /** Google: the purchase token this one replaced (upgrade / downgrade). */
  linkedStoreRef: string | null;
  /** The store's event time of this snapshot (ordering guard). */
  eventAt: Date | null;
  /** appAccountToken / obfuscatedExternalAccountId (the user-derived token), if the store has one. */
  accountToken: string | null;
  /** Google: still to be acknowledged (within 3 days, else Google refunds it). */
  needsAcknowledge?: boolean;
}

export type PurchaseState = 'pending' | 'completed' | 'refunded' | 'revoked';

export interface PurchaseSnapshot {
  store: Store;
  /** Apple transactionId · Google purchaseToken. */
  storeRef: string;
  orderId: string | null;
  productId: string;
  environment: Environment;
  state: PurchaseState;
  purchasedAt: Date | null;
  refundedAt: Date | null;
  eventAt: Date | null;
  accountToken: string | null;
  /** Google only: still to be acknowledged / consumed. */
  needsAcknowledge?: boolean;
  consumed?: boolean;
}

const ms = (v: number | string | undefined | null): Date | null => {
  if (v === undefined || v === null || v === '') return null;
  const n = typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : v;
  const d = new Date(n as number | string);
  return Number.isNaN(d.getTime()) ? null : d;
};

export const appleEnvironment = (env: string | undefined): Environment => (env === 'Production' ? 'production' : 'sandbox');

/** Apple's introductory free month (offerType 1 = introductory; FREE_TRIAL, or a zero price on older payloads). */
export const isAppleTrial = (t: AppleTransaction): boolean =>
  t.offerType === 1 && (t.offerDiscountType === 'FREE_TRIAL' || t.offerDiscountType === undefined || t.price === 0);

/**
 * Apple subscription → snapshot. `status` is the App Store's own verdict when it has one (notification `data.status`
 * or the Get All Subscription Statuses item: 1 active, 2 expired, 3 billing retry, 4 grace, 5 revoked); without it
 * (a client-delivered transaction alone) it is derived from the dates. `notificationType` REVOKE marks a revocation
 * (family sharing) apart from a refund.
 */
export function appleSubscriptionSnapshot(
  tx: AppleTransaction,
  renewal: AppleRenewalInfo | null,
  status: number | null,
  now: Date,
  opts: { notificationType?: string; eventAt?: Date | null } = {},
): SubscriptionSnapshot {
  const expiresAt = ms(tx.expiresDate);
  const graceEndsAt = ms(renewal?.gracePeriodExpiresDate);
  const trial = isAppleTrial(tx);
  const live: SubState = trial ? 'trial' : 'active';
  let state: SubState;
  const revokedAt = ms(tx.revocationDate);
  if (revokedAt) state = opts.notificationType === 'REVOKE' || status === 5 && tx.revocationReason === undefined ? 'revoked' : 'refunded';
  else if (status === 1) state = live;
  else if (status === 2) state = 'expired';
  else if (status === 3) state = 'billing_retry';
  else if (status === 4) state = graceEndsAt ? 'grace' : 'billing_retry';
  else if (status === 5) state = 'revoked';
  else if (expiresAt && expiresAt > now) state = live;
  else if (renewal?.isInBillingRetryPeriod) state = graceEndsAt && graceEndsAt > now ? 'grace' : 'billing_retry';
  else state = 'expired';
  return {
    store: 'apple',
    storeRef: tx.originalTransactionId,
    productId: tx.productId,
    environment: appleEnvironment(tx.environment),
    state,
    autoRenew: renewal ? renewal.autoRenewStatus === 1 : state === 'trial' || state === 'active',
    startedAt: ms(tx.originalPurchaseDate) ?? ms(tx.purchaseDate),
    trialEndsAt: trial ? expiresAt : null,
    expiresAt,
    graceEndsAt: state === 'grace' ? graceEndsAt : null,
    revokedAt,
    latestTransactionId: tx.transactionId,
    linkedStoreRef: null,
    eventAt: opts.eventAt ?? ms(tx.signedDate) ?? null,
    accountToken: tx.appAccountToken ?? renewal?.appAccountToken ?? null,
  };
}

/** Apple one-time purchase (cosmetic / gift) → snapshot. */
export function applePurchaseSnapshot(tx: AppleTransaction, eventAt: Date | null = null): PurchaseSnapshot {
  const refundedAt = ms(tx.revocationDate);
  return {
    store: 'apple',
    storeRef: tx.transactionId,
    orderId: null,
    productId: tx.productId,
    environment: appleEnvironment(tx.environment),
    state: refundedAt ? 'refunded' : 'completed',
    purchasedAt: ms(tx.purchaseDate),
    refundedAt,
    eventAt: eventAt ?? ms(tx.signedDate),
    accountToken: tx.appAccountToken ?? null,
  };
}

/** Google renewal order ids end in `..N` (`GPA.1234-…..0` is the first renewal): the first period has none. */
const isRenewalOrder = (orderId: string | undefined): boolean => !!orderId && /\.\.\d+$/.test(orderId);

/** Google's free month: the `freeTrial` offer phase, else the trial offer on the first (non-renewal) order. */
export function isGoogleTrial(sub: GoogleSubscriptionV2): boolean {
  const li = sub.lineItems?.[0];
  if (!li) return false;
  if (li.offerPhase) return li.offerPhase.freeTrial !== undefined;
  const offer = li.offerDetails;
  const trialOffer = offer?.offerId === GOOGLE_TRIAL_OFFER_ID || (offer?.offerTags ?? []).includes('free-month');
  return trialOffer && !isRenewalOrder(sub.latestOrderId);
}

/**
 * Google subscriptionsv2 → snapshot. `revoked` marks an RTDN SUBSCRIPTION_REVOKED (a refund that ends access now).
 */
export function googleSubscriptionSnapshot(
  sub: GoogleSubscriptionV2,
  purchaseToken: string,
  now: Date,
  opts: { revoked?: boolean; eventAt?: Date | null } = {},
): SubscriptionSnapshot {
  const li = sub.lineItems?.[0];
  const expiresAt = ms(li?.expiryTime);
  const trial = isGoogleTrial(sub);
  const live: SubState = trial ? 'trial' : 'active';
  let state: SubState;
  switch (sub.subscriptionState) {
    case 'SUBSCRIPTION_STATE_PENDING':
      state = 'pending';
      break;
    case 'SUBSCRIPTION_STATE_ACTIVE':
      state = live;
      break;
    case 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD':
      state = 'grace';
      break;
    case 'SUBSCRIPTION_STATE_ON_HOLD':
      state = 'billing_retry';
      break;
    case 'SUBSCRIPTION_STATE_PAUSED':
      state = 'paused';
      break;
    case 'SUBSCRIPTION_STATE_CANCELED':
      state = expiresAt && expiresAt > now ? live : 'expired';
      break;
    default:
      state = 'expired';
  }
  if (opts.revoked) state = 'revoked';
  const autoRenew = sub.subscriptionState === 'SUBSCRIPTION_STATE_CANCELED' ? false : li?.autoRenewingPlan?.autoRenewEnabled ?? false;
  return {
    store: 'google',
    storeRef: purchaseToken,
    productId: li?.productId ?? '',
    environment: sub.testPurchase ? 'sandbox' : 'production',
    state,
    autoRenew,
    startedAt: ms(sub.startTime),
    trialEndsAt: trial ? expiresAt : null,
    expiresAt,
    graceEndsAt: state === 'grace' ? expiresAt : null,
    revokedAt: opts.revoked ? now : null,
    latestTransactionId: sub.latestOrderId ?? null,
    linkedStoreRef: sub.linkedPurchaseToken ?? null,
    eventAt: opts.eventAt ?? null,
    accountToken: sub.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null,
    needsAcknowledge: sub.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING' && (state === 'trial' || state === 'active' || state === 'grace'),
  };
}

/** Google one-time purchase → snapshot (`null` when the purchase was cancelled before it completed). */
export function googlePurchaseSnapshot(p: GoogleProductPurchase, productId: string, purchaseToken: string): PurchaseSnapshot | null {
  if (p.purchaseState === 1) return null;
  const state: PurchaseState = p.purchaseState === 2 ? 'pending' : 'completed';
  return {
    store: 'google',
    storeRef: purchaseToken,
    orderId: p.orderId ?? null,
    productId,
    environment: p.purchaseType === 0 ? 'sandbox' : 'production',
    state,
    purchasedAt: ms(p.purchaseTimeMillis),
    refundedAt: null,
    eventAt: null,
    accountToken: p.obfuscatedExternalAccountId ?? null,
    needsAcknowledge: state === 'completed' && p.acknowledgementState !== 1,
    consumed: p.consumptionState === 1,
  };
}

// ------------------------------------------------------------------------------------------------ entitlement

/** A stored subscription row as the entitlement logic needs it. */
export interface SubscriptionFacts {
  id: string;
  store: Store;
  productId: string;
  state: SubState;
  autoRenew: boolean;
  trialEndsAt: Date | null;
  expiresAt: Date | null;
  graceEndsAt: Date | null;
  updatedAt: Date;
}

/** Until when this subscription gives Plus, or null when it gives none right now. */
export function plusUntil(s: SubscriptionFacts, now: Date): Date | null {
  if ((s.state === 'trial' || s.state === 'active') && s.expiresAt && s.expiresAt > now) return s.expiresAt;
  if (s.state === 'grace' && s.graceEndsAt && s.graceEndsAt > now) return s.graceEndsAt;
  return null;
}

export interface PlusEntitlement {
  active: boolean;
  /** The subscription the view describes: the one giving Plus, else the most recently changed one. */
  subscription: SubscriptionFacts | null;
  until: Date | null;
}

/** Plus is on while any owned subscription gives it; the longest-running one wins. */
export function computePlus(subs: readonly SubscriptionFacts[], now: Date): PlusEntitlement {
  let best: { s: SubscriptionFacts; until: Date } | null = null;
  for (const s of subs) {
    const until = plusUntil(s, now);
    if (until && (!best || until > best.until)) best = { s, until };
  }
  if (best) return { active: true, subscription: best.s, until: best.until };
  const latest = [...subs].filter((s) => s.state !== 'pending' || subs.length === 1).sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime())[0] ?? null;
  return { active: false, subscription: latest, until: null };
}

export type DisplayStatus = 'none' | 'pending' | 'trial' | 'active' | 'cancelled' | 'grace' | 'billing_retry' | 'paused' | 'expired' | 'refunded' | 'revoked';

/** What the app shows (14-states): trial/active with auto-renew off is "cancelled" (Plus on until the period ends). */
export function displayStatus(s: SubscriptionFacts | null, now: Date): DisplayStatus {
  if (!s) return 'none';
  if ((s.state === 'trial' || s.state === 'active') && !plusUntil(s, now)) return 'expired';
  if (s.state === 'grace' && !plusUntil(s, now)) return 'billing_retry';
  if ((s.state === 'trial' || s.state === 'active') && !s.autoRenew) return 'cancelled';
  return s.state;
}

/** PRD 12 / 14: the trial-ending reminder window (48 h before the free month ends). */
export const TRIAL_REMINDER_LEAD_MS = 48 * 3600_000;

export type NoticeKind = 'trial_ending' | 'trial_cancelled' | 'billing_issue' | 'billing_paused' | 'refunded' | 'plus_continues';

export interface Notice {
  kind: NoticeKind;
  /** The date the copy names (trial end / period end), when it names one. */
  date: Date | null;
  /** The store's localized price string, for the trial-ending card. */
  price: string | null;
  /** Stable per event, so the app can show a one-time note once (subscription id + kind + date). */
  key: string;
}

/** In-app notices for the subscription the entitlement describes (PRD 12 "Billing issue", 14-states). */
export function noticesFor(s: SubscriptionFacts | null, now: Date, price: string | null): Notice[] {
  if (!s) return [];
  const key = (kind: NoticeKind, d: Date | null): string => `${s.id}:${kind}:${d ? d.toISOString().slice(0, 10) : ''}`;
  const out: Notice[] = [];
  const until = plusUntil(s, now);
  if (s.state === 'trial' && until) {
    if (!s.autoRenew) out.push({ kind: 'trial_cancelled', date: s.trialEndsAt ?? s.expiresAt, price: null, key: key('trial_cancelled', s.trialEndsAt ?? s.expiresAt) });
    else if (s.trialEndsAt && s.trialEndsAt.getTime() - now.getTime() <= TRIAL_REMINDER_LEAD_MS) {
      out.push({ kind: 'trial_ending', date: s.trialEndsAt, price, key: key('trial_ending', s.trialEndsAt) });
    }
  }
  if (s.state === 'grace' && until) out.push({ kind: 'billing_issue', date: s.graceEndsAt, price: null, key: key('billing_issue', s.graceEndsAt) });
  if (s.state === 'billing_retry' || (s.state === 'grace' && !until)) out.push({ kind: 'billing_paused', date: null, price: null, key: key('billing_paused', s.expiresAt) });
  if (s.state === 'refunded' || s.state === 'revoked') out.push({ kind: 'refunded', date: null, price: null, key: key('refunded', s.expiresAt) });
  if (s.state === 'active' && until && s.trialEndsAt && s.trialEndsAt <= now && now.getTime() - s.trialEndsAt.getTime() < 14 * 86_400_000) {
    out.push({ kind: 'plus_continues', date: null, price: null, key: key('plus_continues', s.trialEndsAt) });
  }
  return out;
}
