/**
 * RULES.md §9 edge cases beyond contracts/rules/vectors/capsules.json (which runs in rules.vectors.spec.ts):
 * DST gap / overlap semantics of the unlock instant, addYears, arming and cooldown arithmetic.
 */
import {
  addYears,
  armedAtFor,
  cooldownUntilFor,
  globalCooldownUntil,
  isValidUnlockDate,
  pickTrigger,
  TRIGGER_ARMING_MS,
  TRIGGER_COOLDOWN_MS,
  unlockAt,
  unlockWindow,
  zonedInstant,
  type TriggerCapsule,
} from '../../src/capsules/capsule-rules';

describe('capsule rules (RULES.md §9)', () => {
  describe('addYears', () => {
    it.each([
      ['2026-10-08', 5, '2031-10-08'],
      ['2028-02-29', 5, '2033-02-28'],
      ['2028-02-29', 4, '2032-02-29'],
      ['2026-12-31', 1, '2027-12-31'],
      ['2026-01-31', 0, '2026-01-31'],
    ])('%s + %i years = %s', (day, n, expected) => expect(addYears(day, n)).toBe(expected));

    it('rejects a malformed day', () => expect(() => addYears('2026-02-30', 1)).toThrow(RangeError));
  });

  it('the window is inclusive and measured from the calendar date in the seal zone', () => {
    expect(unlockWindow('2026-10-08T18:00:00+05:30', 'Asia/Kolkata')).toEqual({ min: '2026-10-15', max: '2031-10-08' });
    // 23:30 in New York on 8 Oct is already 9 Oct in UTC: the device zone decides.
    expect(unlockWindow('2026-10-09T03:30:00Z', 'America/New_York')).toEqual({ min: '2026-10-15', max: '2031-10-08' });
    expect(unlockWindow('2026-10-09T03:30:00Z', 'UTC')).toEqual({ min: '2026-10-16', max: '2031-10-09' });
    expect(isValidUnlockDate('2026-10-08T18:00:00+05:30', 'Asia/Kolkata', 'not-a-date')).toBe(false);
  });

  describe('unlockAt / zonedInstant', () => {
    it('10:00 on ordinary days in several zones', () => {
      expect(unlockAt('2027-10-08', 'Asia/Kolkata').toISOString()).toBe('2027-10-08T04:30:00.000Z');
      expect(unlockAt('2027-10-08', 'UTC').toISOString()).toBe('2027-10-08T10:00:00.000Z');
      expect(unlockAt('2027-10-08', 'Asia/Tokyo').toISOString()).toBe('2027-10-08T01:00:00.000Z');
    });

    it('a wall time inside a DST gap is shifted forward by the gap (Temporal "compatible")', () => {
      // New York springs forward at 02:00 → 03:00 on 14 Mar 2027: 02:30 does not exist → 03:30 EDT.
      expect(zonedInstant('2027-03-14', 2, 30, 'America/New_York').toISOString()).toBe('2027-03-14T07:30:00.000Z');
    });

    it('a wall time that occurs twice (DST fall-back) resolves to the earlier instant', () => {
      // New York falls back at 02:00 → 01:00 on 1 Nov 2026: 01:30 happens in EDT (05:30Z) and EST (06:30Z).
      expect(zonedInstant('2026-11-01', 1, 30, 'America/New_York').toISOString()).toBe('2026-11-01T05:30:00.000Z');
    });

    it('moving zones moves the unlock to 10:00 in the new zone', () => {
      const ist = unlockAt('2027-10-08', 'Asia/Kolkata').getTime();
      const ny = unlockAt('2027-10-08', 'America/New_York').getTime();
      expect((ny - ist) / 3600_000).toBe(9.5); // west → later instant
    });
  });

  it('arming is 24 h and the cooldown 168 h, both absolute', () => {
    expect(TRIGGER_ARMING_MS).toBe(24 * 3600_000);
    expect(TRIGGER_COOLDOWN_MS).toBe(7 * 24 * 3600_000);
    expect(armedAtFor('2026-10-05T18:00:00+05:30').toISOString()).toBe('2026-10-06T12:30:00.000Z');
    // Across the New York fall-back the cooldown ends at 08:00 local, not 09:00: 168 real hours.
    expect(cooldownUntilFor('2026-10-30T13:00:00Z').toISOString()).toBe('2026-11-06T13:00:00.000Z');
  });

  it('globalCooldownUntil takes the latest cooldown over all rows, tombstones included', () => {
    const rows: TriggerCapsule[] = [
      { id: 'a', unlockType: 'mood', sealedAt: '2026-01-01T00:00:00Z', cooldownUntil: '2026-10-10T00:00:00Z' },
      { id: 'b', unlockType: 'mood', sealedAt: '2026-01-01T00:00:00Z', deletedAt: '2026-10-05T00:00:00Z', cooldownUntil: '2026-10-12T00:00:00Z' },
      { id: 'c', unlockType: 'date', sealedAt: '2026-01-01T00:00:00Z' },
    ];
    expect(globalCooldownUntil(rows)).toBe(Date.parse('2026-10-12T00:00:00Z'));
    expect(globalCooldownUntil([])).toBeNull();
  });

  it('instants compare as instants, whatever the offsets', () => {
    const capsule: TriggerCapsule = {
      id: 'x',
      unlockType: 'mood',
      triggerQuadrant: 'storm',
      sealedAt: '2026-10-05T18:00:00+05:30',
      armedAt: '2026-10-06T18:00:00+05:30', // = 12:30Z
    };
    const at = (deviceTs: string) =>
      pickTrigger([capsule], { moodId: 'anxious', quadrant: 'storm', deviceTs, live: true, crisis: false }).fire;
    expect(at('2026-10-06T08:29:00-04:00')).toBeNull(); // 12:29Z
    expect(at('2026-10-06T08:30:00-04:00')).toBe('x'); // 12:30Z
  });
});
