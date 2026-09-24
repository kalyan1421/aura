import type { Queryable } from '../db/db';
import type { SessionPayload } from './ripple-views';
import { gameTopic, roomInviteTopic, type SeatKind } from './ripple-types';

/**
 * Server → client Realtime events for Breath Ripples (contracts/api/v1-ripples.md §3). Every payload is built here:
 * seat numbers, kinds, ids and times only (DS-10: never account ids, ages, DOBs or text). Sent with `realtime.send()`
 * inside the caller's transaction, so an event is delivered only if the write commits. Delivery is best-effort; every
 * event is a hint the phone confirms over REST.
 */
export type RippleServerEvent = 'session_start' | 'seat_update' | 'session_end' | 'ripple_invite' | 'ripple_invite_closed';

async function send(q: Queryable, topic: string, event: RippleServerEvent, payload: Record<string, unknown>): Promise<void> {
  await q.query('select realtime.send($1::jsonb, $2, $3, true)', [JSON.stringify(payload), event, topic]);
}

export const RippleBroadcast = {
  sessionStart(q: Queryable, sessionId: string, session: SessionPayload): Promise<void> {
    return send(q, gameTopic(sessionId), 'session_start', { ...session });
  },

  /** A seat changed (a leave dims the light into an echo). Labels never travel here: phones refetch the session. */
  seatUpdate(q: Queryable, sessionId: string, seat: number, kind: SeatKind, at: Date): Promise<void> {
    return send(q, gameTopic(sessionId), 'seat_update', { seat, kind, at: at.toISOString() });
  },

  sessionEnd(q: Queryable, sessionId: string, at: Date): Promise<void> {
    return send(q, gameTopic(sessionId), 'session_end', { t: at.getTime() });
  },

  /** A room invite opened or gained a person: ids only, the banner fetches the (block-filtered) invite. */
  invite(q: Queryable, roomId: string, inviteId: string, at: Date): Promise<void> {
    return send(q, roomInviteTopic(roomId), 'ripple_invite', { inviteId, at: at.toISOString() });
  },

  inviteClosed(q: Queryable, roomId: string, inviteId: string, at: Date): Promise<void> {
    return send(q, roomInviteTopic(roomId), 'ripple_invite_closed', { inviteId, at: at.toISOString() });
  },
};
