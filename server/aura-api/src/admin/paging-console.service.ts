import { Injectable } from '@nestjs/common';
import { auditConsole } from './admin-audit';
import { AdminConfig } from './admin-config';
import { AdminDb } from './admin-db';
import { AdminErrors } from './admin-errors';
import { pagesQuerySchema, parse } from './admin.schemas';
import type { StaffUser } from './admin-types';
import { GrievanceMail } from './grievance-mail';
import { PagingService } from './paging/paging.service';

/**
 * Pager status and acknowledgement for the console. Acknowledging stops the repeats for that page (and, for a legal
 * order, marks the order acknowledged — its 3 h clock keeps running). There is deliberately no setting to mute or
 * disable page types (REQ-ADM-15): channels come from the environment only.
 */
export interface PageView {
  pageId: string;
  kind: string;
  refId: string | null;
  reason: string;
  lane: string | null;
  minorInvolved: boolean;
  isTest: boolean;
  dueAt: string | null;
  status: string;
  round: number;
  escalationLevel: number;
  nextAttemptAt: string | null;
  lastDeliveredAt: string | null;
  acknowledgedAt: string | null;
  acknowledgedBy: string | null;
  createdAt: string;
  ticket: string | null;
  deliveries: { total: number; ok: number; lastError: string | null };
}

interface PageRow {
  id: string;
  kind: string;
  ref_id: string | null;
  reason: string;
  lane: string | null;
  minor_involved: boolean;
  is_test: boolean;
  due_at: Date | null;
  status: string;
  round: number;
  escalation_level: number;
  next_attempt_at: Date;
  last_delivered_at: Date | null;
  acknowledged_at: Date | null;
  acknowledged_by: string | null;
  created_at: Date;
  ticket: string | null;
  total: number;
  ok: number;
  last_error: string | null;
}

const iso = (d: Date | null): string | null => (d ? d.toISOString() : null);

const PAGE_SELECT = `
  select p.id, p.kind, p.ref_id, p.reason, p.lane, p.minor_involved, p.is_test, p.due_at, p.status, p.round, p.escalation_level,
         p.next_attempt_at, p.last_delivered_at, p.acknowledged_at, p.acknowledged_by, p.created_at,
         coalesce(o.ticket, g.ticket) as ticket,
         (select count(*)::int from public.admin_page_deliveries d where d.page_id = p.id) as total,
         (select count(*)::int from public.admin_page_deliveries d where d.page_id = p.id and d.ok) as ok,
         (select d.error from public.admin_page_deliveries d where d.page_id = p.id and not d.ok order by d.id desc limit 1) as last_error
    from public.admin_pages p
    left join public.admin_legal_orders o on p.kind = 'legal_order' and o.id = p.ref_id
    left join public.admin_grievances g on p.kind = 'grievance' and g.id = p.ref_id`;

@Injectable()
export class PagingConsoleService {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly paging: PagingService,
    private readonly config: AdminConfig,
    private readonly mail: GrievanceMail,
  ) {}

  private view(r: PageRow): PageView {
    return {
      pageId: r.id,
      kind: r.kind,
      refId: r.ref_id,
      reason: r.reason,
      lane: r.lane,
      minorInvolved: r.minor_involved,
      isTest: r.is_test,
      dueAt: iso(r.due_at),
      status: r.status,
      round: r.round,
      escalationLevel: r.escalation_level,
      nextAttemptAt: r.status === 'open' ? r.next_attempt_at.toISOString() : null,
      lastDeliveredAt: iso(r.last_delivered_at),
      acknowledgedAt: iso(r.acknowledged_at),
      acknowledgedBy: r.acknowledged_by,
      createdAt: r.created_at.toISOString(),
      ticket: r.ticket,
      deliveries: { total: r.total, ok: r.ok, lastError: r.last_error },
    };
  }

  async list(query: unknown): Promise<PageView[]> {
    const q = parse(pagesQuerySchema, query);
    const status = q.status ?? 'all';
    const r = await this.adminDb.query<PageRow>(
      `${PAGE_SELECT} where ($1::text = 'all' or p.status = $1) order by (p.status <> 'open'), p.created_at desc limit 200`,
      [status],
    );
    return r.rows.map((x) => this.view(x));
  }

  async get(id: string): Promise<PageView & { deliveryLog: Array<{ channel: string; round: number; level: number; attempt: number; ok: boolean; httpStatus: number | null; error: string | null; latencyMs: number; at: string }> }> {
    return this.adminDb.withTx(async (tx) => {
      const r = (await tx.query<PageRow>(`${PAGE_SELECT} where p.id = $1`, [id])).rows[0];
      if (!r) throw AdminErrors.notFound('That page does not exist.');
      const log = await tx.query<{ channel: string; round: number; level: number; attempt: number; ok: boolean; http_status: number | null; error: string | null; latency_ms: number; created_at: Date }>(
        `select channel, round, level, attempt, ok, http_status, error, latency_ms, created_at
           from public.admin_page_deliveries where page_id = $1 order by id desc limit 200`,
        [id],
      );
      return {
        ...this.view(r),
        deliveryLog: log.rows.map((d) => ({
          channel: d.channel,
          round: d.round,
          level: d.level,
          attempt: d.attempt,
          ok: d.ok,
          httpStatus: d.http_status,
          error: d.error,
          latencyMs: d.latency_ms,
          at: d.created_at.toISOString(),
        })),
      };
    });
  }

  async acknowledge(staff: StaffUser, id: string): Promise<PageView> {
    await this.adminDb.withTx(async (tx) => {
      const r = await tx.query<{ kind: string; ref_id: string | null; reason: string }>(
        `update public.admin_pages set status = 'acknowledged', acknowledged_at = now(), acknowledged_by = $2, lease_until = null
          where id = $1 and status = 'open' returning kind, ref_id, reason`,
        [id, staff.actor],
      );
      const page = r.rows[0];
      if (!page) {
        if (!(await tx.query('select 1 from public.admin_pages where id = $1', [id])).rowCount) throw AdminErrors.notFound('That page does not exist.');
        return; // already acknowledged / closed: idempotent
      }
      if (page.kind === 'legal_order' && page.ref_id) {
        await tx.query(
          `update public.admin_legal_orders set status = 'acknowledged', acknowledged_at = now(), acknowledged_by = $2, updated_at = now()
            where id = $1 and status = 'open'`,
          [page.ref_id, staff.actor],
        );
      }
      await auditConsole(tx, staff.actor, {
        action: 'page_acknowledged',
        reasonCode: page.reason,
        reportId: page.kind === 'report' ? page.ref_id : null,
        detail: { pageId: id, kind: page.kind },
      });
    });
    return (await this.get(id)) as PageView;
  }

  /** A manual drill: pages exactly like a real page, marked TEST. */
  async test(staff: StaffUser): Promise<PageView> {
    const { pageId } = await this.paging.raiseTest('test_manual');
    await auditConsole(this.adminDb, staff.actor, { action: 'page_test', reasonCode: 'test_manual', detail: { pageId } });
    this.paging.kick();
    return (await this.get(pageId)) as PageView;
  }

  /** What is configured (names and booleans only, never URLs or secrets) and when the last drill was answered. */
  async status(): Promise<Record<string, unknown>> {
    const last = (
      await this.adminDb.query<{ id: string; created_at: Date; status: string; acknowledged_at: Date | null; reason: string }>(
        `select id, created_at, status, acknowledged_at, reason from public.admin_pages where kind = 'test' order by created_at desc limit 1`,
      )
    ).rows[0];
    const p = this.config.paging;
    return {
      channels: this.paging.channelSummary,
      configured: {
        webhook: p.webhook ? p.webhook.format : null,
        escalationWebhook: p.escalationWebhook ? p.escalationWebhook.format : null,
        email: p.emailTo.length > 0 && this.mail.enabled,
        smtp: this.mail.enabled,
      },
      warnings: [
        ...(this.paging.channelSummary.length === 0 ? ['no_channels: pages are logged but reach nobody'] : []),
        ...(p.escalationWebhook ? [] : ['no_escalation: the 5-minute step repeats the first channels (no voice call)']),
        ...(this.config.officer.email ? [] : ['no_grievance_officer_email: set GRIEVANCE_OFFICER_EMAIL']),
      ],
      repeatMinutes: p.repeatMinutes,
      escalateAfterMinutes: p.escalateAfterMinutes,
      weeklyTest: p.weeklyTestCron ? { cron: p.weeklyTestCron, timezone: p.weeklyTestTz } : null,
      lastTest: last
        ? { pageId: last.id, reason: last.reason, createdAt: last.created_at.toISOString(), status: last.status, acknowledgedAt: iso(last.acknowledged_at) }
        : null,
    };
  }
}
