import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { pgCode } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { parseOrThrow } from '../common/zod';
import { auraDay } from '../rules';
import { ownedCosmetics, ownedSubscriptions, skyPreference, stardustBalance } from './billing.repository';
import { giftCheckSchema, giftsSeenSchema, redeemSchema, restoreSchema, skySchema, verifySchema } from './billing.schema';
import { DEFAULT_SKY, GIFT_RULES, SKY_THEMES, SOUNDSCAPES, skyById } from './catalogue';
import { cancelGift, checkGift, giftsSentToday, giftStanding, markGiftsSeen, unseenGifts, type GiftChecked, type ReceivedGift } from './gifts';
import { computePlus, displayStatus, noticesFor, type DisplayStatus, type NoticeKind } from './state';
import { StoreSync, type VerifyStatus } from './store-sync.service';

/** `GET /v1/billing/entitlement` (contracts/api/v1-billing.md §2.1). */
export interface EntitlementView {
  accountToken: string;
  plus: {
    active: boolean;
    status: DisplayStatus;
    store: 'apple' | 'google' | null;
    productId: string | null;
    autoRenew: boolean | null;
    trialEndsAt: string | null;
    expiresAt: string | null;
    graceEndsAt: string | null;
    /** The app honours a cached `active` until this instant (16-offline), then asks again. */
    validUntil: string | null;
  };
  notices: { kind: NoticeKind; date: string | null; price: string | null; key: string }[];
  cosmetics: { owned: string[]; available: string[] };
  sky: { theme: string; soundscape: string | null };
  stardust: { balance: number };
  gifting: { state: 'ok' | 'paused' | 'disabled'; until: string | null; sentToday: number; dailyLimit: number };
  giftsUnseen: number;
  /** PRD F12: no paywall within 24 h of onboarding (the profile's creation). Null = no profile yet (never show). */
  paywall: { allowedFrom: string | null };
  serverTime: string;
}

export interface VerifyResponse {
  status: VerifyStatus;
  gift?: string;
  entitlement: EntitlementView;
}

const iso = (d: Date | null | undefined): string | null => (d ? d.toISOString() : null);

@Injectable()
export class BillingService {
  constructor(
    private readonly db: DbService,
    private readonly sync: StoreSync,
  ) {}

  async entitlement(userId: string, now = new Date()): Promise<EntitlementView> {
    const accountToken = await this.sync.accountToken(userId);
    const subs = await ownedSubscriptions(this.db, userId);
    const ent = computePlus(subs, now);
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      await this.sync.recompute(tx, userId, now);
    });
    const s = ent.subscription;
    const price = s ? (subs.find((x) => x.id === s.id)?.priceDisplay ?? null) : null;
    const [owned, balance, pref, standing, unseen, profile] = await Promise.all([
      ownedCosmetics(this.db, userId),
      stardustBalance(this.db, userId),
      skyPreference(this.db, userId),
      giftStanding(this.db, userId, now),
      this.db.query<{ n: number }>(
        "select count(*)::int as n from public.gifts where recipient_user_id = $1 and status = 'delivered' and seen_at is null",
        [userId],
      ),
      this.db.query<{ created_at: Date; timezone: string }>('select created_at, timezone from public.profiles where user_id = $1', [userId]),
    ]);
    const tz = profile.rows[0]?.timezone ?? null;
    const sentToday = tz ? await giftsSentToday(this.db, userId, auraDay(now, tz)) : 0;
    const available = SKY_THEMES.filter((t) => t.tier === 'free' || (t.tier === 'plus' && ent.active) || owned.includes(t.id)).map((t) => t.id);
    const theme = pref && available.includes(pref.sky) ? pref.sky : DEFAULT_SKY;
    return {
      accountToken,
      plus: {
        active: ent.active,
        status: displayStatus(s, now),
        store: s?.store ?? null,
        productId: s?.productId ?? null,
        autoRenew: s ? s.autoRenew : null,
        trialEndsAt: iso(s?.trialEndsAt),
        expiresAt: iso(s?.expiresAt),
        graceEndsAt: iso(s?.graceEndsAt),
        validUntil: iso(ent.until),
      },
      notices: noticesFor(s, now, price).map((n) => ({ kind: n.kind, date: iso(n.date), price: n.price, key: n.key })),
      cosmetics: { owned, available },
      sky: { theme, soundscape: theme === pref?.sky ? pref.soundscape : null },
      stardust: { balance },
      gifting: {
        state: standing.state,
        until: standing.state === 'paused' ? standing.until.toISOString() : null,
        sentToday,
        dailyLimit: GIFT_RULES.perDay,
      },
      giftsUnseen: unseen.rows[0]?.n ?? 0,
      paywall: { allowedFrom: profile.rows[0] ? new Date(profile.rows[0].created_at.getTime() + 24 * 3600_000).toISOString() : null },
      serverTime: now.toISOString(),
    };
  }

  async verify(userId: string, body: unknown, now = new Date()): Promise<VerifyResponse> {
    const b = parseOrThrow(verifySchema, body);
    const r =
      b.store === 'apple'
        ? await this.sync.verifyApple(userId, { productId: b.productId, signedTransaction: b.signedTransaction, priceDisplay: b.priceDisplay, giftId: b.giftId }, now)
        : await this.sync.verifyGoogle(userId, { productId: b.productId, purchaseToken: b.purchaseToken, priceDisplay: b.priceDisplay, giftId: b.giftId }, now);
    return { status: r.status, ...(r.gift ? { gift: r.gift } : {}), entitlement: await this.entitlement(userId, now) };
  }

  /** `POST /v1/billing/restore`: every item verified like a purchase; one bad item never fails the rest. */
  async restore(userId: string, body: unknown, now = new Date()): Promise<{ restored: number; ownedElsewhere: number; confirming: number; invalid: number; entitlement: EntitlementView }> {
    const b = parseOrThrow(restoreSchema, body);
    const counts = { restored: 0, ownedElsewhere: 0, confirming: 0, invalid: 0 };
    const tally = (s: VerifyStatus): void => {
      if (s === 'owned_elsewhere') counts.ownedElsewhere += 1;
      else if (s === 'confirming') counts.confirming += 1;
      else if (s === 'granted' || s === 'pending') counts.restored += 1;
    };
    for (const jws of b.apple?.signedTransactions ?? []) {
      try {
        // The product id comes from the verified transaction itself.
        const productId = await this.sync.jws.verify<{ productId?: string }>(jws).then((t) => t.productId ?? '');
        tally((await this.sync.verifyApple(userId, { productId, signedTransaction: jws }, now)).status);
      } catch (err) {
        if (err instanceof ApiError || (err as Error)?.name === 'AppleJwsError') counts.invalid += 1;
        else throw err;
      }
    }
    for (const p of b.google?.purchases ?? []) {
      try {
        tally((await this.sync.verifyGoogle(userId, { productId: p.productId, purchaseToken: p.purchaseToken }, now)).status);
      } catch (err) {
        if (err instanceof ApiError) counts.invalid += 1;
        else throw err;
      }
    }
    return { ...counts, entitlement: await this.entitlement(userId, now) };
  }

  async checkGift(userId: string, body: unknown, now = new Date()): Promise<GiftChecked & { accountToken: string }> {
    const b = parseOrThrow(giftCheckSchema, body);
    const accountToken = await this.sync.accountToken(userId);
    const out = await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      return checkGift(tx, userId, b, now);
    });
    return { ...out, accountToken };
  }

  async cancelGift(userId: string, giftId: string): Promise<void> {
    if (!/^[0-9a-f-]{36}$/i.test(giftId)) throw ApiError.badRequest('invalid_request', 'giftId: must be a UUID');
    await cancelGift(this.db, userId, giftId.toLowerCase());
  }

  async receivedGifts(userId: string): Promise<{ gifts: ReceivedGift[] }> {
    return { gifts: await unseenGifts(this.db, userId) };
  }

  async giftsSeen(userId: string, body: unknown): Promise<{ marked: number }> {
    const b = parseOrThrow(giftsSeenSchema, body);
    return { marked: await markGiftsSeen(this.db, userId, b.giftIds) };
  }

  /**
   * `POST /v1/billing/stardust/redeem`: a cosmetic sky for its Stardust price. Idempotent on `redemptionId`; never
   * below zero (ledger trigger AR030 → 409 not_enough_stardust).
   */
  async redeem(userId: string, body: unknown, now = new Date()): Promise<EntitlementView> {
    const b = parseOrThrow(redeemSchema, body);
    const sky = skyById(b.cosmeticId);
    if (!sky || sky.tier !== 'cosmetic' || sky.stardust === null) throw ApiError.badRequest('invalid_request', 'cosmeticId: not sold for Stardust');
    const price = sky.stardust;
    try {
      await this.db.withTx(async (tx) => {
        await lockUser(tx, userId);
        const done = await tx.query('select 1 from public.user_cosmetics where user_id = $1 and (cosmetic_id = $2 or redemption_id = $3)', [
          userId,
          sky.id,
          b.redemptionId,
        ]);
        if ((done.rowCount ?? 0) > 0) return;
        await tx.query(
          "insert into public.stardust_ledger (user_id, amount, reason, ref_id) values ($1, $2, 'cosmetic_redeemed', $3)",
          [userId, -price, b.redemptionId],
        );
        await tx.query(
          "insert into public.user_cosmetics (user_id, cosmetic_id, source, redemption_id) values ($1, $2, 'stardust', $3)",
          [userId, sky.id, b.redemptionId],
        );
      });
    } catch (err) {
      if (pgCode(err) === 'AR030') throw ApiError.conflict('not_enough_stardust', 'Not enough Stardust for this sky yet.');
      throw err;
    }
    return this.entitlement(userId, now);
  }

  /** `PUT /v1/billing/sky`: the personal sky + soundscape pairing (free, Plus-included while Plus is on, or owned). */
  async setSky(userId: string, body: unknown, now = new Date()): Promise<EntitlementView> {
    const b = parseOrThrow(skySchema, body);
    const sky = skyById(b.theme);
    if (!sky) throw ApiError.badRequest('invalid_request', 'theme: unknown');
    if (b.soundscape !== null && !(b.soundscape in SOUNDSCAPES)) throw ApiError.badRequest('invalid_request', 'soundscape: unknown');
    const view = await this.entitlement(userId, now);
    if (!view.cosmetics.available.includes(sky.id)) {
      throw ApiError.conflict(sky.tier === 'plus' ? 'plus_required' : 'not_owned', 'This sky is not available on this account.');
    }
    await this.db.query(
      `insert into public.sky_preferences (user_id, sky_theme, soundscape) values ($1, $2, $3)
       on conflict (user_id) do update set sky_theme = excluded.sky_theme, soundscape = excluded.soundscape, updated_at = now()`,
      [userId, sky.id, b.soundscape],
    );
    return { ...view, sky: { theme: sky.id, soundscape: b.soundscape } };
  }
}
