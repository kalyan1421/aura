import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import type { Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { applyUnder13PauseIfDue, insertReport } from './reports.core';
import { CRISIS_REASON, TARGETING_MINOR_REASON, UNDER_13_REASON, type ReportReason, type ReportTargetKind } from './safety-types';
import { invalidTarget, notFound, parseReportRequest, reportLimit } from './safety.schema';
import { anyMinor, assertNotClosed, loadSafetyConfig } from './safety.queries';

export interface ReportCreated {
  reportId: string;
  showHelplines: boolean;
  /** false = an open report by you on the same target for the same reason already existed (repeats count once). */
  created: boolean;
}

export interface MyReport {
  reportId: string;
  reason: ReportReason;
  targetKind: ReportTargetKind;
  status: 'received' | 'reviewed';
  outcome: 'action_taken' | 'no_action' | null;
  createdAt: string;
  reviewedAt: string | null;
}

interface MembershipRow {
  member_id: string;
  user_id: string;
  left_at: Date | null;
}

/**
 * `POST /v1/safety/reports`, `GET /v1/safety/reports` (contracts/api/v1-rooms.md §2.1). The lane, `involves_minor`
 * and SLA are server-only (DS-10: the response never says whether anyone is under 18).
 */
@Injectable()
export class ReportsService {
  constructor(
    private readonly db: DbService,
    private readonly config: AppConfig,
  ) {}

  async create(userId: string, body: unknown): Promise<ReportCreated> {
    const req = parseReportRequest(body);
    await assertNotClosed(this.db, userId); // suspended accounts can still report ("help is never locked")
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadSafetyConfig(tx);
      const mine = await this.membership(tx, req.roomId, userId);
      if (!mine) throw notFound();

      // Resolve the target inside this room (stranger ids never cross rooms).
      let targetMemberId: string | null = null;
      let targetUserId: string | null = null;
      let targetGestureId: string | null = null;
      if (req.targetKind === 'member') {
        const t = await this.member(tx, req.roomId, req.memberId as string);
        if (!t) throw notFound();
        if (t.member_id === mine.member_id) throw invalidTarget();
        targetMemberId = t.member_id;
        targetUserId = t.user_id;
      } else if (req.targetKind === 'gesture') {
        const g = await tx.query<{ id: string; from_member_id: string; from_user_id: string }>(
          `select g.id, g.from_member_id, f.user_id as from_user_id
             from public.room_gestures g join public.room_members f on f.member_id = g.from_member_id
            where g.id = $1 and g.room_id = $2 and g.dropped is null`,
          [req.gestureId, req.roomId],
        );
        const row = g.rows[0];
        if (!row) throw notFound();
        if (row.from_member_id === mine.member_id) throw invalidTarget();
        targetGestureId = row.id;
        targetMemberId = row.from_member_id;
        targetUserId = row.from_user_id;
      }
      const targetRef = req.targetKind === 'member' ? (targetMemberId as string) : req.targetKind === 'gesture' ? (targetGestureId as string) : req.roomId;

      const existing = await tx.query<{ id: string }>(
        `select id from public.reports
          where reporter_user_id = $1 and target_ref = $2 and reason = $3 and status = 'open' and source = 'user'`,
        [userId, targetRef, req.reason],
      );
      if (existing.rows[0]) return { reportId: existing.rows[0].id, showHelplines: req.reason === CRISIS_REASON, created: false };

      if (req.reason !== CRISIS_REASON) {
        const n = await tx.query<{ n: number }>(
          `select count(*)::int as n from public.reports
            where reporter_user_id = $1 and source = 'user' and reason <> $2 and created_at > now() - interval '24 hours'`,
          [userId, CRISIS_REASON],
        );
        if ((n.rows[0]?.n ?? 0) >= cfg.reportDailyLimit) throw reportLimit();
      }

      // Anyone involved under 18 (either side; for a room, anyone in it) → Minors & grooming lane, invisibly.
      // "Targeting a young person" (9) is that lane whatever the ages; the young person is someone else in the room
      // (maybe already gone because of it), so everyone who has been in the room counts for its "Under 18" flag and
      // the 2 h / 24×7 page (lanes.ts). Nothing of this reaches any client (DS-10).
      const involved: Array<string | null> = [userId, targetUserId];
      const wholeRoom = req.reason === TARGETING_MINOR_REASON;
      if (req.targetKind === 'room' || wholeRoom) {
        const members = await tx.query<{ user_id: string }>(
          'select user_id from public.room_members where room_id = $1 and ($2::boolean or left_at is null)',
          [req.roomId, wholeRoom],
        );
        involved.push(...members.rows.map((x) => x.user_id));
      }
      const created = await insertReport(
        tx,
        {
          source: 'user',
          reporterUserId: userId,
          reporterMemberId: mine.member_id,
          reason: req.reason,
          targetKind: req.targetKind,
          roomId: req.roomId,
          targetMemberId,
          targetGestureId,
          targetUserId,
          targetRef,
          note: req.note,
          involvesMinor: await anyMinor(tx, involved),
        },
        cfg,
      );

      // The item hides for the reporter at once: a reported member is muted for them in this room (not for a
      // crisis report — "I'm worried about this person" isn't a violation); a reported gesture drops out of their lists.
      if (req.targetKind === 'member' && req.reason !== CRISIS_REASON && targetMemberId) {
        await tx.query(
          `insert into public.room_mutes (room_id, muter_member_id, muted_member_id) values ($1, $2, $3)
           on conflict (muter_member_id, muted_member_id) do nothing`,
          [req.roomId, mine.member_id, targetMemberId],
        );
      }
      if (req.reason === UNDER_13_REASON && targetUserId) {
        await applyUnder13PauseIfDue(tx, targetUserId, created.id, cfg, this.config.masterKey);
      }
      return { reportId: created.id, showHelplines: req.reason === CRISIS_REASON, created: true };
    });
  }

  /** The reporter's inbox: own reports and a coarse outcome — never what happened to the other person. */
  async listMine(userId: string): Promise<{ reports: MyReport[] }> {
    const r = await this.db.query<{
      id: string;
      reason: number;
      target_kind: ReportTargetKind;
      status: 'open' | 'actioned' | 'dismissed';
      created_at: Date;
      resolved_at: Date | null;
    }>(
      `select id, reason, target_kind, status, created_at, resolved_at from public.reports
        where reporter_user_id = $1 and source = 'user' order by created_at desc, id limit 100`,
      [userId],
    );
    return {
      reports: r.rows.map((x) => ({
        reportId: x.id,
        reason: x.reason as ReportReason,
        targetKind: x.target_kind,
        status: x.status === 'open' ? 'received' : 'reviewed',
        outcome: x.status === 'actioned' ? 'action_taken' : x.status === 'dismissed' ? 'no_action' : null,
        createdAt: x.created_at.toISOString(),
        reviewedAt: x.resolved_at ? x.resolved_at.toISOString() : null,
      })),
    };
  }

  /** Any membership (current, left or in a memory) of a room that still exists. */
  private async membership(q: Queryable, roomId: string, userId: string): Promise<MembershipRow | null> {
    const r = await q.query<MembershipRow>(
      `select m.member_id, m.user_id, m.left_at from public.room_members m join public.rooms r on r.id = m.room_id
        where m.room_id = $1 and m.user_id = $2 and r.purge_at > now()`,
      [roomId, userId],
    );
    return r.rows[0] ?? null;
  }

  private async member(q: Queryable, roomId: string, memberId: string): Promise<MembershipRow | null> {
    const r = await q.query<MembershipRow>('select member_id, user_id, left_at from public.room_members where room_id = $1 and member_id = $2', [
      roomId,
      memberId,
    ]);
    return r.rows[0] ?? null;
  }
}
