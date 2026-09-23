import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import type { Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { Broadcast } from '../rooms/broadcast';
import { loadMatchingConfig } from '../rooms/matching-config';
import { countsView } from '../rooms/room-views';
import { RoomsRepository } from '../rooms/rooms.repository';
import type { Quadrant } from '../rules';
import { appendAudit, readAudit, subjectHash, verifyAuditChain, type AuditRow } from './audit';
import {
  ACTIVE_SANCTION_SQL,
  CRISIS_REASON,
  LANE_PRIORITY,
  REPORT_REASONS,
  ROOM_ACCESS_SANCTIONS,
  type Lane,
  type ReportReason,
  type ReportReasonKey,
  type ReportTargetKind,
  type SanctionKind,
} from './safety-types';
import { loadSafetyConfig } from './safety.queries';
import { consequenceForActiveStrikes } from './strikes';

/**
 * Internal moderation API for the admin console (19-admin-console.md; the console's HTTP layer, SSO/2FA and roles come
 * next stage and wrap these methods). Never exposes content beyond what a report carries, DOBs, emails or raw account
 * ids: subjects appear as an HMAC (`subject.hash`) plus the room pseudonym; "Under 18" is a boolean flag. Every
 * action writes the append-only, hash-chained audit log with a reason code (REQ-SAFE-08).
 */
export type ModerationActionKind = 'dismiss' | 'warn' | 'strike' | 'shadow_mute' | 'suspend' | 'pause' | 'ban';

export type ModerationErrorCode =
  | 'report_not_found'
  | 'report_closed'
  | 'no_subject'
  | 'crisis_never_strikes'
  | 'invalid_duration'
  | 'invalid_input'
  | 'sanction_not_found'
  | 'evidence_not_found';

export class ModerationError extends Error {
  constructor(
    readonly code: ModerationErrorCode,
    message: string = code,
  ) {
    super(message);
    this.name = 'ModerationError';
  }
}

export interface QueueItem {
  reportId: string;
  lane: Lane;
  priority: number;
  reason: ReportReason;
  reasonKey: ReportReasonKey;
  source: 'user' | 'auto';
  autoSignal: string | null;
  targetKind: ReportTargetKind;
  createdAt: string;
  slaDueAt: string;
  overdue: boolean;
  pages: boolean;
  /** The console's "Under 18" flag (by stored DOB) — never the DOB or an age. */
  involvesMinor: boolean;
  /** Distinct people with an open report on the same item. */
  reporterCount: number;
  note: string | null;
  room: { roomId: string; quadrant: Quadrant; languagePool: string; tzRegion: string; ageHours: number } | null;
  subject: {
    hash: string;
    pseudonym: string | null;
    accountAgeDays: number | null;
    activeStrikes: number;
    activeSanctions: SanctionKind[];
  } | null;
  evidenceHoldId: string | null;
}

export interface ActInput {
  reportId: string;
  action: ModerationActionKind;
  /** Staff identity (e.g. `staff:<console user>`), never an app account. */
  actor: string;
  /** Reason code for the log and the person's notice; defaults to the report reason key. */
  reasonCode?: string;
  /** `shadow_mute`: 1–720 h (default 168 = 7 days). `suspend`: 24 or 168 (default 24). */
  hours?: number;
}

export interface ActResult {
  reportId: string;
  status: 'open' | 'actioned' | 'dismissed';
  sanctionId: string | null;
  strikeId: string | null;
  activeStrikes: number | null;
}

const REASON_CODE_RE = /^[a-z0-9_]{1,40}$/;

@Injectable()
export class ModerationService {
  constructor(
    private readonly db: DbService,
    private readonly config: AppConfig,
    private readonly rooms: RoomsRepository,
  ) {}

  /** Open items, lane priority first (crisis > minors & grooming > harassment > spam), then oldest first. */
  async listQueue(opts: { lane?: Lane; limit?: number; now?: Date } = {}): Promise<QueueItem[]> {
    const now = opts.now ?? new Date();
    const r = await this.db.query<{
      id: string;
      lane: Lane;
      reason: number;
      source: 'user' | 'auto';
      auto_signal: string | null;
      target_kind: ReportTargetKind;
      created_at: Date;
      sla_due_at: Date;
      pages: boolean;
      involves_minor: boolean;
      note: string | null;
      evidence_hold_id: string | null;
      target_user_id: string | null;
      room_id: string | null;
      quadrant: Quadrant | null;
      language_pool: string | null;
      tz_region: string | null;
      room_created_at: Date | null;
      pseudonym: string | null;
      reporter_count: number;
      account_created_at: Date | null;
      active_strikes: number;
      active_sanctions: SanctionKind[];
    }>(
      `select r.id, r.lane, r.reason, r.source, r.auto_signal, r.target_kind, r.created_at, r.sla_due_at, r.pages,
              r.involves_minor, r.note, r.evidence_hold_id, r.target_user_id,
              rm.id as room_id, rm.quadrant, rm.language_pool, rm.tz_region, rm.created_at as room_created_at,
              coalesce(tm.pseudonym, gm.pseudonym) as pseudonym,
              (select count(distinct x.reporter_user_id) from public.reports x
                where x.status = 'open' and x.target_ref = r.target_ref)::int as reporter_count,
              u.created_at as account_created_at,
              (select count(*) from public.strikes s
                where s.user_id = r.target_user_id and s.revoked_at is null and s.expires_at > now())::int as active_strikes,
              coalesce((select array_agg(distinct s.kind) from public.sanctions s
                         where s.user_id = r.target_user_id and ${ACTIVE_SANCTION_SQL('s')}), '{}') as active_sanctions
         from public.reports r
         left join public.rooms rm on rm.id = r.room_id
         left join public.room_members tm on tm.member_id = r.target_member_id
         left join public.room_gestures g on g.id = r.target_gesture_id
         left join public.room_members gm on gm.member_id = g.from_member_id
         left join auth.users u on u.id = r.target_user_id
        where r.status = 'open' and ($1::text is null or r.lane = $1)
        order by case r.lane when 'crisis' then 0 when 'minors_grooming' then 1 when 'harassment' then 2 else 3 end,
                 r.created_at, r.id
        limit $2`,
      [opts.lane ?? null, Math.min(Math.max(opts.limit ?? 50, 1), 500)],
    );
    return r.rows.map((x) => ({
      reportId: x.id,
      lane: x.lane,
      priority: LANE_PRIORITY[x.lane],
      reason: x.reason as ReportReason,
      reasonKey: REPORT_REASONS[x.reason as ReportReason],
      source: x.source,
      autoSignal: x.auto_signal,
      targetKind: x.target_kind,
      createdAt: x.created_at.toISOString(),
      slaDueAt: x.sla_due_at.toISOString(),
      overdue: x.sla_due_at.getTime() < now.getTime(),
      pages: x.pages,
      involvesMinor: x.involves_minor,
      reporterCount: x.reporter_count,
      note: x.note,
      room:
        x.room_id && x.quadrant && x.room_created_at
          ? {
              roomId: x.room_id,
              quadrant: x.quadrant,
              languagePool: x.language_pool ?? '',
              tzRegion: x.tz_region ?? '',
              ageHours: Math.floor((now.getTime() - x.room_created_at.getTime()) / 3_600_000),
            }
          : null,
      subject: x.target_user_id
        ? {
            hash: subjectHash(this.config.masterKey, x.target_user_id),
            pseudonym: x.pseudonym,
            accountAgeDays: x.account_created_at ? Math.floor((now.getTime() - x.account_created_at.getTime()) / 86_400_000) : null,
            activeStrikes: x.active_strikes,
            activeSanctions: x.active_sanctions,
          }
        : null,
      evidenceHoldId: x.evidence_hold_id,
    }));
  }

  /** Act on an open report. One transaction: sanction/strike, report status, audit row (and hiding from rooms). */
  async act(input: ActInput, now = new Date()): Promise<ActResult> {
    if (!input.actor || input.actor.length > 120) throw new ModerationError('invalid_input', 'actor is required');
    if (input.reasonCode !== undefined && !REASON_CODE_RE.test(input.reasonCode)) throw new ModerationError('invalid_input', 'reasonCode');
    return this.db.withTx(async (tx) => {
      const rp = (
        await tx.query<{ id: string; status: string; lane: Lane; reason: number; target_user_id: string | null; evidence_hold_id: string | null }>(
          'select id, status, lane, reason, target_user_id, evidence_hold_id from public.reports where id = $1 for update',
          [input.reportId],
        )
      ).rows[0];
      if (!rp) throw new ModerationError('report_not_found');
      if (rp.status !== 'open') throw new ModerationError('report_closed');
      const reasonCode = input.reasonCode ?? REPORT_REASONS[rp.reason as ReportReason];
      const subject = (): string => {
        if (!rp.target_user_id) throw new ModerationError('no_subject', 'this report has no account to act on');
        return rp.target_user_id;
      };
      const safety = await loadSafetyConfig(tx);

      let sanctionId: string | null = null;
      let sanctionKind: SanctionKind | null = null;
      let strikeId: string | null = null;
      let activeStrikes: number | null = null;
      let hours: number | null = null;
      let resolution: 'actioned' | 'dismissed' | null = 'actioned';

      switch (input.action) {
        case 'dismiss':
          resolution = 'dismissed';
          break;
        case 'warn':
          sanctionKind = 'warning';
          break;
        case 'strike': {
          // REQ-SAFE-08 / REQ-ADM-07: a crisis flag never creates a strike.
          if (rp.lane === 'crisis' || rp.reason === CRISIS_REASON) throw new ModerationError('crisis_never_strikes');
          const uid = subject();
          strikeId = (
            await tx.query<{ id: string }>(
              `insert into public.strikes (user_id, reason_code, report_id, created_by, expires_at)
               values ($1, $2, $3, $4, now() + make_interval(days => $5)) returning id`,
              [uid, reasonCode, rp.id, input.actor, safety.strikeTtlDays],
            )
          ).rows[0].id;
          activeStrikes = (
            await tx.query<{ n: number }>(
              'select count(*)::int as n from public.strikes where user_id = $1 and revoked_at is null and expires_at > now()',
              [uid],
            )
          ).rows[0].n;
          const c = consequenceForActiveStrikes(activeStrikes);
          sanctionKind = c.kind;
          hours = c.hours;
          break;
        }
        case 'shadow_mute':
          hours = input.hours ?? 7 * 24;
          if (!Number.isInteger(hours) || hours < 1 || hours > 720) throw new ModerationError('invalid_duration');
          sanctionKind = 'shadow_mute';
          break;
        case 'suspend':
          hours = input.hours ?? 24;
          if (hours !== 24 && hours !== 7 * 24) throw new ModerationError('invalid_duration', 'suspensions are 24 h or 7 days');
          sanctionKind = 'room_suspension';
          break;
        case 'pause':
          sanctionKind = 'rooms_pause'; // pending review: the report stays open
          resolution = null;
          break;
        case 'ban':
          sanctionKind = 'account_ban';
          if (rp.lane === 'minors_grooming' && rp.evidence_hold_id) {
            // Minors & grooming SOP: 180-day hold from the ban and a mandatory report task (REQ-ADM-14).
            await tx.query(
              `update public.evidence_holds
                  set hold_until = greatest(hold_until, now() + make_interval(days => $2)), mandatory_report_required = true
                where id = $1`,
              [rp.evidence_hold_id, safety.evidenceHoldDays],
            );
          }
          break;
        default:
          throw new ModerationError('invalid_input', 'unknown action');
      }

      if (sanctionKind) {
        sanctionId = (
          await tx.query<{ id: string }>(
            `insert into public.sanctions (user_id, kind, reason_code, source, report_id, ends_at, created_by)
             values ($1, $2, $3, 'moderator', $4, case when $5::int is null then null else now() + make_interval(hours => $5::int) end, $6)
             returning id`,
            [subject(), sanctionKind, reasonCode, rp.id, hours, input.actor],
          )
        ).rows[0].id;
      }
      if (resolution) {
        await tx.query(`update public.reports set status = $2, resolved_at = now(), resolved_by = $3 where id = $1`, [
          rp.id,
          resolution,
          input.actor,
        ]);
      }
      await appendAudit(tx, {
        actor: input.actor,
        action: input.action,
        reportId: rp.id,
        subjectHash: rp.target_user_id ? subjectHash(this.config.masterKey, rp.target_user_id) : null,
        reasonCode,
        detail: { lane: rp.lane, sanction: sanctionKind, hours, activeStrikes },
      });
      if (sanctionKind && (ROOM_ACCESS_SANCTIONS as readonly string[]).includes(sanctionKind)) {
        await this.hideFromRooms(tx, subject(), now);
      }
      const status = resolution ?? 'open';
      return { reportId: rp.id, status, sanctionId, strikeId, activeStrikes };
    });
  }

  /** Lift a sanction early (appeal upheld, review cleared). */
  async liftSanction(sanctionId: string, actor: string, reasonCode = 'lifted'): Promise<void> {
    if (!actor || !REASON_CODE_RE.test(reasonCode)) throw new ModerationError('invalid_input');
    await this.db.withTx(async (tx) => {
      const r = await tx.query<{ user_id: string; kind: string; report_id: string | null }>(
        'update public.sanctions set lifted_at = now() where id = $1 and lifted_at is null returning user_id, kind, report_id',
        [sanctionId],
      );
      const s = r.rows[0];
      if (!s) throw new ModerationError('sanction_not_found');
      await appendAudit(tx, {
        actor,
        action: 'lift',
        reportId: s.report_id,
        subjectHash: subjectHash(this.config.masterKey, s.user_id),
        reasonCode,
        detail: { sanction: s.kind },
      });
    });
  }

  /** Minors & grooming SOP step 3: the task closes only with an external reference or an Owner-recorded legal reason. */
  async recordMandatoryReport(
    evidenceHoldId: string,
    actor: string,
    outcome: { reportedTo: string; reportRef: string } | { legalReason: string },
  ): Promise<void> {
    if (!actor) throw new ModerationError('invalid_input');
    await this.db.withTx(async (tx) => {
      const r =
        'reportRef' in outcome
          ? await tx.query('update public.evidence_holds set reported_to = $2, report_ref = $3 where id = $1', [
              evidenceHoldId,
              outcome.reportedTo,
              outcome.reportRef,
            ])
          : await tx.query('update public.evidence_holds set legal_reason = $2 where id = $1', [evidenceHoldId, outcome.legalReason]);
      if ((r.rowCount ?? 0) === 0) throw new ModerationError('evidence_not_found');
      await appendAudit(tx, {
        actor,
        action: 'mandatory_report',
        reasonCode: 'reportRef' in outcome ? 'reported' : 'legal_reason',
        detail: { evidenceHoldId },
      });
    });
  }

  /** Evidence holds awaiting a mandatory report (no external reference and no legal reason yet). */
  async pendingMandatoryReports(): Promise<Array<{ evidenceHoldId: string; reportId: string | null; createdAt: string; holdUntil: string }>> {
    const r = await this.db.query<{ id: string; report_id: string | null; created_at: Date; hold_until: Date }>(
      `select id, report_id, created_at, hold_until from public.evidence_holds
        where mandatory_report_required and report_ref is null and legal_reason is null order by created_at`,
    );
    return r.rows.map((x) => ({
      evidenceHoldId: x.id,
      reportId: x.report_id,
      createdAt: x.created_at.toISOString(),
      holdUntil: x.hold_until.toISOString(),
    }));
  }

  auditLog(opts: { limit?: number; beforeId?: number } = {}): Promise<AuditRow[]> {
    return readAudit(this.db, opts);
  }

  verifyAuditChain(): Promise<boolean> {
    return verifyAuditChain(this.db);
  }

  /** A suspended/paused/closed account "leaves its rooms" for everyone else at once (membership kept for review). */
  private async hideFromRooms(tx: Tx, userId: string, now: Date): Promise<void> {
    const r = await tx.query<{ member_id: string; room_id: string }>(
      `select m.member_id, m.room_id from public.room_members m join public.rooms r on r.id = m.room_id
        where m.user_id = $1 and m.left_at is null and r.memory_at > now()`,
      [userId],
    );
    if (r.rows.length === 0) return;
    const { liveWindowS } = await loadMatchingConfig(tx);
    for (const m of r.rows) {
      const counts = countsView(await this.rooms.counts(tx, m.room_id, liveWindowS));
      await Broadcast.memberLeft(tx, m.room_id, m.member_id, counts, now);
    }
  }
}
