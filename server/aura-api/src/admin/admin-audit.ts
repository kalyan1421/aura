import type { Queryable } from '../db/db';
import { appendAudit } from '../safety/audit';

/**
 * Console audit rows go to the same append-only, hash-chained `moderation_actions` log as the moderation service
 * (PRD 19 "Audit log": every staff action, config change, break-glass and login), written in the SAME transaction as
 * the change they describe. `detail` holds kinds, counts, ticket ids and internal record ids — never content, emails,
 * account ids or pseudonyms.
 */
export interface ConsoleAuditEntry {
  action: string;
  reasonCode?: string | null;
  reportId?: string | null;
  subjectHash?: string | null;
  detail?: Record<string, unknown>;
}

/** Actors that are not a staff member. */
export const SYSTEM_ACTORS = {
  pager: 'system:pager',
  publicForm: 'public:grievance_form',
  legalIntake: 'intake:legal_orders',
  unknown: 'unknown',
} as const;

export function auditConsole(q: Queryable, actor: string, e: ConsoleAuditEntry): Promise<number> {
  return appendAudit(q, {
    actor,
    action: e.action,
    reportId: e.reportId ?? null,
    subjectHash: e.subjectHash ?? null,
    reasonCode: e.reasonCode ?? null,
    detail: e.detail ?? {},
  });
}

/** Reason codes share the audit column's shape (`[a-z0-9_]{1,40}`). */
export const REASON_CODE_RE = /^[a-z0-9_]{1,40}$/;
