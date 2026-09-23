import { z } from 'zod';

/** F8 REQ-ACC-11: the purge runs this long after the FIRST deletion request (restorable until then). */
export const DELETION_GRACE_DAYS = 7;
const DAY_MS = 86_400_000;

/** `scheduled_for` = first request + exactly 7 × 24 h (an instant, so DST and time zones don't matter). */
export function deletionDateFor(requestedAt: Date): Date {
  return new Date(requestedAt.getTime() + DELETION_GRACE_DAYS * DAY_MS);
}

/**
 * `POST` / `DELETE /v1/account/deletion` carry no fields: no body, or a JSON object (unknown keys are
 * ignored). Anything else (e.g. an array) → `400 invalid_request`.
 */
export const deletionRequestSchema = z.object({}).optional();

/** `GET /v1/account`, and the body of every account-deletion response (contracts/api/v1.md). */
export interface AccountStatus {
  /** ISO instant the purge becomes due, or null when no deletion is scheduled. */
  deletionScheduledFor: string | null;
}
