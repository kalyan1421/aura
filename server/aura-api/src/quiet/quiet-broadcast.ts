import type { Queryable } from '../db/db';
import type { GestureType } from '../rooms/room-types';
import { quietTopic, type QuietEvent } from './quiet-types';

/**
 * Server → client Realtime events for Quiet Together (contracts/api/v1-quiet.md §3). Every payload is built here: a
 * count, a preset key, a random gesture id and a time — never the sender, never a member (REQ-QUIET-01/02). Sent with
 * `realtime.send()` inside the caller's transaction (delivered only if the write commits). Best-effort; the heartbeat
 * is authoritative.
 */
async function send(q: Queryable, sessionId: string, event: QuietEvent, payload: Record<string, unknown>): Promise<void> {
  await q.query('select realtime.send($1::jsonb, $2, $3, true)', [JSON.stringify(payload), event, quietTopic(sessionId)]);
}

export const QuietBroadcast = {
  count(q: Queryable, sessionId: string, count: number, at: Date): Promise<void> {
    return send(q, sessionId, 'count', { count, at: at.toISOString() });
  },

  /** An unnamed animation for everyone live ("Someone lit a candle"). */
  gesture(q: Queryable, sessionId: string, g: { gestureId: string; type: GestureType }, at: Date): Promise<void> {
    return send(q, sessionId, 'gesture', { gestureId: g.gestureId, type: g.type, at: at.toISOString() });
  },
};
