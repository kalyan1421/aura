import { randomInt } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { pgCode, pgConstraint, type Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { SYSTEM_ACTORS, auditConsole } from './admin-audit';
import { AdminConfig } from './admin-config';
import { AdminDb } from './admin-db';
import { AdminErrors } from './admin-errors';
import { grievanceListSchema, parse, publicGrievanceSchema, resolveGrievanceSchema, staffGrievanceSchema } from './admin.schemas';
import type { StaffUser } from './admin-types';
import { GAC_APPEAL_TEXT, GRIEVANCE_ACK_HOURS, GRIEVANCE_RULES, grievanceClock, type GrievanceCategory } from './clocks';
import { GrievanceMail } from './grievance-mail';
import { PagingService } from './paging/paging.service';
import { RateLimiter } from './rate-limit';

/**
 * Grievance Officer tickets (PRD 19 "Grievances and deletion", F9 "Grievance Officer: AK … ticketed form,
 * auto-acknowledged"; REQ-ADM-09, REQ-SAFE-11):
 * - `POST /v1/grievances` — public (in-app form and website), no login, rate-limited per client and globally. It files
 *   the ticket, answers at once with the ticket id and timelines (the acknowledgement), then emails the acknowledgement
 *   and a content-free notice to the officer; 2-hour categories (nudity / CSAM, NCII) page the Owner 24×7.
 * - Console (Owner only): inbox with statutory timers, manual entry of emailed / posted grievances, resolve with a reply
 *   that always carries the Grievance Appellate Committee route.
 */
const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

export function newTicket(prefix: 'GRV' | 'LO' | 'DEL'): string {
  let s = '';
  for (let i = 0; i < 8; i++) s += CROCKFORD[randomInt(32)];
  return `${prefix}-${s}`;
}

export interface GrievanceReceipt {
  ticket: string;
  category: GrievanceCategory;
  receivedAt: string;
  acknowledgedAt: string;
  resolveBy: string;
  officer: { name: string; email: string | null; address: string | null };
  appeal: string;
}

export interface GrievanceView {
  grievanceId: string;
  ticket: string;
  channel: string;
  category: GrievanceCategory;
  categoryLabel: string;
  status: string;
  receivedAt: string;
  ackDueAt: string;
  resolveDueAt: string;
  pages: boolean;
  acknowledgedAt: string | null;
  ackEmailSentAt: string | null;
  resolvedAt: string | null;
  resolvedBy: string | null;
  outcome: string | null;
  replyEmailSentAt: string | null;
  overdue: boolean;
}

export interface GrievanceDetail extends GrievanceView {
  complainantName: string | null;
  complainantEmail: string;
  locale: string | null;
  description: string;
  contentLocation: string | null;
  reply: string | null;
  createdBy: string;
}

interface Row {
  id: string;
  ticket: string;
  channel: string;
  category: GrievanceCategory;
  status: string;
  received_at: Date;
  ack_due_at: Date;
  resolve_due_at: Date;
  pages: boolean;
  acknowledged_at: Date | null;
  ack_email_sent_at: Date | null;
  resolved_at: Date | null;
  resolved_by: string | null;
  outcome: string | null;
  reply_email_sent_at: Date | null;
  complainant_name: string | null;
  complainant_email: string;
  locale: string | null;
  description: string;
  content_location: string | null;
  reply: string | null;
  created_by: string;
}

const iso = (d: Date | null): string | null => (d ? d.toISOString() : null);

@Injectable()
export class GrievancesService {
  private readonly logger = new Logger('Grievances');

  constructor(
    private readonly db: DbService,
    private readonly adminDb: AdminDb,
    private readonly config: AdminConfig,
    private readonly mail: GrievanceMail,
    private readonly paging: PagingService,
    private readonly limiter: RateLimiter,
  ) {}

  officer(): { officer: GrievanceReceipt['officer']; timelines: Record<string, unknown>; appeal: string; categories: Array<{ key: string; label: string }> } {
    return {
      officer: { ...this.config.officer },
      timelines: {
        acknowledgeWithinHours: GRIEVANCE_ACK_HOURS,
        resolveWithinHours: Object.fromEntries(Object.entries(GRIEVANCE_RULES).map(([k, v]) => [k, v.resolveHours])),
      },
      appeal: GAC_APPEAL_TEXT,
      categories: Object.entries(GRIEVANCE_RULES).map(([key, v]) => ({ key, label: v.label })),
    };
  }

  // ------------------------------------------------------------------------------------------------ public intake
  async submitPublic(body: unknown, clientAddress: string | undefined): Promise<GrievanceReceipt> {
    const b = parse(publicGrievanceSchema, body);
    const who = this.limiter.bucket(clientAddress ?? 'unknown');
    const perClient = await this.limiter.hit(`grievance:ip:${who}`, this.config.grievancePerIpPerHour, 3600);
    const global = await this.limiter.hit('grievance:global', this.config.grievanceGlobalPerHour, 3600);
    if (!perClient || !global) throw AdminErrors.rateLimited();

    const receivedAt = new Date();
    const row = await this.db.withTx((tx) =>
      this.insert(tx, {
        category: b.category,
        channel: b.channel ?? 'web_form',
        name: b.name ?? null,
        email: b.email,
        locale: b.locale ?? null,
        description: b.description,
        contentLocation: b.contentLocation ?? null,
        receivedAt,
        acknowledged: true, // the response below is the acknowledgement (ticket id + timelines)
        actor: SYSTEM_ACTORS.publicForm,
      }),
    );
    this.afterIntake(row.id, row.pages, row.resolveDueAt, true);
    return {
      ticket: row.ticket,
      category: b.category,
      receivedAt: receivedAt.toISOString(),
      acknowledgedAt: receivedAt.toISOString(),
      resolveBy: row.resolveDueAt.toISOString(),
      officer: { ...this.config.officer },
      appeal: GAC_APPEAL_TEXT,
    };
  }

  /** Mail and paging after the ticket committed (never blocks or fails the intake). */
  private afterIntake(id: string, pages: boolean, dueAt: Date, sendAck: boolean): void {
    void (async () => {
      if (pages) {
        await this.paging.raise({ kind: 'grievance', refId: id, reason: 'grievance_2h', dueAt });
        this.paging.kick();
      }
      if (sendAck) await this.mail.sendAck(id);
      await this.mail.notifyOfficer(id);
    })().catch((e: unknown) => this.logger.warn(`after-intake step failed: ${(e as Error).name}`));
  }

  private async insert(
    tx: Tx,
    g: {
      category: GrievanceCategory;
      channel: string;
      name: string | null;
      email: string;
      locale: string | null;
      description: string;
      contentLocation: string | null;
      receivedAt: Date;
      acknowledged: boolean;
      actor: string;
    },
  ): Promise<{ id: string; ticket: string; pages: boolean; resolveDueAt: Date }> {
    const clock = grievanceClock(g.category, g.receivedAt);
    for (let attempt = 0; ; attempt++) {
      const ticket = newTicket('GRV');
      try {
        // A savepoint, so a (vanishingly rare) ticket collision doesn't abort the transaction.
        const r = await tx.savepoint((sp) =>
          sp.query<{ id: string }>(
            `insert into public.admin_grievances
               (ticket, channel, category, complainant_name, complainant_email, locale, description, content_location, status,
                received_at, ack_due_at, resolve_due_at, pages, acknowledged_at, created_by)
             values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
             returning id`,
            [
              ticket,
              g.channel,
              g.category,
              g.name,
              g.email,
              g.locale,
              g.description,
              g.contentLocation,
              g.acknowledged ? 'acknowledged' : 'open',
              g.receivedAt,
              clock.ackDueAt,
              clock.resolveDueAt,
              clock.pages,
              g.acknowledged ? g.receivedAt : null,
              g.actor,
            ],
          ),
        );
        const id = r.rows[0].id;
        await auditConsole(tx, g.actor, {
          action: 'grievance_received',
          reasonCode: g.category,
          detail: { grievanceId: id, ticket, channel: g.channel, pages: clock.pages },
        });
        return { id, ticket, pages: clock.pages, resolveDueAt: clock.resolveDueAt };
      } catch (e) {
        if (pgCode(e) === '23505' && pgConstraint(e) === 'admin_grievances_ticket_key' && attempt < 5) continue;
        throw e;
      }
    }
  }

  // ------------------------------------------------------------------------------------------------ console (Owner)
  private view(r: Row, now = Date.now()): GrievanceView {
    return {
      grievanceId: r.id,
      ticket: r.ticket,
      channel: r.channel,
      category: r.category,
      categoryLabel: GRIEVANCE_RULES[r.category]?.label ?? r.category,
      status: r.status,
      receivedAt: r.received_at.toISOString(),
      ackDueAt: r.ack_due_at.toISOString(),
      resolveDueAt: r.resolve_due_at.toISOString(),
      pages: r.pages,
      acknowledgedAt: iso(r.acknowledged_at),
      ackEmailSentAt: iso(r.ack_email_sent_at),
      resolvedAt: iso(r.resolved_at),
      resolvedBy: r.resolved_by,
      outcome: r.outcome,
      replyEmailSentAt: iso(r.reply_email_sent_at),
      overdue: r.status !== 'resolved' && r.resolve_due_at.getTime() < now,
    };
  }

  async list(query: unknown): Promise<GrievanceView[]> {
    const q = parse(grievanceListSchema, query);
    const status = q.status ?? 'active';
    const r = await this.adminDb.query<Row>(
      `select * from public.admin_grievances
        where case $1::text when 'all' then true when 'active' then status <> 'resolved' else status = $1 end
        order by (status = 'resolved'), resolve_due_at, received_at limit 500`,
      [status],
    );
    return r.rows.map((x) => this.view(x));
  }

  async get(id: string): Promise<GrievanceDetail> {
    const r = (await this.adminDb.query<Row>('select * from public.admin_grievances where id = $1', [id])).rows[0];
    if (!r) throw AdminErrors.notFound('That grievance does not exist.');
    return {
      ...this.view(r),
      complainantName: r.complainant_name,
      complainantEmail: r.complainant_email,
      locale: r.locale,
      description: r.description,
      contentLocation: r.content_location,
      reply: r.reply,
      createdBy: r.created_by,
    };
  }

  /** An emailed / posted grievance entered by the Owner (the clock runs from its receipt). */
  async createFromStaff(staff: StaffUser, body: unknown): Promise<GrievanceDetail> {
    const b = parse(staffGrievanceSchema, body);
    const sendAck = b.sendAcknowledgement ?? true;
    const receivedAt = new Date(b.receivedAt);
    const row = await this.adminDb.withTx((tx) =>
      this.insert(tx, {
        category: b.category,
        channel: b.channel,
        name: b.name ?? null,
        email: b.email,
        locale: b.locale ?? null,
        description: b.description,
        contentLocation: b.contentLocation ?? null,
        receivedAt,
        acknowledged: sendAck,
        actor: staff.actor,
      }),
    );
    this.afterIntake(row.id, row.pages, row.resolveDueAt, sendAck);
    return this.get(row.id);
  }

  async acknowledge(staff: StaffUser, id: string): Promise<GrievanceDetail> {
    await this.adminDb.withTx(async (tx) => {
      const r = await tx.query(
        `update public.admin_grievances set status = 'acknowledged', acknowledged_at = now(), updated_at = now()
          where id = $1 and status = 'open' returning ticket`,
        [id],
      );
      if (!r.rowCount) {
        const exists = (await tx.query('select 1 from public.admin_grievances where id = $1', [id])).rowCount;
        if (!exists) throw AdminErrors.notFound('That grievance does not exist.');
        return;
      }
      await auditConsole(tx, staff.actor, { action: 'grievance_acknowledged', detail: { grievanceId: id, ticket: r.rows[0].ticket } });
    });
    void this.mail.sendAck(id).catch(() => undefined);
    return this.get(id);
  }

  /** Resolve with a reply; the email always states the appeal route (REQ-ADM-09). */
  async resolve(staff: StaffUser, id: string, body: unknown): Promise<GrievanceDetail & { replyEmailed: boolean }> {
    const b = parse(resolveGrievanceSchema, body);
    await this.adminDb.withTx(async (tx) => {
      const r = await tx.query<{ ticket: string; category: string }>(
        `update public.admin_grievances
            set status = 'resolved', resolved_at = now(), resolved_by = $2, outcome = $3, reply = $4,
                acknowledged_at = coalesce(acknowledged_at, now()), updated_at = now()
          where id = $1 and status <> 'resolved' returning ticket, category`,
        [id, staff.actor, b.outcome, b.reply],
      );
      if (!r.rowCount) {
        const exists = (await tx.query('select 1 from public.admin_grievances where id = $1', [id])).rowCount;
        if (!exists) throw AdminErrors.notFound('That grievance does not exist.');
        throw AdminErrors.conflict('grievance_resolved', 'That grievance is already resolved.');
      }
      await auditConsole(tx, staff.actor, {
        action: 'grievance_resolved',
        reasonCode: b.outcome,
        detail: { grievanceId: id, ticket: r.rows[0].ticket, category: r.rows[0].category },
      });
      await tx.query(
        `update public.admin_pages set status = 'resolved', closed_at = now(), lease_until = null
          where kind = 'grievance' and ref_id = $1 and status = 'open'`,
        [id],
      );
    });
    const replyEmailed = await this.mail.sendReply(id);
    return { ...(await this.get(id)), replyEmailed };
  }
}
