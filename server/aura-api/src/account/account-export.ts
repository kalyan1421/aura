import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import type { Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { tryOpen } from '../reflections/reflection-cipher';

/**
 * F8 REQ-ACC-12 data export — the server half (`GET /v1/account/export`, contracts/api/v1.md "Data export").
 *
 * The app builds the export on the phone (JSON + readable HTML + a check-in CSV) from its own decrypted records —
 * check-ins and notes, habits, capsules — because private text is only ever decrypted on the device (DS-1). This adds
 * what only the server holds: the profile (incl. the full DOB, DS-6), purchases and subscriptions, Plus, Stardust,
 * cosmetics, gifts (never who sent or received them), keepsakes, Sanctuary session records, consents, notification
 * settings, the guidelines accepted, and the person's own reflections still stored.
 *
 * Never included (REQ-ACC-12 "Neg: no other users' content or moderation notes"): anything about another person
 * (gift counterparts, room members, pseudonyms, reports about or by others), moderation detail (reports, lanes,
 * scores, strikes, sanctions, audit rows, evidence), store receipts and tokens, keys and install ids.
 */
export interface ServerExport {
  format: 'aura.export.server.v1';
  exportedAt: string;
  profile: {
    birthDate: string;
    uiLocale: string;
    languagePool: string;
    timezone: string;
    country: string | null;
    createdAt: string;
  } | null;
  progress: {
    totalStarlight: number;
    stage: string | null;
    glowStreak: number;
    longestGlowStreak: number;
    lifetimeGlowDays: number;
    restBank: number;
  } | null;
  plus: { active: boolean; state: string | null; until: string | null; store: string | null; productId: string | null; autoRenew: boolean | null } | null;
  purchases: Array<{ productId: string; store: string; kind: string; state: string; orderId: string | null; purchasedAt: string | null; refundedAt: string | null }>;
  subscriptions: Array<{
    productId: string;
    store: string;
    state: string;
    autoRenew: boolean | null;
    startedAt: string | null;
    trialEndsAt: string | null;
    expiresAt: string | null;
    cancelledAt: string | null;
    price: string | null;
  }>;
  stardust: { balance: number; entries: Array<{ amount: number; reason: string; at: string }> };
  cosmetics: Array<{ cosmeticId: string; source: string; acquiredAt: string }>;
  skyTheme: { skyTheme: string | null; soundscape: string | null } | null;
  giftsSent: Array<{ gift: string; status: string; day: string | null; deliveredAt: string | null; refundedAt: string | null }>;
  giftsReceived: Array<{ gift: string; stardust: number; deliveredAt: string | null }>;
  keepsakes: Array<{ key: string; earnedOn: string }>;
  /** W07: when the person started or ended a habit commitment (dates only; the habit is not named). */
  commitmentHistory: Array<{ kind: 'start' | 'end'; day: string }>;
  sanctuarySessions: Array<{ activity: string; variant: string | null; durationS: number; localDay: string }>;
  consents: Array<{ purpose: string; policyVersion: string; grantedAt: string; withdrawnAt: string | null }>;
  guidelinesAccepted: Array<{ version: number; acceptedAt: string }>;
  notificationSettings: Record<string, unknown> | null;
  reflections: Array<{ createdAt: string; status: 'published' | 'waiting' | 'not_published'; text: string | null }>;
}

const iso = (d: Date | null | undefined): string | null => (d ? d.toISOString() : null);
const day = (d: Date | string | null | undefined): string | null =>
  d === null || d === undefined ? null : typeof d === 'string' ? d.slice(0, 10) : d.toISOString().slice(0, 10);

/** Everything the server holds about `userId` that belongs in their export. Sequential (one connection). */
export async function buildServerExport(q: Queryable, masterKey: Buffer, userId: string, now = new Date()): Promise<ServerExport> {
  const profile = (
    await q.query<{ birth_date: string; ui_locale: string; language_pool: string; timezone: string; country: string | null; created_at: Date }>(
      `select to_char(birth_date, 'YYYY-MM-DD') as birth_date, ui_locale, language_pool, timezone, country, created_at
         from public.profiles where user_id = $1`,
      [userId],
    )
  ).rows[0];
  const avatar = (await q.query<{ total_starlight: string; stage: string }>('select total_starlight, stage from public.avatar_state where user_id = $1', [userId])).rows[0];
  const streak = (
    await q.query<{ glow_streak: number; longest_glow_streak: number; lifetime_glow_days: number; rest_bank: number }>(
      'select glow_streak, longest_glow_streak, lifetime_glow_days, rest_bank from public.streak_state where user_id = $1',
      [userId],
    )
  ).rows[0];
  const ent = (
    await q.query<{ plus_active: boolean; plus_state: string | null; plus_until: Date | null; plus_store: string | null; plus_product_id: string | null; plus_auto_renew: boolean | null }>(
      'select plus_active, plus_state, plus_until, plus_store, plus_product_id, plus_auto_renew from public.entitlements where user_id = $1',
      [userId],
    )
  ).rows[0];
  const purchases = await q.query<{ product_id: string; store: string; kind: string; state: string; order_id: string | null; purchased_at: Date | null; refunded_at: Date | null }>(
    `select product_id, store, kind, state, order_id, purchased_at, refunded_at from public.purchases
      where owner_user_id = $1 order by coalesce(purchased_at, created_at)`,
    [userId],
  );
  const subs = await q.query<{
    product_id: string;
    store: string;
    state: string;
    auto_renew: boolean | null;
    started_at: Date | null;
    trial_ends_at: Date | null;
    expires_at: Date | null;
    cancelled_at: Date | null;
    price_display: string | null;
  }>(
    `select product_id, store, state, auto_renew, started_at, trial_ends_at, expires_at, cancelled_at, price_display
       from public.subscriptions where owner_user_id = $1 order by coalesce(started_at, created_at)`,
    [userId],
  );
  const stardust = await q.query<{ amount: number; reason: string; created_at: Date }>(
    'select amount, reason, created_at from public.stardust_ledger where user_id = $1 order by created_at, id',
    [userId],
  );
  const cosmetics = await q.query<{ cosmetic_id: string; source: string; acquired_at: Date }>(
    'select cosmetic_id, source, acquired_at from public.user_cosmetics where user_id = $1 order by acquired_at',
    [userId],
  );
  const sky = (await q.query<{ sky_theme: string | null; soundscape: string | null }>('select sky_theme, soundscape from public.sky_preferences where user_id = $1', [userId])).rows[0];
  const sent = await q.query<{ gift_kind: string; status: string; sender_day: string | null; delivered_at: Date | null; refunded_at: Date | null }>(
    `select gift_kind, status, to_char(sender_day, 'YYYY-MM-DD') as sender_day, delivered_at, refunded_at
       from public.gifts where sender_user_id = $1 order by checked_at`,
    [userId],
  );
  const received = await q.query<{ gift_kind: string; stardust_amount: number; delivered_at: Date | null }>(
    `select gift_kind, stardust_amount, delivered_at from public.gifts
      where recipient_user_id = $1 and status = 'delivered' order by delivered_at`,
    [userId],
  );
  const commitmentHistory = await q.query<{ kind: 'start' | 'end'; day: string }>(
    `select kind, to_char(day, 'YYYY-MM-DD') as day from public.habit_commitment_events where user_id = $1 order by at, id`,
    [userId],
  );
  const keepsakes = await q.query<{ keepsake_key: string; earned_on: string }>(
    `select keepsake_key, to_char(earned_on, 'YYYY-MM-DD') as earned_on from public.keepsakes where user_id = $1 order by earned_on, keepsake_key`,
    [userId],
  );
  const sessions = await q.query<{ activity: string; variant: string | null; duration_s: number; local_day: string }>(
    `select activity, variant, duration_s, to_char(local_day, 'YYYY-MM-DD') as local_day
       from public.sanctuary_sessions where user_id = $1 order by local_day, device_ts`,
    [userId],
  );
  const consents = await q.query<{ purpose: string; policy_version: string; granted_at: Date; withdrawn_at: Date | null }>(
    'select purpose, policy_version, granted_at, withdrawn_at from public.user_consents where user_id = $1 order by granted_at',
    [userId],
  );
  const guidelines = await q.query<{ version: number; accepted_at: Date }>(
    'select version, accepted_at from public.guidelines_acceptances where user_id = $1 order by accepted_at',
    [userId],
  );
  const prefs = (
    await q.query<Record<string, unknown>>(
      `select enabled, reminder_enabled, reminder_time::text as reminder_time, quiet_start::text as quiet_start,
              quiet_end::text as quiet_end, discreet, lantern_opt_in, capsule_enabled, gestures_enabled,
              welcome_back_enabled, wind_down_enabled, wind_down_time::text as wind_down_time, habit_nudges
         from public.notification_prefs where user_id = $1`,
      [userId],
    )
  ).rows[0];
  const reflections = await q.query<{ id: string; created_at: Date; status: string; body_ct: string | null; body_key: string | null }>(
    `select id, created_at, status, body_ct, body_key from public.reflections
      where user_id = $1 and status not in ('deleted', 'expired') order by created_at`,
    [userId],
  );

  return {
    format: 'aura.export.server.v1',
    exportedAt: now.toISOString(),
    profile: profile
      ? {
          birthDate: profile.birth_date,
          uiLocale: profile.ui_locale,
          languagePool: profile.language_pool,
          timezone: profile.timezone,
          country: profile.country,
          createdAt: profile.created_at.toISOString(),
        }
      : null,
    progress:
      avatar || streak
        ? {
            totalStarlight: Number(avatar?.total_starlight ?? 0),
            stage: avatar?.stage ?? null,
            glowStreak: streak?.glow_streak ?? 0,
            longestGlowStreak: streak?.longest_glow_streak ?? 0,
            lifetimeGlowDays: streak?.lifetime_glow_days ?? 0,
            restBank: streak?.rest_bank ?? 1,
          }
        : null,
    plus: ent
      ? {
          active: ent.plus_active,
          state: ent.plus_state,
          until: iso(ent.plus_until),
          store: ent.plus_store,
          productId: ent.plus_product_id,
          autoRenew: ent.plus_auto_renew,
        }
      : null,
    purchases: purchases.rows.map((p) => ({
      productId: p.product_id,
      store: p.store,
      kind: p.kind,
      state: p.state,
      orderId: p.order_id,
      purchasedAt: iso(p.purchased_at),
      refundedAt: iso(p.refunded_at),
    })),
    subscriptions: subs.rows.map((s) => ({
      productId: s.product_id,
      store: s.store,
      state: s.state,
      autoRenew: s.auto_renew,
      startedAt: iso(s.started_at),
      trialEndsAt: iso(s.trial_ends_at),
      expiresAt: iso(s.expires_at),
      cancelledAt: iso(s.cancelled_at),
      price: s.price_display,
    })),
    stardust: {
      balance: stardust.rows.reduce((n, e) => n + Number(e.amount), 0),
      entries: stardust.rows.map((e) => ({ amount: Number(e.amount), reason: e.reason, at: e.created_at.toISOString() })),
    },
    cosmetics: cosmetics.rows.map((c) => ({ cosmeticId: c.cosmetic_id, source: c.source, acquiredAt: c.acquired_at.toISOString() })),
    skyTheme: sky ? { skyTheme: sky.sky_theme, soundscape: sky.soundscape } : null,
    giftsSent: sent.rows.map((g) => ({ gift: g.gift_kind, status: g.status, day: day(g.sender_day), deliveredAt: iso(g.delivered_at), refundedAt: iso(g.refunded_at) })),
    giftsReceived: received.rows.map((g) => ({ gift: g.gift_kind, stardust: Number(g.stardust_amount), deliveredAt: iso(g.delivered_at) })),
    keepsakes: keepsakes.rows.map((k) => ({ key: k.keepsake_key, earnedOn: k.earned_on })),
    commitmentHistory: commitmentHistory.rows.map((c) => ({ kind: c.kind, day: c.day })),
    sanctuarySessions: sessions.rows.map((s) => ({ activity: s.activity, variant: s.variant, durationS: s.duration_s, localDay: s.local_day })),
    consents: consents.rows.map((c) => ({ purpose: c.purpose, policyVersion: c.policy_version, grantedAt: c.granted_at.toISOString(), withdrawnAt: iso(c.withdrawn_at) })),
    guidelinesAccepted: guidelines.rows.map((g) => ({ version: g.version, acceptedAt: g.accepted_at.toISOString() })),
    notificationSettings: prefs ?? null,
    // Own words only: never the room, the pseudonym or anyone else's reflection.
    reflections: reflections.rows.map((r) => ({
      createdAt: r.created_at.toISOString(),
      // Plain states only: no moderation outcome, category or crisis marker (REQ-ACC-12 "no moderation notes").
      status: r.status === 'published' ? 'published' : r.status === 'pending' || r.status === 'held' ? 'waiting' : 'not_published',
      text: tryOpen(masterKey, r.id, r.body_ct, r.body_key),
    })),
  };
}

/** `GET /v1/account/export` (AccountController). One read-only transaction, so the parts agree with each other. */
@Injectable()
export class AccountExportService {
  constructor(
    private readonly db: DbService,
    private readonly app: AppConfig,
  ) {}

  export(userId: string): Promise<ServerExport> {
    return this.db.withTx((tx) => buildServerExport(tx, this.app.masterKey, userId));
  }
}
