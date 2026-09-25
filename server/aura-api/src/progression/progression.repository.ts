import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';
import { isQuadrant, type Quadrant } from '../rules';
import type { ProgressionInputs, Snapshot } from './snapshot';

@Injectable()
export class ProgressionRepository {
  async loadInputs(q: Queryable, userId: string, today: string, hueFrom: string): Promise<ProgressionInputs> {
    // Sequential on purpose: `q` may be a single transaction client (pg forbids overlapping queries).
    const ledger = await q.query<{ total: string; today: string; breathe: string; sleep: string }>(
      `select coalesce(sum(amount), 0)                                              as total,
              coalesce(sum(amount) filter (where local_day = $2), 0)                as today,
              count(distinct local_day) filter (where reason = 'habit' and habit_key = 'breathe')       as breathe,
              count(distinct local_day) filter (where reason = 'habit' and habit_key = 'sleep_on_time') as sleep
         from public.starlight_ledger where user_id = $1`,
      [userId, today],
    );
    const hue = await q.query<{ quadrant: string; n: number }>(
      `select quadrant, count(*)::int as n from public.check_ins
        where user_id = $1 and local_day between $2 and $3 group by quadrant`,
      [userId, hueFrom, today],
    );
    const days = await q.query<{ local_day: string }>(
      'select local_day from public.active_days where user_id = $1 order by local_day',
      [userId],
    );
    const avatar = await q.query<{ equipped_cosmetics: string[] }>(
      'select equipped_cosmetics from public.avatar_state where user_id = $1',
      [userId],
    );
    const l = ledger.rows[0];
    const hueCounts: Partial<Record<Quadrant, number>> = {};
    for (const r of hue.rows) if (isQuadrant(r.quadrant)) hueCounts[r.quadrant] = r.n;
    return {
      totalStarlight: Number(l?.total ?? 0),
      todayStarlight: Number(l?.today ?? 0),
      breatheCompletions: Number(l?.breathe ?? 0),
      sleepCompletions: Number(l?.sleep ?? 0),
      hueCounts,
      activeDays: days.rows.map((r) => r.local_day),
      equippedCosmetics: avatar.rows[0]?.equipped_cosmetics ?? [],
    };
  }

  async persist(q: Queryable, userId: string, s: Snapshot): Promise<void> {
    const a = s.avatar;
    await q.query(
      `insert into public.avatar_state
         (user_id, stage, total_starlight, hue, is_resting, ring_count, glow_level, constellation_stars, updated_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, now())
       on conflict (user_id) do update set
         stage = excluded.stage, total_starlight = excluded.total_starlight, hue = excluded.hue,
         is_resting = excluded.is_resting, ring_count = excluded.ring_count, glow_level = excluded.glow_level,
         constellation_stars = excluded.constellation_stars, updated_at = now()`,
      [userId, a.stage, s.starlight.total, a.hue, a.isResting, a.ringCount, a.glowLevel, a.constellationStars],
    );
    const k = s.streak;
    await q.query(
      `insert into public.streak_state
         (user_id, glow_streak, longest_glow_streak, lifetime_glow_days, rest_bank, earn_counter, last_active_day, updated_at)
       values ($1, $2, $3, $4, $5, $6, $7, now())
       on conflict (user_id) do update set
         glow_streak = excluded.glow_streak, longest_glow_streak = excluded.longest_glow_streak,
         lifetime_glow_days = excluded.lifetime_glow_days,
         rest_bank = excluded.rest_bank, earn_counter = excluded.earn_counter,
         last_active_day = excluded.last_active_day, updated_at = now()`,
      [userId, k.glowStreak, k.longestGlowStreak, k.lifetimeGlowDays, k.restBank, k.earnCounter, k.lastActiveDay],
    );
  }
}
