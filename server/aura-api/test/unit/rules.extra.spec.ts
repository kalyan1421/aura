/** Edge cases beyond the shared vectors: DST, odd offsets, incremental awards, fold idempotence. */
import {
  addDays,
  applyAward,
  auraDay,
  awardFor,
  daysBetween,
  emptyDayState,
  foldStreak,
  initialStreak,
  isEligible,
  isLocalDay,
  isValidTimeZone,
  localDate,
  starlightAwards,
  type StarlightEvent,
} from '../../src/rules';

describe('auraDay across DST', () => {
  const ny = 'America/New_York';
  it.each([
    // spring forward 2026-03-08 02:00 EST → 03:00 EDT
    ['2026-03-08T07:30:00Z', '2026-03-07'], // 03:30 EDT → 23:30 prev day
    ['2026-03-08T07:59:59Z', '2026-03-07'], // 03:59:59 EDT
    ['2026-03-08T08:00:00Z', '2026-03-08'], // 04:00 EDT
    // fall back 2026-11-01 02:00 EDT → 01:00 EST
    ['2026-11-01T05:30:00Z', '2026-10-31'], // 01:30 EDT (first)
    ['2026-11-01T06:30:00Z', '2026-10-31'], // 01:30 EST (second)
    ['2026-11-01T08:59:59Z', '2026-10-31'], // 03:59:59 EST
    ['2026-11-01T09:00:00Z', '2026-11-01'], // 04:00 EST
  ])('%s → %s', (utc, expected) => expect(auraDay(utc, ny)).toBe(expected));

  it('London BST end', () => {
    expect(auraDay('2026-10-25T02:59:59Z', 'Europe/London')).toBe('2026-10-24'); // 02:59:59 GMT
    expect(auraDay('2026-10-25T04:00:00Z', 'Europe/London')).toBe('2026-10-25'); // 04:00 GMT
  });

  it('quarter-hour and +13 offsets', () => {
    expect(auraDay('2026-10-07T22:14:59Z', 'Asia/Kathmandu')).toBe('2026-10-07'); // 03:59:59 +05:45
    expect(auraDay('2026-10-07T22:15:00Z', 'Asia/Kathmandu')).toBe('2026-10-08'); // 04:00
    expect(auraDay('2026-10-07T15:00:00Z', 'Pacific/Tongatapu')).toBe('2026-10-08'); // 04:00 +13
  });

  it('crosses month and year boundaries', () => {
    expect(auraDay('2027-01-01T01:00:00Z', 'UTC')).toBe('2026-12-31');
    expect(auraDay('2026-03-01T03:00:00Z', 'UTC')).toBe('2026-02-28');
  });

  it('localDate has no rollover', () => {
    expect(localDate('2026-10-07T20:00:00Z', 'Asia/Kolkata')).toBe('2026-10-08');
  });
});

describe('date helpers', () => {
  it('validates days and time zones', () => {
    expect(isLocalDay('2026-02-29')).toBe(false);
    expect(isLocalDay('2028-02-29')).toBe(true);
    expect(isLocalDay('2026-1-01')).toBe(false);
    expect(isValidTimeZone('Asia/Kolkata')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus')).toBe(false);
    expect(isValidTimeZone('')).toBe(false);
  });
  it('day arithmetic', () => {
    expect(daysBetween('2026-10-05', '2026-10-08')).toBe(3);
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
  });
});

describe('eligibility edges', () => {
  const base = { tz: 'Asia/Kolkata', localDay: '2026-10-08' };
  it('exactly +5 min is ok, exactly 30 days is ok', () => {
    expect(isEligible({ ...base, deviceTs: '2026-10-08T10:05:00Z', serverNow: '2026-10-08T10:00:00Z' })).toBe(true);
    expect(isEligible({ ...base, deviceTs: '2026-10-08T10:00:00Z', serverNow: '2026-11-07T10:00:00Z' })).toBe(true);
    expect(isEligible({ ...base, deviceTs: '2026-10-08T10:00:00Z', serverNow: '2026-11-07T10:00:01Z' })).toBe(false);
  });
  it('garbage timestamps are ineligible', () => {
    expect(isEligible({ ...base, deviceTs: 'nope', serverNow: '2026-10-08T10:00:00Z' })).toBe(false);
  });
});

describe('incremental awards match the batch fold', () => {
  it('awardFor/applyAward reproduce starlightAwards', () => {
    const events: StarlightEvent[] = [
      { type: 'habit', habitId: 'a' },
      { type: 'checkin', eligible: false },
      { type: 'checkin' },
      { type: 'habit', habitId: 'a' },
      ...Array.from({ length: 12 }, (_, i): StarlightEvent => ({ type: 'habit', habitId: `h${i}` })),
      { type: 'checkin' },
    ];
    let s = emptyDayState();
    const inc = events.map((e) => {
      const a = awardFor(s, e);
      s = applyAward(s, e, a);
      return a;
    });
    expect(inc).toEqual(starlightAwards(events));
    expect(s.total).toBe(60);
  });
  it('day total is order independent', () => {
    const evs: StarlightEvent[] = [
      { type: 'checkin' },
      { type: 'checkin' },
      ...Array.from({ length: 11 }, (_, i): StarlightEvent => ({ type: 'habit', habitId: `h${i}` })),
    ];
    const sum = (xs: number[]): number => xs.reduce((a, b) => a + b, 0);
    expect(sum(starlightAwards(evs))).toBe(sum(starlightAwards([...evs].reverse())));
  });
});

describe('foldStreak', () => {
  it('re-folding already-folded days is a no-op', () => {
    const s1 = foldStreak(initialStreak(), ['2026-10-05', '2026-10-06']);
    expect(foldStreak(s1, ['2026-10-05', '2026-10-06'])).toEqual(s1);
    expect(foldStreak(s1, ['2026-10-07'])).toEqual(foldStreak(initialStreak(), ['2026-10-05', '2026-10-06', '2026-10-07']));
  });
  it('does not mutate the initial state', () => {
    const init = initialStreak();
    foldStreak(init, ['2026-10-05']);
    expect(init).toEqual(initialStreak());
  });
});
