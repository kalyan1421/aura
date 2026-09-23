import type { Pool } from 'pg';
import { pgCode, withTx } from '../db/db';
import { ensureEvidenceForRoom, purgeExpiredEvidence } from '../safety/evidence';
import { loadSafetyConfig } from '../safety/safety.queries';
import { Broadcast } from './broadcast';
import { loadMatchingConfig } from './matching-config';
import { countsView, roomInfo, roomStateView, stateOf } from './room-views';
import { RoomsRepository, type RoomRow } from './rooms.repository';

/**
 * Worker `room-lifecycle` queue, job `room-lifecycle-tick` (every minute at :00, so Lantern Hour transitions land within
 * seconds of 21:00 / 23:00 on each region clock). Reads always derive the state from timestamps; this tick only
 * (1) moves the cached `rooms.status` and broadcasts each transition once (`room_state`, plus `lantern_hour` when the
 * lantern starts or ends), (2) re-broadcasts "here now" when it changed (people going quiet), (3) purges rooms at
 * 24 h + 7 d after copying any reported item not yet in the evidence store, and (4) deletes evidence past its hold.
 * Idempotent; each room is its own transaction. Returns counts only (callers log them; never ids).
 */
export interface LifecycleSummary {
  transitions: number;
  presence: number;
  purged: number;
  evidenceCopied: number;
  evidenceExpired: number;
  errors: string[];
}

const PURGE_BATCH = 200;

export async function runRoomLifecycle(pool: Pool, now = new Date()): Promise<LifecycleSummary> {
  const repo = new RoomsRepository();
  const s: LifecycleSummary = { transitions: 0, presence: 0, purged: 0, evidenceCopied: 0, evidenceExpired: 0, errors: [] };
  const fail = (err: unknown): void => {
    const kind = pgCode(err) ?? (err instanceof Error ? err.name : 'error');
    if (!s.errors.includes(kind)) s.errors.push(kind);
  };
  const cfg = await loadMatchingConfig(pool);

  // (1) + (2): rooms that aren't memories yet (plus any whose memory moment just passed).
  const active = await pool.query<{ id: string }>(`select id from public.rooms where status <> 'memory' and purge_at > now()`);
  for (const { id } of active.rows) {
    try {
      await withTx(pool, async (tx) => {
        const room = await repo.lockRoom(tx, id);
        if (!room) return;
        const derived = stateOf(room, now, cfg);
        if (derived === 'purged') return;
        if (derived !== room.status) {
          const r = await tx.query<RoomRow>(
            `update public.rooms set status = $2, status_changed_at = now() where id = $1 and status = $3 returning *`,
            [id, derived, room.status],
          );
          if (r.rows[0]) {
            s.transitions += 1;
            const info = roomInfo(room, now, cfg);
            await Broadcast.roomState(tx, id, roomStateView(info), now);
            const lanternStarted = derived === 'lantern_hour';
            const lanternEnded = room.status === 'lantern_hour';
            if (lanternStarted || lanternEnded) await Broadcast.lanternHour(tx, id, info.lanternHour, now);
          }
        }
        if (derived !== 'memory') {
          const counts = countsView(await repo.counts(tx, id, cfg.liveWindowS));
          if (counts.hereNow !== room.here_now_broadcast) {
            await tx.query('update public.rooms set here_now_broadcast = $2 where id = $1', [id, counts.hereNow]);
            await Broadcast.presence(tx, id, counts, now);
            s.presence += 1;
          }
        }
      });
    } catch (err) {
      fail(err);
    }
  }

  // (3) purge: 24 h + 7 d — hard-delete the room (cascades memberships, pseudonyms, gestures, mutes).
  const safety = await loadSafetyConfig(pool);
  const due = await pool.query<{ id: string }>('select id from public.rooms where purge_at <= now() order by purge_at limit $1', [PURGE_BATCH]);
  for (const { id } of due.rows) {
    try {
      await withTx(pool, async (tx) => {
        const room = await repo.lockRoom(tx, id);
        if (!room) return;
        s.evidenceCopied += await ensureEvidenceForRoom(tx, id, safety.evidenceHoldDays);
        const r = await tx.query('delete from public.rooms where id = $1 and purge_at <= now()', [id]);
        s.purged += r.rowCount ?? 0;
      });
    } catch (err) {
      fail(err);
    }
  }

  // (4) evidence past its hold.
  try {
    s.evidenceExpired = await purgeExpiredEvidence(pool);
  } catch (err) {
    fail(err);
  }
  return s;
}
