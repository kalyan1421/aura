import type { Queryable } from '../db/db';
import { loadMatchingConfig } from '../rooms/matching-config';
import { isTzRegion } from '../rooms/regions';
import { appendAudit, subjectHash } from './audit';
import { createEvidenceHold, type EvidenceItemKind } from './evidence';
import { laneFor, slaFor, type SlaContext } from './lanes';
import { REPORT_REASONS, UNDER_13_REASON, type Lane, type ReportReason } from './safety-types';
import { hasActiveSanction, type SafetyConfig } from './safety.queries';

/**
 * Report creation shared by `POST /v1/safety/reports` and automatic signals (gesture flooding). Routes to a lane,
 * starts the SLA clock, snapshots the item into the evidence store (180 days) and links it. Callers hold the
 * reporter's advisory lock inside their transaction.
 */
export interface NewReport {
  source: 'user' | 'auto';
  autoSignal?: 'gesture_flood' | 'reflection_hold' | 'reflection_crisis' | 'reflection_minor_safety' | 'reflection_violation';
  reporterUserId: string | null;
  reporterMemberId: string | null;
  reason: ReportReason;
  targetKind: EvidenceItemKind;
  roomId: string | null;
  targetMemberId: string | null;
  targetGestureId: string | null;
  /** F6: the reported / queued reflection (target kind `reflection`). */
  targetReflectionId?: string | null;
  targetUserId: string | null;
  /** member / gesture / room / reflection id: the dedupe key. */
  targetRef: string;
  note: string | null;
  involvesMinor: boolean;
}

export interface CreatedReport {
  id: string;
  lane: Lane;
  evidenceHoldId: string;
  /** Pages the Owner at once (REQ-ADM-05 / REQ-ADM-13): the caller hands it to the pager after commit. */
  pages: boolean;
}

/** Crisis clock context: the room's region (its own Lantern Hour) and the configured Lantern Hour window. */
async function crisisContext(q: Queryable, roomId: string | null): Promise<SlaContext> {
  const cfg = await loadMatchingConfig(q);
  const region = roomId ? (await q.query<{ tz_region: string }>('select tz_region from public.rooms where id = $1', [roomId])).rows[0]?.tz_region : null;
  return { roomRegion: isTzRegion(region) ? region : null, lanternStart: cfg.lanternStart, lanternEnd: cfg.lanternEnd };
}

export async function insertReport(q: Queryable, r: NewReport, cfg: Pick<SafetyConfig, 'evidenceHoldDays'>, now = new Date()): Promise<CreatedReport> {
  const lane = laneFor(r.reason, r.involvesMinor);
  const sla = slaFor(lane, r.reason, r.involvesMinor, now, lane === 'crisis' ? await crisisContext(q, r.roomId) : {});
  const ins = await q.query<{ id: string }>(
    `insert into public.reports (source, auto_signal, reporter_user_id, reporter_member_id, reason, lane, involves_minor, pages,
                                 target_kind, room_id, target_member_id, target_gesture_id, target_user_id, target_ref, note,
                                 sla_due_at, target_reflection_id)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
     returning id`,
    [
      r.source,
      r.autoSignal ?? null,
      r.reporterUserId,
      r.reporterMemberId,
      r.reason,
      lane,
      r.involvesMinor,
      sla.pages,
      r.targetKind,
      r.roomId,
      r.targetMemberId,
      r.targetGestureId,
      r.targetUserId,
      r.targetRef,
      r.note,
      sla.dueAt,
      r.targetReflectionId ?? null,
    ],
  );
  const id = ins.rows[0].id;
  const evidenceHoldId = await createEvidenceHold(q, {
    reportId: id,
    itemKind: r.targetKind,
    roomId: r.roomId,
    memberId: r.targetMemberId,
    gestureId: r.targetGestureId,
    reflectionId: r.targetReflectionId ?? null,
    reason: `${lane}:${REPORT_REASONS[r.reason]}`,
    reporterUserId: r.reporterUserId,
    fallbackSubjectUserId: r.targetUserId,
    holdDays: cfg.evidenceHoldDays,
    context: {
      source: r.source,
      autoSignal: r.autoSignal ?? null,
      reason: r.reason,
      reasonKey: REPORT_REASONS[r.reason],
      lane,
      involvesMinor: r.involvesMinor,
      reporterMemberId: r.reporterMemberId,
      note: r.note,
      filedAt: now.toISOString(),
    },
  });
  await q.query('update public.reports set evidence_hold_id = $2 where id = $1', [id, evidenceHoldId]);
  return { id, lane, evidenceHoldId, pages: sla.pages };
}

/**
 * "May be under 13" reports from N distinct people (default 2) pause the reported account's rooms pending review
 * (PRD F5 "Under-18 accounts"). Idempotent: one active pause at a time. Returns true when a pause was applied now.
 */
export async function applyUnder13PauseIfDue(
  q: Queryable,
  targetUserId: string,
  reportId: string,
  cfg: Pick<SafetyConfig, 'under13ReportsToPause'>,
  masterKey: Buffer,
): Promise<boolean> {
  const r = await q.query<{ n: number }>(
    `select count(distinct reporter_user_id)::int as n from public.reports
      where target_user_id = $1 and reason = $2 and status = 'open' and source = 'user' and reporter_user_id is not null`,
    [targetUserId, UNDER_13_REASON],
  );
  if ((r.rows[0]?.n ?? 0) < cfg.under13ReportsToPause) return false;
  if (await hasActiveSanction(q, targetUserId, 'rooms_pause')) return false;
  await q.query(
    `insert into public.sanctions (user_id, kind, reason_code, source, report_id, created_by)
     values ($1, 'rooms_pause', 'under_13_reports', 'auto', $2, 'system')`,
    [targetUserId, reportId],
  );
  await appendAudit(q, {
    actor: 'system',
    action: 'auto_rooms_pause',
    reportId,
    subjectHash: subjectHash(masterKey, targetUserId),
    reasonCode: 'under_13_reports',
    detail: { distinctReporters: r.rows[0]?.n ?? 0 },
  });
  return true;
}
