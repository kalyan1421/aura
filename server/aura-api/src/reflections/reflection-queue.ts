import type { Queryable } from '../db/db';
import { appendAudit, subjectHash } from '../safety/audit';
import { insertReport } from '../safety/reports.core';
import type { ReportReason } from '../safety/safety-types';
import { loadSafetyConfig } from '../safety/safety.queries';
import type { Decision } from './decide';
import type { ReflectionRow } from './reflections.repository';

/**
 * The pipeline's queue items (PRD 19 "Queues and priority lanes"; contracts/api/v1-reflections.md §4): every held,
 * crisis-diverted, minor-safety or violation reflection becomes an automatic report on the reflection (`source: auto`,
 * `target_kind: reflection`), routed by the usual lanes (src/safety/lanes.ts: crisis → L0; minors & grooming, or anyone
 * under 18 involved → L1; harassment / hate / sexual → L2; the rest → L3), with its SLA, page flag and a 180-day
 * evidence snapshot (encrypted text). Minor-safety hits also shadow-mute the author until review [ASSUMPTION, F6
 * step 4] — their gestures and reflections stop reaching anyone, invisibly. Audited as `system`.
 */
export interface QueuedItem {
  reportId: string;
  pages: boolean;
}

export async function queueReflection(q: Queryable, row: ReflectionRow, decision: Decision, masterKey: Buffer, now = new Date()): Promise<QueuedItem | null> {
  if (!decision.queue) return null;
  const safety = await loadSafetyConfig(q);
  // Sexual content about minors involves a minor by definition (the "Under 18" flag, the 2 h clock and the 24×7 page).
  const involvesMinor = row.involves_minor || (decision.minorSafety && decision.queue.reason === 3);
  const report = await insertReport(
    q,
    {
      source: 'auto',
      autoSignal: decision.queue.signal,
      reporterUserId: null,
      reporterMemberId: null,
      reason: decision.queue.reason as ReportReason,
      targetKind: 'reflection',
      roomId: row.room_id,
      targetMemberId: row.member_id,
      targetGestureId: null,
      targetReflectionId: row.id,
      targetUserId: row.user_id,
      targetRef: row.id,
      note: null,
      involvesMinor,
    },
    safety,
    now,
  );
  const hash = subjectHash(masterKey, row.user_id);
  await appendAudit(q, {
    actor: 'system',
    action: `auto_${decision.queue.signal}`,
    reportId: report.id,
    subjectHash: hash,
    reasonCode: decision.holdReason ?? decision.rejectReason ?? (decision.outcome === 'crisis_diverted' ? 'crisis' : 'reflection'),
    detail: { reflectionId: row.id, outcome: decision.outcome, stage: decision.stage, topCategory: decision.topCategory, strict: row.strict },
  });
  if (decision.minorSafety) {
    const s = await q.query<{ id: string }>(
      `insert into public.sanctions (user_id, kind, reason_code, source, report_id, created_by)
       select $1, 'shadow_mute', 'auto_minor_safety', 'auto', $2, 'system'
        where not exists (select 1 from public.sanctions x where x.user_id = $1 and x.kind = 'shadow_mute' and x.source = 'auto'
                            and x.lifted_at is null and x.ends_at is null)
       returning id`,
      [row.user_id, report.id],
    );
    if (s.rows[0]) {
      await appendAudit(q, {
        actor: 'system',
        action: 'auto_reflection_shadow_mute',
        reportId: report.id,
        subjectHash: hash,
        reasonCode: 'auto_minor_safety',
        detail: { reflectionId: row.id, until: 'review' },
      });
    }
  }
  return { reportId: report.id, pages: report.pages };
}
