import { Inject, Injectable, Optional } from '@nestjs/common';
import { parseOrThrow } from '../common/zod';
import { AppConfig } from '../config/app-config';
import type { Queryable, Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { loadMatchingConfig } from '../rooms/matching-config';
import { isTzRegion } from '../rooms/regions';
import { laneFor, slaFor, type SlaContext } from '../safety/lanes';
import { applyUnder13PauseIfDue } from '../safety/reports.core';
import { CRISIS_REASON, REPORT_REASONS, TARGETING_MINOR_REASON, UNDER_13_REASON, type ReportReason } from '../safety/safety-types';
import { reportLimit, REPORT_NOTE_MAX_CHARS } from '../safety/safety.schema';
import { anyMinor, assertNotClosed, loadSafetyConfig, type SafetyConfig } from '../safety/safety.queries';
import { URGENT_PAGER, type UrgentPager } from '../safety/urgent-pager';
import { fitsChars } from '../sync/text-limits';
import { ApiError } from '../common/api-error';
import { dbNow, logEvent } from './ripple-core';
import { invalidTarget, notFound, pathId, seatNotFound, seatReportSchema, seatSchema } from './ripples.schema';

interface SessionCtx {
  id: string;
  room_id: string | null;
  tz_region: string | null;
  entry: string;
  start_rule: string;
  t0: Date;
  ends_at: Date;
  ended_at: Date | null;
  created_at: Date;
}

interface SeatCtx {
  id: string;
  seat: number;
  kind: 'human' | 'echo' | 'guide';
  user_id: string | null;
  pseudonym: string | null;
  room_member_id: string | null;
  joined_at: Date;
  left_at: Date | null;
  cycles_done: number | null;
}

/**
 * Safety on a light (contracts/api/v1-ripples.md §2.4–§2.6; PRD 06b "Breath Ripples HUD: tap a light: all three";
 * REQ-GAME-05 / REQ-GAME-08). Reports use the same reasons, lanes, SLA clocks, daily limit and 180-day evidence store as
 * rooms (src/safety); the evidence snapshot is the session (seats, pseudonyms, times, event log) with the reported
 * person as its subject. Blocks are the same account-level `public.blocks` (never matched again). Works after the
 * seat was left and for suspended accounts ("help is never locked"). Never returns lanes or ages (DS-10).
 */
@Injectable()
export class RippleSafetyService {
  constructor(
    private readonly db: DbService,
    private readonly config: AppConfig,
    @Optional() @Inject(URGENT_PAGER) private readonly pager?: UrgentPager,
  ) {}

  async report(userId: string, sessionIdParam: string, body: unknown): Promise<{ reportId: string; showHelplines: boolean; created: boolean }> {
    const sessionId = pathId(sessionIdParam);
    const req = parseOrThrow(seatReportSchema, body);
    const note = req.note?.trim() ? req.note.trim() : null;
    if (note !== null && !fitsChars(note, REPORT_NOTE_MAX_CHARS)) {
      throw ApiError.badRequest('invalid_request', `note: at most ${REPORT_NOTE_MAX_CHARS} characters`);
    }
    const reason = req.reason as ReportReason;
    await assertNotClosed(this.db, userId);
    const out = await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadSafetyConfig(tx);
      const { session, seats, target } = await this.resolve(tx, sessionId, userId, req.seat);
      const targetUserId = target.user_id as string;

      const existing = await tx.query<{ id: string }>(
        `select id from public.reports where reporter_user_id = $1 and target_ref = $2 and reason = $3 and status = 'open' and source = 'user'`,
        [userId, target.id, reason],
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

      // Anyone involved under 18 → Minors & grooming, invisibly; "targeting a young person" counts everyone seated.
      const involved: Array<string | null> = [userId, targetUserId];
      if (reason === TARGETING_MINOR_REASON) involved.push(...seats.map((s) => s.user_id));
      const created = await this.insert(
        tx,
        {
          source: 'user',
          reporterUserId: userId,
          reason,
          session,
          seats,
          target,
          note,
          involvesMinor: await anyMinor(tx, involved),
        },
        cfg,
      );
      await logEvent(tx, sessionId, target, 'report');
      if (reason === UNDER_13_REASON) await applyUnder13PauseIfDue(tx, targetUserId, created.id, cfg, this.config.masterKey);
      return { reportId: created.id, showHelplines: reason === CRISIS_REASON, created: true, pages: created.pages };
    });
    if (out.pages) this.pager?.reportFiled(out.reportId);
    return { reportId: out.reportId, showHelplines: out.showHelplines, created: out.created };
  }

  async block(userId: string, sessionIdParam: string, body: unknown): Promise<{ blockId: string; created: boolean }> {
    const sessionId = pathId(sessionIdParam);
    const { seat } = parseOrThrow(seatSchema, body);
    await assertNotClosed(this.db, userId);
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const { session, target } = await this.resolve(tx, sessionId, userId, seat);
      const ins = await tx.query<{ id: string }>(
        `insert into public.blocks (blocker_user_id, blocked_user_id, source_room_id, quadrant) values ($1, $2, $3, null)
         on conflict (blocker_user_id, blocked_user_id) do nothing returning id`,
        [userId, target.user_id, session.room_id],
      );
      await logEvent(tx, sessionId, target, 'block');
      if (ins.rows[0]) return { blockId: ins.rows[0].id, created: true };
      const existing = await tx.query<{ id: string }>('select id from public.blocks where blocker_user_id = $1 and blocked_user_id = $2', [
        userId,
        target.user_id,
      ]);
      return { blockId: existing.rows[0].id, created: false };
    });
  }

  /** REQ-GAME-05: one automatic spam-lane item per seat for a moderator; never a sanction by itself. */
  async flood(userId: string, sessionIdParam: string, body: unknown): Promise<void> {
    const sessionId = pathId(sessionIdParam);
    const { seat } = parseOrThrow(seatSchema, body);
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadSafetyConfig(tx);
      const { session, seats, target } = await this.resolve(tx, sessionId, userId, seat);
      await tx.query("select pg_advisory_xact_lock(hashtextextended('aura:ripple-flood:' || $1, 0))", [target.id]);
      const already = await tx.query(`select 1 from public.reports where target_ref = $1 and auto_signal = 'ripple_flood' limit 1`, [target.id]);
      if (already.rowCount) return;
      await this.insert(
        tx,
        {
          source: 'auto',
          reporterUserId: null,
          reason: 6,
          session,
          seats,
          target,
          note: null,
          involvesMinor: await anyMinor(tx, [target.user_id]),
        },
        cfg,
      );
      await logEvent(tx, sessionId, target, 'flood');
    });
  }

  /** The caller's seat (current or left) and a human target seat that isn't theirs. */
  private async resolve(tx: Tx, sessionId: string, userId: string, seatNo: number): Promise<{ session: SessionCtx; seats: SeatCtx[]; target: SeatCtx }> {
    const s = await tx.query<SessionCtx>(
      'select id, room_id, tz_region, entry, start_rule, t0, ends_at, ended_at, created_at from public.ripple_sessions where id = $1',
      [sessionId],
    );
    const session = s.rows[0];
    if (!session) throw notFound();
    const seats = (
      await tx.query<SeatCtx>(
        `select id, seat, kind, user_id, pseudonym, room_member_id, joined_at, left_at, cycles_done
           from public.ripple_seats where session_id = $1 order by seat`,
        [sessionId],
      )
    ).rows;
    if (!seats.some((x) => x.user_id === userId)) throw notFound();
    const target = seats.find((x) => x.seat === seatNo);
    if (!target || target.kind !== 'human' || !target.user_id) throw seatNotFound();
    if (target.user_id === userId) throw invalidTarget();
    return { session, seats, target };
  }

  /** The report row, its SLA clock and the evidence snapshot (180 days), linked. Same shape as src/safety/reports.core.ts. */
  private async insert(
    tx: Tx,
    r: {
      source: 'user' | 'auto';
      reporterUserId: string | null;
      reason: ReportReason;
      session: SessionCtx;
      seats: SeatCtx[];
      target: SeatCtx;
      note: string | null;
      involvesMinor: boolean;
    },
    cfg: SafetyConfig,
  ): Promise<{ id: string; pages: boolean }> {
    const now = await dbNow(tx);
    const lane = laneFor(r.reason, r.involvesMinor);
    const sla = slaFor(lane, r.reason, r.involvesMinor, now, lane === 'crisis' ? await crisisContext(tx, r.session.tz_region) : {});
    const ins = await tx.query<{ id: string }>(
      `insert into public.reports (source, auto_signal, reporter_user_id, reason, lane, involves_minor, pages, target_kind, room_id,
                                   target_user_id, target_ref, note, sla_due_at)
       values ($1, $2, $3, $4, $5, $6, $7, 'ripple_seat', $8, $9, $10, $11, $12) returning id`,
      [
        r.source,
        r.source === 'auto' ? 'ripple_flood' : null,
        r.reporterUserId,
        r.reason,
        lane,
        r.involvesMinor,
        sla.pages,
        r.session.room_id,
        r.target.user_id,
        r.target.id,
        r.note,
        sla.dueAt,
      ],
    );
    const id = ins.rows[0].id;
    const log = await tx.query('select seat, seat_id, event, at from public.ripple_session_log where session_id = $1 order by at, id', [r.session.id]);
    const snapshot = {
      capturedAt: now.toISOString(),
      report: {
        reportId: id,
        source: r.source,
        autoSignal: r.source === 'auto' ? 'ripple_flood' : null,
        reason: r.reason,
        reasonKey: REPORT_REASONS[r.reason],
        lane,
        involvesMinor: r.involvesMinor,
        note: r.note,
        filedAt: now.toISOString(),
      },
      rippleSession: r.session,
      // Only the SUBJECT's account id is held (never the reporter's): evidence.ts rules.
      seats: r.seats.map((x) => ({
        seat: x.seat,
        seatId: x.id,
        kind: x.kind,
        pseudonym: x.pseudonym,
        roomMemberId: x.room_member_id,
        accountId: x.id === r.target.id ? x.user_id : null,
        isReporter: r.reporterUserId !== null && x.user_id === r.reporterUserId,
        joinedAt: x.joined_at,
        leftAt: x.left_at,
        cyclesDone: x.cycles_done,
      })),
      log: log.rows,
    };
    const hold = await tx.query<{ id: string }>(
      `insert into public.evidence_holds (report_id, item_kind, item_ref, reason, account_ids, snapshot, hold_until)
       values ($1, 'ripple_seat', $2, $3, $4::uuid[], $5::jsonb, now() + make_interval(days => $6)) returning id`,
      [id, r.target.id, `${lane}:${REPORT_REASONS[r.reason]}`, [r.target.user_id], JSON.stringify(snapshot), cfg.evidenceHoldDays],
    );
    await tx.query('update public.reports set evidence_hold_id = $2 where id = $1', [id, hold.rows[0].id]);
    return { id, pages: sla.pages };
  }
}

/** Crisis clock: a room session's region (its Lantern Hour) and the configured window, like rooms. */
async function crisisContext(q: Queryable, region: string | null): Promise<SlaContext> {
  const cfg = await loadMatchingConfig(q);
  return { roomRegion: isTzRegion(region) ? region : null, lanternStart: cfg.lanternStart, lanternEnd: cfg.lanternEnd };
}
