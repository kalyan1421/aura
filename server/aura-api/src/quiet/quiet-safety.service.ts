import { Inject, Injectable, Optional } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { CRISIS_REASON, TARGETING_MINOR_REASON, type ReportReason } from '../safety/safety-types';
import { reportLimit, REPORT_NOTE_MAX_CHARS } from '../safety/safety.schema';
import { assertNotClosed, loadSafetyConfig } from '../safety/safety.queries';
import { URGENT_PAGER, type UrgentPager } from '../safety/urgent-pager';
import { fitsChars } from '../sync/text-limits';
import { EVIDENCE_WINDOW_MIN, fileQuietReport } from './quiet-reports';
import { notFound, pathId, reportRequestSchema } from './quiet.schema';

/**
 * "Report a problem here" (contracts/api/v1-quiet.md §1.5; PRD 06b table "Quiet Together session: Session menu";
 * REQ-QUIET-06). Same reasons, lanes, SLA clocks, daily limit and 180-day evidence store as rooms; nobody is shown, so
 * there is no per-person block or mute. Works after leaving (while the session is kept, 7 days) and for suspended
 * accounts ("help is never locked"). Never returns lanes or ages (DS-10).
 */
@Injectable()
export class QuietSafetyService {
  constructor(
    private readonly db: DbService,
    @Optional() @Inject(URGENT_PAGER) private readonly pager?: UrgentPager,
  ) {}

  async report(userId: string, sessionIdParam: string, body: unknown, now = new Date()): Promise<{ reportId: string; showHelplines: boolean; created: boolean }> {
    const sessionId = pathId(sessionIdParam);
    const req = parseOrThrow(reportRequestSchema, body);
    const note = req.note?.trim() ? req.note.trim() : null;
    if (note !== null && !fitsChars(note, REPORT_NOTE_MAX_CHARS)) {
      throw ApiError.badRequest('invalid_request', `note: at most ${REPORT_NOTE_MAX_CHARS} characters`);
    }
    const reason = req.reason as ReportReason;
    await assertNotClosed(this.db, userId);
    const out = await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadSafetyConfig(tx);
      const member = await tx.query('select 1 from public.quiet_members where session_id = $1 and user_id = $2 limit 1', [sessionId, userId]);
      if (!member.rowCount) throw notFound();

      const existing = await tx.query<{ id: string }>(
        `select id from public.reports where reporter_user_id = $1 and target_ref = $2 and reason = $3 and status = 'open' and source = 'user'`,
        [userId, sessionId, reason],
      );
      if (existing.rows[0]) return { reportId: existing.rows[0].id, showHelplines: reason === CRISIS_REASON, created: false, pages: false };
      if (reason !== CRISIS_REASON) {
        const n = await tx.query<{ n: number }>(
          `select count(*)::int as n from public.reports
            where reporter_user_id = $1 and source = 'user' and reason <> $2 and created_at > now() - interval '24 hours'`,
          [userId, CRISIS_REASON],
        );
        if ((n.rows[0]?.n ?? 0) >= cfg.reportDailyLimit) throw reportLimit();
      }

      const senders = await tx.query<{ user_id: string }>(
        `select distinct m.user_id from public.quiet_gestures g join public.quiet_members m on m.member_id = g.member_id
          where g.session_id = $1 and g.created_at > $2::timestamptz - make_interval(mins => $3) and m.user_id <> $4`,
        [sessionId, now, EVIDENCE_WINDOW_MIN, userId],
      );
      // "Targeting a young person" counts everyone in the session (the reporter's sense of it is the signal).
      const everyone =
        reason === TARGETING_MINOR_REASON
          ? (await tx.query<{ user_id: string }>('select distinct user_id from public.quiet_members where session_id = $1', [sessionId])).rows.map((r) => r.user_id)
          : [];
      const created = await fileQuietReport(
        tx,
        { source: 'user', reporterUserId: userId, reason, sessionId, note, subjects: senders.rows.map((r) => r.user_id), now },
        cfg,
        everyone,
      );
      return { reportId: created.id, showHelplines: reason === CRISIS_REASON, created: true, pages: created.pages };
    });
    if (out.pages) this.pager?.reportFiled(out.reportId);
    return { reportId: out.reportId, showHelplines: out.showHelplines, created: out.created };
  }
}
