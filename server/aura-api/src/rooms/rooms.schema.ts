import { z } from 'zod';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { parseOrThrow } from '../common/zod';
import { isValidTimeZone, QUADRANTS } from '../rules';
import { GESTURE_TARGETS, GESTURE_TYPES, type GestureTarget, type GestureType } from './room-types';

const uuid = z.string().refine(isUuid, 'must be a UUID').transform((s) => s.toLowerCase());

/** `POST /v1/rooms/match` (contracts/api/v1-rooms.md §1.1). */
export const matchRequestSchema = z.object({
  quadrant: z.enum(QUADRANTS),
  moodId: z.string().min(1).max(64),
  timezone: z.string().trim().refine(isValidTimeZone, 'must be an IANA time zone, e.g. Asia/Kolkata').optional(),
  allowPoolFallback: z.boolean().optional(),
});
export type MatchRequest = z.infer<typeof matchRequestSchema>;

const gestureShape = z.object({
  type: z.enum(GESTURE_TYPES),
  target: z.enum(GESTURE_TARGETS),
  toMemberId: uuid.nullish(),
  toReflectionId: uuid.nullish(),
});

export interface GestureRequest {
  type: GestureType;
  target: GestureTarget;
  toMemberId: string | null;
  /** F6: exactly when `target` is `reflection`. */
  toReflectionId: string | null;
}

/** `POST /v1/rooms/:roomId/gestures` (§1.5): `toMemberId` exactly when `target` is `member`, `toReflectionId` for `reflection`. */
export function parseGestureRequest(body: unknown): GestureRequest {
  const g = parseOrThrow(gestureShape, body);
  if (g.target === 'member' && !g.toMemberId) throw ApiError.badRequest('invalid_request', 'toMemberId: required for a member gesture');
  if (g.target !== 'member' && g.toMemberId) throw ApiError.badRequest('invalid_request', `toMemberId: not allowed for a ${g.target} gesture`);
  if (g.target === 'reflection' && !g.toReflectionId) throw ApiError.badRequest('invalid_request', 'toReflectionId: required for a reflection gesture');
  if (g.target !== 'reflection' && g.toReflectionId) throw ApiError.badRequest('invalid_request', `toReflectionId: not allowed for a ${g.target} gesture`);
  return { type: g.type, target: g.target, toMemberId: g.toMemberId ?? null, toReflectionId: g.toReflectionId ?? null };
}

export const surveyRequestSchema = z.object({ answer: z.enum(['yes', 'no', 'skip']) });
export const muteRequestSchema = z.object({ memberId: uuid });

/** Path ids: anything that isn't a UUID can't name a room or member → the same 404 as an unknown one. */
export function pathId(v: string, notFound: () => ApiError): string {
  if (!isUuid(v)) throw notFound();
  return v.toLowerCase();
}

export const roomNotFound = (): ApiError => new ApiError(404, 'not_found', 'No such room.');
export const memberNotFound = (): ApiError => new ApiError(404, 'member_not_found', 'That member is not in this room.');
export const invalidTarget = (): ApiError => ApiError.badRequest('invalid_target', 'You cannot target yourself.');
export const roomReadOnly = (): ApiError => ApiError.conflict('room_read_only', 'This room has become a memory and is read-only.');
export const languagePoolUnavailable = (): ApiError =>
  ApiError.conflict('language_pool_unavailable', 'Hindi and Hinglish rooms are opening soon. Retry with allowPoolFallback to join an English room.');
export const joinLimit = (): ApiError =>
  new ApiError(429, 'room_join_limit', 'That is 3 new rooms for this feeling today. Your current rooms are still open to you.');

/** `POST /v1/rooms/:roomId/intention/hold` outside the room's Lantern Hour (or a memory): nothing to hold now. */
export const intentionClosed = (): ApiError =>
  ApiError.conflict('intention_closed', "Tonight's intention opens with Lantern Hour.");
/** Kill switch `room_intention_enabled` off. */
export const intentionPaused = (): ApiError =>
  new ApiError(503, 'intention_paused', "Tonight's intention is resting for a bit.");
