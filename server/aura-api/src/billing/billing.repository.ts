import type { Queryable } from '../db/db';
import type { PurchaseSnapshot, SubscriptionFacts, SubscriptionSnapshot, SubState } from './state';

/** Plain SQL for F12 (service role). Callers hold the per-user lock (`lockUser`) around read-then-write paths. */

export interface SubscriptionRow {
  id: string;
  owner_user_id: string | null;
  store: 'apple' | 'google';
  store_ref: string;
  product_id: string;
  environment: 'production' | 'sandbox';
  state: SubState;
  auto_renew: boolean;
  trial_ends_at: Date | null;
  expires_at: Date | null;
  grace_ends_at: Date | null;
  price_display: string | null;
  acknowledged_at: Date | null;
  last_event_at: Date | null;
  verified_at: Date | null;
  updated_at: Date;
}

export interface PurchaseRow {
  id: string;
  owner_user_id: string | null;
  store: 'apple' | 'google';
  store_ref: string;
  product_id: string;
  kind: 'cosmetic' | 'gift';
  environment: 'production' | 'sandbox';
  state: 'pending' | 'completed' | 'refunded' | 'revoked';
  acknowledged_at: Date | null;
  consumed_at: Date | null;
  refunded_at: Date | null;
}

const SUB_COLS = `id, owner_user_id, store, store_ref, product_id, environment, state, auto_renew, trial_ends_at, expires_at,
  grace_ends_at, price_display, acknowledged_at, last_event_at, verified_at, updated_at`;
const PURCHASE_COLS = 'id, owner_user_id, store, store_ref, product_id, kind, environment, state, acknowledged_at, consumed_at, refunded_at';

// ------------------------------------------------------------------------------------------------ accounts

export async function ensureBillingAccount(q: Queryable, userId: string, token: string): Promise<void> {
  await q.query('insert into public.billing_accounts (user_id, account_token) values ($1, $2) on conflict (user_id) do nothing', [
    userId,
    token,
  ]);
}

export async function userForToken(q: Queryable, token: string | null): Promise<string | null> {
  if (!token || !/^[0-9a-f-]{36}$/i.test(token)) return null;
  const r = await q.query<{ user_id: string }>('select user_id from public.billing_accounts where account_token = $1', [token.toLowerCase()]);
  return r.rows[0]?.user_id ?? null;
}

/** Deletion pending or purged → not a live account (nothing is granted to it; its purchases wait unowned). */
export async function isLiveAccount(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query<{ live: boolean }>(
    `select exists (select 1 from auth.users where id = $1)
        and not exists (select 1 from public.account_deletions where user_id = $1) as live`,
    [userId],
  );
  return r.rows[0]?.live ?? false;
}

// ------------------------------------------------------------------------------------------------ subscriptions

export async function subscriptionByRef(q: Queryable, store: string, ref: string, forUpdate = false): Promise<SubscriptionRow | null> {
  const r = await q.query<SubscriptionRow>(
    `select ${SUB_COLS} from public.subscriptions where store = $1 and store_ref = $2${forUpdate ? ' for update' : ''}`,
    [store, ref],
  );
  return r.rows[0] ?? null;
}

export async function subscriptionById(q: Queryable, id: string): Promise<SubscriptionRow | null> {
  const r = await q.query<SubscriptionRow>(`select ${SUB_COLS} from public.subscriptions where id = $1`, [id]);
  return r.rows[0] ?? null;
}

export interface UpsertSubOptions {
  owner: string | null;
  priceDisplay?: string | null;
  /** Confirmed with the store's server API now (stamps verified_at; bypasses the ordering guard). */
  verified?: boolean;
}

/**
 * Inserts or updates a subscription from a store snapshot. Ordering guard: a snapshot older than the one applied last
 * (`eventAt < last_event_at`) changes nothing — unless it was just read from the store API (`verified`), which is
 * always current. The owner is set only where there is none (transfers are explicit, see `setSubscriptionOwner`).
 * Returns the row and whether it changed.
 */
export async function upsertSubscription(
  q: Queryable,
  s: SubscriptionSnapshot,
  o: UpsertSubOptions,
): Promise<{ row: SubscriptionRow; applied: boolean }> {
  const r = await q.query<SubscriptionRow & { applied: boolean }>(
    `insert into public.subscriptions as s (owner_user_id, store, store_ref, product_id, environment, state, auto_renew,
        started_at, trial_ends_at, expires_at, grace_ends_at, revoked_at, latest_transaction_id, linked_store_ref,
        price_display, last_event_at, verified_at, cancelled_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, case when $17 then now() end,
             case when not $7 then now() end)
     on conflict (store, store_ref) do update set
        owner_user_id = coalesce(s.owner_user_id, excluded.owner_user_id),
        product_id = excluded.product_id,
        environment = excluded.environment,
        state = excluded.state,
        auto_renew = excluded.auto_renew,
        started_at = coalesce(s.started_at, excluded.started_at),
        trial_ends_at = coalesce(excluded.trial_ends_at, s.trial_ends_at),
        expires_at = excluded.expires_at,
        grace_ends_at = excluded.grace_ends_at,
        revoked_at = coalesce(excluded.revoked_at, case when excluded.state in ('refunded','revoked') then s.revoked_at end),
        latest_transaction_id = coalesce(excluded.latest_transaction_id, s.latest_transaction_id),
        linked_store_ref = coalesce(excluded.linked_store_ref, s.linked_store_ref),
        price_display = coalesce(excluded.price_display, s.price_display),
        last_event_at = greatest(s.last_event_at, excluded.last_event_at),
        verified_at = coalesce(excluded.verified_at, s.verified_at),
        cancelled_at = case when excluded.auto_renew then null else coalesce(s.cancelled_at, now()) end,
        updated_at = now()
      where $17 or excluded.last_event_at is null or s.last_event_at is null or excluded.last_event_at >= s.last_event_at
     returning ${SUB_COLS.split(',').map((c) => `s.${c.trim()}`).join(', ')}, true as applied`,
    [
      o.owner,
      s.store,
      s.storeRef,
      s.productId,
      s.environment,
      s.state,
      s.autoRenew,
      s.startedAt,
      s.trialEndsAt,
      s.expiresAt,
      s.graceEndsAt,
      s.revokedAt,
      s.latestTransactionId,
      s.linkedStoreRef,
      o.priceDisplay ?? null,
      s.eventAt,
      o.verified === true,
    ],
  );
  if (r.rows[0]) return { row: r.rows[0], applied: true };
  const row = await subscriptionByRef(q, s.store, s.storeRef);
  if (!row) throw new Error('subscription vanished');
  // Not applied (older snapshot) — still record a missing owner / price.
  if ((o.owner && !row.owner_user_id) || (o.priceDisplay && !row.price_display)) {
    await q.query(
      `update public.subscriptions set owner_user_id = coalesce(owner_user_id, $2), price_display = coalesce(price_display, $3)
        where id = $1`,
      [row.id, o.owner, o.priceDisplay ?? null],
    );
    return { row: { ...row, owner_user_id: row.owner_user_id ?? o.owner, price_display: row.price_display ?? o.priceDisplay ?? null }, applied: false };
  }
  return { row, applied: false };
}

export async function setSubscriptionOwner(q: Queryable, id: string, owner: string | null): Promise<void> {
  await q.query('update public.subscriptions set owner_user_id = $2, updated_at = now() where id = $1', [id, owner]);
}

export async function markAcknowledged(q: Queryable, table: 'subscriptions' | 'purchases', id: string): Promise<void> {
  await q.query(`update public.${table} set acknowledged_at = coalesce(acknowledged_at, now()) where id = $1`, [id]);
}

/** Google upgrade / downgrade: the replaced subscription ends now (its token stays for the record). */
export async function retireReplaced(q: Queryable, store: 'google', linkedRef: string): Promise<string | null> {
  const r = await q.query<{ owner_user_id: string | null }>(
    `update public.subscriptions set state = 'expired', auto_renew = false, updated_at = now()
      where store = $1 and store_ref = $2 and state not in ('expired','refunded','revoked')
      returning owner_user_id`,
    [store, linkedRef],
  );
  return r.rows[0]?.owner_user_id ?? null;
}

export interface OwnedSubscription extends SubscriptionFacts {
  priceDisplay: string | null;
}

export async function ownedSubscriptions(q: Queryable, userId: string): Promise<OwnedSubscription[]> {
  const r = await q.query<SubscriptionRow>(`select ${SUB_COLS} from public.subscriptions where owner_user_id = $1`, [userId]);
  return r.rows.map((x) => ({
    id: x.id,
    store: x.store,
    productId: x.product_id,
    state: x.state,
    autoRenew: x.auto_renew,
    trialEndsAt: x.trial_ends_at,
    expiresAt: x.expires_at,
    graceEndsAt: x.grace_ends_at,
    updatedAt: x.updated_at,
    priceDisplay: x.price_display,
  }));
}

export async function writeEntitlement(
  q: Queryable,
  userId: string,
  e: { active: boolean; sub: SubscriptionFacts | null; until: Date | null },
): Promise<void> {
  await q.query(
    `insert into public.entitlements as e (user_id, plus_active, plus_state, plus_until, plus_store, plus_product_id,
        plus_auto_renew, plus_trial_ends_at, plus_subscription_id, updated_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
     on conflict (user_id) do update set plus_active = excluded.plus_active, plus_state = excluded.plus_state,
        plus_until = excluded.plus_until, plus_store = excluded.plus_store, plus_product_id = excluded.plus_product_id,
        plus_auto_renew = excluded.plus_auto_renew, plus_trial_ends_at = excluded.plus_trial_ends_at,
        plus_subscription_id = excluded.plus_subscription_id, updated_at = now()`,
    [
      userId,
      e.active,
      e.sub?.state ?? null,
      e.until,
      e.sub?.store ?? null,
      e.sub?.productId ?? null,
      e.sub?.autoRenew ?? null,
      e.sub?.trialEndsAt ?? null,
      e.sub?.id ?? null,
    ],
  );
}

// ------------------------------------------------------------------------------------------------ purchases

export async function purchaseByRef(q: Queryable, store: string, ref: string, forUpdate = false): Promise<PurchaseRow | null> {
  const r = await q.query<PurchaseRow>(
    `select ${PURCHASE_COLS} from public.purchases where store = $1 and store_ref = $2${forUpdate ? ' for update' : ''}`,
    [store, ref],
  );
  return r.rows[0] ?? null;
}

/** Inserts / updates a one-time purchase. Never moves a refunded purchase back to completed (except `reinstate`). */
export async function upsertPurchase(
  q: Queryable,
  p: PurchaseSnapshot,
  kind: 'cosmetic' | 'gift',
  owner: string | null,
  opts: { reinstate?: boolean } = {},
): Promise<{ row: PurchaseRow; previous: PurchaseRow['state'] | null }> {
  const before = await purchaseByRef(q, p.store, p.storeRef, true);
  const r = await q.query<PurchaseRow>(
    `insert into public.purchases as p (owner_user_id, store, store_ref, order_id, product_id, kind, environment, state,
        purchased_at, refunded_at, last_event_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     on conflict (store, store_ref) do update set
        owner_user_id = coalesce(p.owner_user_id, excluded.owner_user_id),
        order_id = coalesce(excluded.order_id, p.order_id),
        state = case when p.state in ('refunded','revoked') and not $12 then p.state else excluded.state end,
        purchased_at = coalesce(p.purchased_at, excluded.purchased_at),
        refunded_at = case when $12 then excluded.refunded_at else coalesce(p.refunded_at, excluded.refunded_at) end,
        last_event_at = greatest(p.last_event_at, excluded.last_event_at),
        updated_at = now()
     returning ${PURCHASE_COLS}`,
    [owner, p.store, p.storeRef, p.orderId, p.productId, kind, p.environment, p.state, p.purchasedAt, p.refundedAt, p.eventAt, opts.reinstate === true],
  );
  return { row: r.rows[0], previous: before?.state ?? null };
}

export async function setPurchaseOwner(q: Queryable, id: string, owner: string): Promise<void> {
  await q.query('update public.purchases set owner_user_id = $2, updated_at = now() where id = $1', [id, owner]);
}

export async function markConsumed(q: Queryable, id: string): Promise<void> {
  await q.query('update public.purchases set consumed_at = coalesce(consumed_at, now()), acknowledged_at = coalesce(acknowledged_at, now()) where id = $1', [id]);
}

// ------------------------------------------------------------------------------------------------ cosmetics, Stardust

export async function grantCosmetic(q: Queryable, userId: string, cosmeticId: string, purchaseId: string): Promise<void> {
  await q.query(
    `insert into public.user_cosmetics (user_id, cosmetic_id, source, purchase_id) values ($1, $2, 'purchase', $3)
     on conflict (user_id, cosmetic_id) do nothing`,
    [userId, cosmeticId, purchaseId],
  );
}

/** A refunded store cosmetic is removed (PRD "Cosmetic refunded → removed"); one redeemed with Stardust stays. */
export async function removeCosmeticForPurchase(q: Queryable, purchaseId: string): Promise<string | null> {
  const r = await q.query<{ user_id: string; cosmetic_id: string }>(
    "delete from public.user_cosmetics where purchase_id = $1 and source = 'purchase' returning user_id, cosmetic_id",
    [purchaseId],
  );
  const row = r.rows[0];
  if (row) {
    await q.query('delete from public.sky_preferences where user_id = $1 and sky_theme = $2', [row.user_id, row.cosmetic_id]);
  }
  return row?.user_id ?? null;
}

export async function ownedCosmetics(q: Queryable, userId: string): Promise<string[]> {
  const r = await q.query<{ cosmetic_id: string }>('select cosmetic_id from public.user_cosmetics where user_id = $1 order by acquired_at', [userId]);
  return r.rows.map((x) => x.cosmetic_id);
}

export async function stardustBalance(q: Queryable, userId: string): Promise<number> {
  const r = await q.query<{ n: number }>('select coalesce(sum(amount), 0)::int as n from public.stardust_ledger where user_id = $1', [userId]);
  return r.rows[0]?.n ?? 0;
}

export async function skyPreference(q: Queryable, userId: string): Promise<{ sky: string; soundscape: string | null } | null> {
  const r = await q.query<{ sky_theme: string; soundscape: string | null }>(
    'select sky_theme, soundscape from public.sky_preferences where user_id = $1',
    [userId],
  );
  return r.rows[0] ? { sky: r.rows[0].sky_theme, soundscape: r.rows[0].soundscape } : null;
}

// ------------------------------------------------------------------------------------------------ store notifications

export interface StoredNotification {
  id: string;
  store: 'apple' | 'google';
  notification_id: string;
  notification_type: string;
  payload: string;
  status: 'received' | 'processed' | 'ignored' | 'failed';
  attempts: number;
}

/** Logs a verified notification once. `inserted=false` = a duplicate (already logged). */
export async function logNotification(
  q: Queryable,
  n: {
    store: 'apple' | 'google';
    notificationId: string;
    type: string;
    subtype: string | null;
    environment: 'production' | 'sandbox' | null;
    signedAt: Date | null;
    payload: string;
    storeRef: string | null;
  },
): Promise<{ row: StoredNotification; inserted: boolean }> {
  const ins = await q.query<StoredNotification>(
    `insert into public.store_notifications (store, notification_id, notification_type, subtype, environment, signed_at, payload, store_ref)
     values ($1, $2, $3, $4, $5, $6, $7, $8)
     on conflict (store, notification_id) do nothing
     returning id, store, notification_id, notification_type, payload, status, attempts`,
    [n.store, n.notificationId, n.type.slice(0, 64), n.subtype?.slice(0, 64) ?? null, n.environment, n.signedAt, n.payload, n.storeRef],
  );
  if (ins.rows[0]) return { row: ins.rows[0], inserted: true };
  const r = await q.query<StoredNotification>(
    `select id, store, notification_id, notification_type, payload, status, attempts from public.store_notifications
      where store = $1 and notification_id = $2`,
    [n.store, n.notificationId],
  );
  return { row: r.rows[0], inserted: false };
}

export async function finishNotification(
  q: Queryable,
  id: string,
  status: 'processed' | 'ignored' | 'failed',
  error: string | null = null,
): Promise<void> {
  await q.query(
    `update public.store_notifications set status = $2, last_error = $3, attempts = attempts + 1,
            processed_at = case when $2 in ('processed','ignored') then now() else processed_at end
      where id = $1`,
    [id, status, error],
  );
}
