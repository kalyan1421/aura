import { z } from 'zod';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { parseOrThrow } from '../common/zod';
import { fitsChars } from '../sync/text-limits';
import type { ReportReason, ReportTargetKind } from './safety-types';

const uuid = z.string().refine(isUuid, 'must be a UUID').transform((s) => s.toLowerCase());

/** Reporter's optional note: ≤ 500 characters as people see them (grapheme clusters), moderators only. */
export const REPORT_NOTE_MAX_CHARS = 500;

const reportShape = z.object({
  target: z.discriminatedUnion('kind', [
    z.object({ kind: z.literal('member'), roomId: uuid, memberId: uuid }),
    z.object({ kind: z.literal('gesture'), roomId: uuid, gestureId: uuid }),
    z.object({ kind: z.literal('room'), roomId: uuid }),
  ]),
  reason: z.number().int().min(1).max(8),
  note: z.string().nullish(),
});

export interface ReportRequest {
  targetKind: ReportTargetKind;
  roomId: string;
  memberId: string | null;
  gestureId: string | null;
  reason: ReportReason;
  note: string | null;
}

export function parseReportRequest(body: unknown): ReportRequest {
  const r = parseOrThrow(reportShape, body);
  const note = r.note?.trim() ? r.note.trim() : null;
  if (note !== null && !fitsChars(note, REPORT_NOTE_MAX_CHARS)) {
    throw ApiError.badRequest('invalid_request', `note: at most ${REPORT_NOTE_MAX_CHARS} characters`);
  }
  return {
    targetKind: r.target.kind,
    roomId: r.target.roomId,
    memberId: r.target.kind === 'member' ? r.target.memberId : null,
    gestureId: r.target.kind === 'gesture' ? r.target.gestureId : null,
    reason: r.reason as ReportReason,
    note,
  };
}

export const blockRequestSchema = z.object({ roomId: uuid, memberId: uuid });

export const notFound = (): ApiError => new ApiError(404, 'not_found', 'Not found.');
export const memberNotFound = (): ApiError => new ApiError(404, 'member_not_found', 'That member is not in this room.');
export const invalidTarget = (): ApiError => ApiError.badRequest('invalid_target', 'You cannot target yourself.');
export const reportLimit = (): ApiError =>
  new ApiError(429, 'report_limit', 'That is a lot of reports today. If someone is in danger, the "I need help now" button is always here.');
