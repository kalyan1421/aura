import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import type { Queryable } from '../db/db';
import { subjectHash } from '../safety/audit';
import { ModerationError, ModerationService, type ActResult, type ModerationActionKind, type QueueItem } from '../safety/moderation.service';
import { ACTIVE_SANCTION_SQL, LANE_PRIORITY, LANES, REPORT_REASONS, type Lane, type ReportReason } from '../safety/safety-types';
import { auditConsole } from './admin-audit';
import { AdminDb } from './admin-db';
import { AdminErrors, moderationHttpError } from './admin-errors';
import {
  MANUAL_CHECKLIST_ITEMS,
  actionSchema,
  checklistSchema,
  exportSchema,
  liftSchema,
  parse,
  recordReportSchema,
  type ManualChecklistItem,
} from './admin.schemas';
import type { StaffRole, StaffUser } from './admin-types';
import {
  LEGAL_ORDER_PRIORITY,
  compareWork,
  grievancePriority,
  reportPriority,
  type GrievanceCategory,
  type WorkItem,
} from './clocks';
import { evidenceBundle, evidenceView, withoutReporter, type EvidenceHoldRow, type EvidenceView } from './evidence-view';

/**
 * The moderation side of the console (PRD 19 "Queues", "Item view", "Actions and strikes", "Minors & grooming SOP").
 * Reads run under aura_admin (AdminDb); actions go through the internal ModerationService (one transaction each, with
 * its own audit row) after the console checks the staff member's role; refusals are audited here.
 */
const ACTION_ROLES: Readonly<Record<ModerationActionKind, readonly StaffRole[]>> = {
  dismiss: ['owner', 'moderator'],
  warn: ['owner', 'moderator'],
  strike: ['owner', 'moderator'],
  shadow_mute: ['owner', 'moderator'],
  suspend: ['owner', 'moderator'],
  pause: ['owner', 'moderator'],
  ban: ['owner'], // permanent; the minors & grooming SOP and its mandatory report are Owner business
};
/** PRD 19 Roles: a Moderator's shadow-mute is the 7-day one at most. */
const MODERATOR_MAX_SHADOW_MUTE_H = 7 * 24;
const BAN_KINDS = new Set(['account_ban', 'social_ban']);

export interface LaneSummary {
  lane: Lane;
  priority: number;
  open: number;
  overdue: number;
  paging: number;
  oldestCreatedAt: string | null;
}

export interface WorkEntry extends WorkItem {
  title: string;
  lane: Lane | null;
  minorInvolved: boolean;
  pages: boolean;
  ticket: string | null;
  href: string;
}

export interface SanctionView {
  sanctionId: string;
  subjectHash: string;
  kind: string;
  reasonCode: string;
  source: string;
  reportId: string | null;
  startsAt: string;
  endsAt: string | null;
  liftedAt: string | null;
  createdBy: string;
  active: boolean;
}

export interface ItemView {
  report: {
    reportId: string;
    lane: Lane;
    priority: number;
    reason: ReportReason;
    reasonKey: string;
    source: string;
    autoSignal: string | null;
    targetKind: string;
    status: string;
    createdAt: string;
    slaDueAt: string;
    overdue: boolean;
    pages: boolean;
    involvesMinor: boolean;
    note: string | null;
    resolvedAt: string | null;
    resolvedBy: string | null;
    reporters: { count: number; reasons: string[] };
  };
  subject: {
    hash: string;
    pseudonym: string | null;
    accountAgeDays: number | null;
    under18: boolean;
    activeStrikes: number;
    strikes: Array<{ strikeId: string; reasonCode: string; createdAt: string; expiresAt: string; active: boolean }>;
    sanctions: SanctionView[];
    otherReports: Array<{ reportId: string; lane: Lane; reasonKey: string; status: string; createdAt: string }>;
  } | null;
  room: { roomId: string; quadrant: string; languagePool: string; tzRegion: string; ageHours: number; status: string; memoryAt: string; purgeAt: string } | null;
  evidence: EvidenceView | null;
  audit: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null }>;
  allowedActions: ModerationActionKind[];
}

interface ReportRow {
  id: string;
  source: string;
  auto_signal: string | null;
  reason: number;
  lane: Lane;
  involves_minor: boolean;
  pages: boolean;
  target_kind: string;
  room_id: string | null;
  target_member_id: string | null;
  target_user_id: string | null;
  target_ref: string;
  note: string | null;
  status: string;
  sla_due_at: Date;
  created_at: Date;
  resolved_at: Date | null;
  resolved_by: string | null;
  evidence_hold_id: string | null;
}

const EVIDENCE_COLS = `id, report_id, item_kind, item_ref, reason, account_ids, snapshot, created_at, hold_until,
                       mandatory_report_required, reported_to, report_ref, legal_reason`;

@Injectable()
export class ModerationConsoleService {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly moderation: ModerationService,
    private readonly app: AppConfig,
  ) {}

  private hash(userId: string): string {
    return subjectHash(this.app.masterKey, userId);
  }

  /**
   * Urgent review work is never capped by the 2-hour queue session (PRD 19): the crisis lane and anything that pages.
   * An unknown id counts as urgent (the item route answers 404 right after).
   */
  async isUrgent(reportId: string): Promise<boolean> {
    const r = (await this.adminDb.query<{ lane: Lane; pages: boolean }>('select lane, pages from public.reports where id = $1', [reportId])).rows[0];
    return !r || r.lane === 'crisis' || r.pages;
  }

  // ------------------------------------------------------------------------------------------------ queue
  async queue(opts: { lane?: Lane; limit?: number }): Promise<{ items: QueueItem[]; lanes: LaneSummary[]; generatedAt: string }> {
    const [items, lanes] = await Promise.all([this.moderation.listQueue({ lane: opts.lane, limit: opts.limit ?? 200 }), this.laneSummary()]);
    return { items, lanes, generatedAt: new Date().toISOString() };
  }

  async laneSummary(): Promise<LaneSummary[]> {
    const r = await this.adminDb.query<{ lane: Lane; open: number; overdue: number; paging: number; oldest: Date | null }>(
      `select lane, count(*)::int as open, count(*) filter (where sla_due_at < now())::int as overdue,
              count(*) filter (where pages)::int as paging, min(created_at) as oldest
         from public.reports where status = 'open' group by lane`,
    );
    const byLane = new Map(r.rows.map((x) => [x.lane, x]));
    return LANES.map((lane) => {
      const x = byLane.get(lane);
      return {
        lane,
        priority: LANE_PRIORITY[lane],
        open: x?.open ?? 0,
        overdue: x?.overdue ?? 0,
        paging: x?.paging ?? 0,
        oldestCreatedAt: x?.oldest ? x.oldest.toISOString() : null,
      };
    });
  }

  /** Aggregates only (the Read-only analyst's view): counts, never ids or content. */
  async stats(): Promise<Record<string, unknown>> {
    return this.adminDb.withTx(async (tx) => {
      const lanes = await this.laneSummaryWith(tx);
      const g = (
        await tx.query<{ open: number; overdue: number; paging: number }>(
          `select count(*) filter (where status <> 'resolved')::int as open,
                  count(*) filter (where status <> 'resolved' and resolve_due_at < now())::int as overdue,
                  count(*) filter (where status <> 'resolved' and pages)::int as paging
             from public.admin_grievances`,
        )
      ).rows[0];
      const lo = (
        await tx.query<{ open: number; overdue: number }>(
          `select count(*) filter (where status in ('open','acknowledged') and not is_test)::int as open,
                  count(*) filter (where status in ('open','acknowledged') and not is_test and due_at < now())::int as overdue
             from public.admin_legal_orders`,
        )
      ).rows[0];
      const pages = (await tx.query<{ open: number }>(`select count(*)::int as open from public.admin_pages where status = 'open'`)).rows[0];
      return {
        lanes: lanes.map(({ lane, open, overdue, paging }) => ({ lane, open, overdue, paging })),
        grievances: g,
        legalOrders: lo,
        pagesOpen: pages.open,
        generatedAt: new Date().toISOString(),
      };
    });
  }

  /**
   * W07: do habit commitments help? Aggregates only (adults, within-person comparison, cells under 20 people
   * suppressed by the database), no ids and no content. See docs/measurement/commitments.md for how to read it.
   */
  async commitmentOutcomes(): Promise<{
    rows: Array<{ measure: string; cohort: string; users: number; units: number; value: number | null; suppressed: boolean }>;
    generatedAt: string;
  }> {
    return this.adminDb.withTx(async (tx) => {
      const r = await tx.query<{ measure: string; cohort: string; users: number; units: number; value: number | null; suppressed: boolean }>(
        `select measure, cohort, users, units, value::float8 as value, suppressed from public.commitment_outcomes()`,
      );
      return { rows: r.rows, generatedAt: new Date().toISOString() };
    });
  }

  private async laneSummaryWith(q: Queryable): Promise<LaneSummary[]> {
    const r = await q.query<{ lane: Lane; open: number; overdue: number; paging: number }>(
      `select lane, count(*)::int as open, count(*) filter (where sla_due_at < now())::int as overdue,
              count(*) filter (where pages)::int as paging
         from public.reports where status = 'open' group by lane`,
    );
    const byLane = new Map(r.rows.map((x) => [x.lane, x]));
    return LANES.map((lane) => ({
      lane,
      priority: LANE_PRIORITY[lane],
      open: byLane.get(lane)?.open ?? 0,
      overdue: byLane.get(lane)?.overdue ?? 0,
      paging: byLane.get(lane)?.paging ?? 0,
      oldestCreatedAt: null,
    }));
  }

  /** The "Now" list: reports (+ for the Owner: legal orders and grievances), priority then deadline then age. */
  async work(staff: StaffUser): Promise<WorkEntry[]> {
    const reports = await this.moderation.listQueue({ limit: 300 });
    const out: WorkEntry[] = reports.map((r) => ({
      kind: 'report',
      id: r.reportId,
      priority: reportPriority(r.lane),
      dueAt: r.slaDueAt,
      createdAt: r.createdAt,
      title: `${r.reasonKey.replace(/_/g, ' ')} (${r.targetKind})`,
      lane: r.lane,
      minorInvolved: r.involvesMinor,
      pages: r.pages,
      ticket: null,
      href: `/reports/${r.reportId}`,
    }));
    if (staff.role === 'owner') {
      await this.adminDb.withTx(async (tx) => {
        const orders = await tx.query<{ id: string; ticket: string; due_at: Date; received_at: Date; is_test: boolean; source: string }>(
          `select id, ticket, due_at, received_at, is_test, source from public.admin_legal_orders
            where status in ('open','acknowledged') order by due_at limit 100`,
        );
        for (const o of orders.rows) {
          out.push({
            kind: 'legal_order',
            id: o.id,
            priority: LEGAL_ORDER_PRIORITY,
            dueAt: o.due_at.toISOString(),
            createdAt: o.received_at.toISOString(),
            title: `${o.is_test ? 'TEST ' : ''}${o.source.replace(/_/g, ' ')} order`,
            lane: null,
            minorInvolved: false,
            pages: true,
            ticket: o.ticket,
            href: `/legal-orders/${o.id}`,
          });
        }
        const gr = await tx.query<{ id: string; ticket: string; category: GrievanceCategory; resolve_due_at: Date; received_at: Date; pages: boolean }>(
          `select id, ticket, category, resolve_due_at, received_at, pages from public.admin_grievances
            where status <> 'resolved' order by resolve_due_at limit 200`,
        );
        for (const g of gr.rows) {
          out.push({
            kind: 'grievance',
            id: g.id,
            priority: grievancePriority(g.category),
            dueAt: g.resolve_due_at.toISOString(),
            createdAt: g.received_at.toISOString(),
            title: `grievance: ${g.category.replace(/_/g, ' ')}`,
            lane: null,
            minorInvolved: false,
            pages: g.pages,
            ticket: g.ticket,
            href: `/grievances/${g.id}`,
          });
        }
      });
    }
    return out.sort(compareWork);
  }

  // ------------------------------------------------------------------------------------------------ item view
  async item(staff: StaffUser, reportId: string): Promise<ItemView> {
    const view = await this.adminDb.withTx(async (tx) => {
      const rp = (
        await tx.query<ReportRow>(
          `select id, source, auto_signal, reason, lane, involves_minor, pages, target_kind, room_id, target_member_id, target_user_id,
                  target_ref, note, status, sla_due_at, created_at, resolved_at, resolved_by, evidence_hold_id
             from public.reports where id = $1`,
          [reportId],
        )
      ).rows[0];
      if (!rp) throw AdminErrors.notFound('That report does not exist.');
      const now = Date.now();

      const reporters = (
        await tx.query<{ n: number; reasons: number[] | null }>(
          `select count(distinct reporter_member_id)::int as n, array_agg(distinct reason) as reasons
             from public.reports where target_ref = $1 and source = 'user'`,
          [rp.target_ref],
        )
      ).rows[0];

      const roomRow = rp.room_id
        ? (
            await tx.query<{ id: string; quadrant: string; language_pool: string; tz_region: string; status: string; created_at: Date; memory_at: Date; purge_at: Date }>(
              `select id, quadrant, language_pool, tz_region, status, created_at, memory_at, purge_at from public.rooms where id = $1`,
              [rp.room_id],
            )
          ).rows[0]
        : undefined;

      let subject: ItemView['subject'] = null;
      if (rp.target_user_id) {
        const uid = rp.target_user_id;
        const pseudonym = rp.target_member_id
          ? ((await tx.query<{ pseudonym: string }>('select pseudonym from public.room_members where member_id = $1', [rp.target_member_id])).rows[0]
              ?.pseudonym ?? null)
          : null;
        const facts = (
          await tx.query<{ age: number | null; minor: boolean }>('select public.admin_account_age_days($1) as age, public.user_is_minor($1) as minor', [uid])
        ).rows[0];
        const strikes = await tx.query<{ id: string; reason_code: string; created_at: Date; expires_at: Date; active: boolean }>(
          `select id, reason_code, created_at, expires_at, (revoked_at is null and expires_at > now()) as active
             from public.strikes where user_id = $1 order by created_at desc limit 50`,
          [uid],
        );
        const sanctions = await this.sanctionRows(tx, { userId: uid, limit: 50 });
        const others = await tx.query<{ id: string; lane: Lane; reason: number; status: string; created_at: Date }>(
          `select id, lane, reason, status, created_at from public.reports
            where target_user_id = $1 and id <> $2 order by created_at desc limit 20`,
          [uid, rp.id],
        );
        subject = {
          hash: this.hash(uid),
          pseudonym,
          accountAgeDays: facts?.age ?? null,
          under18: facts?.minor ?? false,
          activeStrikes: strikes.rows.filter((s) => s.active).length,
          strikes: strikes.rows.map((s) => ({
            strikeId: s.id,
            reasonCode: s.reason_code,
            createdAt: s.created_at.toISOString(),
            expiresAt: s.expires_at.toISOString(),
            active: s.active,
          })),
          sanctions,
          otherReports: others.rows.map((o) => ({
            reportId: o.id,
            lane: o.lane,
            reasonKey: REPORT_REASONS[o.reason as ReportReason] ?? String(o.reason),
            status: o.status,
            createdAt: o.created_at.toISOString(),
          })),
        };
      }

      const hold = rp.evidence_hold_id
        ? (await tx.query<EvidenceHoldRow>(`select ${EVIDENCE_COLS} from public.evidence_holds where id = $1`, [rp.evidence_hold_id])).rows[0]
        : undefined;
      const audit = await tx.query<{ id: string; created_at: Date; actor: string; action: string; reason_code: string | null }>(
        `select id, created_at, actor, action, reason_code from public.moderation_actions where report_id = $1 order by id`,
        [rp.id],
      );

      const view: ItemView = {
        report: {
          reportId: rp.id,
          lane: rp.lane,
          priority: LANE_PRIORITY[rp.lane],
          reason: rp.reason as ReportReason,
          reasonKey: REPORT_REASONS[rp.reason as ReportReason] ?? String(rp.reason),
          source: rp.source,
          autoSignal: rp.auto_signal,
          targetKind: rp.target_kind,
          status: rp.status,
          createdAt: rp.created_at.toISOString(),
          slaDueAt: rp.sla_due_at.toISOString(),
          overdue: rp.status === 'open' && rp.sla_due_at.getTime() < now,
          pages: rp.pages,
          involvesMinor: rp.involves_minor,
          note: rp.note,
          resolvedAt: rp.resolved_at ? rp.resolved_at.toISOString() : null,
          resolvedBy: rp.resolved_by,
          reporters: {
            count: reporters?.n ?? 0,
            reasons: (reporters?.reasons ?? []).map((x) => REPORT_REASONS[x as ReportReason] ?? String(x)),
          },
        },
        subject,
        room: roomRow
          ? {
              roomId: roomRow.id,
              quadrant: roomRow.quadrant,
              languagePool: roomRow.language_pool,
              tzRegion: roomRow.tz_region,
              ageHours: Math.floor((now - roomRow.created_at.getTime()) / 3_600_000),
              status: roomRow.status,
              memoryAt: roomRow.memory_at.toISOString(),
              purgeAt: roomRow.purge_at.toISOString(),
            }
          : null,
        evidence: hold ? evidenceView(hold, (id) => this.hash(id)) : null,
        audit: audit.rows.map((a) => ({
          id: Number(a.id),
          createdAt: a.created_at.toISOString(),
          actor: a.actor,
          action: a.action,
          reasonCode: a.reason_code,
        })),
        allowedActions: [],
      };
      return view;
    });
    view.allowedActions =
      view.report.status === 'open'
        ? (Object.keys(ACTION_ROLES) as ModerationActionKind[]).filter(
            (a) =>
              ACTION_ROLES[a].includes(staff.role) &&
              !(a === 'strike' && view.report.lane === 'crisis') &&
              (view.subject !== null || a === 'dismiss'),
          )
        : [];
    return view;
  }

  // ------------------------------------------------------------------------------------------------ actions
  async act(staff: StaffUser, reportId: string, body: unknown): Promise<ActResult & { mandatoryReport: { evidenceHoldId: string } | null }> {
    const b = parse(actionSchema, body);
    const tooLong = staff.role === 'moderator' && b.action === 'shadow_mute' && (b.hours ?? MODERATOR_MAX_SHADOW_MUTE_H) > MODERATOR_MAX_SHADOW_MUTE_H;
    if (!ACTION_ROLES[b.action].includes(staff.role) || tooLong) {
      await auditConsole(this.adminDb, staff.actor, {
        action: 'access_denied',
        reasonCode: 'forbidden_role',
        reportId,
        detail: { route: 'POST /admin/reports/:id/actions', attempted: b.action, role: staff.role },
      });
      throw AdminErrors.forbiddenRole();
    }
    const rp = (await this.adminDb.query<{ lane: Lane; evidence_hold_id: string | null }>('select lane, evidence_hold_id from public.reports where id = $1', [reportId]))
      .rows[0];
    if (!rp) throw AdminErrors.notFound('That report does not exist.');
    let out: Awaited<ReturnType<ModerationService['act']>>;
    try {
      out = await this.moderation.act({ reportId, action: b.action, actor: staff.actor, reasonCode: b.reasonCode, hours: b.hours });
    } catch (e) {
      if (e instanceof ModerationError) throw moderationHttpError(e);
      throw e;
    }
    const mandatoryReport = await this.adminDb.withTx(async (tx): Promise<{ evidenceHoldId: string } | null> => {
      if (out.status !== 'open') {
        // The item is closed: stop paging for it now rather than at its next round.
        await tx.query(
          `update public.admin_pages set status = 'resolved', closed_at = now(), lease_until = null
            where kind = 'report' and ref_id = $1 and status = 'open'`,
          [reportId],
        );
      }
      if (b.action === 'ban' && rp.lane === 'minors_grooming' && rp.evidence_hold_id) {
        await tx.query(
          `insert into public.admin_mandatory_checklists (evidence_hold_id, updated_by) values ($1, $2) on conflict (evidence_hold_id) do nothing`,
          [rp.evidence_hold_id, staff.actor],
        );
        return { evidenceHoldId: rp.evidence_hold_id };
      }
      return null;
    });
    return { ...out, mandatoryReport };
  }

  // ------------------------------------------------------------------------------------------------ sanctions
  private async sanctionRows(q: Queryable, opts: { userId?: string; active?: boolean; limit: number }): Promise<SanctionView[]> {
    const r = await q.query<{
      id: string;
      user_id: string;
      kind: string;
      reason_code: string;
      source: string;
      report_id: string | null;
      starts_at: Date;
      ends_at: Date | null;
      lifted_at: Date | null;
      created_by: string;
      active: boolean;
    }>(
      `select s.id, s.user_id, s.kind, s.reason_code, s.source, s.report_id, s.starts_at, s.ends_at, s.lifted_at, s.created_by,
              (${ACTIVE_SANCTION_SQL('s')}) as active
         from public.sanctions s
        where ($1::uuid is null or s.user_id = $1) and ($2::boolean is null or (${ACTIVE_SANCTION_SQL('s')}) = $2)
        order by s.created_at desc limit $3`,
      [opts.userId ?? null, opts.active ?? null, opts.limit],
    );
    return r.rows.map((s) => ({
      sanctionId: s.id,
      subjectHash: this.hash(s.user_id),
      kind: s.kind,
      reasonCode: s.reason_code,
      source: s.source,
      reportId: s.report_id,
      startsAt: s.starts_at.toISOString(),
      endsAt: s.ends_at ? s.ends_at.toISOString() : null,
      liftedAt: s.lifted_at ? s.lifted_at.toISOString() : null,
      createdBy: s.created_by,
      active: s.active,
    }));
  }

  async sanctions(opts: { active?: boolean; subject?: string }): Promise<SanctionView[]> {
    const rows = await this.adminDb.withTx((tx) => this.sanctionRows(tx, { active: opts.active, limit: 500 }));
    return opts.subject ? rows.filter((s) => s.subjectHash.startsWith(opts.subject as string)) : rows;
  }

  /** Lift a sanction early; lifting a ban ("unban") is Owner-only. */
  async lift(staff: StaffUser, sanctionId: string, body: unknown): Promise<void> {
    const b = parse(liftSchema, body);
    const s = (await this.adminDb.query<{ kind: string; report_id: string | null }>('select kind, report_id from public.sanctions where id = $1', [sanctionId]))
      .rows[0];
    if (!s) throw AdminErrors.notFound('That sanction does not exist.');
    if (BAN_KINDS.has(s.kind) && staff.role !== 'owner') {
      await auditConsole(this.adminDb, staff.actor, {
        action: 'access_denied',
        reasonCode: 'forbidden_role',
        reportId: s.report_id,
        detail: { route: 'POST /admin/sanctions/:id/lift', attempted: 'unban', role: staff.role },
      });
      throw AdminErrors.forbiddenRole();
    }
    try {
      await this.moderation.liftSanction(sanctionId, staff.actor, b.reasonCode);
    } catch (e) {
      if (e instanceof ModerationError) throw moderationHttpError(e);
      throw e;
    }
  }

  // ------------------------------------------------------------------------------------------------ minors & grooming SOP
  async mandatoryReports(): Promise<
    Array<{
      evidenceHoldId: string;
      reportId: string | null;
      createdAt: string;
      holdUntil: string;
      subjectHashes: string[];
      checklist: Record<string, { done: boolean; auto: boolean; at: string | null }>;
      bundleExportedAt: string | null;
    }>
  > {
    const pending = await this.moderation.pendingMandatoryReports();
    if (pending.length === 0) return [];
    return this.adminDb.withTx(async (tx) => {
      const ids = pending.map((p) => p.evidenceHoldId);
      const holds = await tx.query<{ id: string; account_ids: string[]; hold_until: Date; created_at: Date }>(
        'select id, account_ids, hold_until, created_at from public.evidence_holds where id = any($1::uuid[])',
        [ids],
      );
      const lists = await tx.query<{ evidence_hold_id: string; items: Record<string, { done?: boolean; at?: string }>; bundle_exported_at: Date | null }>(
        'select evidence_hold_id, items, bundle_exported_at from public.admin_mandatory_checklists where evidence_hold_id = any($1::uuid[])',
        [ids],
      );
      const banned = await tx.query<{ report_id: string }>(
        `select distinct r.id as report_id from public.reports r join public.sanctions s on s.user_id = r.target_user_id
          where r.id = any($1::uuid[]) and s.kind = 'account_ban' and ${ACTIVE_SANCTION_SQL('s')}`,
        [pending.map((p) => p.reportId).filter((x): x is string => !!x)],
      );
      const holdById = new Map(holds.rows.map((h) => [h.id, h]));
      const listById = new Map(lists.rows.map((l) => [l.evidence_hold_id, l]));
      const bannedReports = new Set(banned.rows.map((b) => b.report_id));
      return pending.map((p) => {
        const h = holdById.get(p.evidenceHoldId);
        const l = listById.get(p.evidenceHoldId);
        const items = l?.items ?? {};
        const preserved = !!h && h.hold_until.getTime() - Date.now() >= 170 * 86_400_000;
        const checklist: Record<string, { done: boolean; auto: boolean; at: string | null }> = {
          evidence_preserved: { done: preserved, auto: true, at: null },
          account_banned: { done: !!p.reportId && bannedReports.has(p.reportId), auto: true, at: null },
          bundle_exported: { done: !!l?.bundle_exported_at, auto: true, at: l?.bundle_exported_at ? l.bundle_exported_at.toISOString() : null },
        };
        for (const k of MANUAL_CHECKLIST_ITEMS) {
          checklist[k] = { done: items[k]?.done === true, auto: false, at: typeof items[k]?.at === 'string' ? (items[k].at as string) : null };
        }
        return {
          evidenceHoldId: p.evidenceHoldId,
          reportId: p.reportId,
          createdAt: p.createdAt,
          holdUntil: p.holdUntil,
          subjectHashes: (h?.account_ids ?? []).map((id) => this.hash(id)),
          checklist,
          bundleExportedAt: l?.bundle_exported_at ? l.bundle_exported_at.toISOString() : null,
        };
      });
    });
  }

  async setChecklistItem(staff: StaffUser, evidenceHoldId: string, body: unknown): Promise<void> {
    const b = parse(checklistSchema, body);
    await this.adminDb.withTx(async (tx) => {
      const hold = (await tx.query('select 1 from public.evidence_holds where id = $1', [evidenceHoldId])).rowCount;
      if (!hold) throw AdminErrors.notFound('That evidence hold does not exist (it may have expired).');
      const entry = JSON.stringify({ [b.item as ManualChecklistItem]: { done: b.done, at: new Date().toISOString(), by: staff.actor } });
      await tx.query(
        `insert into public.admin_mandatory_checklists (evidence_hold_id, items, updated_at, updated_by)
         values ($1, $2::jsonb, now(), $3)
         on conflict (evidence_hold_id) do update
           set items = public.admin_mandatory_checklists.items || excluded.items, updated_at = now(), updated_by = excluded.updated_by`,
        [evidenceHoldId, entry, staff.actor],
      );
      await auditConsole(tx, staff.actor, {
        action: 'mandatory_checklist',
        reasonCode: b.item,
        detail: { evidenceHoldId, done: b.done },
      });
    });
  }

  /** Closes the SOP task: an external reference, or an Owner-recorded legal reason (REQ-ADM-14). */
  async recordMandatoryReport(staff: StaffUser, evidenceHoldId: string, body: unknown): Promise<void> {
    const b = parse(recordReportSchema, body);
    try {
      await this.moderation.recordMandatoryReport(
        evidenceHoldId,
        staff.actor,
        'reportRef' in b ? { reportedTo: b.reportedTo, reportRef: b.reportRef } : { legalReason: b.legalReason },
      );
    } catch (e) {
      if (e instanceof ModerationError) throw moderationHttpError(e);
      throw e;
    }
  }

  /**
   * Break-glass (Owner): the evidence bundle with the subjects' account ids, for the mandatory report. Audited in the
   * same transaction, with its SHA-256; the reporter stays withheld.
   */
  async exportEvidence(staff: StaffUser, evidenceHoldId: string, body: unknown): Promise<{ filename: string; bundle: ReturnType<typeof evidenceBundle> }> {
    const b = parse(exportSchema, body);
    return this.adminDb.withTx(async (tx) => {
      const h = (await tx.query<EvidenceHoldRow>(`select ${EVIDENCE_COLS} from public.evidence_holds where id = $1`, [evidenceHoldId])).rows[0];
      if (!h) throw AdminErrors.notFound('That evidence hold does not exist (it may have expired).');
      const rp = h.report_id
        ? (
            await tx.query<{ id: string; lane: string; reason: number; source: string; target_kind: string; status: string; created_at: Date; sla_due_at: Date; resolved_at: Date | null; resolved_by: string | null }>(
              `select id, lane, reason, source, target_kind, status, created_at, sla_due_at, resolved_at, resolved_by
                 from public.reports where id = $1`,
              [h.report_id],
            )
          ).rows[0]
        : undefined;
      const log = h.report_id
        ? (
            await tx.query<{ id: string; created_at: Date; actor: string; action: string; reason_code: string | null; row_hash: string }>(
              'select id, created_at, actor, action, reason_code, row_hash from public.moderation_actions where report_id = $1 order by id',
              [h.report_id],
            )
          ).rows
        : [];
      const exportedAt = new Date().toISOString();
      const bundle = evidenceBundle({
        exportedAt,
        exportedBy: staff.actor,
        purpose: b.purpose,
        notice: 'Restricted: evidence preserved under the Aura minors & grooming SOP. The reporter is withheld by design.',
        evidenceHold: {
          id: h.id,
          reportId: h.report_id,
          itemKind: h.item_kind,
          itemRef: h.item_ref,
          reason: h.reason,
          accountIds: h.account_ids,
          createdAt: h.created_at.toISOString(),
          holdUntil: h.hold_until.toISOString(),
          mandatoryReportRequired: h.mandatory_report_required,
          reportedTo: h.reported_to,
          reportRef: h.report_ref,
          legalReason: h.legal_reason ? 'recorded' : null,
        },
        report: rp
          ? {
              id: rp.id,
              lane: rp.lane,
              reason: REPORT_REASONS[rp.reason as ReportReason] ?? String(rp.reason),
              source: rp.source,
              targetKind: rp.target_kind,
              status: rp.status,
              createdAt: rp.created_at.toISOString(),
              slaDueAt: rp.sla_due_at.toISOString(),
              resolvedAt: rp.resolved_at ? rp.resolved_at.toISOString() : null,
              resolvedBy: rp.resolved_by,
            }
          : null,
        snapshot: withoutReporter(h.snapshot),
        moderationLog: log.map((a) => ({
          id: Number(a.id),
          createdAt: a.created_at.toISOString(),
          actor: a.actor,
          action: a.action,
          reasonCode: a.reason_code,
          rowHash: a.row_hash,
        })),
      });
      await tx.query(
        `insert into public.admin_mandatory_checklists (evidence_hold_id, bundle_exported_at, bundle_sha256, updated_at, updated_by)
         values ($1, now(), $2, now(), $3)
         on conflict (evidence_hold_id) do update
           set bundle_exported_at = now(), bundle_sha256 = excluded.bundle_sha256, updated_at = now(), updated_by = excluded.updated_by`,
        [h.id, bundle.integrity.canonicalJsonSha256, staff.actor],
      );
      await auditConsole(tx, staff.actor, {
        action: 'evidence_export',
        reasonCode: b.purpose,
        reportId: h.report_id,
        detail: { evidenceHoldId: h.id, sha256: bundle.integrity.canonicalJsonSha256, subjects: h.account_ids.length },
      });
      return { filename: `aura-evidence-${h.id}.json`, bundle };
    });
  }
}
