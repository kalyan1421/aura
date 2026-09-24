import { HttpStatus } from '@nestjs/common';
import { z } from 'zod';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { parseOrThrow } from '../common/zod';
import { fitsChars } from '../sync/text-limits';

/** `POST /v1/rooms/:roomId/reflections` (contracts/api/v1-reflections.md §1.3). Unknown keys are refused. */
const sendShape = z
  .object({
    reflectionId: z.string().refine(isUuid, 'must be a UUID').transform((s) => s.toLowerCase()),
    text: z.string(),
  })
  .strict();

export interface SendRequest {
  reflectionId: string;
  text: string;
}

export function parseSendRequest(body: unknown, maxChars: number): SendRequest {
  // REQ-REF-05: a reply payload is refused by name, whatever its value (text replies are post-v1).
  if (body && typeof body === 'object' && ('parentId' in body || 'parent_id' in body)) throw repliesNotSupported();
  const b = parseOrThrow(sendShape, body);
  const text = b.text.trim();
  if (text.length === 0) throw ApiError.badRequest('invalid_request', 'text: must not be empty');
  if (!fitsChars(text, maxChars)) throw ApiError.badRequest('invalid_request', `text: at most ${maxChars} characters`);
  return { reflectionId: b.reflectionId, text };
}

export const repliesNotSupported = (): ApiError =>
  ApiError.badRequest('replies_not_supported', 'Reflections are answered with gestures only; replies are not supported.');
export const reflectionNotFound = (): ApiError => new ApiError(HttpStatus.NOT_FOUND, 'reflection_not_found', 'No such reflection.');
export const reflectionIdConflict = (): ApiError =>
  ApiError.conflict('reflection_id_conflict', 'That reflection id is already used. Generate a new one for a new reflection.');
export const roomLimit = (): ApiError =>
  new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'reflection_room_limit', "That's 3 reflections for today in this room. Gestures are always open.");
export const dailyLimit = (): ApiError =>
  new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'reflection_daily_limit', "That's all the reflections for today. Gestures are always open.");
export const reflectionsPaused = (): ApiError =>
  new ApiError(HttpStatus.SERVICE_UNAVAILABLE, 'reflections_paused', 'Reflections are resting for a bit. Gestures still work.');
