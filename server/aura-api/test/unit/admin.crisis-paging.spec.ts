/**
 * REQ-ADM-05 crisis phone alert: an L0 (crisis) item filed in India's Lantern Hour — or its room region's Lantern Hour —
 * pages at once through the API's fast path (UrgentPager → PagingService.reportFiled); outside those windows the
 * worker pages crisis items still open 5 minutes after they arrived, 24×7 (06c F9 "crisis items unassigned 5 min");
 * pages repeat every 5 minutes until acknowledged and never carry content (admin.paging.spec.ts covers the rounds).
 */
import { parseAdminConfig } from '../../src/admin/admin-config';
import { PagingService, reportPageReason } from '../../src/admin/paging/paging.service';
import type { DbService } from '../../src/db/db.service';
import { slaFor } from '../../src/safety/lanes';

const at = (iso: string): Date => new Date(iso);
const mins = (from: Date, to: Date): number => (to.getTime() - from.getTime()) / 60_000;

describe('crisis clock and page-at-once (slaFor)', () => {
  it('India’s Lantern Hour (21:00–23:00 IST): 15-minute SLA and an immediate page', () => {
    const t = at('2026-10-08T16:00:00Z'); // 21:30 IST
    const s = slaFor('crisis', 1, false, t, { roomRegion: 'americas' });
    expect(s.pages).toBe(true);
    expect(mins(t, s.dueAt)).toBe(15);
  });

  it('the room region’s own Lantern Hour also pages at once (the PRD’s 15-minute SLA stays India’s)', () => {
    const berlinEvening = at('2026-10-08T19:30:00Z'); // 21:30 CEST, 01:00 IST
    const s = slaFor('crisis', 1, false, berlinEvening, { roomRegion: 'europe_africa' });
    expect(s).toEqual({ dueAt: new Date(berlinEvening.getTime() + 60 * 60_000), pages: true });
    expect(slaFor('crisis', 1, false, berlinEvening, { roomRegion: 'east_asia_pacific' }).pages).toBe(false);
    expect(slaFor('crisis', 1, false, berlinEvening).pages).toBe(false); // no room (e.g. purged): India's clock only
  });

  it('outside every Lantern Hour: 1-hour SLA, no page at filing (the worker pages it at 5 minutes, 24×7)', () => {
    const t = at('2026-10-08T06:30:00Z'); // 12:00 IST, 08:30 CEST, 01:30 CDT, 15:30 JST
    for (const region of ['americas', 'europe_africa', 'south_asia', 'east_asia_pacific'] as const) {
      expect(slaFor('crisis', 1, false, t, { roomRegion: region })).toEqual({ dueAt: new Date(t.getTime() + 60 * 60_000), pages: false });
    }
  });

  it('follows the configured Lantern Hour window (matching_config)', () => {
    const t = at('2026-10-08T15:00:00Z'); // 20:30 IST
    expect(slaFor('crisis', 1, false, t).pages).toBe(false);
    expect(slaFor('crisis', 1, false, t, { lanternStart: { hour: 20, minute: 0 }, lanternEnd: { hour: 22, minute: 0 } }).pages).toBe(true);
  });

  it('page reasons are the same from the fast path and the sweep', () => {
    expect(reportPageReason('crisis', true)).toBe('crisis_lantern_hour');
    expect(reportPageReason('crisis', false)).toBe('crisis_unassigned');
    expect(reportPageReason('minors_grooming', true)).toBe('minors_urgent');
    expect(reportPageReason('harassment', true)).toBe('report_urgent');
  });
});

describe('PagingService: fast path and the 24×7 sweep', () => {
  const REPORT = '0192f0c2-7a4e-7c1a-9b3d-0000000000f1';

  function service(rows: Record<string, unknown>[]): { paging: PagingService; queries: Array<{ text: string; params: unknown[] }> } {
    const queries: Array<{ text: string; params: unknown[] }> = [];
    const db = {
      async query(text: string, params: unknown[] = []) {
        queries.push({ text, params });
        return { rows, rowCount: rows.length };
      },
    } as unknown as DbService;
    return { paging: new PagingService(db, parseAdminConfig({ PAGING_CRISIS_AFTER_MINUTES: '5' }), []), queries };
  }

  it('reportFiled raises the page for a paging report at once and starts delivery (no worker needed)', async () => {
    const due = new Date(Date.now() + 15 * 60_000);
    const { paging } = service([{ id: REPORT, lane: 'crisis', pages: true, involves_minor: false, sla_due_at: due, status: 'open' }]);
    const raise = jest.spyOn(paging, 'raise').mockResolvedValue({ pageId: 'p1', created: true });
    const kick = jest.spyOn(paging, 'kick').mockImplementation(() => undefined);
    paging.reportFiled(REPORT);
    await new Promise((r) => setImmediate(r));
    await new Promise((r) => setImmediate(r));
    expect(raise).toHaveBeenCalledWith({ kind: 'report', refId: REPORT, reason: 'crisis_lantern_hour', lane: 'crisis', minorInvolved: false, dueAt: due });
    expect(kick).toHaveBeenCalledTimes(1);
  });

  it('reportFiled ignores reports that no longer page (closed, or not flagged)', async () => {
    const { paging } = service([{ id: REPORT, lane: 'crisis', pages: false, involves_minor: false, sla_due_at: new Date(), status: 'open' }]);
    const raise = jest.spyOn(paging, 'raise');
    paging.reportFiled(REPORT);
    await new Promise((r) => setImmediate(r));
    expect(raise).not.toHaveBeenCalled();
  });

  it('the worker sweep pages crisis items still open after PAGING_CRISIS_AFTER_MINUTES, with no overnight exception', async () => {
    const { paging, queries } = service([]);
    const now = new Date('2026-10-08T21:40:00Z'); // 03:10 IST — overnight in India
    await paging.sweep(now);
    const q = queries[0];
    expect(q.params).toEqual([now, 5]);
    expect(q.text).toMatch(/r\.lane = 'crisis' and \(r\.created_at <= \$1::timestamptz - make_interval\(mins => \$2::int\)/);
    expect(q.text).toMatch(/'crisis_unassigned'/);
    expect(q.text).not.toMatch(/staffed|overnight|extract\(hour/i); // no time-of-day exception
  });
});

describe('dispatch under a backlog (REQ-ADM-05: a fresh page never waits behind repeats)', () => {
  it('first deliveries (round 0) are claimed before repeats, then the longest-waiting', async () => {
    const queries: string[] = [];
    const db = { query: async (text: string) => (queries.push(text), { rows: [], rowCount: 0 }) } as unknown as DbService;
    await new PagingService(db, parseAdminConfig({}), []).runDue(new Date());
    expect(queries[0]).toMatch(/order by \(x\.round = 0\) desc, x\.next_attempt_at, x\.id limit \$2 for update skip locked/);
  });

  it('the fast path drains batch after batch until a batch comes back short', async () => {
    const paging = new PagingService({} as DbService, parseAdminConfig({}), []);
    const batches = [20, 20, 7];
    const runDue = jest.spyOn(paging, 'runDue').mockImplementation(async () => ({ claimed: batches.shift() ?? 0, delivered: 0, failed: 0, resolved: 0, expired: 0 }));
    const total = await paging.drain();
    expect(runDue).toHaveBeenCalledTimes(3);
    expect(total.claimed).toBe(47);
    paging.kick();
    await paging.idle();
    expect(runDue).toHaveBeenCalledTimes(4); // a kick drains too (here one short batch)
  });
});
