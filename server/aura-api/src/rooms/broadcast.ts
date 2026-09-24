import type { Queryable } from '../db/db';
import type { Counts, LanternHourView, PublicMember, RoomStateView } from './room-views';
import { memberTopic, roomTopic, type GestureTarget, type GestureType } from './room-types';

/**
 * Server → client Realtime events (contracts/api/v1-rooms.md §3). Every payload is built here — ids, pseudonyms and
 * preset keys only (DS-10: never account ids, ages, DOBs or text). Sent with `realtime.send()` inside the caller's
 * transaction, so an event is delivered only if the write commits. `realtime.send` never throws (it logs a Postgres
 * WARNING), so broadcasting can't fail a request; delivery is best-effort and clients refetch the REST detail.
 */
export type RoomEvent = 'member_joined' | 'member_left' | 'presence' | 'gesture_sent' | 'room_state' | 'lantern_hour';
export type MemberEvent = 'gesture_received';

async function send(q: Queryable, topic: string, event: RoomEvent | MemberEvent, payload: Record<string, unknown>): Promise<void> {
  await q.query('select realtime.send($1::jsonb, $2, $3, true)', [JSON.stringify(payload), event, topic]);
}

const iso = (d: Date): string => d.toISOString();

export const Broadcast = {
  memberJoined(q: Queryable, roomId: string, member: PublicMember, counts: Counts, at: Date): Promise<void> {
    return send(q, roomTopic(roomId), 'member_joined', { member, counts, at: iso(at) });
  },

  memberLeft(q: Queryable, roomId: string, memberId: string, counts: Counts, at: Date): Promise<void> {
    return send(q, roomTopic(roomId), 'member_left', { memberId, counts, at: iso(at) });
  },

  presence(q: Queryable, roomId: string, counts: Counts, at: Date): Promise<void> {
    return send(q, roomTopic(roomId), 'presence', { counts, at: iso(at) });
  },

  /** Anonymous: everyone sees an unnamed animation. No sender, no recipient. */
  gestureSent(
    q: Queryable,
    roomId: string,
    g: { gestureId: string; type: GestureType; target: GestureTarget; reflectionId?: string | null },
    at: Date,
  ): Promise<void> {
    return send(q, roomTopic(roomId), 'gesture_sent', {
      gestureId: g.gestureId,
      type: g.type,
      target: g.target,
      ...(g.reflectionId ? { reflectionId: g.reflectionId } : {}), // F6: which card animates (never who sent it)
      at: iso(at),
    });
  },

  /** Only the recipient's own member topic learns who sent it ("Quiet Comet sent you Warm Tea"). */
  gestureReceived(
    q: Queryable,
    toMemberId: string,
    g: { gestureId: string; type: GestureType; fromMemberId: string; fromPseudonym: string; reflectionId?: string | null },
    at: Date,
  ): Promise<void> {
    return send(q, memberTopic(toMemberId), 'gesture_received', {
      gestureId: g.gestureId,
      type: g.type,
      fromMemberId: g.fromMemberId,
      fromPseudonym: g.fromPseudonym,
      ...(g.reflectionId ? { reflectionId: g.reflectionId } : {}), // F6: a gesture on your reflection
      at: iso(at),
    });
  },

  roomState(q: Queryable, roomId: string, state: RoomStateView, at: Date): Promise<void> {
    return send(q, roomTopic(roomId), 'room_state', { ...state, at: iso(at) });
  },

  lanternHour(q: Queryable, roomId: string, lanternHour: LanternHourView, at: Date): Promise<void> {
    return send(q, roomTopic(roomId), 'lantern_hour', { lanternHour, at: iso(at) });
  },

  /**
   * Admin-triggered: a moderation sanction just took this account's room access away → `member_left` (same payload as
   * `memberLeft`, fresh counts) to every live room it sits in. Built and sent inside Postgres by the SECURITY DEFINER
   * `public.admin_hide_account_from_rooms` (migration 20261005000016), because the console's `aura_admin` role can
   * neither see the account behind a membership nor use the realtime schema; it sends nothing for an account that isn't
   * hidden. Runs in the caller's transaction (delivered only if the sanction commits). Returns how many rooms were told.
   * The payload shape is covered by test/e2e/rooms.e2e-spec.ts (suspend → member_left, DS-10 scan).
   */
  async accountHidden(q: Queryable, userId: string, at: Date): Promise<number> {
    const r = await q.query<{ n: number }>('select public.admin_hide_account_from_rooms($1, $2) as n', [userId, at]);
    return r.rows[0]?.n ?? 0;
  },
};
