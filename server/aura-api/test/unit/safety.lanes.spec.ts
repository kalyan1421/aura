/**
 * F9 core: report reasons → lanes (crisis wins; minors & grooming when anyone involved is under 18 or reason 7),
 * SLA clocks (19 admin console), the strike ladder, and the audit subject hash (no raw account ids).
 */
import { subjectHash } from '../../src/safety/audit';
import { laneFor, slaFor } from '../../src/safety/lanes';
import { isReportReason, LANE_PRIORITY, REPORT_REASONS, type ReportReason } from '../../src/safety/safety-types';
import { consequenceForActiveStrikes } from '../../src/safety/strikes';

const ALL: ReportReason[] = [1, 2, 3, 4, 5, 6, 7, 8];

describe('report reasons → lanes', () => {
  it('the 8 one-tap reasons from the PRD', () => {
    expect(REPORT_REASONS).toEqual({
      1: 'in_danger',
      2: 'harassment',
      3: 'sexual',
      4: 'hate',
      5: 'contact_info',
      6: 'spam',
      7: 'under_13',
      8: 'other',
    });
    expect(ALL.every(isReportReason)).toBe(true);
    for (const bad of [0, 9, 1.5, '1', null]) expect(isReportReason(bad)).toBe(false);
  });

  it('adults on both sides', () => {
    expect(ALL.map((r) => laneFor(r, false))).toEqual([
      'crisis',
      'harassment',
      'harassment',
      'harassment',
      'harassment',
      'spam',
      'minors_grooming',
      'spam',
    ]);
  });

  it('anyone involved under 18 → minors & grooming, except crisis which sorts above everything', () => {
    expect(ALL.map((r) => laneFor(r, true))).toEqual([
      'crisis',
      'minors_grooming',
      'minors_grooming',
      'minors_grooming',
      'minors_grooming',
      'minors_grooming',
      'minors_grooming',
      'minors_grooming',
    ]);
    expect(Object.entries(LANE_PRIORITY).sort((a, b) => a[1] - b[1]).map(([lane]) => lane)).toEqual([
      'crisis',
      'minors_grooming',
      'harassment',
      'spam',
    ]);
  });
});

describe('SLA clocks', () => {
  const at = (iso: string) => new Date(iso);
  const mins = (from: Date, to: Date) => (to.getTime() - from.getTime()) / 60_000;

  it('crisis: < 15 min in India’s Lantern Hour (pages), < 1 h otherwise', () => {
    const inLh = at('2026-10-08T16:00:00Z'); // 21:30 IST
    expect(mins(inLh, slaFor('crisis', 1, false, inLh).dueAt)).toBe(15);
    expect(slaFor('crisis', 1, false, inLh).pages).toBe(true);
    const day = at('2026-10-08T06:00:00Z');
    expect(mins(day, slaFor('crisis', 1, true, day).dueAt)).toBe(60);
    expect(slaFor('crisis', 1, true, day).pages).toBe(false);
  });

  it('minors & grooming: sexual or contact/personal info involving a minor < 2 h and pages 24×7; other L1 < 4 h', () => {
    const t = at('2026-10-08T21:00:00Z'); // 02:30 IST: overnight still pages
    expect(slaFor('minors_grooming', 3, true, t)).toEqual({ dueAt: new Date(t.getTime() + 120 * 60_000), pages: true });
    expect(slaFor('minors_grooming', 5, true, t)).toEqual({ dueAt: new Date(t.getTime() + 120 * 60_000), pages: true });
    expect(slaFor('minors_grooming', 7, false, t)).toEqual({ dueAt: new Date(t.getTime() + 240 * 60_000), pages: false });
    expect(slaFor('minors_grooming', 2, true, t)).toEqual({ dueAt: new Date(t.getTime() + 240 * 60_000), pages: false });
  });

  it('harassment and spam: < 24 h, no page', () => {
    const t = at('2026-10-08T10:00:00Z');
    for (const lane of ['harassment', 'spam'] as const) {
      expect(slaFor(lane, 2, false, t)).toEqual({ dueAt: new Date(t.getTime() + 24 * 3_600_000), pages: false });
    }
  });
});

describe('strike ladder', () => {
  it('warning → 24 h shadow-mute → 7-day room suspension → permanent social ban', () => {
    expect([1, 2, 3, 4, 5].map(consequenceForActiveStrikes)).toEqual([
      { kind: 'warning', hours: null },
      { kind: 'shadow_mute', hours: 24 },
      { kind: 'room_suspension', hours: 168 },
      { kind: 'social_ban', hours: null },
      { kind: 'social_ban', hours: null },
    ]);
  });
});

describe('audit subject hash', () => {
  const key = Buffer.alloc(32, 7);
  const id = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';

  it('is a stable 64-hex HMAC that never contains the account id and depends on the master key', () => {
    const h = subjectHash(key, id);
    expect(h).toMatch(/^[0-9a-f]{64}$/);
    expect(h).toBe(subjectHash(key, id.toUpperCase()));
    expect(h).not.toContain(id.replace(/-/g, '').slice(0, 12));
    expect(subjectHash(Buffer.alloc(32, 8), id)).not.toBe(h);
    expect(subjectHash(key, '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0e')).not.toBe(h);
  });
});
