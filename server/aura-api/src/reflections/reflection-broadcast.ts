import type { Queryable } from '../db/db';
import { memberTopic, roomTopic } from '../rooms/room-types';

/**
 * F6 realtime events (contracts/api/v1-reflections.md §2), sent with `realtime.send()` inside the caller's transaction
 * (delivered only if it commits), on the existing private room / member topics. **Ids and a status only** — the text
 * is always fetched through the API, so a blocked pair never sees each other's words (PRD F5 "Realtime").
 */
export type ReflectionRoomEvent = 'reflection_published' | 'reflection_removed';
export type AuthorStatus = 'published' | 'held' | 'rejected' | 'removed' | 'crisis_diverted';

async function send(q: Queryable, topic: string, event: string, payload: Record<string, unknown>): Promise<void> {
  await q.query('select realtime.send($1::jsonb, $2, $3, true)', [JSON.stringify(payload), event, topic]);
}

export const ReflectionBroadcast = {
  published(q: Queryable, roomId: string, reflectionId: string, at: Date): Promise<void> {
    return send(q, roomTopic(roomId), 'reflection_published', { reflectionId, at: at.toISOString() });
  },
  removed(q: Queryable, roomId: string, reflectionId: string, at: Date): Promise<void> {
    return send(q, roomTopic(roomId), 'reflection_removed', { reflectionId, at: at.toISOString() });
  },
  /** The author's own item changed (their member topic only). */
  status(q: Queryable, authorMemberId: string, reflectionId: string, status: AuthorStatus, at: Date): Promise<void> {
    return send(q, memberTopic(authorMemberId), 'reflection_status', { reflectionId, status, at: at.toISOString() });
  },
};
