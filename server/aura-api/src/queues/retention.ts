import type { Queryable } from '../db/db';

/**
 * Worker `maintenance` queue, job `retention` (daily): moderation retention settings on `public.safety_config`
 * (supabase/migrations/20261005000014_account_followups.sql).
 *
 *  - `moderation_actions` (the append-only, hash-chained audit log): rows older than
 *    `moderation_audit_retention_days` (default 1096 = 3 years, 19 admin console "Retention 3 years" [LEGAL]) go through
 *    `public.prune_moderation_actions()` — the only way to delete them. It removes a prefix of the chain in batches,
 *    never the newest row, and moves `moderation_audit_anchor`, so `verifyAuditChain()` keeps passing.
 *  - closed `reports` (actioned / dismissed): the PRD defines no retention. `closed_report_retention_days` is NULL by
 *    default = keep everything; nothing is deleted until AK and the lawyer choose a period [LEGAL]. When set, a closed
 *    report is deleted that long after it was resolved, unless its evidence hold is still running.
 *
 * Returns counts only (callers log them; never ids or content).
 */
export interface RetentionSummary {
  auditPruned: number;
  reportsPruned: number;
  /** The configured closed-report retention; null = keep (no deletion ran). */
  closedReportRetentionDays: number | null;
}

const AUDIT_BATCH = 10_000;
const REPORT_BATCH = 5_000;

export async function runRetention(q: Queryable): Promise<RetentionSummary> {
  let auditPruned = 0;
  for (;;) {
    // One statement = one transaction: the prune holds the audit chain's advisory lock only per batch.
    const r = await q.query<{ n: string | number }>('select public.prune_moderation_actions($1) as n', [AUDIT_BATCH]);
    const n = Number(r.rows[0]?.n ?? 0);
    auditPruned += n;
    if (n < AUDIT_BATCH) break;
  }

  const cfg = await q.query<{ days: number | null }>(
    'select closed_report_retention_days as days from public.safety_config where id',
  );
  const days = cfg.rows[0]?.days ?? null;
  let reportsPruned = 0;
  if (days !== null) {
    for (;;) {
      const r = await q.query(
        `delete from public.reports where id in (
           select r.id from public.reports r
            where r.status <> 'open' and r.resolved_at < now() - make_interval(days => $1)
              and not exists (select 1 from public.evidence_holds e where e.id = r.evidence_hold_id and e.hold_until > now())
            limit $2)`,
        [days, REPORT_BATCH],
      );
      const n = r.rowCount ?? 0;
      reportsPruned += n;
      if (n < REPORT_BATCH) break;
    }
  }
  return { auditPruned, reportsPruned, closedReportRetentionDays: days };
}
