import { z } from 'zod';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { GESTURE_TYPES } from '../rooms/room-types';
import { MAX_REPORT_REASON } from '../safety/safety-types';
import { QUIET_MODES } from './quiet-types';

/** §1.1 — strict: an unknown field is refused. `timezone` (else the profile's) picks the region. */
export const joinRequestSchema = z
  .object({
    mode: z.enum(QUIET_MODES),
    timezone: z.string().min(1).max(64).nullish(),
  })
  .strict();

/**
 * §1.4 — REQ-QUIET-02: a preset, to the whole session. **Strict**: any other field (text, a member, a target) is a
 * `400 invalid_request`; there is no text anywhere and nothing can be aimed at a person.
 */
export const gestureRequestSchema = z.object({ type: z.enum(GESTURE_TYPES) }).strict();

/** §1.5 */
export const reportRequestSchema = z
  .object({
    reason: z.number().int().min(1).max(MAX_REPORT_REASON),
    note: z.string().nullish(),
  })
  .strict();

/** Path ids: anything that isn't a UUID can't name a session → the same 404 as an unknown one. */
export function pathId(v: string): string {
  if (!isUuid(v)) throw notFound();
  return v.toLowerCase();
}

export const notFound = (): ApiError => new ApiError(404, 'not_found', 'Not found.');
export const quietPaused = (): ApiError =>
  new ApiError(503, 'quiet_paused', 'Quiet Together is resting for a bit. The Sanctuary is always open.');
export const blockOver = (): ApiError => ApiError.conflict('block_over', 'This block has ended. The next one has already begun.');
export const invalidTimezone = (): ApiError => ApiError.badRequest('invalid_request', 'timezone: must be an IANA time zone');
