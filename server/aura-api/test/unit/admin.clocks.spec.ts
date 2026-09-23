/**
 * Statutory clocks and work order (PRD 19: IT Rules timelines; REQ-ADM-04 "a new L0 item sorts above all L1–L3 items";
 * lanes then oldest first).
 */
import {
  GRIEVANCE_CATEGORIES,
  GRIEVANCE_RULES,
  LEGAL_ORDER_PRIORITY,
  compareWork,
  grievanceClock,
  grievancePriority,
  legalOrderDueAt,
  minutesLeft,
  reportPriority,
  type WorkItem,
} from '../../src/admin/clocks';

const T0 = new Date('2026-10-12T21:30:00.000Z'); // 03:00 IST
const H = 3_600_000;

describe('statutory clocks', () => {
  it('grievances: acknowledge in 24 h; resolve in 7 days, 36 h (unlawful content) or 2 h (nudity / CSAM, NCII — these page)', () => {
    const due = (c: (typeof GRIEVANCE_CATEGORIES)[number]) => grievanceClock(c, T0);
    for (const c of GRIEVANCE_CATEGORIES) expect(due(c).ackDueAt.getTime() - T0.getTime()).toBe(24 * H);
    expect(due('general').resolveDueAt.getTime() - T0.getTime()).toBe(7 * 24 * H);
    expect(due('data_request').resolveDueAt.getTime() - T0.getTime()).toBe(7 * 24 * H);
    expect(due('moderation_appeal').resolveDueAt.getTime() - T0.getTime()).toBe(7 * 24 * H);
    expect(due('unlawful_content').resolveDueAt.getTime() - T0.getTime()).toBe(36 * H);
    expect(due('nudity_csam')).toMatchObject({ pages: true });
    expect(due('nudity_csam').resolveDueAt.getTime() - T0.getTime()).toBe(2 * H);
    expect(due('ncii')).toMatchObject({ pages: true });
    expect(due('ncii').resolveDueAt.getTime() - T0.getTime()).toBe(2 * H);
    expect(GRIEVANCE_CATEGORIES.filter((c) => GRIEVANCE_RULES[c].pages)).toEqual(['nudity_csam', 'ncii']);
  });

  it('court / government orders: 3 h from receipt (not from data entry)', () => {
    expect(legalOrderDueAt(T0).getTime() - T0.getTime()).toBe(3 * H);
  });

  it('minutes left goes negative when overdue', () => {
    expect(minutesLeft(new Date(T0.getTime() + 90 * 60_000), T0)).toBe(90);
    expect(minutesLeft(new Date(T0.getTime() - 61 * 60_000).toISOString(), T0)).toBe(-61);
  });
});

describe('work order', () => {
  const item = (kind: WorkItem['kind'], id: string, priority: number, dueMin: number, createdMin: number): WorkItem => ({
    kind,
    id,
    priority,
    dueAt: new Date(T0.getTime() + dueMin * 60_000).toISOString(),
    createdAt: new Date(T0.getTime() + createdMin * 60_000).toISOString(),
  });

  it('priorities: legal orders and crisis L0; minors & grooming and 2 h grievances L1; harassment and unlawful content L2; the rest L3', () => {
    expect(LEGAL_ORDER_PRIORITY).toBe(0);
    expect(reportPriority('crisis')).toBe(0);
    expect(reportPriority('minors_grooming')).toBe(1);
    expect(grievancePriority('nudity_csam')).toBe(1);
    expect(grievancePriority('ncii')).toBe(1);
    expect(reportPriority('harassment')).toBe(2);
    expect(grievancePriority('unlawful_content')).toBe(2);
    expect(reportPriority('spam')).toBe(3);
    expect(grievancePriority('general')).toBe(3);
  });

  it('REQ-ADM-04: a brand-new L0 item sorts above every older L1–L3 item', () => {
    const list = [
      item('report', 'spam-old', reportPriority('spam'), -600, -2000),
      item('report', 'harassment-overdue', reportPriority('harassment'), -30, -1500),
      item('report', 'minors', reportPriority('minors_grooming'), 60, -60),
      item('grievance', 'ncii', grievancePriority('ncii'), 30, -90),
      item('report', 'crisis-new', reportPriority('crisis'), 15, 0),
      item('legal_order', 'order', LEGAL_ORDER_PRIORITY, 170, -10),
    ].sort(compareWork);
    expect(list.map((x) => x.id)).toEqual(['crisis-new', 'order', 'ncii', 'minors', 'harassment-overdue', 'spam-old']);
  });

  it('within a priority: earliest deadline, then oldest, then id (stable)', () => {
    const a = item('report', 'a', 2, 100, -10);
    const b = item('report', 'b', 2, 50, 0);
    const c = item('report', 'c', 2, 50, -5);
    const d = item('report', 'd', 2, 50, -5);
    expect([a, b, d, c].sort(compareWork).map((x) => x.id)).toEqual(['c', 'd', 'b', 'a']);
  });
});
