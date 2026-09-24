import type { Pool } from 'pg';
import { pgCode, withTx } from '../db/db';
import { purgeOldEchoes } from './echoes';
import { RippleBroadcast } from './ripple-broadcast';
import { loadRippleConfig } from './ripple-config';
import { dbNow, groupInvite, lockInvite } from './ripple-core';

/**
 * Worker tick for Breath Ripples (every 15 s, src/ripples/ripples.worker.ts). Phones drive matching by polling; this
 * is the backstop and the janitor:
 *  1. sessions past `t0 + 180 s` end (`session_end`, once);
 *  2. waiting tickets not polled for 6 s expire (they come back if the phone polls again);
 *  3. room invites past their 20 s start everyone still waiting (echo-fill), then close;
 *  4. retention: sessions (seats, event log) 7 days after they end; tickets and invites after a day; echoes after
 *     90 days (by ISO week).
 * Idempotent; returns counts only (never ids).
 */
export interface RippleTickSummary {
  ended: number;
  expired: number;
  invitesStarted: number;
  purgedSessions: number;
  purgedEchoes: number;
  errors: string[];
}

export async function runRippleLifecycle(pool: Pool): Promise<RippleTickSummary> {
  const s: RippleTickSummary = { ended: 0, expired: 0, invitesStarted: 0, purgedSessions: 0, purgedEchoes: 0, errors: [] };
  const fail = (err: unknown): void => {
    const kind = pgCode(err) ?? (err instanceof Error ? err.name : 'error');
    if (!s.errors.includes(kind)) s.errors.push(kind);
  };
  const cfg = await loadRippleConfig(pool);

  // 1. end sessions
  try {
    await withTx(pool, async (tx) => {
      const ended = await tx.query<{ id: string; ends_at: Date }>(
        `update public.ripple_sessions set ended_at = ends_at
          where id in (select id from public.ripple_sessions where ended_at is null and ends_at <= now() limit 500)
          returning id, ends_at`,
      );
      for (const x of ended.rows) await RippleBroadcast.sessionEnd(tx, x.id, x.ends_at);
      s.ended = ended.rows.length;
    });
  } catch (err) {
    fail(err);
  }

  // 2. quiet tickets
  try {
    const r = await pool.query(
      `update public.ripple_tickets set status = 'expired'
        where status = 'waiting' and last_poll_at <= now() - make_interval(secs => $1)`,
      [cfg.ticketStaleS],
    );
    s.expired = r.rowCount ?? 0;
  } catch (err) {
    fail(err);
  }

  // 3. due invites
  const due = await pool.query<{ id: string }>(`select id from public.ripple_invites where status = 'open' and starts_at <= now() limit 200`);
  for (const { id } of due.rows) {
    try {
      await withTx(pool, async (tx) => {
        const invite = await lockInvite(tx, id);
        if (!invite || invite.status !== 'open') return;
        s.invitesStarted += await groupInvite(tx, invite, cfg, await dbNow(tx));
      });
    } catch (err) {
      fail(err);
    }
  }

  // 4. retention
  try {
    const r = await pool.query('delete from public.ripple_sessions where purge_at <= now()');
    s.purgedSessions = r.rowCount ?? 0;
    await pool.query(`delete from public.ripple_tickets where enqueued_at <= now() - interval '1 day'`);
    await pool.query(`delete from public.ripple_invites where created_at <= now() - interval '1 day'`);
    s.purgedEchoes = await purgeOldEchoes(pool, cfg.echoRetentionD);
  } catch (err) {
    fail(err);
  }
  return s;
}
