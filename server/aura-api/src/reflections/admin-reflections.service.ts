import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { z } from 'zod';
import { auditConsole } from '../admin/admin-audit';
import { AdminDb } from '../admin/admin-db';
import { AdminErrors, moderationHttpError } from '../admin/admin-errors';
import type { StaffUser } from '../admin/admin-types';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { AppConfig } from '../config/app-config';
import { pgCode, type Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { loadMatchingConfig } from '../rooms/matching-config';
import { isTzRegion } from '../rooms/regions';
import { appendAudit, subjectHash } from '../safety/audit';
import { slaFor } from '../safety/lanes';
import { ModerationError, ModerationService } from '../safety/moderation.service';
import { ACTIVE_SANCTION_SQL, LANE_PRIORITY, REPORT_REASONS, type Lane, type ReportReason } from '../safety/safety-types';
import { URGENT_PAGER, type UrgentPager } from '../safety/urgent-pager';
import type { HoldReason, RejectReason, Scores } from './decide';
import { corpusLabel, feedCorpus } from './corpus';
import { tryOpen } from './reflection-cipher';
import { COMPOSER_FLAG, REFLECTION_POOLS, type ReflectionPool } from './reflection-config';

/**
 * The reflection side of the admin console (contracts/api/v1-reflections.md §4; PRD 19 "Item view", "Actions",
 * US-42). Reads run as `aura_admin` (AdminDb: no account behind a membership, no duplicate hash, nothing private);
 * NestJS decrypts the text for the item view only and never logs it. State changes go through the SECURITY DEFINER
 * functions of migration 20261005000018 (`admin_reflection_decide`, `admin_reflection_escalate`) and strikes through
 * the strike ladder (`ModerationService.act`). Every decision writes the hash-chained audit log in the same transaction.
 * The per-pool kill switch edits a flag payload, which `aura_admin` can't (only `enabled`): like the lexicon publish,
 * it runs as the service role behind the Owner-only route, audited.
 */
export type AdminStatus = 'pending' | 'published' | 'held' | 'rejected' | 'crisis_diverted' | 'removed' | 'deleted' | 'expired';
export type Decision = 'approve' | 'remove' | 'escalate';

export interface ReviewItem {
  reflectionId: string;
  status: AdminStatus;
  hidden: boolean;
  holdReason: HoldReason | null;
  rejectReason: RejectReason | null;
  text: string | null;
  charCount: number;
  languagePool: ReflectionPool;
  strict: boolean;
  overnight: boolean;
  involvesMinor: boolean;
  createdAt: string;
  decidedAt: string | null;
  decidedBy: string | null;
  room: { roomId: string; quadrant: string; tzRegion: string; state: string } | null;
  report: {
    reportId: string;
    lane: Lane;
    reasonKey: string;
    source: 'user' | 'auto';
    autoSignal: string | null;
    slaDueAt: string;
    pages: boolean;
    overdue: boolean;
  } | null;
}

export interface ReviewView extends ReviewItem {
  scores: Scores | null;
  ruleHits: string[];
  stage: string | null;
  publishedAt: string | null;
  removedAt: string | null;
  hiddenAt: string | null;
  gestureCount: number;
  /** US-42: the support sheet opened for the author (a crisis diversion). */
  supportShown: boolean;
  author: {
    pseudonym: string;
    hash: string | null;
    accountAgeDays: number | null;
    under18: boolean;
    activeStrikes: number;
    strikes: Array<{ strikeId: string; reasonCode: string; createdAt: string; expiresAt: string; active: boolean }>;
    sanctions: Array<{ sanctionId: string; kind: string; reasonCode: string; source: string; startsAt: string; endsAt: string | null; active: boolean }>;
    /** US-42 "the author's recent flags": other reports about the same account (not about this reflection). */
    otherReports: Array<{ reportId: string; lane: Lane; reasonKey: string; status: string; createdAt: string }>;
  };
  roomContext: {
    roomId: string;
    quadrant: string;
    languagePool: string;
    tzRegion: string;
    ageHours: number;
    state: string;
    memoryAt: string;
    purgeAt: string;
    others: Array<{ reflectionId: string; pseudonym: string; text: string | null; publishedAt: string }>;
  } | null;
  reports: Array<{
    reportId: string;
    lane: Lane;
    reasonKey: string;
    source: 'user' | 'auto';
    autoSignal: string | null;
    status: 'open' | 'actioned' | 'dismissed';
    createdAt: string;
    slaDueAt: string;
    pages: boolean;
  }>;
  audit: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null }>;
  allowedDecisions: Decision[];
  canStrike: boolean;
}

export interface PoolState {
  pool: ReflectionPool;
  paused: boolean;
  held: number;
}

export interface DecisionResult {
  reflectionId: string;
  previousStatus: AdminStatus;
  status: AdminStatus;
  hidden: boolean;
  reportsResolved: number;
  sanctionsLifted: number;
  strike: { activeStrikes: number | null; autoBan: boolean } | null;
  escalated: { reportId: string; lane: Lane; pages: boolean } | null;
}

export const LIST_STATUSES = ['held', 'pending', 'published', 'rejected', 'crisis_diverted', 'removed', 'all'] as const;
const listQuery = z.object({
  status: z.enum(LIST_STATUSES).optional(),
  limit: z.coerce.number().int().min(1).max(500).optional(),
});
const reasonCode = z.string().regex(/^[a-z0-9_]{1,40}$/, 'must be a reason code ([a-z0-9_], at most 40)');
const decisionBody = z
  .object({
    decision: z.enum(['approve', 'remove', 'escalate']),
    reasonCode,
    strike: z.boolean().optional(),
    rejectReason: z.enum(['contact_details', 'link', 'personal_questions', 'hurtful', 'sexual', 'other']).optional(),
    lane: z.enum(['minors_grooming', 'crisis']).optional(),
  })
  .strict();
const poolBody = z.object({ reasonCode }).strict();

interface Row {
  id: string;
  room_id: string;
  member_id: string;
  status: AdminStatus;
  body_ct: string | null;
  body_key: string | null;
  char_count: number;
  language_pool: ReflectionPool;
  involves_minor: boolean;
  strict: boolean;
  overnight: boolean;
  stage: string | null;
  hold_reason: HoldReason | null;
  reject_reason: RejectReason | null;
  mod_scores: Scores | null;
  rule_hits: string[];
  created_at: Date;
  decided_at: Date | null;
  decided_by: string | null;
  published_at: Date | null;
  removed_at: Date | null;
  hidden_at: Date | null;
  quadrant: string | null;
  tz_region: string | null;
  room_state: string | null;
  r_report_id: string | null;
  r_lane: Lane | null;
  r_reason: number | null;
  r_source: 'user' | 'auto' | null;
  r_auto_signal: string | null;
  r_sla_due_at: Date | null;
  r_pages: boolean | null;
}

const ROW_SQL = `
  select r.id, r.room_id, r.member_id, r.status, r.body_ct, r.body_key, r.char_count, r.language_pool, r.involves_minor, r.strict,
         r.overnight, r.stage, r.hold_reason, r.reject_reason, r.mod_scores, r.rule_hits, r.created_at, r.decided_at, r.decided_by,
         r.published_at, r.removed_at, r.hidden_at,
         rm.quadrant, rm.tz_region, case when rm.memory_at <= now() then 'memory' else rm.status end as room_state,
         rp.id as r_report_id, rp.lane as r_lane, rp.reason as r_reason, rp.source as r_source, rp.auto_signal as r_auto_signal,
         rp.sla_due_at as r_sla_due_at, rp.pages as r_pages
    from public.reflections r
    left join public.rooms rm on rm.id = r.room_id
    left join lateral (
      select x.id, x.lane, x.reason, x.source, x.auto_signal, x.sla_due_at, x.pages from public.reports x
       where x.target_reflection_id = r.id and x.status = 'open'
       order by case x.lane when 'crisis' then 0 when 'minors_grooming' then 1 when 'harassment' then 2 else 3 end, x.sla_due_at
       limit 1) rp on true`;

const REVIEWABLE: ReadonlySet<AdminStatus> = new Set(['pending', 'held', 'rejected', 'crisis_diverted', 'removed', 'published']);

@Injectable()
export class AdminReflectionsService {
  private readonly logger = new Logger('AdminReflections');

  constructor(
    private readonly adminDb: AdminDb,
    private readonly db: DbService,
    private readonly app: AppConfig,
    private readonly moderation: ModerationService,
    @Optional() @Inject(URGENT_PAGER) private readonly pager?: UrgentPager,
  ) {}

  private hash(userId: string): string {
    return subjectHash(this.app.masterKey, userId);
  }

  private item(x: Row, now: number): ReviewItem {
    return {
      reflectionId: x.id,
      status: x.status,
      hidden: x.status === 'published' && x.hidden_at !== null,
      holdReason: x.hold_reason,
      rejectReason: x.reject_reason,
      text: tryOpen(this.app.masterKey, x.id, x.body_ct, x.body_key),
      charCount: x.char_count,
      languagePool: x.language_pool,
      strict: x.strict,
      overnight: x.overnight,
      involvesMinor: x.involves_minor,
      createdAt: x.created_at.toISOString(),
      decidedAt: x.decided_at ? x.decided_at.toISOString() : null,
      decidedBy: x.decided_by,
      room: x.quadrant && x.tz_region ? { roomId: x.room_id, quadrant: x.quadrant, tzRegion: x.tz_region, state: x.room_state ?? 'open' } : null,
      report:
        x.r_report_id && x.r_lane && x.r_sla_due_at
          ? {
              reportId: x.r_report_id,
              lane: x.r_lane,
              reasonKey: REPORT_REASONS[x.r_reason as ReportReason] ?? String(x.r_reason),
              source: x.r_source ?? 'auto',
              autoSignal: x.r_auto_signal,
              slaDueAt: x.r_sla_due_at.toISOString(),
              pages: x.r_pages === true,
              overdue: x.r_sla_due_at.getTime() < now,
            }
          : null,
    };
  }

  // ------------------------------------------------------------------------------------------------ list
  async list(query: unknown): Promise<{ items: ReviewItem[]; pools: PoolState[]; generatedAt: string }> {
    const q = parseOrThrow(listQuery, query);
    const status = q.status ?? 'held';
    const limit = q.limit ?? 200;
    const waiting = status === 'held' || status === 'pending';
    return this.adminDb.withTx(async (tx) => {
      const rows = await tx.query<Row>(
        `${ROW_SQL}
          where ($1 = 'all' or r.status = $1 or ($1 = 'held' and r.status = 'published' and r.hidden_at is not null))
          order by case when $2 then r.created_at end asc, case when not $2 then r.created_at end desc, r.id
          limit $3`,
        [status, waiting, limit],
      );
      const now = Date.now();
      return { items: rows.rows.map((x) => this.item(x, now)), pools: await this.pools(tx), generatedAt: new Date().toISOString() };
    });
  }

  private async pools(q: Queryable): Promise<PoolState[]> {
    const held = await q.query<{ language_pool: ReflectionPool; n: number }>(
      `select language_pool, count(*)::int as n from public.reflections where status = 'held' group by language_pool`,
    );
    const flag = await q.query<{ payload: { pausedPools?: unknown } | null; enabled: boolean }>(
      'select enabled, payload from public.feature_flags where key = $1',
      [COMPOSER_FLAG],
    );
    const paused = Array.isArray(flag.rows[0]?.payload?.pausedPools) ? (flag.rows[0]?.payload?.pausedPools as string[]) : [];
    const n = new Map(held.rows.map((x) => [x.language_pool, x.n]));
    return REFLECTION_POOLS.map((pool) => ({ pool, paused: paused.includes(pool), held: n.get(pool) ?? 0 }));
  }

  /** Urgent review work is never capped by the queue session (crisis lane or a paging report on it). */
  async isUrgent(reflectionId: string): Promise<boolean> {
    const r = await this.adminDb.query<{ urgent: boolean }>(
      `select exists (select 1 from public.reports x where x.target_reflection_id = $1 and x.status = 'open'
                        and (x.lane = 'crisis' or x.pages)) as urgent`,
      [reflectionId],
    );
    return r.rows[0]?.urgent ?? false;
  }

  async byReport(reportId: string): Promise<{ reflectionId: string }> {
    const r = await this.adminDb.query<{ id: string | null }>('select target_reflection_id as id from public.reports where id = $1', [reportId]);
    if (!r.rows[0]?.id) throw AdminErrors.notFound('That report is not about a reflection (or the reflection is gone).');
    return { reflectionId: r.rows[0].id };
  }

  // ------------------------------------------------------------------------------------------------ item view
  async view(staff: StaffUser, reflectionId: string): Promise<ReviewView> {
    return this.adminDb.withTx(async (tx) => {
      const x = (await tx.query<Row>(`${ROW_SQL} where r.id = $1`, [reflectionId])).rows[0];
      if (!x) throw AdminErrors.notFound('That reflection does not exist (it may have been purged with its room).');
      const now = Date.now();
      const base = this.item(x, now);
      const reports = await tx.query<{ id: string; lane: Lane; reason: number; source: 'user' | 'auto'; auto_signal: string | null; status: 'open' | 'actioned' | 'dismissed'; created_at: Date; sla_due_at: Date; pages: boolean }>(
        `select id, lane, reason, source, auto_signal, status, created_at, sla_due_at, pages from public.reports
          where target_reflection_id = $1 order by created_at`,
        [reflectionId],
      );
      const pseudonym = (await tx.query<{ pseudonym: string }>('select pseudonym from public.room_members where member_id = $1', [x.member_id])).rows[0]?.pseudonym ?? '—';
      const uid = (await tx.query<{ uid: string | null }>('select public.admin_reflection_author($1) as uid', [reflectionId])).rows[0]?.uid ?? null;
      const author: ReviewView['author'] = {
        pseudonym,
        hash: uid ? this.hash(uid) : null,
        accountAgeDays: null,
        under18: false,
        activeStrikes: 0,
        strikes: [],
        sanctions: [],
        otherReports: [],
      };
      if (uid) {
        const facts = (await tx.query<{ age: number | null; minor: boolean }>('select public.admin_account_age_days($1) as age, public.user_is_minor($1) as minor', [uid])).rows[0];
        const strikes = await tx.query<{ id: string; reason_code: string; created_at: Date; expires_at: Date; active: boolean }>(
          `select id, reason_code, created_at, expires_at, (revoked_at is null and expires_at > now()) as active
             from public.strikes where user_id = $1 order by created_at desc limit 50`,
          [uid],
        );
        const sanctions = await tx.query<{ id: string; kind: string; reason_code: string; source: string; starts_at: Date; ends_at: Date | null; active: boolean }>(
          `select s.id, s.kind, s.reason_code, s.source, s.starts_at, s.ends_at, (${ACTIVE_SANCTION_SQL('s')}) as active
             from public.sanctions s where s.user_id = $1 order by s.created_at desc limit 50`,
          [uid],
        );
        const others = await tx.query<{ id: string; lane: Lane; reason: number; status: string; created_at: Date }>(
          `select id, lane, reason, status, created_at from public.reports
            where target_user_id = $1 and (target_reflection_id is distinct from $2) order by created_at desc limit 20`,
          [uid, reflectionId],
        );
        author.accountAgeDays = facts?.age ?? null;
        author.under18 = facts?.minor ?? false;
        author.activeStrikes = strikes.rows.filter((s) => s.active).length;
        author.strikes = strikes.rows.map((s) => ({ strikeId: s.id, reasonCode: s.reason_code, createdAt: s.created_at.toISOString(), expiresAt: s.expires_at.toISOString(), active: s.active }));
        author.sanctions = sanctions.rows.map((s) => ({
          sanctionId: s.id,
          kind: s.kind,
          reasonCode: s.reason_code,
          source: s.source,
          startsAt: s.starts_at.toISOString(),
          endsAt: s.ends_at ? s.ends_at.toISOString() : null,
          active: s.active,
        }));
        author.otherReports = others.rows.map((o) => ({
          reportId: o.id,
          lane: o.lane,
          reasonKey: REPORT_REASONS[o.reason as ReportReason] ?? String(o.reason),
          status: o.status,
          createdAt: o.created_at.toISOString(),
        }));
      }

      const room = (
        await tx.query<{ id: string; quadrant: string; language_pool: string; tz_region: string; status: string; created_at: Date; memory_at: Date; purge_at: Date }>(
          'select id, quadrant, language_pool, tz_region, status, created_at, memory_at, purge_at from public.rooms where id = $1',
          [x.room_id],
        )
      ).rows[0];
      let roomContext: ReviewView['roomContext'] = null;
      if (room) {
        const others = await tx.query<{ id: string; body_ct: string | null; body_key: string | null; published_at: Date; pseudonym: string }>(
          `select r.id, r.body_ct, r.body_key, r.published_at, m.pseudonym
             from public.reflections r join public.room_members m on m.member_id = r.member_id
            where r.room_id = $1 and r.id <> $2 and r.status = 'published' and r.hidden_at is null
            order by r.published_at desc limit 20`,
          [room.id, reflectionId],
        );
        roomContext = {
          roomId: room.id,
          quadrant: room.quadrant,
          languagePool: room.language_pool,
          tzRegion: room.tz_region,
          ageHours: Math.floor((now - room.created_at.getTime()) / 3_600_000),
          state: room.memory_at.getTime() <= now ? 'memory' : room.status,
          memoryAt: room.memory_at.toISOString(),
          purgeAt: room.purge_at.toISOString(),
          others: others.rows.map((o) => ({ reflectionId: o.id, pseudonym: o.pseudonym, text: tryOpen(this.app.masterKey, o.id, o.body_ct, o.body_key), publishedAt: o.published_at.toISOString() })),
        };
      }
      const gestureCount = (await tx.query<{ n: number }>('select count(*)::int as n from public.room_gestures where to_reflection_id = $1 and dropped is null', [reflectionId])).rows[0]?.n ?? 0;
      const reportIds = reports.rows.map((r) => r.id);
      const audit = await tx.query<{ id: string; created_at: Date; actor: string; action: string; reason_code: string | null }>(
        `select id, created_at, actor, action, reason_code from public.moderation_actions
          where report_id = any($1::uuid[]) or detail ->> 'reflectionId' = $2::text order by id`,
        [reportIds, reflectionId],
      );

      const open = reports.rows.filter((r) => r.status === 'open');
      const crisisItem = x.status === 'crisis_diverted' || x.rule_hits.includes('crisis_lexicon') || open.some((r) => r.lane === 'crisis' || r.reason === 1);
      const visible = x.status === 'published' && x.hidden_at === null;
      const memory = !room || room.memory_at.getTime() <= now;
      const allowed: Decision[] = [];
      if (REVIEWABLE.has(x.status) && !visible && !memory) allowed.push('approve');
      if (REVIEWABLE.has(x.status) && (x.status !== 'rejected' && x.status !== 'removed' ? true : open.length > 0)) allowed.push('remove');
      if (open.some((r) => r.lane !== 'crisis')) allowed.push('escalate');
      const roles: ReadonlyArray<StaffUser['role']> = ['owner', 'moderator'];
      return {
        ...base,
        scores: x.mod_scores,
        ruleHits: x.rule_hits,
        stage: x.stage,
        publishedAt: x.published_at ? x.published_at.toISOString() : null,
        removedAt: x.removed_at ? x.removed_at.toISOString() : null,
        hiddenAt: x.hidden_at ? x.hidden_at.toISOString() : null,
        gestureCount,
        supportShown: x.status === 'crisis_diverted',
        author,
        roomContext,
        reports: reports.rows.map((r) => ({
          reportId: r.id,
          lane: r.lane,
          reasonKey: REPORT_REASONS[r.reason as ReportReason] ?? String(r.reason),
          source: r.source,
          autoSignal: r.auto_signal,
          status: r.status,
          createdAt: r.created_at.toISOString(),
          slaDueAt: r.sla_due_at.toISOString(),
          pages: r.pages,
        })),
        audit: audit.rows.map((a) => ({ id: Number(a.id), createdAt: a.created_at.toISOString(), actor: a.actor, action: a.action, reasonCode: a.reason_code })),
        allowedDecisions: roles.includes(staff.role) ? allowed : [],
        canStrike: roles.includes(staff.role) && !crisisItem && open.some((r) => r.lane !== 'crisis' && r.reason !== 1),
      };
    });
  }

  // ------------------------------------------------------------------------------------------------ decisions
  async decide(staff: StaffUser, reflectionId: string, body: unknown): Promise<DecisionResult> {
    const b = parseOrThrow(decisionBody, body);
    if (staff.role !== 'owner' && staff.role !== 'moderator') throw AdminErrors.forbiddenRole();
    const current = (await this.adminDb.query<{ status: AdminStatus; hidden_at: Date | null; room_id: string; language_pool: string; involves_minor: boolean }>(
      'select status, hidden_at, room_id, language_pool, involves_minor from public.reflections where id = $1',
      [reflectionId],
    )).rows[0];
    if (!current) throw AdminErrors.notFound('That reflection does not exist (it may have been purged with its room).');
    const openReports = (
      await this.adminDb.query<{ id: string; lane: Lane; reason: number; involves_minor: boolean }>(
        `select id, lane, reason, involves_minor from public.reports where target_reflection_id = $1 and status = 'open'
          order by case lane when 'crisis' then 0 when 'minors_grooming' then 1 when 'harassment' then 2 else 3 end, sla_due_at`,
        [reflectionId],
      )
    ).rows;

    if (b.decision === 'escalate') return this.escalate(staff, reflectionId, current, openReports, b.lane, b.reasonCode);
    if (b.strike && b.decision !== 'remove') throw AdminErrors.badRequest('A strike goes with remove.');
    let strike: DecisionResult['strike'] = null;
    if (b.strike) {
      // REQ-SAFE-08: a crisis-flagged item never adds a strike (the database trigger refuses it too).
      if (current.status === 'crisis_diverted' || openReports.some((r) => r.lane === 'crisis' || r.reason === 1)) {
        throw ApiError.conflict('crisis_never_strikes', 'A crisis-flagged reflection never adds a strike (PRD REQ-SAFE-08).');
      }
      const target = openReports[0];
      if (!target) throw ApiError.conflict('no_open_report', 'There is no open report on this reflection to strike from.');
      try {
        const out = await this.moderation.act({ reportId: target.id, action: 'strike', actor: staff.actor, reasonCode: b.reasonCode });
        strike = { activeStrikes: out.activeStrikes, autoBan: !!out.autoBan };
      } catch (e) {
        if (e instanceof ModerationError) throw moderationHttpError(e);
        throw e;
      }
    }

    const res = await this.adminDb.withTx(async (tx) => {
      type DecideRow = { room_id: string; previous_status: AdminStatus; status: AdminStatus; hidden: boolean; reports_resolved: number; sanctions_lifted: number; subject: string };
      let d: DecideRow;
      try {
        d = (
          await tx.query<DecideRow>('select * from public.admin_reflection_decide($1, $2, $3, $4)', [reflectionId, b.decision, staff.actor, b.rejectReason ?? null])
        ).rows[0];
      } catch (e) {
        throw decideRefusal(e);
      }
      const resolved = openReports.map((r) => r.id);
      if (resolved.length) {
        // The items are closed: stop paging for them now (like the report page's actions).
        await tx.query(
          `update public.admin_pages set status = 'resolved', closed_at = now(), lease_until = null
            where kind = 'report' and ref_id = any($1::uuid[]) and status = 'open'`,
          [resolved],
        );
      }
      await auditConsole(tx, staff.actor, {
        action: b.decision === 'approve' ? 'reflection_approve' : 'reflection_remove',
        reasonCode: b.reasonCode,
        reportId: resolved[0] ?? null,
        subjectHash: this.hash(d.subject),
        detail: {
          reflectionId,
          from: d.previous_status,
          to: d.status,
          reportsResolved: d.reports_resolved,
          sanctionsLifted: d.sanctions_lifted,
          rejectReason: b.decision === 'remove' ? (b.rejectReason ?? 'other') : null,
          strike: strike !== null,
        },
      });
      return d;
    });
    // REQ-SAFE-16: the moderator's decision joins the de-identified corpus when it may. Never for crisis or Minors &
    // grooming items; after the decision committed, so a failure here changes nothing.
    const minorsOrCrisis = current.status === 'crisis_diverted' || openReports.some((r) => r.lane === 'crisis' || r.lane === 'minors_grooming');
    if (res.previous_status !== res.status) {
      await this.feedCorpus(reflectionId, res.status, b.decision === 'remove' ? (b.rejectReason ?? 'other') : null, minorsOrCrisis);
    }
    return {
      reflectionId,
      previousStatus: res.previous_status,
      status: res.status,
      hidden: res.hidden,
      reportsResolved: res.reports_resolved,
      sanctionsLifted: res.sanctions_lifted,
      strike,
      escalated: null,
    };
  }

  private async feedCorpus(reflectionId: string, status: AdminStatus, rejectReason: RejectReason | null, minorSafety: boolean): Promise<void> {
    const label = corpusLabel(status, rejectReason, { minorSafety });
    if (!label) return;
    try {
      // Service role, not aura_admin: the console role has no grant on the corpus or the author.
      const row = (
        await this.db.query<{ user_id: string; language_pool: string; body_ct: string | null; body_key: string | null }>(
          'select user_id, language_pool, body_ct, body_key from public.reflections where id = $1',
          [reflectionId],
        )
      ).rows[0];
      const text = row ? tryOpen(this.app.masterKey, reflectionId, row.body_ct, row.body_key) : null;
      if (!row || !text) return;
      await feedCorpus(this.db, this.app.masterKey, {
        authorId: row.user_id,
        languagePool: row.language_pool,
        text,
        label,
        source: 'human',
        decidedAt: new Date(),
      });
    } catch (err) {
      this.logger.warn(`corpus: not added (${(err as Error).name})`);
    }
  }

  private async escalate(
    staff: StaffUser,
    reflectionId: string,
    current: { status: AdminStatus; hidden_at: Date | null; room_id: string; involves_minor: boolean },
    open: Array<{ id: string; lane: Lane; reason: number; involves_minor: boolean }>,
    lane: 'minors_grooming' | 'crisis' | undefined,
    reason: string,
  ): Promise<DecisionResult> {
    if (!lane) throw AdminErrors.badRequest('lane: required to escalate (minors_grooming or crisis)');
    const target = open.find((r) => LANE_PRIORITY[r.lane] > LANE_PRIORITY[lane]);
    if (!target) {
      throw open.length
        ? ApiError.conflict('invalid_lane', 'Escalation only moves an item to a higher-priority lane.')
        : ApiError.conflict('no_open_report', 'There is no open report on this reflection to escalate.');
    }
    const now = new Date();
    const cfg = await loadMatchingConfig(this.db);
    const region = (await this.db.query<{ tz_region: string }>('select tz_region from public.rooms where id = $1', [current.room_id])).rows[0]?.tz_region;
    const sla = slaFor(lane, target.reason as ReportReason, target.involves_minor || current.involves_minor, now, {
      roomRegion: isTzRegion(region) ? region : null,
      lanternStart: cfg.lanternStart,
      lanternEnd: cfg.lanternEnd,
    });
    const pages = await this.adminDb.withTx(async (tx) => {
      try {
        await tx.query('select public.admin_reflection_escalate($1, $2, $3, $4)', [target.id, lane, sla.dueAt, sla.pages]);
      } catch (e) {
        throw decideRefusal(e);
      }
      const p = (await tx.query<{ pages: boolean; target_user_id: string | null }>('select pages, target_user_id from public.reports where id = $1', [target.id])).rows[0];
      await auditConsole(tx, staff.actor, {
        action: 'reflection_escalate',
        reasonCode: reason,
        reportId: target.id,
        subjectHash: p?.target_user_id ? this.hash(p.target_user_id) : null,
        detail: { reflectionId, from: target.lane, to: lane, pages: p?.pages === true },
      });
      return p?.pages === true;
    });
    if (pages) this.pager?.reportFiled(target.id);
    return {
      reflectionId,
      previousStatus: current.status,
      status: current.status,
      hidden: current.status === 'published' && current.hidden_at !== null,
      reportsResolved: 0,
      sanctionsLifted: 0,
      strike: null,
      escalated: { reportId: target.id, lane, pages },
    };
  }

  // ------------------------------------------------------------------------------------------------ pool kill switch (Owner)
  async setPoolPaused(staff: StaffUser, poolParam: string, paused: boolean, body: unknown): Promise<void> {
    const b = parseOrThrow(poolBody, body ?? {});
    if (!(REFLECTION_POOLS as readonly string[]).includes(poolParam)) throw AdminErrors.notFound('Unknown language pool (en, te or hi).');
    const pool = poolParam as ReflectionPool;
    await this.db.withTx(async (tx) => {
      const row = (await tx.query<{ payload: Record<string, unknown> | null }>('select payload from public.feature_flags where key = $1 for update', [COMPOSER_FLAG])).rows[0];
      if (!row) throw AdminErrors.notFound('The reflections_composer flag is missing (migration 20261005000018).');
      const list = Array.isArray(row.payload?.pausedPools) ? (row.payload?.pausedPools as string[]).filter((p) => p !== pool) : [];
      if (paused) list.push(pool);
      await tx.query(`update public.feature_flags set payload = coalesce(payload, '{}'::jsonb) || jsonb_build_object('pausedPools', $2::jsonb) where key = $1`, [
        COMPOSER_FLAG,
        JSON.stringify(list.sort()),
      ]);
      await appendAudit(tx, {
        actor: staff.actor,
        action: paused ? 'reflections_pool_pause' : 'reflections_pool_resume',
        reasonCode: b.reasonCode,
        detail: { flag: COMPOSER_FLAG, pool, pausedPools: list },
      });
    });
  }
}

const DECIDE_REFUSALS: Readonly<Record<string, [number, string]>> = {
  not_found: [404, 'That reflection does not exist.'],
  not_reviewable: [409, 'A deleted or expired reflection can no longer be reviewed.'],
  room_read_only: [409, 'The room is already a memory: the reflection can no longer be published.'],
  no_open_report: [409, 'There is no open report on this reflection.'],
  invalid_lane: [409, 'Escalation only moves an item to a higher-priority lane.'],
  invalid_input: [400, 'Invalid input.'],
};

function decideRefusal(e: unknown): unknown {
  if (pgCode(e) !== 'AR040') return e;
  const code = (e as Error).message;
  const known = DECIDE_REFUSALS[code];
  return known ? new ApiError(known[0], code, known[1]) : new ApiError(400, 'invalid_request', 'Invalid request.');
}
