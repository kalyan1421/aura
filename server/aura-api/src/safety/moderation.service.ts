import { Injectable } from '@nestjs/common';
import { ADMIN_DB_ROLE, AdminDb } from '../admin/admin-db';
import { AppConfig } from '../config/app-config';
import { pgCode, type Queryable, type Tx } from '../db/db';
import { banDevicesForAccount, installHashesForAccount } from '../devices/device-bans';
import { Broadcast } from '../rooms/broadcast';
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
 * Internal moderation API for the admin console (19-admin-console.md; the console's HTTP layer in src/admin adds staff
 * auth, roles and the queue-session cap around it). Never exposes content beyond what a report carries, DOBs, emails or
 * raw account ids: subjects appear as an HMAC (`subject.hash`) plus the room pseudonym; "Under 18" is a boolean flag.
 * Every action writes the append-only, hash-chained audit log with a reason code (REQ-SAFE-08).
 *
 * Least privilege (REQ-ADM-03): every query here runs as the `aura_admin` Postgres role (AdminDb: `SET LOCAL ROLE`),
 * which can read the moderation tables (column-scoped: no reporter, no account behind a pseudonym, nothing private)
 * but write none of them directly. State changes go through the SECURITY DEFINER functions of migration
 * 20261005000016 (`admin_report_for_action`, `admin_add_strike`, `admin_add_sanction`, `admin_resolve_report`,
 * `admin_extend_evidence_hold`, `admin_lift_sanction`, `admin_record_mandatory_report`), each checking its own
 * preconditions, and the room broadcast after a sanction through `admin_hide_account_from_rooms` (Broadcast.accountHidden).
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

const ERROR_CODES: ReadonlySet<string> = new Set<ModerationErrorCode>([
  'report_not_found',
  'report_closed',
  'no_subject',
  'crisis_never_strikes',
  'invalid_duration',
  'invalid_input',
  'sanction_not_found',
  'evidence_not_found',
]);

export class ModerationError extends Error {
  constructor(
    readonly code: ModerationErrorCode,
    message: string = code,
  ) {
    super(message);
    this.name = 'ModerationError';
  }
}

/** A refusal raised by one of the definer functions (SQLSTATE AR040, message = code) → ModerationError. */
export function asModerationError(err: unknown): unknown {
  if (pgCode(err) !== 'AR040') return err;
  const code = (err as Error).message;
  return new ModerationError(ERROR_CODES.has(code) ? (code as ModerationErrorCode) : 'invalid_input');
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
  /** Distinct people (room memberships) with an open report on the same item. */
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
  /** REQ-ADM-07: this strike was the 4th active one and the ladder banned the account (permanent social ban). */
  autoBan?: { sanctionId: string | null; alreadyBanned: boolean; evidenceHolds: number } | null;
  /**
   * REQ-ADM-14 "bans account and device": for `ban`, the installs seen for the account and how many were newly banned
   * in the same transaction; `snapshotted` = their HMACs were added to the report's evidence hold.
   */
  devices?: { devices: number; newlyBanned: number; snapshotted: boolean } | null;
}

const REASON_CODE_RE = /^[a-z0-9_]{1,40}$/;
/** Actor of the strike ladder's automatic ban in the audit log (the striking staff member's row precedes it). */
export const STRIKE_LADDER_ACTOR = 'system:strike_ladder';
const BAN_KINDS_SQL = `('social_ban','account_ban')`;

interface ReportForAction {
  report_id: string;
  status: string;
  lane: Lane;
  reason: number;
  target_user_id: string | null;
  evidence_hold_id: string | null;
  crisis_flagged: boolean;
}

@Injectable()
export class ModerationService {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly config: AppConfig,
  ) {}

  private hash(userId: string): string {
    return subjectHash(this.config.masterKey, userId);
  }

  /** One transaction as aura_admin; definer-function refusals come out as ModerationError. */
  private async tx<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    try {
      return await this.adminDb.withTx(fn);
    } catch (e) {
      throw asModerationError(e);
    }
  }

  /** Open items, lane priority first (crisis > minors & grooming > harassment > spam), then oldest first. */
  async listQueue(opts: { lane?: Lane; limit?: number; now?: Date } = {}): Promise<QueueItem[]> {
    const now = opts.now ?? new Date();
    // As aura_admin: no auth schema (account age comes from admin_account_age_days), no reporter identity (reporters
    // are counted by their room membership), no account behind a pseudonym.
    const r = await this.adminDb.query<{
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
      account_age_days: number | null;
      active_strikes: number;
      active_sanctions: SanctionKind[];
    }>(
      `select r.id, r.lane, r.reason, r.source, r.auto_signal, r.target_kind, r.created_at, r.sla_due_at, r.pages,
              r.involves_minor, r.note, r.evidence_hold_id, r.target_user_id,
              rm.id as room_id, rm.quadrant, rm.language_pool, rm.tz_region, rm.created_at as room_created_at,
              coalesce(tm.pseudonym, gm.pseudonym) as pseudonym,
              (select count(distinct x.reporter_member_id) from public.reports x
                where x.status = 'open' and x.target_ref = r.target_ref and x.source = 'user')::int as reporter_count,
              case when r.target_user_id is null then null else public.admin_account_age_days(r.target_user_id) end as account_age_days,
              (select count(*) from public.strikes s
                where s.user_id = r.target_user_id and s.revoked_at is null and s.expires_at > now())::int as active_strikes,
              coalesce((select array_agg(distinct s.kind) from public.sanctions s
                         where s.user_id = r.target_user_id and ${ACTIVE_SANCTION_SQL('s')}), '{}') as active_sanctions
         from public.reports r
         left join public.rooms rm on rm.id = r.room_id
         left join public.room_members tm on tm.member_id = r.target_member_id
         left join public.room_gestures g on g.id = r.target_gesture_id
         left join public.room_members gm on gm.member_id = g.from_member_id
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
            hash: this.hash(x.target_user_id),
            pseudonym: x.pseudonym,
            accountAgeDays: x.account_age_days,
            activeStrikes: x.active_strikes,
            activeSanctions: x.active_sanctions,
          }
        : null,
      evidenceHoldId: x.evidence_hold_id,
    }));
  }

  /**
   * Act on an open report. One transaction as aura_admin: report lock, strike / sanction, report status, audit row,
   * and — when room access is taken away — the `member_left` broadcast to that account's live rooms.
   *
   * Strike ladder (REQ-ADM-07; PRD 19 "Actions and strikes"): 1 warning → 2 24 h shadow-mute → 3 7-day room suspension →
   * 4 permanent social ban. Strikes stop counting 90 days after issue (`safety_config.strike_ttl_days`). On the 4th
   * active strike the ladder bans automatically: the ban is audited separately as `system:strike_ladder` and the
   * evidence behind the active strikes is kept at least 180 days from the ban (REQ-ADM-10). A crisis-flagged item never
   * adds a strike (checked here, and by the `strikes_never_crisis` trigger whoever inserts).
   */
  async act(input: ActInput, now = new Date()): Promise<ActResult> {
    if (!input.actor || input.actor.length > 120) throw new ModerationError('invalid_input', 'actor is required');
    if (input.reasonCode !== undefined && !REASON_CODE_RE.test(input.reasonCode)) throw new ModerationError('invalid_input', 'reasonCode');
    return this.tx(async (tx) => {
      const rp = (await tx.query<ReportForAction>('select * from public.admin_report_for_action($1)', [input.reportId])).rows[0];
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
      let ladderBan = false;
      let alreadyBanned = false;

      switch (input.action) {
        case 'dismiss':
          resolution = 'dismissed';
          break;
        case 'warn':
          sanctionKind = 'warning';
          break;
        case 'strike': {
          // REQ-SAFE-08 / REQ-ADM-07: a crisis flag never creates a strike (the item itself, or a crisis report about the
          // same item that was not dismissed).
          if (rp.lane === 'crisis' || rp.reason === CRISIS_REASON || rp.crisis_flagged) throw new ModerationError('crisis_never_strikes');
          const uid = subject();
          const s = (
            await tx.query<{ strike_id: string; active_strikes: number }>('select * from public.admin_add_strike($1, $2, $3)', [
              rp.report_id,
              reasonCode,
              input.actor,
            ])
          ).rows[0];
          strikeId = s.strike_id;
          activeStrikes = s.active_strikes;
          const c = consequenceForActiveStrikes(activeStrikes);
          if (c.kind === 'social_ban') {
            ladderBan = true;
            alreadyBanned = await this.isBanned(tx, uid);
          }
          sanctionKind = alreadyBanned ? null : c.kind;
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
            await tx.query('select public.admin_extend_evidence_hold($1, $2, true)', [rp.evidence_hold_id, safety.evidenceHoldDays]);
          }
          break;
        default:
          throw new ModerationError('invalid_input', 'unknown action');
      }

      if (sanctionKind) {
        sanctionId = (
          await tx.query<{ id: string }>('select public.admin_add_sanction($1, $2, $3, $4, $5, $6) as id', [
            rp.report_id,
            sanctionKind,
            reasonCode,
            hours, // null for warnings, pauses and bans
            input.actor,
            ladderBan ? 'auto' : 'moderator',
          ])
        ).rows[0].id;
      }
      let devices: ActResult['devices'] = null;
      if (input.action === 'ban') devices = await this.banDevices(tx, subject(), rp, reasonCode, input.actor, now);
      if (resolution) {
        await tx.query('select public.admin_resolve_report($1, $2, $3)', [rp.report_id, resolution, input.actor]);
      }
      const hash = rp.target_user_id ? this.hash(rp.target_user_id) : null;
      await appendAudit(tx, {
        actor: input.actor,
        action: input.action,
        reportId: rp.report_id,
        subjectHash: hash,
        reasonCode,
        detail: { lane: rp.lane, sanction: sanctionKind, hours, activeStrikes },
      });

      let autoBan: ActResult['autoBan'] = null;
      if (ladderBan) {
        // REQ-ADM-10 for the ladder's ban: what the ban rests on stays reviewable (appeal, legal) ≥ 180 days from now.
        const holds = await tx.query<{ id: string }>(
          `select distinct r.evidence_hold_id as id from public.strikes s join public.reports r on r.id = s.report_id
            where s.user_id = $1 and s.revoked_at is null and s.expires_at > now() and r.evidence_hold_id is not null`,
          [subject()],
        );
        for (const h of holds.rows) await tx.query('select public.admin_extend_evidence_hold($1, $2, false)', [h.id, safety.evidenceHoldDays]);
        await appendAudit(tx, {
          actor: STRIKE_LADDER_ACTOR,
          action: 'auto_strike_ban',
          reportId: rp.report_id,
          subjectHash: hash,
          reasonCode: 'fourth_active_strike',
          detail: { activeStrikes, sanction: alreadyBanned ? null : 'social_ban', sanctionId, alreadyBanned, evidenceHolds: holds.rows.length, holdDays: safety.evidenceHoldDays, struckBy: input.actor },
        });
        autoBan = { sanctionId, alreadyBanned, evidenceHolds: holds.rows.length };
      }
      if (sanctionKind && (ROOM_ACCESS_SANCTIONS as readonly string[]).includes(sanctionKind)) {
        // "Leaves its rooms" for everyone else at once (membership kept for review).
        await Broadcast.accountHidden(tx, subject(), now);
      }
      const status = resolution ?? 'open';
      return { reportId: rp.report_id, status, sanctionId, strikeId, activeStrikes, autoBan, devices };
    });
  }

  /**
   * The device half of an account ban (PRD 19 REQ-ADM-14 "One confirm action bans account and device"; src/devices):
   * every install seen for the account is banned and its HMAC goes into the report's evidence snapshot ("account and
   * device IDs") — never a raw install id. Same transaction as the account ban, so it is all or nothing.
   *
   * The device tables belong to the devices module (migration 20261005000017) and `aura_admin` has no grant on them, so
   * this one step runs as the service role (`set local role none`) and then drops back to `aura_admin`. The 4th-strike
   * social ban does not ban devices: a social ban keeps the solo features on that phone, and device bans are Owner-only.
   */
  private async banDevices(
    tx: Tx,
    userId: string,
    rp: ReportForAction,
    reasonCode: string,
    actor: string,
    now: Date,
  ): Promise<NonNullable<ActResult['devices']>> {
    await tx.query('set local role none');
    const r = await banDevicesForAccount(tx, this.config.masterKey, userId, { reasonCode, actor, reportId: rp.report_id });
    let snapshotted = false;
    if (rp.evidence_hold_id) {
      const hashes = await installHashesForAccount(tx, userId);
      const u = await tx.query(
        `update public.evidence_holds
            set snapshot = snapshot || jsonb_build_object('devicesAtBan', jsonb_build_object('installHashes', to_jsonb($2::text[]), 'at', $3::timestamptz))
          where id = $1`,
        [rp.evidence_hold_id, hashes, now.toISOString()],
      );
      snapshotted = (u.rowCount ?? 0) > 0;
    }
    await tx.query(`set local role ${ADMIN_DB_ROLE}`);
    return { ...r, snapshotted };
  }

  /** An active permanent ban already in place (the ladder never stacks a second one). */
  private async isBanned(q: Queryable, userId: string): Promise<boolean> {
    const r = await q.query(`select 1 from public.sanctions s where s.user_id = $1 and s.kind in ${BAN_KINDS_SQL} and ${ACTIVE_SANCTION_SQL('s')} limit 1`, [
      userId,
    ]);
    return (r.rowCount ?? 0) > 0;
  }

  /** Lift a sanction early (appeal upheld, review cleared). */
  async liftSanction(sanctionId: string, actor: string, reasonCode = 'lifted'): Promise<void> {
    if (!actor || !REASON_CODE_RE.test(reasonCode)) throw new ModerationError('invalid_input');
    await this.tx(async (tx) => {
      const s = (await tx.query<{ user_id: string; kind: string; report_id: string | null }>('select * from public.admin_lift_sanction($1)', [sanctionId])).rows[0];
      if (!s) throw new ModerationError('sanction_not_found');
      await appendAudit(tx, {
        actor,
        action: 'lift',
        reportId: s.report_id,
        subjectHash: this.hash(s.user_id),
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
    await this.tx(async (tx) => {
      const ok = (
        await tx.query<{ ok: boolean }>('select public.admin_record_mandatory_report($1, $2, $3, $4) as ok', [
          evidenceHoldId,
          'reportRef' in outcome ? outcome.reportedTo : null,
          'reportRef' in outcome ? outcome.reportRef : null,
          'legalReason' in outcome ? outcome.legalReason : null,
        ])
      ).rows[0]?.ok;
      if (!ok) throw new ModerationError('evidence_not_found');
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
    const r = await this.adminDb.query<{ id: string; report_id: string | null; created_at: Date; hold_until: Date }>(
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
    return this.adminDb.withTx((tx) => readAudit(tx, opts));
  }

  verifyAuditChain(): Promise<boolean> {
    return this.adminDb.withTx((tx) => verifyAuditChain(tx));
  }
}
