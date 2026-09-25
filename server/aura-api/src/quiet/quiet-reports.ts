import type { Queryable } from '../db/db';
import { loadMatchingConfig } from '../rooms/matching-config';
import { isTzRegion } from '../rooms/regions';
import { laneFor, slaFor } from '../safety/lanes';
import { REPORT_REASONS, type ReportReason } from '../safety/safety-types';
import type { SafetyConfig } from '../safety/safety.queries';
import { anyMinor } from '../safety/safety.queries';

/**
 * "Report a problem here" in a Quiet Together session (and the automatic flood signal): the report row (target kind
 * `quiet_session`, F9 lanes and SLA clocks), linked to an evidence snapshot held 180 days. Nobody is shown in a
 * session, so the SUBJECTS are the accounts whose gestures are in the window (the only thing anyone does there); only
 * their account ids are held, never the reporter's (src/safety/evidence.ts rules). Runs in the caller's transaction,
 * under the caller's lock.
 */
export const EVIDENCE_WINDOW_MIN = 60;

export interface NewQuietReport {
  source: 'user' | 'auto';
  reporterUserId: string | null;
  reason: ReportReason;
  sessionId: string;
  note: string | null;
  /** The accounts the report is about (auto: the flooder; user: whoever sent gestures in the last hour). */
  subjects: string[];
  now: Date;
}

export async function fileQuietReport(
  q: Queryable,
  r: NewQuietReport,
  cfg: Pick<SafetyConfig, 'evidenceHoldDays'>,
  involved: Array<string | null> = [],
): Promise<{ id: string; lane: string; pages: boolean }> {
  const session = (
    await q.query<{ id: string; mode: string; tz_region: string; t0: Date; ends_at: Date; created_at: Date }>(
      'select id, mode, tz_region, t0, ends_at, created_at from public.quiet_sessions where id = $1',
      [r.sessionId],
    )
  ).rows[0];
  const subjects = [...new Set(r.subjects)].filter((s) => s !== r.reporterUserId);
  const involvesMinor = await anyMinor(q, [r.reporterUserId, ...subjects, ...involved]);
  const lane = laneFor(r.reason, involvesMinor);
  let ctx = {};
  if (lane === 'crisis') {
    const m = await loadMatchingConfig(q);
    ctx = { roomRegion: isTzRegion(session?.tz_region) ? session.tz_region : null, lanternStart: m.lanternStart, lanternEnd: m.lanternEnd };
  }
  const sla = slaFor(lane, r.reason, involvesMinor, r.now, ctx);
  const ins = await q.query<{ id: string }>(
    `insert into public.reports (source, auto_signal, reporter_user_id, reason, lane, involves_minor, pages, target_kind, room_id,
                                 target_user_id, target_ref, note, sla_due_at)
     values ($1, $2, $3, $4, $5, $6, $7, 'quiet_session', null, $8, $9, $10, $11) returning id`,
    [
      r.source,
      r.source === 'auto' ? 'gesture_flood' : null,
      r.reporterUserId,
      r.reason,
      lane,
      involvesMinor,
      sla.pages,
      subjects.length === 1 ? subjects[0] : null,
      r.sessionId,
      r.note,
      sla.dueAt,
    ],
  );
  const id = ins.rows[0].id;
  // The session's recent log: member ids (server-side), gesture types and times. No text exists to copy.
  const members = await q.query<{ member_id: string; user_id: string; joined_at: Date; left_at: Date | null }>(
    'select member_id, user_id, joined_at, left_at from public.quiet_members where session_id = $1 order by joined_at, member_id',
    [r.sessionId],
  );
  const gestures = await q.query<{ member_id: string; type: string; dropped: string | null; created_at: Date }>(
    `select member_id, type, dropped, created_at from public.quiet_gestures
      where session_id = $1 and created_at > $2::timestamptz - make_interval(mins => $3)
      order by created_at, id limit 2000`,
    [r.sessionId, r.now, EVIDENCE_WINDOW_MIN],
  );
  const subjectSet = new Set(subjects);
  const snapshot = {
    capturedAt: r.now.toISOString(),
    report: {
      reportId: id,
      source: r.source,
      autoSignal: r.source === 'auto' ? 'gesture_flood' : null,
      reason: r.reason,
      reasonKey: REPORT_REASONS[r.reason],
      lane,
      involvesMinor,
      note: r.note,
      filedAt: r.now.toISOString(),
    },
    quietSession: session ?? { id: r.sessionId },
    members: members.rows.map((m) => ({
      memberId: m.member_id,
      accountId: subjectSet.has(m.user_id) ? m.user_id : null,
      isReporter: r.reporterUserId !== null && m.user_id === r.reporterUserId,
      joinedAt: m.joined_at,
      leftAt: m.left_at,
    })),
    gestures: gestures.rows.map((g) => ({ memberId: g.member_id, type: g.type, dropped: g.dropped, at: g.created_at })),
  };
  const hold = await q.query<{ id: string }>(
    `insert into public.evidence_holds (report_id, item_kind, item_ref, reason, account_ids, snapshot, hold_until)
     values ($1, 'quiet_session', $2, $3, $4::uuid[], $5::jsonb, $6::timestamptz + make_interval(days => $7)) returning id`,
    [id, r.sessionId, `${lane}:${REPORT_REASONS[r.reason]}`, subjects, JSON.stringify(snapshot), r.now, cfg.evidenceHoldDays],
  );
  await q.query('update public.reports set evidence_hold_id = $2 where id = $1', [id, hold.rows[0].id]);
  return { id, lane, pages: sla.pages };
}
