import { Injectable, Logger } from '@nestjs/common';
import { pgCode, pgConstraint, type Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { SYSTEM_ACTORS, auditConsole } from './admin-audit';
import { AdminDb } from './admin-db';
import { AdminErrors } from './admin-errors';
import { closeLegalOrderSchema, legalOrderSchema, parse } from './admin.schemas';
import type { StaffUser } from './admin-types';
import { legalOrderDueAt } from './clocks';
import { newTicket } from './grievances.service';
import { PagingService } from './paging/paging.service';

/**
 * Court / government takedown orders (PRD 19 "Grievances and deletion": 3 h, Owner only, a dedicated L0-priority
 * ticket type that pages AK 24×7; REQ-ADM-09, REQ-ADM-15; F9 REQ-SAFE-10). Two intakes: the console form (Owner) and
 * `POST /v1/intake/legal-orders` for a mail relay holding LEGAL_INTAKE_TOKEN. Every order pages immediately — test
 * orders too, identically, so the drill proves the real path ("A test takedown order pages AK", week 13).
 */
export interface LegalOrderView {
  legalOrderId: string;
  ticket: string;
  source: string;
  authority: string;
  reference: string | null;
  receivedAt: string;
  dueAt: string;
  intakeChannel: string;
  isTest: boolean;
  status: string;
  acknowledgedAt: string | null;
  acknowledgedBy: string | null;
  closedAt: string | null;
  closedBy: string | null;
  overdue: boolean;
  createdAt: string;
}

export interface LegalOrderDetail extends LegalOrderView {
  summary: string;
  targets: string | null;
  resolutionNote: string | null;
  createdBy: string;
  page: {
    pageId: string;
    status: string;
    round: number;
    escalationLevel: number;
    lastDeliveredAt: string | null;
    acknowledgedAt: string | null;
    deliveries: Array<{ channel: string; round: number; level: number; attempt: number; ok: boolean; httpStatus: number | null; error: string | null; at: string }>;
  } | null;
}

interface Row {
  id: string;
  ticket: string;
  source: string;
  authority: string;
  reference: string | null;
  received_at: Date;
  due_at: Date;
  summary: string;
  targets: string | null;
  intake_channel: string;
  is_test: boolean;
  status: string;
  acknowledged_at: Date | null;
  acknowledged_by: string | null;
  closed_at: Date | null;
  closed_by: string | null;
  resolution_note: string | null;
  created_by: string;
  created_at: Date;
}

const iso = (d: Date | null): string | null => (d ? d.toISOString() : null);

@Injectable()
export class LegalOrdersService {
  private readonly logger = new Logger('LegalOrders');

  constructor(
    private readonly db: DbService,
    private readonly adminDb: AdminDb,
    private readonly paging: PagingService,
  ) {}

  private view(r: Row, now = Date.now()): LegalOrderView {
    return {
      legalOrderId: r.id,
      ticket: r.ticket,
      source: r.source,
      authority: r.authority,
      reference: r.reference,
      receivedAt: r.received_at.toISOString(),
      dueAt: r.due_at.toISOString(),
      intakeChannel: r.intake_channel,
      isTest: r.is_test,
      status: r.status,
      acknowledgedAt: iso(r.acknowledged_at),
      acknowledgedBy: r.acknowledged_by,
      closedAt: iso(r.closed_at),
      closedBy: r.closed_by,
      overdue: (r.status === 'open' || r.status === 'acknowledged') && r.due_at.getTime() < now,
      createdAt: r.created_at.toISOString(),
    };
  }

  /** Console (Owner) or the authenticated intake. Pages at once; the worker tick re-sweeps if this process dies. */
  async create(body: unknown, by: { staff: StaffUser } | { intake: true }): Promise<LegalOrderDetail> {
    const b = parse(legalOrderSchema, body);
    const receivedAt = b.receivedAt ? new Date(b.receivedAt) : new Date();
    const actor = 'staff' in by ? by.staff.actor : SYSTEM_ACTORS.legalIntake;
    const channel = 'staff' in by ? 'console' : 'intake_api';
    const run = (tx: Tx) => this.insert(tx, { ...b, receivedAt, actor, channel, isTest: b.isTest ?? false });
    const row = 'staff' in by ? await this.adminDb.withTx(run) : await this.db.withTx(run);
    try {
      await this.paging.raise({ kind: 'legal_order', refId: row.id, reason: 'legal_order', isTest: row.is_test, dueAt: row.due_at });
      this.paging.kick();
    } catch (e) {
      this.logger.warn(`page for ${row.ticket} not raised yet (${(e as Error).name}); the worker sweep will raise it`);
    }
    return this.get(row.id);
  }

  private async insert(
    tx: Tx,
    o: { source: string; authority: string; reference?: string; receivedAt: Date; summary: string; targets?: string; isTest: boolean; actor: string; channel: string },
  ): Promise<Row> {
    for (let attempt = 0; ; attempt++) {
      const ticket = newTicket('LO');
      try {
        const r = await tx.savepoint((sp) =>
          sp.query<Row>(
            `insert into public.admin_legal_orders
               (ticket, source, authority, reference, received_at, due_at, summary, targets, intake_channel, is_test, created_by)
             values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) returning *`,
            [ticket, o.source, o.authority, o.reference ?? null, o.receivedAt, legalOrderDueAt(o.receivedAt), o.summary, o.targets ?? null, o.channel, o.isTest, o.actor],
          ),
        );
        const row = r.rows[0];
        await auditConsole(tx, o.actor, {
          action: 'legal_order_received',
          reasonCode: o.source,
          detail: { legalOrderId: row.id, ticket, test: o.isTest, channel: o.channel },
        });
        return row;
      } catch (e) {
        if (pgCode(e) === '23505' && pgConstraint(e) === 'admin_legal_orders_ticket_key' && attempt < 5) continue;
        throw e;
      }
    }
  }

  async list(): Promise<LegalOrderView[]> {
    const r = await this.adminDb.query<Row>(
      `select * from public.admin_legal_orders
        order by (status in ('actioned','rejected')), due_at desc limit 300`,
    );
    return r.rows.map((x) => this.view(x));
  }

  async get(id: string): Promise<LegalOrderDetail> {
    return this.adminDb.withTx(async (tx) => {
      const r = (await tx.query<Row>('select * from public.admin_legal_orders where id = $1', [id])).rows[0];
      if (!r) throw AdminErrors.notFound('That legal order does not exist.');
      const page = (
        await tx.query<{ id: string; status: string; round: number; escalation_level: number; last_delivered_at: Date | null; acknowledged_at: Date | null }>(
          `select id, status, round, escalation_level, last_delivered_at, acknowledged_at from public.admin_pages
            where kind = 'legal_order' and ref_id = $1`,
          [id],
        )
      ).rows[0];
      const deliveries = page
        ? (
            await tx.query<{ channel: string; round: number; level: number; attempt: number; ok: boolean; http_status: number | null; error: string | null; created_at: Date }>(
              `select channel, round, level, attempt, ok, http_status, error, created_at from public.admin_page_deliveries
                where page_id = $1 order by id desc limit 100`,
              [page.id],
            )
          ).rows
        : [];
      return {
        ...this.view(r),
        summary: r.summary,
        targets: r.targets,
        resolutionNote: r.resolution_note,
        createdBy: r.created_by,
        page: page
          ? {
              pageId: page.id,
              status: page.status,
              round: page.round,
              escalationLevel: page.escalation_level,
              lastDeliveredAt: iso(page.last_delivered_at),
              acknowledgedAt: iso(page.acknowledged_at),
              deliveries: deliveries.map((d) => ({
                channel: d.channel,
                round: d.round,
                level: d.level,
                attempt: d.attempt,
                ok: d.ok,
                httpStatus: d.http_status,
                error: d.error,
                at: d.created_at.toISOString(),
              })),
            }
          : null,
      };
    });
  }

  /** "I have it": stops the paging for this order (the 3 h clock keeps running until it's actioned or rejected). */
  async acknowledge(staff: StaffUser, id: string): Promise<LegalOrderDetail> {
    await this.adminDb.withTx(async (tx) => {
      const r = await tx.query<{ ticket: string }>(
        `update public.admin_legal_orders set status = 'acknowledged', acknowledged_at = now(), acknowledged_by = $2, updated_at = now()
          where id = $1 and status = 'open' returning ticket`,
        [id, staff.actor],
      );
      if (!r.rowCount) {
        if (!(await tx.query('select 1 from public.admin_legal_orders where id = $1', [id])).rowCount) throw AdminErrors.notFound('That legal order does not exist.');
        return;
      }
      await tx.query(
        `update public.admin_pages set status = 'acknowledged', acknowledged_at = now(), acknowledged_by = $2, lease_until = null
          where kind = 'legal_order' and ref_id = $1 and status = 'open'`,
        [id, staff.actor],
      );
      await auditConsole(tx, staff.actor, { action: 'legal_order_acknowledged', detail: { legalOrderId: id, ticket: r.rows[0].ticket } });
    });
    return this.get(id);
  }

  /** Actioned (content removed / access disabled) or rejected (with counsel's reason). */
  async close(staff: StaffUser, id: string, body: unknown): Promise<LegalOrderDetail> {
    const b = parse(closeLegalOrderSchema, body);
    await this.adminDb.withTx(async (tx) => {
      const r = await tx.query<{ ticket: string; overdue: boolean }>(
        `update public.admin_legal_orders
            set status = $2, closed_at = now(), closed_by = $3, resolution_note = $4, updated_at = now(),
                acknowledged_at = coalesce(acknowledged_at, now()), acknowledged_by = coalesce(acknowledged_by, $3)
          where id = $1 and status in ('open','acknowledged')
          returning ticket, (due_at < now()) as overdue`,
        [id, b.status, staff.actor, b.note],
      );
      if (!r.rowCount) {
        if (!(await tx.query('select 1 from public.admin_legal_orders where id = $1', [id])).rowCount) throw AdminErrors.notFound('That legal order does not exist.');
        throw AdminErrors.conflict('legal_order_closed', 'That legal order is already closed.');
      }
      await tx.query(
        `update public.admin_pages set status = 'resolved', closed_at = now(), lease_until = null
          where kind = 'legal_order' and ref_id = $1 and status = 'open'`,
        [id],
      );
      await auditConsole(tx, staff.actor, {
        action: 'legal_order_closed',
        reasonCode: b.status,
        detail: { legalOrderId: id, ticket: r.rows[0].ticket, withinDeadline: !r.rows[0].overdue },
      });
    });
    return this.get(id);
  }
}
