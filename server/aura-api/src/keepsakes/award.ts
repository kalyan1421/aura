import type { Queryable } from '../db/db';
import { lockUser } from '../db/locks';
import { auraDay } from '../rules/aura-day';
import { earnedKeepsakes, KEEPSAKE_KEYS, type KeepsakeEvent } from './keepsake-rules';

/**
 * F13 keepsake awarding — the SQL side of RULES.md §11 (rules: keepsake-rules.ts; schema: migration
 * 20261005000026). Reads records NestJS already holds (capsule metadata, active days, Breath Ripples seats, Lantern
 * Hour room memberships, Sanctuary session records), never content, and writes only `keepsakes` (key + day) and the
 * Lantern Hour tally. Idempotent: a keepsake is stored once with the day computed the first time
 * (`on conflict do nothing`), and the tally only counts nights after its watermark. Never logs ids.
 *
 * Runs inside the caller's transaction and takes the per-user lock (the same one as the sync push), so the worker
 * tick and `GET /v1/keepsakes` serialise with each other and with the person's writes.
 */

export interface OwnKeepsake {
  key: string;
  /** `YYYY-MM-DD`: the Aura day it was earned. */
  earnedOn: string;
}

export interface AwardOutcome {
  /** Keys newly stored by this run (for the worker's count only; never logged with an id). */
  added: string[];
  /** Lantern Hour nights newly counted by this run. */
  newNights: number;
}

const days = (rows: Array<{ day: string }>): KeepsakeEvent[] => rows.map((r) => ({ day: r.day, amount: 1 }));

/**
 * Awards every keepsake `userId` has reached. A person without a profile (not onboarded) has nothing to award and
 * no zone to date anything in: returns without writing.
 */
export async function awardKeepsakes(q: Queryable, userId: string, now = new Date()): Promise<AwardOutcome> {
  await lockUser(q, userId);
  const profile = await q.query<{ timezone: string }>('select timezone from public.profiles where user_id = $1', [userId]);
  const tz = profile.rows[0]?.timezone;
  if (!tz) return { added: [], newNights: 0 };
  const dayOf = (t: Date | string): string => auraDay(t instanceof Date ? t : new Date(t), tz);

  // Capsules (tombstones included: deleting a capsule never takes its seal away). Only the earliest instant matters.
  const caps = await q.query<{ sealed: Date | null; opened: Date | null }>(
    'select min(sealed_at) as sealed, min(opened_at) as opened from public.capsules where user_id = $1',
    [userId],
  );
  const c = caps.rows[0];

  // Lifetime glow days = distinct active days (RULES.md §7; `active_days` survives check-in deletion).
  const glow = await q.query<{ day: string }>(
    'select local_day as day from public.active_days where user_id = $1 order by local_day',
    [userId],
  );

  // Breath Ripples: a human seat in a session that has ended (sessions are purged 7 days after they end).
  const ripple = await q.query<{ ended: Date | null }>(
    `select min(s.ended_at) as ended from public.ripple_seats st join public.ripple_sessions s on s.id = st.session_id
      where st.user_id = $1 and st.kind = 'human' and s.ended_at is not null and s.ended_at <= $2`,
    [userId, now],
  );

  // Lantern Hour nights after the tally's watermark: a room whose Lantern Hour window has ended, in which the person
  // was a member during it. Rooms are purged after 7 days, which is why the tally exists.
  const tally = await q.query<{ lantern_nights: number; lantern_through: Date | null }>(
    'select lantern_nights, lantern_through from public.keepsake_tallies where user_id = $1',
    [userId],
  );
  const counted = tally.rows[0]?.lantern_nights ?? 0;
  const through = tally.rows[0]?.lantern_through ?? null;
  const nights = await q.query<{ night: Date }>(
    `with cfg as (select coalesce((select lantern_end - lantern_start from public.matching_config limit 1), interval '2 hours') as len)
     select distinct r.lantern_hour_at as night
       from public.room_members m
       join public.rooms r on r.id = m.room_id
       cross join cfg
      where m.user_id = $1
        and r.lantern_hour_at is not null
        and r.lantern_hour_at + cfg.len <= $2
        and ($3::timestamptz is null or r.lantern_hour_at > $3)
        and m.joined_at < r.lantern_hour_at + cfg.len
        and coalesce(m.left_at, m.last_seen_at) >= r.lantern_hour_at
      order by night`,
    [userId, now, through],
  );

  // Sanctuary session records: content-free durations on their Aura day.
  const sanctuary = await q.query<{ day: string; seconds: number }>(
    'select local_day as day, duration_s as seconds from public.sanctuary_sessions where user_id = $1 order by local_day, device_ts, id',
    [userId],
  );

  const earned = earnedKeepsakes({
    capsuleSeals: c?.sealed ? [{ day: dayOf(c.sealed), amount: 1 }] : [],
    capsuleOpens: c?.opened ? [{ day: dayOf(c.opened), amount: 1 }] : [],
    glowDays: days(glow.rows),
    rippleSessions: ripple.rows[0]?.ended ? [{ day: dayOf(ripple.rows[0].ended), amount: 1 }] : [],
    lanternNights: days(nights.rows.map((r) => ({ day: dayOf(r.night) }))),
    lanternCounted: counted,
    sanctuarySeconds: sanctuary.rows.map((r) => ({ day: r.day, amount: Number(r.seconds) })),
  });

  const added: string[] = [];
  for (const k of earned) {
    const r = await q.query(
      `insert into public.keepsakes (user_id, keepsake_key, earned_on) values ($1, $2, $3)
       on conflict (user_id, keepsake_key) do nothing`,
      [userId, k.key, k.day],
    );
    if ((r.rowCount ?? 0) > 0) added.push(k.key);
  }

  const newNights = nights.rows.length;
  if (newNights === 0) return { added, newNights };
  await q.query(
    `insert into public.keepsake_tallies (user_id, lantern_nights, lantern_through, updated_at)
     values ($1, $2, $3, now())
     on conflict (user_id) do update set
       lantern_nights = excluded.lantern_nights,
       lantern_through = excluded.lantern_through,
       updated_at = now()`,
    [userId, counted + newNights, nights.rows[newNights - 1].night],
  );
  return { added, newNights };
}

/** The person's own keepsakes, in catalogue order (unknown keys, if any, last). Only ever for the caller. */
export async function listOwnKeepsakes(q: Queryable, userId: string): Promise<OwnKeepsake[]> {
  const r = await q.query<{ keepsake_key: string; earned_on: string }>(
    'select keepsake_key, earned_on from public.keepsakes where user_id = $1',
    [userId],
  );
  const order = (key: string): number => {
    const i = KEEPSAKE_KEYS.indexOf(key);
    return i < 0 ? KEEPSAKE_KEYS.length : i;
  };
  return r.rows
    .map((x) => ({ key: x.keepsake_key, earnedOn: x.earned_on }))
    .sort((a, b) => order(a.key) - order(b.key) || (a.key < b.key ? -1 : 1));
}
