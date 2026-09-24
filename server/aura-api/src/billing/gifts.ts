import { ApiError, profileRequired } from '../common/api-error';
import { Logger } from '@nestjs/common';
import { pgCode, Tx, type Queryable } from '../db/db';
import { auraDay } from '../rules';
import { insertReport } from '../safety/reports.core';
import { ACTIVE_SANCTION_SQL, TARGETING_MINOR_REASON } from '../safety/safety-types';
import { blockBetween, loadSafetyConfig } from '../safety/safety.queries';
import { GIFT_RULES, giftByKind, giftByProduct, type GiftProduct } from './catalogue';
import type { PurchaseRow } from './billing.repository';

/**
 * F12 gifts (PRD 06c "Gifts", 06b "Send a gift"): checked BEFORE the store sheet — no block either way, sender
 * unsanctioned, ≤ 5 per Aura day, gifting not paused by refunds — then delivered once the store confirms the payment.
 * No message; the recipient only ever learns the kind ("Someone here sent you a Comfort Lantern") and gets Stardust.
 * Refund: the recipient keeps the Stardust (never told) and the sender's refund count grows (2 in 90 days pause
 * gifting 90 days, a 3rd disables it). 3+ gifts in 7 days from one adult to the same under-18 account open a
 * Minors & grooming review item (`gift_pattern`); the gifts still go through.
 */

const DAY_MS = 86_400_000;

export type GiftStanding =
  | { state: 'ok' }
  | { state: 'paused'; until: Date }
  | { state: 'disabled' };

/** The sender's gifting standing from their refunded gifts (pure, see billing.gifts.spec.ts). */
export function standingFromRefunds(refundedAt: readonly Date[], now: Date): GiftStanding {
  const r = [...refundedAt].sort((a, b) => a.getTime() - b.getTime());
  if (r.length >= GIFT_RULES.disableAfterRefunds) return { state: 'disabled' };
  let until: Date | null = null;
  for (let i = GIFT_RULES.pauseAfterRefunds - 1; i < r.length; i++) {
    const first = r[i - (GIFT_RULES.pauseAfterRefunds - 1)];
    if (r[i].getTime() - first.getTime() <= GIFT_RULES.refundWindowDays * DAY_MS) {
      until = new Date(r[i].getTime() + GIFT_RULES.pauseDays * DAY_MS);
    }
  }
  return until && until > now ? { state: 'paused', until } : { state: 'ok' };
}

export async function giftStanding(q: Queryable, userId: string, now: Date): Promise<GiftStanding> {
  const r = await q.query<{ refunded_at: Date }>(
    'select refunded_at from public.gifts where sender_user_id = $1 and refunded_at is not null',
    [userId],
  );
  return standingFromRefunds(r.rows.map((x) => x.refunded_at), now);
}

/** Active sanctions other than a warning mean "not unsanctioned" (PRD: "sender unsanctioned"). */
export async function senderSanctioned(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query(
    `select 1 from public.sanctions s where s.user_id = $1 and s.kind <> 'warning' and ${ACTIVE_SANCTION_SQL('s')} limit 1`,
    [userId],
  );
  return (r.rowCount ?? 0) > 0;
}

export async function giftsSentToday(q: Queryable, userId: string, day: string): Promise<number> {
  const r = await q.query<{ n: number }>(
    `select count(*)::int as n from public.gifts where sender_user_id = $1 and sender_day = $2::date
        and status in ('checked','delivered')`,
    [userId, day],
  );
  return r.rows[0]?.n ?? 0;
}

export interface GiftCheckInput {
  giftId: string;
  roomId: string;
  memberId: string;
  kind: string;
}

export interface GiftChecked {
  giftId: string;
  productId: string;
  kind: string;
  expiresAt: string;
}

/** Refusals leave as these codes (contracts/api/v1-billing.md §4.1). A block never says so ("gift_unavailable"). */
export const giftErrors = {
  unavailable: (): ApiError => ApiError.conflict('gift_unavailable', "This gift can't be sent right now. Nothing was charged."),
  sanctioned: (): ApiError => ApiError.forbidden('gifting_unavailable', "Gifts aren't available on this account right now."),
  paused: (until: Date): ApiError =>
    ApiError.forbidden('gifting_paused', `Gifts are paused on this account until ${until.toISOString().slice(0, 10)}.`),
  disabled: (): ApiError => ApiError.forbidden('gifting_disabled', 'Gifts are turned off on this account.'),
  dailyLimit: (): ApiError => new ApiError(429, 'gift_daily_limit', 'That is 5 gifts today. You can send more tomorrow.'),
  unknownKind: (): ApiError => ApiError.badRequest('invalid_request', 'kind: unknown gift'),
};

/**
 * The pre-check (`POST /v1/billing/gifts`). Idempotent on `giftId`. Reserves one of today's 5 slots until the store
 * confirms (or the app cancels after a failed / dismissed store sheet). Caller holds the sender's advisory lock.
 */
export async function checkGift(q: Queryable, senderId: string, input: GiftCheckInput, now: Date): Promise<GiftChecked> {
  const product = giftByKind(input.kind);
  if (!product) throw giftErrors.unknownKind();
  const existing = await q.query<{ id: string; product_id: string; gift_kind: string; expires_at: Date; status: string }>(
    'select id, product_id, gift_kind, expires_at, status from public.gifts where id = $1 and sender_user_id = $2',
    [input.giftId, senderId],
  );
  if (existing.rows[0]) {
    const g = existing.rows[0];
    if (g.status === 'checked' || g.status === 'delivered') {
      return { giftId: g.id, productId: g.product_id, kind: g.gift_kind, expiresAt: g.expires_at.toISOString() };
    }
    throw giftErrors.unavailable();
  }
  const tz = (await q.query<{ timezone: string }>('select timezone from public.profiles where user_id = $1', [senderId])).rows[0]?.timezone;
  if (!tz) throw profileRequired();

  if (await senderSanctioned(q, senderId)) throw giftErrors.sanctioned();
  const standing = await giftStanding(q, senderId, now);
  if (standing.state === 'disabled') throw giftErrors.disabled();
  if (standing.state === 'paused') throw giftErrors.paused(standing.until);

  // Both people are in this live room right now; never yourself; no block either way (06b: fails before any charge).
  const members = await q.query<{ member_id: string; user_id: string }>(
    `select m.member_id, m.user_id from public.room_members m join public.rooms r on r.id = m.room_id
      where m.room_id = $1 and r.memory_at > now() and m.left_at is null
        and (m.user_id = $2 or m.member_id = $3)`,
    [input.roomId, senderId, input.memberId],
  );
  const me = members.rows.find((m) => m.user_id === senderId);
  const them = members.rows.find((m) => m.member_id === input.memberId && m.user_id !== senderId);
  if (!me || !them) throw giftErrors.unavailable();
  if (await blockBetween(q, senderId, them.user_id)) throw giftErrors.unavailable();

  const day = auraDay(now, tz);
  if ((await giftsSentToday(q, senderId, day)) >= GIFT_RULES.perDay) throw giftErrors.dailyLimit();

  const expiresAt = new Date(now.getTime() + GIFT_RULES.reservationDays * DAY_MS);
  await q.query(
    `insert into public.gifts (id, sender_user_id, recipient_user_id, recipient_member_id, room_id, gift_kind, product_id,
        stardust_amount, status, sender_day, checked_at, expires_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, 'checked', $9::date, $10, $11)`,
    [input.giftId, senderId, them.user_id, them.member_id, input.roomId, product.kind, product.productId, product.stardust, day, now, expiresAt],
  );
  return { giftId: input.giftId, productId: product.productId, kind: product.kind, expiresAt: expiresAt.toISOString() };
}

/** The store sheet was dismissed or failed: frees the day's slot. Only a still-open check can be cancelled. */
export async function cancelGift(q: Queryable, senderId: string, giftId: string): Promise<boolean> {
  const r = await q.query("update public.gifts set status = 'cancelled' where id = $1 and sender_user_id = $2 and status = 'checked'", [
    giftId,
    senderId,
  ]);
  return (r.rowCount ?? 0) > 0;
}

export type GiftDelivery = 'delivered' | 'already' | 'unmatched';

/**
 * Delivers the gift a completed store purchase paid for, inside the caller's transaction: the gift named by the app
 * (`giftId`) or else the sender's oldest open check for that product (a purchase confirmed only by a store
 * notification, e.g. an Ask to Buy approval while the app was closed). "Pending gifts deliver into the room memory":
 * a room that became a memory meanwhile still gets it. Credits the recipient's Stardust once (ledger unique key).
 */
export async function deliverGift(
  q: Queryable,
  purchase: Pick<PurchaseRow, 'id' | 'product_id'>,
  senderId: string,
  giftId: string | null,
  now: Date,
  masterKey?: Buffer,
): Promise<GiftDelivery> {
  const already = await q.query('select 1 from public.gifts where purchase_id = $1', [purchase.id]);
  if ((already.rowCount ?? 0) > 0) return 'already';
  const product = giftByProduct(purchase.product_id);
  if (!product) return 'unmatched';
  const found = giftId
    ? await q.query<GiftRow>(
        `select ${GIFT_COLS} from public.gifts where id = $1 and sender_user_id = $2 and product_id = $3
            and status in ('checked','expired') and purchase_id is null for update`,
        [giftId, senderId, product.productId],
      )
    : await q.query<GiftRow>(
        `select ${GIFT_COLS} from public.gifts where sender_user_id = $1 and product_id = $2 and status = 'checked'
            and purchase_id is null and expires_at > $3 order by checked_at limit 1 for update`,
        [senderId, product.productId, now],
      );
  const gift = found.rows[0];
  if (!gift) return 'unmatched';
  await q.query("update public.gifts set status = 'delivered', delivered_at = $2, purchase_id = $3 where id = $1", [gift.id, now, purchase.id]);
  if (gift.recipient_user_id) {
    await q.query(
      `insert into public.stardust_ledger (user_id, amount, reason, ref_id) values ($1, $2, 'gift_received', $3)
       on conflict (user_id, reason, ref_id) do nothing`,
      [gift.recipient_user_id, gift.stardust_amount, gift.id],
    );
    await flagMinorPatternIfDue(q, senderId, gift, product, now, masterKey);
  }
  return 'delivered';
}

interface GiftRow {
  id: string;
  recipient_user_id: string | null;
  recipient_member_id: string | null;
  room_id: string | null;
  stardust_amount: number;
}
const GIFT_COLS = 'id, recipient_user_id, recipient_member_id, room_id, stardust_amount';

/**
 * 3+ gifts in 7 days from one adult to the same under-18 account → one open Minors & grooming item about the sender
 * (auto signal `gift_pattern`, reason 9 "targeting a young person"). Invisible to both; aggregate-only elsewhere.
 */
async function flagMinorPatternIfDue(
  q: Queryable,
  senderId: string,
  gift: GiftRow,
  _product: GiftProduct,
  now: Date,
  _masterKey?: Buffer,
): Promise<boolean> {
  if (!gift.recipient_user_id) return false;
  const ages = await q.query<{ sender_minor: boolean; recipient_minor: boolean }>(
    'select public.user_is_minor($1) as sender_minor, public.user_is_minor($2) as recipient_minor',
    [senderId, gift.recipient_user_id],
  );
  const a = ages.rows[0];
  if (!a || a.sender_minor || !a.recipient_minor) return false;
  const n = await q.query<{ n: number }>(
    `select count(*)::int as n from public.gifts where sender_user_id = $1 and recipient_user_id = $2
        and status = 'delivered' and delivered_at > $3`,
    [senderId, gift.recipient_user_id, new Date(now.getTime() - GIFT_RULES.minorPatternDays * DAY_MS)],
  );
  if ((n.rows[0]?.n ?? 0) < GIFT_RULES.minorPatternCount) return false;
  const open = await q.query(
    `select 1 from public.reports where source = 'auto' and auto_signal = 'gift_pattern' and status = 'open'
        and target_user_id = $1 limit 1`,
    [senderId],
  );
  if ((open.rowCount ?? 0) > 0) return false;
  // The sender's seat in the room the gift was sent from (the item's subject); none left → the account alone.
  const seat = gift.room_id
    ? (await q.query<{ member_id: string }>('select member_id from public.room_members where room_id = $1 and user_id = $2', [gift.room_id, senderId]))
        .rows[0]?.member_id ?? null
    : null;
  const cfg = await loadSafetyConfig(q);
  const file = (x: Queryable): ReturnType<typeof insertReport> =>
    insertReport(
      x,
      {
        source: 'auto',
        autoSignal: 'gift_pattern',
        reporterUserId: null,
        reporterMemberId: null,
        reason: TARGETING_MINOR_REASON,
        targetKind: 'member',
        roomId: seat ? gift.room_id : null,
        targetMemberId: seat,
        targetGestureId: null,
        targetUserId: senderId,
        targetRef: seat ?? senderId,
        note: `gift_pattern: ${n.rows[0]?.n ?? 0} gifts in ${GIFT_RULES.minorPatternDays} days to one under-18 account`,
        involvesMinor: true,
      },
      cfg,
      now,
    );
  if (!(q instanceof Tx)) {
    await file(q);
    return true;
  }
  try {
    // Its own savepoint: a refused review item must never undo the gift the person paid for.
    await q.savepoint(file);
    return true;
  } catch (err) {
    if (pgCode(err) !== '23514') throw err;
    new Logger('Billing').warn('gift_pattern review item refused by reports_auto_signal_check (migration keeps the list?)');
    return false;
  }
}

/** Store refund of a gift purchase: the recipient keeps the Stardust; the sender's refund count grows. */
export async function refundGift(q: Queryable, purchaseId: string, now: Date): Promise<boolean> {
  const r = await q.query('update public.gifts set refunded_at = $2 where purchase_id = $1 and refunded_at is null', [purchaseId, now]);
  return (r.rowCount ?? 0) > 0;
}

/** A reversed refund (Apple REFUND_REVERSED) no longer counts against the sender. */
export async function unrefundGift(q: Queryable, purchaseId: string): Promise<void> {
  await q.query('update public.gifts set refunded_at = null where purchase_id = $1', [purchaseId]);
}

export interface ReceivedGift {
  giftId: string;
  kind: string;
  stardust: number;
  roomId: string | null;
  deliveredAt: string;
}

/** Delivered gifts the recipient hasn't seen yet. Never the sender (REQ-PAY-04: not even a pseudonym). */
export async function unseenGifts(q: Queryable, userId: string): Promise<ReceivedGift[]> {
  const r = await q.query<{ id: string; gift_kind: string; stardust_amount: number; room_id: string | null; delivered_at: Date }>(
    `select id, gift_kind, stardust_amount, room_id, delivered_at from public.gifts
      where recipient_user_id = $1 and status = 'delivered' and seen_at is null order by delivered_at limit 50`,
    [userId],
  );
  return r.rows.map((g) => ({ giftId: g.id, kind: g.gift_kind, stardust: g.stardust_amount, roomId: g.room_id, deliveredAt: g.delivered_at.toISOString() }));
}

export async function markGiftsSeen(q: Queryable, userId: string, ids: readonly string[]): Promise<number> {
  if (ids.length === 0) return 0;
  const r = await q.query(
    "update public.gifts set seen_at = now() where recipient_user_id = $1 and id = any($2::uuid[]) and status = 'delivered' and seen_at is null",
    [userId, ids],
  );
  return r.rowCount ?? 0;
}

/** Worker: checks the store never confirmed within the reservation window stop counting toward the day. */
export async function expireOpenGifts(q: Queryable, now: Date): Promise<number> {
  const r = await q.query("update public.gifts set status = 'expired' where status = 'checked' and expires_at <= $1", [now]);
  return r.rowCount ?? 0;
}
