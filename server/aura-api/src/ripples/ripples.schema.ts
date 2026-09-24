import { z } from 'zod';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { parseOrThrow } from '../common/zod';
import { MAX_REPORT_REASON } from '../safety/safety-types';
import { RIPPLE_ENTRIES } from './ripple-types';

const uuid = z.string().refine(isUuid, 'must be a UUID').transform((s) => s.toLowerCase());

/** `POST /v1/ripples/match` (contracts/api/v1-ripples.md §1.1): `roomId` exactly for a room entry. */
const matchShape = z.object({
  ticketId: uuid,
  entry: z.enum(RIPPLE_ENTRIES),
  roomId: uuid.nullish(),
});
export interface MatchRequest {
  ticketId: string;
  entry: 'quick' | 'room';
  roomId: string | null;
}
export function parseMatchRequest(body: unknown): MatchRequest {
  const m = parseOrThrow(matchShape, body);
  if (m.entry === 'room' && !m.roomId) throw ApiError.badRequest('invalid_request', 'roomId: required for a room entry');
  if (m.entry === 'quick' && m.roomId) throw ApiError.badRequest('invalid_request', 'roomId: not allowed for a quick match');
  return { ticketId: m.ticketId, entry: m.entry, roomId: m.roomId ?? null };
}

const seat = z.number().int().min(1).max(4);

/** §2.3: breath cycles this phone completed, and its own transitions (50 ms steps, null = missed). */
export const completeRequestSchema = z.object({
  cycles: z.number().int().min(0).max(60),
  trace: z
    .object({ offsets: z.array(z.number().int().min(-40).max(40).nullable()).min(1).max(120) })
    .nullish(),
});

/** §2.4 */
export const seatReportSchema = z.object({
  seat,
  reason: z.number().int().min(1).max(MAX_REPORT_REASON),
  note: z.string().nullish(),
});

/** §2.5, §2.6 */
export const seatSchema = z.object({ seat });

/** §2.7 */
export const echoConsentSchema = z.object({ enabled: z.boolean() });

/** Path ids: anything that isn't a UUID can't name a session / ticket → the same 404 as an unknown one. */
export function pathId(v: string): string {
  if (!isUuid(v)) throw notFound();
  return v.toLowerCase();
}

export const notFound = (): ApiError => new ApiError(404, 'not_found', 'Not found.');
export const seatNotFound = (): ApiError => new ApiError(404, 'seat_not_found', 'There is no one to report or block in that seat.');
export const invalidTarget = (): ApiError => ApiError.badRequest('invalid_target', 'You cannot target yourself.');
export const ticketConflict = (): ApiError => ApiError.conflict('ticket_conflict', 'That ticket id is already in use. Start a new one.');
