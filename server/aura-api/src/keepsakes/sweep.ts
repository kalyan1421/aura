import type { Pool } from 'pg';
import { withTx } from '../db/db';
import { awardKeepsakes } from './award';

/**
 * F13 worker side: who might have reached a keepsake since `since`, and awarding them. Content-free: it reads ids,
 * timestamps and counts only, and the summary holds counts only (never an id).
 */

export interface SweepSummary {
  people: number;
  added: number;
  nights: number;
  errors: number;
}

const BATCH = 500;

/**
 * People with a record newer than `since` that can move a keepsake: a capsule write, a progression change (glow days),
 * a Breath Ripples session that ended, a Lantern Hour window that ended with them in the room, a Sanctuary record.
 * Accounts on their way out (a deletion request) are skipped.
 */
export async function recentCandidates(pool: Pool, since: Date, now: Date): Promise<string[]> {
  const r = await pool.query<{ user_id: string }>(
    `with cfg as (select coalesce((select lantern_end - lantern_start from public.matching_config limit 1), interval '2 hours') as len),
     c as (
       select user_id from public.capsules where updated_at > $1
       union select user_id from public.streak_state where updated_at > $1
       union select st.user_id from public.ripple_seats st join public.ripple_sessions s on s.id = st.session_id
              where st.user_id is not null and st.kind = 'human' and s.ended_at > $1 and s.ended_at <= $2
       union select m.user_id from public.room_members m join public.rooms r on r.id = m.room_id cross join cfg
              where r.lantern_hour_at is not null and r.lantern_hour_at + cfg.len > $1 and r.lantern_hour_at + cfg.len <= $2
       union select user_id from public.sanctuary_sessions where server_ts > $1
     )
     select c.user_id from c
      where exists (select 1 from public.profiles p where p.user_id = c.user_id)
        and not exists (select 1 from public.account_deletions d where d.user_id = c.user_id)
      order by c.user_id`,
    [since, now],
  );
  return r.rows.map((x) => x.user_id);
}

async function awardAll(pool: Pool, ids: string[], now: Date, s: SweepSummary): Promise<void> {
  for (const id of ids) {
    try {
      const out = await withTx(pool, (tx) => awardKeepsakes(tx, id, now));
      s.people += 1;
      s.added += out.added.length;
      s.nights += out.newNights;
    } catch {
      s.errors += 1; // the next sweep retries; nothing is half-written (one transaction per person)
    }
  }
}

/** Awards the people with recent records (every tick). */
export async function runRecentSweep(pool: Pool, since: Date, now = new Date()): Promise<SweepSummary> {
  const s: SweepSummary = { people: 0, added: 0, nights: 0, errors: 0 };
  await awardAll(pool, await recentCandidates(pool, since, now), now, s);
  return s;
}

/**
 * Awards everyone with a profile, in id order and batches (at start-up and daily): covers past activity when F13
 * ships ("seals are awarded for past activity where the records still exist") and anything a tick missed.
 */
export async function runFullSweep(pool: Pool, now = new Date()): Promise<SweepSummary> {
  const s: SweepSummary = { people: 0, added: 0, nights: 0, errors: 0 };
  let after = '00000000-0000-0000-0000-000000000000';
  for (;;) {
    const r = await pool.query<{ user_id: string }>(
      `select p.user_id from public.profiles p
        where p.user_id > $1
          and not exists (select 1 from public.account_deletions d where d.user_id = p.user_id)
        order by p.user_id limit $2`,
      [after, BATCH],
    );
    if (r.rows.length === 0) break;
    await awardAll(pool, r.rows.map((x) => x.user_id), now, s);
    after = r.rows[r.rows.length - 1].user_id;
    if (r.rows.length < BATCH) break;
  }
  return s;
}
