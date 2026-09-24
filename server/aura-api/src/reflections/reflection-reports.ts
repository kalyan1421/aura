import type { Queryable } from '../db/db';
import { appendAudit, subjectHash } from '../safety/audit';
import { anyMinor } from '../safety/safety.queries';
import { ReflectionBroadcast } from './reflection-broadcast';

/**
 * Reports on a reflection (`POST /v1/safety/reports`, `target.kind: "reflection"`; contracts/api/v1-reflections.md
 * §1.6). Plain SQL helpers called by ReportsService inside its transaction (no DI, like the other safety helpers).
 */
export interface ReportableReflection {
  id: string;
  room_id: string;
  member_id: string;
  user_id: string;
}

/** A published reflection in this room — or one this reporter already reported (repeats answer 200). */
export async function reflectionForReport(q: Queryable, roomId: string, reflectionId: string, reporterUserId: string): Promise<ReportableReflection | null> {
  const r = await q.query<ReportableReflection>(
    `select r.id, r.room_id, r.member_id, r.user_id from public.reflections r
      where r.id = $1 and r.room_id = $2
        and (r.status = 'published'
             or exists (select 1 from public.reports x where x.target_reflection_id = r.id and x.reporter_user_id = $3))`,
    [reflectionId, roomId, reporterUserId],
  );
  return r.rows[0] ?? null;
}

/** Report reasons that hide on ONE report when the author or the reporter is under 18 (PRD F6 step 6, F9 edge cases). */
const ONE_REPORT_REASONS: ReadonlySet<number> = new Set([3, 5, 9]);
export const DISTINCT_REPORTERS_TO_HIDE = 3;

/**
 * REQ-REF-06 auto-hide, in the reporter's transaction ("within 5 s"): open reports from 3 distinct members (repeats
 * count once; reason 1 "in danger" never counts toward hiding), or 1 sexual / contact / targeting-a-young-person report
 * when the author or that reporter is under 18. The item hides for everyone (`reflection_removed`) and waits in the
 * queue; a moderator's approve restores it. Audited as `system`. Returns true when it hid the reflection now.
 */
export async function hideReflectionIfDue(
  q: Queryable,
  reflectionId: string,
  report: { reporterUserId: string; reason: number; reportId: string },
  masterKey: Buffer,
  now = new Date(),
): Promise<boolean> {
  const row = (
    await q.query<{ id: string; room_id: string; user_id: string; status: string; hidden_at: Date | null }>(
      'select id, room_id, user_id, status, hidden_at from public.reflections where id = $1 for update',
      [reflectionId],
    )
  ).rows[0];
  if (!row || row.status !== 'published' || row.hidden_at) return false;
  const n = (
    await q.query<{ n: number }>(
      `select count(distinct reporter_user_id)::int as n from public.reports
        where target_reflection_id = $1 and source = 'user' and status = 'open' and reason <> 1 and reporter_user_id is not null`,
      [reflectionId],
    )
  ).rows[0]?.n ?? 0;
  const oneReport = ONE_REPORT_REASONS.has(report.reason) && (await anyMinor(q, [row.user_id, report.reporterUserId]));
  if (n < DISTINCT_REPORTERS_TO_HIDE && !oneReport) return false;
  await q.query(`update public.reflections set hidden_at = now(), hold_reason = 'reported' where id = $1`, [reflectionId]);
  await ReflectionBroadcast.removed(q, row.room_id, reflectionId, now);
  await appendAudit(q, {
    actor: 'system',
    action: 'auto_reflection_hide',
    reportId: report.reportId,
    subjectHash: subjectHash(masterKey, row.user_id),
    reasonCode: oneReport ? 'one_report_minor' : 'distinct_reporters',
    detail: { reflectionId, distinctReporters: n },
  });
  return true;
}
