import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Queryable } from '../../db/db';
import { DbService } from '../../db/db.service';
import { AdminConfig } from '../admin-config';
import { SYSTEM_ACTORS, auditConsole } from '../admin-audit';
import { PAGE_CHANNELS } from './channels';
import {
  escalationLevel,
  nextAttemptAt,
  runRound,
  sleep,
  type DeliveryAttempt,
  type PageChannel,
  type PageKind,
  type PagePayload,
} from './paging-rules';

/**
 * The on-call pager (PRD 19 REQ-ADM-05 / REQ-ADM-15, F9 "24×7 paging"). Pages are rows in `admin_pages`; a dispatcher
 * claims due rows with a short lease (`FOR UPDATE SKIP LOCKED`, so the API's in-process fast path and the worker's
 * 30-second tick never double-send), delivers one round on the configured channels, logs every attempt in
 * `admin_page_deliveries` and schedules the next round until the page is acknowledged or its item is closed.
 * Test pages stop after `PAGING_TEST_MAX_ROUNDS`. Runs as the service role: it reads item state across tables and
 * writes the log; staff acknowledge through the console (aura_admin).
 */
export interface RaiseInput {
  kind: PageKind;
  refId: string | null;
  reason: string;
  lane?: string | null;
  minorInvolved?: boolean;
  isTest?: boolean;
  dueAt?: Date | null;
}

interface ClaimedPage {
  id: string;
  kind: PageKind;
  ref_id: string | null;
  reason: string;
  lane: string | null;
  minor_involved: boolean;
  is_test: boolean;
  due_at: Date | null;
  round: number;
  escalation_level: number;
  created_at: Date;
}

export interface PagingRunSummary {
  claimed: number;
  delivered: number;
  failed: number;
  resolved: number;
  expired: number;
}

interface RefState {
  open: boolean;
  ticket: string | null;
  itemAt: Date | null;
}

@Injectable()
export class PagingService {
  private readonly logger = new Logger('Pager');
  private running: Promise<void> | null = null;
  private rerun = false;
  /** How retries inside a round wait (tests swap in an instant clock). */
  wait: (ms: number) => Promise<void> = sleep;

  constructor(
    private readonly db: DbService,
    private readonly config: AdminConfig,
    @Inject(PAGE_CHANNELS) private readonly channels: PageChannel[],
  ) {}

  /** Configured channels, for the console's status panel (names and levels only — never URLs or tokens). */
  get channelSummary(): Array<{ name: string; level: 0 | 1 }> {
    return this.channels.map((c) => ({ name: c.name, level: c.level }));
  }

  /** Raise a page for an item — idempotent per item (one page per order / grievance / report, ever). */
  async raise(input: RaiseInput): Promise<{ pageId: string; created: boolean }> {
    return this.db.withTx(async (tx) => {
      const ins = await tx.query<{ id: string }>(
        `insert into public.admin_pages (kind, ref_id, reason, lane, minor_involved, is_test, due_at)
         values ($1, $2, $3, $4, $5, $6, $7)
         on conflict (kind, ref_id) where ref_id is not null do nothing
         returning id`,
        [input.kind, input.refId, input.reason, input.lane ?? null, input.minorInvolved ?? false, input.isTest ?? false, input.dueAt ?? null],
      );
      const id = ins.rows[0]?.id;
      if (!id) {
        const existing = await tx.query<{ id: string }>('select id from public.admin_pages where kind = $1 and ref_id = $2', [input.kind, input.refId]);
        return { pageId: existing.rows[0].id, created: false };
      }
      await auditConsole(tx, SYSTEM_ACTORS.pager, {
        action: 'page_raised',
        reasonCode: input.reason,
        reportId: input.kind === 'report' ? input.refId : null,
        detail: { pageId: id, kind: input.kind, test: input.isTest ?? false, minorInvolved: input.minorInvolved ?? false },
      });
      return { pageId: id, created: true };
    });
  }

  /** In-process fast path after raising a page: deliver now (the worker tick is the safety net). */
  kick(): void {
    if (this.running) {
      this.rerun = true;
      return;
    }
    this.running = (async () => {
      do {
        this.rerun = false;
        try {
          await this.runDue();
        } catch (e) {
          this.logger.warn(`dispatch failed: ${(e as Error).name}`);
        }
      } while (this.rerun);
    })().finally(() => {
      this.running = null;
    });
  }

  /** Resolves once no in-process dispatch is running (tests, shutdown). */
  async idle(): Promise<void> {
    while (this.running) await this.running;
  }

  /** Deliver every due page once. `now` is injectable so tests can fast-forward repeats and escalation. */
  async runDue(now: Date = new Date(), limit = 20): Promise<PagingRunSummary> {
    const s: PagingRunSummary = { claimed: 0, delivered: 0, failed: 0, resolved: 0, expired: 0 };
    const claimed = await this.db.query<ClaimedPage>(
      `update public.admin_pages p set lease_until = $1::timestamptz + interval '2 minutes'
        where p.id in (select x.id from public.admin_pages x
                        where x.status = 'open' and x.next_attempt_at <= $1::timestamptz
                          and (x.lease_until is null or x.lease_until < $1::timestamptz)
                        order by x.next_attempt_at, x.id limit $2 for update skip locked)
        returning p.id, p.kind, p.ref_id, p.reason, p.lane, p.minor_involved, p.is_test, p.due_at, p.round,
                  p.escalation_level, p.created_at`,
      [now, limit],
    );
    for (const page of claimed.rows) {
      s.claimed++;
      try {
        await this.deliver(page, now, s);
      } catch (e) {
        this.logger.warn(`page ${page.kind} round ${page.round} failed: ${(e as Error).name}`);
        await this.db
          .query(`update public.admin_pages set lease_until = null, next_attempt_at = $2 where id = $1 and status = 'open'`, [
            page.id,
            new Date(now.getTime() + 60_000),
          ])
          .catch(() => undefined);
      }
    }
    return s;
  }

  private async deliver(page: ClaimedPage, now: Date, s: PagingRunSummary): Promise<void> {
    const ref = await this.refState(page);
    if (!ref.open) {
      await this.db.query(`update public.admin_pages set status = 'resolved', closed_at = $2, lease_until = null where id = $1 and status = 'open'`, [
        page.id,
        now,
      ]);
      s.resolved++;
      return;
    }
    if (page.is_test && page.round >= this.config.paging.testMaxRounds) {
      await this.db.withTx(async (tx) => {
        const r = await tx.query(`update public.admin_pages set status = 'expired', closed_at = $2, lease_until = null where id = $1 and status = 'open'`, [
          page.id,
          now,
        ]);
        if ((r.rowCount ?? 0) > 0) {
          await auditConsole(tx, SYSTEM_ACTORS.pager, { action: 'page_expired', reasonCode: page.reason, detail: { pageId: page.id, rounds: page.round } });
        }
      });
      s.expired++;
      return;
    }

    const p = this.config.paging;
    const level = escalationLevel(page.round, page.created_at, now, p.escalateAfterMinutes);
    const payload: PagePayload = {
      pageId: page.id,
      kind: page.kind,
      reason: page.reason,
      lane: page.lane,
      minorInvolved: page.minor_involved,
      isTest: page.is_test,
      ticket: ref.ticket,
      dueAt: page.due_at ? page.due_at.toISOString() : null,
      waitingMinutes: Math.max(0, Math.floor((now.getTime() - (ref.itemAt ?? page.created_at).getTime()) / 60_000)),
      round: page.round,
      escalationLevel: level,
      consoleUrl: `${this.config.consoleUrl}/paging/${page.id}`,
    };
    const { attempts, delivered } =
      this.channels.length > 0 ? await runRound(this.channels, level, payload, p.retryDelaysMs, this.wait) : { attempts: [], delivered: false };

    await this.db.withTx(async (tx) => {
      await this.logAttempts(tx, page, level, attempts);
      await tx.query(
        `update public.admin_pages
            set round = round + 1, escalation_level = greatest(escalation_level, $2), last_attempt_at = $3,
                last_delivered_at = case when $4 then $3 else last_delivered_at end, next_attempt_at = $5, lease_until = null
          where id = $1 and status = 'open'`,
        [page.id, level, now, delivered, nextAttemptAt(now, delivered, p.repeatMinutes)],
      );
    });
    if (delivered) {
      s.delivered++;
    } else {
      s.failed++;
      const codes = attempts.length ? [...new Set(attempts.map((a) => a.result.error ?? 'error'))].join(',') : 'no_channels';
      this.logger.warn(`page ${page.kind} round ${page.round} was not delivered (${codes})`);
    }
  }

  private async logAttempts(tx: Queryable, page: ClaimedPage, level: 0 | 1, attempts: DeliveryAttempt[]): Promise<void> {
    if (attempts.length === 0) {
      await tx.query(
        `insert into public.admin_page_deliveries (page_id, round, level, channel, attempt, ok, error) values ($1, $2, $3, 'none', 1, false, 'no_channels')`,
        [page.id, page.round, level],
      );
      return;
    }
    for (const a of attempts) {
      await tx.query(
        `insert into public.admin_page_deliveries (page_id, round, level, channel, attempt, ok, http_status, error, latency_ms)
         values ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [page.id, page.round, a.level, a.channel, a.attempt, a.result.ok, a.result.httpStatus, a.result.error, Math.max(0, Math.round(a.result.latencyMs))],
      );
    }
  }

  /** Is the paged item still waiting? (A missing item — e.g. a purged report — counts as closed.) */
  private async refState(page: ClaimedPage): Promise<RefState> {
    if (page.kind === 'test' || !page.ref_id) return { open: true, ticket: null, itemAt: null };
    const sql: Record<Exclude<PageKind, 'test'>, string> = {
      legal_order: `select status = 'open' as open, ticket, received_at as item_at from public.admin_legal_orders where id = $1`,
      grievance: `select status <> 'resolved' as open, ticket, received_at as item_at from public.admin_grievances where id = $1`,
      report: `select status = 'open' as open, null::text as ticket, created_at as item_at from public.reports where id = $1`,
    };
    const r = await this.db.query<{ open: boolean; ticket: string | null; item_at: Date }>(sql[page.kind], [page.ref_id]);
    const row = r.rows[0];
    return row ? { open: row.open, ticket: row.ticket, itemAt: row.item_at } : { open: false, ticket: null, itemAt: null };
  }

  /**
   * Items that must page and have no page yet (the worker's tick; idempotent): reports the safety module flagged
   * `pages` (L1 sexual / contact involving a minor; L0 crisis in India's Lantern Hour), crisis reports within 5 minutes
   * of their SLA or past it, open 2-hour grievances (nudity / CSAM / NCII) and open legal orders.
   */
  async sweep(now: Date = new Date()): Promise<number> {
    const r = await this.db.query<{
      kind: Exclude<PageKind, 'test'>;
      ref_id: string;
      reason: string;
      lane: string | null;
      minor: boolean;
      is_test: boolean;
      due_at: Date | null;
    }>(
      `(select 'report' as kind, r.id as ref_id,
               case when r.lane = 'crisis' and r.pages then 'crisis_lantern_hour'
                    when r.lane = 'crisis' then 'crisis_near_sla'
                    when r.lane = 'minors_grooming' then 'minors_urgent'
                    else 'report_urgent' end as reason,
               r.lane, r.involves_minor as minor, false as is_test, r.sla_due_at as due_at
          from public.reports r
         where r.status = 'open'
           and (r.pages or (r.lane = 'crisis' and r.sla_due_at <= $1::timestamptz + interval '5 minutes'))
           and not exists (select 1 from public.admin_pages p where p.kind = 'report' and p.ref_id = r.id)
         limit 50)
       union all
       (select 'grievance', g.id, 'grievance_2h', null, false, false, g.resolve_due_at
          from public.admin_grievances g
         where g.pages and g.status <> 'resolved'
           and not exists (select 1 from public.admin_pages p where p.kind = 'grievance' and p.ref_id = g.id)
         limit 50)
       union all
       (select 'legal_order', o.id, 'legal_order', null, false, o.is_test, o.due_at
          from public.admin_legal_orders o
         where o.status = 'open'
           and not exists (select 1 from public.admin_pages p where p.kind = 'legal_order' and p.ref_id = o.id)
         limit 50)`,
      [now],
    );
    let created = 0;
    for (const x of r.rows) {
      const out = await this.raise({
        kind: x.kind,
        refId: x.ref_id,
        reason: x.reason,
        lane: x.lane,
        minorInvolved: x.minor,
        isTest: x.is_test,
        dueAt: x.due_at,
      });
      if (out.created) created++;
    }
    return created;
  }

  /** Weekly drill (REQ-ADM-15 "weekly test page logged") or a manual test from the console. */
  raiseTest(reason: 'test_weekly' | 'test_manual'): Promise<{ pageId: string; created: boolean }> {
    return this.raise({ kind: 'test', refId: null, reason, isTest: true });
  }
}
