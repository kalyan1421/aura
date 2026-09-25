import type { Pool } from 'pg';
import { pgCode, withTx } from '../db/db';
import { HIDDEN_ACCOUNT_SQL } from '../safety/safety-types';
import { QuietBroadcast } from './quiet-broadcast';
import { loadQuietConfig } from './quiet-config';

/**
 * Worker tick for F16 (every 30 s; src/quiet/quiet.worker.ts), idempotent, counts only in its summary (never ids):
 *   1. `count` on `quiet:<id>` for every running session with anyone live — "a live count every 30 s" (PRD F16
 *      "Matching and realtime"); there is no per-member Presence;
 *   2. closes memberships that went quiet (not seen for `stale_after_min`, or their block ended that long ago) — leaving
 *      costs nothing, and it frees the account's one active membership;
 *   3. purges sessions 7 days after their block ended (members and the gesture log cascade; a reported session was
 *      snapshotted into the evidence store when it was reported).
 */
export interface QuietLifecycleSummary {
  counts: number;
  closed: number;
  purged: number;
  errors: string[];
}

const PURGE_BATCH = 500;

export async function runQuietLifecycle(pool: Pool, now = new Date(), onlySessionIds?: readonly string[]): Promise<QuietLifecycleSummary> {
  const s: QuietLifecycleSummary = { counts: 0, closed: 0, purged: 0, errors: [] };
  const fail = (err: unknown): void => {
    const kind = pgCode(err) ?? (err instanceof Error ? err.name : 'error');
    if (!s.errors.includes(kind)) s.errors.push(kind);
  };
  const cfg = await loadQuietConfig(pool);
  const only = onlySessionIds ? [...onlySessionIds] : null;

  // (1) live counts
  try {
    const live = await pool.query<{ id: string; n: number }>(
      `select s.id, count(m.member_id)::int as n
         from public.quiet_sessions s
         join public.quiet_members m on m.session_id = s.id
        where s.t0 <= $1 and s.ends_at > $1
          and ($3::uuid[] is null or s.id = any($3::uuid[]))
          and m.left_at is null and m.last_seen_at > $1::timestamptz - make_interval(secs => $2)
          and not ${HIDDEN_ACCOUNT_SQL('m.user_id')}
        group by s.id`,
      [now, cfg.liveWindowS, only],
    );
    for (const row of live.rows) {
      try {
        await withTx(pool, (tx) => QuietBroadcast.count(tx, row.id, row.n, now));
        s.counts += 1;
      } catch (err) {
        fail(err);
      }
    }
  } catch (err) {
    fail(err);
  }

  // (2) quiet memberships
  try {
    const r = await pool.query(
      `update public.quiet_members m set left_at = greatest(m.joined_at, $1::timestamptz)
         from public.quiet_sessions x
        where x.id = m.session_id and m.left_at is null
          and ($3::uuid[] is null or x.id = any($3::uuid[]))
          and (m.last_seen_at < $1::timestamptz - make_interval(mins => $2)
               or x.ends_at < $1::timestamptz - make_interval(mins => $2))`,
      [now, cfg.staleAfterMin, only],
    );
    s.closed = r.rowCount ?? 0;
  } catch (err) {
    fail(err);
  }

  // (3) retention
  try {
    const r = await pool.query(
      `delete from public.quiet_sessions where id in (
         select id from public.quiet_sessions where purge_at <= $1 and ($3::uuid[] is null or id = any($3::uuid[]))
          order by purge_at limit $2)`,
      [now, PURGE_BATCH, only],
    );
    s.purged = r.rowCount ?? 0;
  } catch (err) {
    fail(err);
  }
  return s;
}
