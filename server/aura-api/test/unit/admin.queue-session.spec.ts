/**
 * PRD 19 "Queue sessions capped at 2 h": continuous review work (opening report items, acting on them) is capped; after
 * the cap, non-urgent items stay closed until the reviewer has been away for the break; crisis and paging items always
 * stay open and never postpone the break; the cap is audited once per session; Redis down → the cap fails open.
 */
import type { AdminConfig } from '../../src/admin/admin-config';
import type { AdminDb } from '../../src/admin/admin-db';
import type { StaffUser } from '../../src/admin/admin-types';
import { QueueSessionService, stepQueueSession, type QueueSessionState } from '../../src/admin/queue-session';
import type { QueuesService } from '../../src/queues/queues.service';

const MIN = 60_000;
const CFG = { maxMinutes: 120, breakMinutes: 15 };
const T0 = Date.parse('2026-10-12T14:00:00Z');

describe('stepQueueSession (pure)', () => {
  it('the first review starts a session; a peek never does', () => {
    expect(stepQueueSession(null, T0, CFG, { touch: false, urgent: false })).toMatchObject({ next: null, allowed: true, minutesLeft: 120 });
    const s = stepQueueSession(null, T0, CFG, { touch: true, urgent: false });
    expect(s).toMatchObject({ next: { startedAt: T0, lastAt: T0, cappedAt: null }, allowed: true, minutesLeft: 120 });
  });

  it('work keeps the session going (gaps under the break); 2 h after its start non-urgent items close', () => {
    let st: QueueSessionState = { startedAt: T0, lastAt: T0, cappedAt: null };
    for (let m = 10; m < 120; m += 10) {
      const s = stepQueueSession(st, T0 + m * MIN, CFG, { touch: true, urgent: false });
      expect(s.allowed).toBe(true);
      expect(s.minutesLeft).toBe(120 - m);
      st = s.next as QueueSessionState;
    }
    const capped = stepQueueSession(st, T0 + 121 * MIN, CFG, { touch: true, urgent: false });
    expect(capped).toMatchObject({ allowed: false, capped: true, newlyCapped: true, minutesLeft: 0 });
    expect(capped.breakUntil).toBe(T0 + 110 * MIN + 15 * MIN); // 15 min after the last allowed review
    const again = stepQueueSession(capped.next, T0 + 122 * MIN, CFG, { touch: true, urgent: false });
    expect(again).toMatchObject({ allowed: false, newlyCapped: false }); // audited once
  });

  it('urgent (crisis / paging) items stay open when capped and do not postpone the break', () => {
    const st: QueueSessionState = { startedAt: T0, lastAt: T0 + 119 * MIN, cappedAt: T0 + 121 * MIN };
    const urgent = stepQueueSession(st, T0 + 125 * MIN, CFG, { touch: true, urgent: true });
    expect(urgent).toMatchObject({ allowed: true, capped: true });
    expect(urgent.next).toBe(st);
  });

  it('a break of 15 minutes ends the session; the next review starts a fresh 2 hours', () => {
    const st: QueueSessionState = { startedAt: T0, lastAt: T0 + 119 * MIN, cappedAt: T0 + 121 * MIN };
    const fresh = stepQueueSession(st, T0 + 134 * MIN, CFG, { touch: true, urgent: false });
    expect(fresh).toMatchObject({ allowed: true, capped: false, next: { startedAt: T0 + 134 * MIN, cappedAt: null }, minutesLeft: 120 });
  });
});

describe('QueueSessionService', () => {
  const staff = { id: '0192f0c2-7a4e-7c1a-9b3d-000000000001', actor: 'staff:0192f0c2-7a4e-7c1a-9b3d-000000000001' } as StaffUser;
  const config = { queueSession: CFG } as unknown as AdminConfig;

  function build(store: { get: (k: string) => Promise<string | null>; set: (...a: unknown[]) => Promise<unknown> }) {
    const audits: unknown[] = [];
    const adminDb = {
      query: async (text: string, params: unknown[]) => {
        if (/insert into public\.moderation_actions/.test(text)) audits.push({ action: params[1], actor: params[0] });
        return { rows: [{ id: '1' }], rowCount: 1 };
      },
    } as unknown as AdminDb;
    const svc = new QueueSessionService({ redis: store } as unknown as QueuesService, config, adminDb);
    return { svc, audits };
  }

  function memoryStore() {
    const m = new Map<string, string>();
    return { m, get: async (k: string) => m.get(k) ?? null, set: async (k: unknown, v: unknown) => void m.set(k as string, v as string) };
  }

  it('gates review work: 423 queue_session_cap after 2 h (audited once), urgent items still open', async () => {
    const store = memoryStore();
    const { svc, audits } = build(store);
    let now = T0;
    svc.clock = () => now;
    await svc.gate(staff, { urgent: false });
    for (now = T0 + 10 * MIN; now <= T0 + 110 * MIN; now += 10 * MIN) await svc.gate(staff, { urgent: false });
    now = T0 + 121 * MIN;
    await expect(svc.gate(staff, { urgent: false })).rejects.toMatchObject({ status: 423, code: 'queue_session_cap' });
    await expect(svc.gate(staff, { urgent: false })).rejects.toMatchObject({ code: 'queue_session_cap' });
    expect(audits).toEqual([{ action: 'queue_session_capped', actor: staff.actor }]);
    await expect(svc.gate(staff, { urgent: true })).resolves.toMatchObject({ capped: true });
    expect(await svc.peek(staff)).toMatchObject({ capped: true, breakUntil: new Date(T0 + 125 * MIN).toISOString(), maxMinutes: 120, breakMinutes: 15 });
    now = T0 + 126 * MIN; // 16 minutes after the last allowed review
    await expect(svc.gate(staff, { urgent: false })).resolves.toMatchObject({ capped: false, minutesLeft: 120 });
  });

  it('fails open when Redis is unavailable', async () => {
    const { svc } = build({ get: () => Promise.reject(new Error('down')), set: () => Promise.reject(new Error('down')) });
    await expect(svc.gate(staff, { urgent: false })).resolves.toMatchObject({ capped: false });
  });
});
