import { completion, echoRow, isoWeek, medianOffsetMs, validTrace } from '../../src/ripples/echoes';
import { blockSet, fillPlan, nextPollMs, pairKey, percentile, planInviteGroups, planQuickMatch, type WaitingTicket } from '../../src/ripples/matcher';
import { DEFAULT_RIPPLE_CONFIG, sessionLengthMs } from '../../src/ripples/ripple-config';
import { sessionPayload, type SeatRow, type SessionRow } from '../../src/ripples/ripple-views';

/** F7 Breath Ripples matching and echo rules (PRD 06b F7; contracts/api/v1-ripples.md §1.1, §2.3). */
const cfg = DEFAULT_RIPPLE_CONFIG;
const S = 1000;
const t = (id: string, atS: number, userId = `u-${id}`): WaitingTicket => ({ id, userId, enqueuedAtMs: atS * S });
const none = new Set<string>();

describe('quick-match start rules', () => {
  it('starts at once with 4 humans (full)', () => {
    const g = planQuickMatch([t('a', 0), t('b', 1), t('c', 1), t('d', 2)], none, 2 * S, cfg);
    expect(g).toEqual([{ ticketIds: ['a', 'b', 'c', 'd'], rule: 'full' }]);
  });

  it('with 2–3 humans waits until the oldest has waited 8 s (early), then starts with echo-fill', () => {
    const q = [t('a', 0), t('b', 3), t('c', 5)];
    expect(planQuickMatch(q, none, 7_999, cfg)).toEqual([]);
    expect(planQuickMatch(q, none, 8 * S, cfg)).toEqual([{ ticketIds: ['a', 'b', 'c'], rule: 'early' }]);
  });

  it('one human alone starts at exactly 20 s with echoes — never later, never a "no one found" state', () => {
    expect(planQuickMatch([t('a', 0)], none, 19_999, cfg)).toEqual([]);
    expect(planQuickMatch([t('a', 0)], none, 20 * S, cfg)).toEqual([{ ticketIds: ['a'], rule: 'timeout' }]);
  });

  it('never seats a blocked pair together, in either direction', () => {
    const blocked = blockSet([{ blocker: 'u-a', blocked: 'u-b' }]);
    expect(blocked.has(pairKey('u-b', 'u-a'))).toBe(true);
    const g = planQuickMatch([t('a', 0), t('b', 1), t('c', 2)], blocked, 8 * S, cfg);
    expect(g).toEqual([{ ticketIds: ['a', 'c'], rule: 'early' }]);
    for (const grp of g) expect(grp.ticketIds.includes('a') && grp.ticketIds.includes('b')).toBe(false);
  });

  it('a blocked pair of lone waiters each time out alone rather than sit together', () => {
    const blocked = blockSet([{ blocker: 'u-b', blocked: 'u-a' }]);
    const g = planQuickMatch([t('a', 0), t('b', 0.5)], blocked, 21 * S, cfg);
    expect(g).toEqual([
      { ticketIds: ['a'], rule: 'timeout' },
      { ticketIds: ['b'], rule: 'timeout' },
    ]);
  });

  it('younger tickets can still fill a table when the oldest cannot join it', () => {
    const blocked = blockSet(['b', 'c', 'd', 'e'].map((x) => ({ blocker: 'u-a', blocked: `u-${x}` })));
    const g = planQuickMatch([t('a', 0), t('b', 1), t('c', 1), t('d', 2), t('e', 2)], blocked, 3 * S, cfg);
    expect(g).toEqual([{ ticketIds: ['b', 'c', 'd', 'e'], rule: 'full' }]);
  });

  it('never seats one account twice', () => {
    const g = planQuickMatch([t('a', 0, 'same'), t('b', 1, 'same'), t('c', 1)], none, 9 * S, cfg);
    expect(g[0].ticketIds).toEqual(['a', 'c']);
  });

  it('p50 path: with people arriving every 5 s, the median wait is well under 20 s and nobody waits past 20 s', () => {
    // Simulate phones polling every 2 s (deadlines honoured via nextPollMs), arrivals every 5 s for 10 minutes.
    const arrivals = Array.from({ length: 120 }, (_, i) => t(`p${i}`, i * 5));
    const waiting = new Map<string, WaitingTicket>();
    const waits: number[] = [];
    for (let now = 0; now <= 620 * S; now += 250) {
      for (const a of arrivals) if (a.enqueuedAtMs <= now && a.enqueuedAtMs > now - 250) waiting.set(a.id, a);
      for (const g of planQuickMatch([...waiting.values()], none, now, cfg)) {
        for (const id of g.ticketIds) {
          waits.push(now - (waiting.get(id) as WaitingTicket).enqueuedAtMs);
          waiting.delete(id);
        }
      }
    }
    expect(waits).toHaveLength(120);
    expect(percentile(waits, 0.5)).toBeLessThan(20 * S);
    expect(Math.max(...waits)).toBeLessThanOrEqual(20 * S);
  });

  it('sparse traffic (one person every 40 s) still starts everyone by 20 s', () => {
    const waits: number[] = [];
    for (let i = 0; i < 20; i++) {
      const g = planQuickMatch([t(`s${i}`, 0)], none, 20 * S, cfg);
      if (g.length) waits.push(20 * S);
    }
    expect(waits).toHaveLength(20);
    expect(percentile(waits, 0.5)).toBeLessThanOrEqual(20 * S);
  });
});

describe('room invites', () => {
  it('before the 20 s deadline only a full table starts; at the deadline everyone does', () => {
    const q = [t('a', 0), t('b', 1)];
    expect(planInviteGroups(q, none, false, cfg)).toEqual([]);
    expect(planInviteGroups(q, none, true, cfg)).toEqual([{ ticketIds: ['a', 'b'], rule: 'invite' }]);
    expect(planInviteGroups([t('a', 0), t('b', 1), t('c', 1), t('d', 2), t('e', 3)], none, false, cfg)).toEqual([
      { ticketIds: ['a', 'b', 'c', 'd'], rule: 'invite' },
    ]);
  });

  it('blocked members sit in parallel sessions of the same invite', () => {
    const blocked = blockSet([{ blocker: 'u-a', blocked: 'u-b' }]);
    expect(planInviteGroups([t('a', 0), t('b', 1), t('c', 2)], blocked, true, cfg)).toEqual([
      { ticketIds: ['a', 'c'], rule: 'invite' },
      { ticketIds: ['b'], rule: 'invite' },
    ]);
  });
});

describe('polling and fill', () => {
  it('polls every 2 s, or just after the next start deadline', () => {
    expect(nextPollMs(0, [8 * S, 20 * S], cfg)).toBe(2000);
    expect(nextPollMs(7 * S, [8 * S, 20 * S], cfg)).toBe(1050);
    expect(nextPollMs(7_900, [8 * S, 20 * S], cfg)).toBe(250);
    expect(nextPollMs(21 * S, [8 * S, 20 * S], cfg)).toBe(500);
  });

  it('echoes when the library is big enough, guides while it is small, nothing when echoes are off', () => {
    expect(fillPlan(1, cfg, true, 50)).toEqual({ echoes: 3, guides: 0 });
    expect(fillPlan(2, cfg, true, 49)).toEqual({ echoes: 0, guides: 2 });
    expect(fillPlan(1, cfg, false, 500)).toEqual({ echoes: 0, guides: 0 });
    expect(fillPlan(4, cfg, true, 500)).toEqual({ echoes: 0, guides: 0 });
  });

  it('the session is 3 minutes: 10 s settle-in, 16 × (4 s + 6 s), 10 s fade-out', () => {
    expect(sessionLengthMs(cfg)).toBe(180 * S);
  });
});

describe('echo recordings', () => {
  it('validates offsets: ±40 steps of 50 ms, nulls allowed, ≤ 2 per cycle', () => {
    expect(validTrace({ offsets: [0, 1, -3, null] }, 16)).toBe(true);
    expect(validTrace({ offsets: [41] }, 16)).toBe(false);
    expect(validTrace({ offsets: [0.5] }, 16)).toBe(false);
    expect(validTrace({ offsets: [] }, 16)).toBe(false);
    expect(validTrace({ offsets: Array(33).fill(0) }, 16)).toBe(false);
  });

  it('computes completion, median |offset| and the ISO week, and nothing that identifies anyone', () => {
    const offsets = [0, 2, -4, null, 6, ...Array(27).fill(1)];
    expect(completion(offsets, 16)).toBeCloseTo(31 / 32, 3);
    expect(medianOffsetMs([2, -4, 6, null])).toBe(200);
    expect(isoWeek(new Date('2026-10-08T10:00:00Z'))).toBe('2026-W41');
    expect(isoWeek(new Date('2021-01-03T10:00:00Z'))).toBe('2020-W53');
    const row = echoRow({ offsets }, 16, cfg, new Date('2026-10-08T10:00:00Z'));
    expect(Object.keys(row).sort()).toEqual(['completion', 'isoWeek', 'medianOffsetMs', 'offsets', 'pacerVersion']);
  });
});

describe('DS-10: the session payload', () => {
  it('holds seat numbers, kinds and pseudonyms only — never an account or seat member id', () => {
    const session: SessionRow = {
      id: 's1',
      entry: 'quick',
      room_id: null,
      start_rule: 'early',
      t0: new Date(0),
      settle_ms: 10_000,
      inhale_ms: 4000,
      exhale_ms: 6000,
      cycles: 16,
      fade_ms: 10_000,
      pacer_version: 1,
      ends_at: new Date(180_000),
      ended_at: null,
    };
    const seats: SeatRow[] = [
      { id: 'seat-member-1', seat: 1, kind: 'human', user_id: 'account-1', pseudonym: 'Quiet Comet', echo_id: null, left_at: null },
      { id: 'seat-member-2', seat: 2, kind: 'human', user_id: 'account-2', pseudonym: 'Soft Star', echo_id: null, left_at: new Date(5) },
      { id: 'seat-member-3', seat: 3, kind: 'echo', user_id: null, pseudonym: null, echo_id: 'echo-1', left_at: null },
      { id: 'seat-member-4', seat: 4, kind: 'guide', user_id: null, pseudonym: null, echo_id: null, left_at: null },
    ];
    const p = sessionPayload(session, seats, new Map([['echo-1', [0, 1]]]), cfg, new Date(1));
    const json = JSON.stringify(p);
    for (const secret of ['account-1', 'account-2', 'seat-member', 'echo-1']) expect(json).not.toContain(secret);
    expect(p.seats).toEqual([
      { seat: 1, kind: 'human', label: 'Quiet Comet' },
      { seat: 2, kind: 'echo', label: null }, // left: dims into an echo, no "left" anywhere
      { seat: 3, kind: 'echo', label: null, trace: [0, 1] },
      { seat: 4, kind: 'guide', label: null },
    ]);
    expect(JSON.stringify(p.seats)).not.toMatch(/left|failed|disconnect/i);
    expect({ humans: p.humans, echoes: p.echoes, guides: p.guides }).toEqual({ humans: 2, echoes: 1, guides: 1 });
  });
});
