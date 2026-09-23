/**
 * Timezone regions by UTC offset, Lantern Hour 21:00–23:00 on each region clock incl. DST (REQ-ROOM-11), and the
 * room state machine (PRD F5 state diagram).
 */
import { isLanternHour, lanternWindow, regionForOffset, regionForTimeZone, utcOffsetMinutes, zonedInstant } from '../../src/rooms/regions';
import { deriveRoomState } from '../../src/rooms/room-state';

describe('regions by UTC offset', () => {
  it.each([
    [-600, 'americas'], // Honolulu
    [-300, 'americas'], // Chicago (CDT)
    [-150, 'americas'], // St John's (NDT −2:30)
    [-120, 'europe_africa'], // −2:00
    [0, 'europe_africa'],
    [60, 'europe_africa'],
    [180, 'europe_africa'], // Moscow, Nairobi
    [210, 'south_asia'], // Tehran +3:30
    [240, 'south_asia'], // Dubai (Gulf)
    [330, 'south_asia'], // IST
    [345, 'south_asia'], // Kathmandu
    [390, 'south_asia'], // Yangon +6:30
    [420, 'east_asia_pacific'], // Bangkok
    [540, 'east_asia_pacific'], // Tokyo
    [840, 'east_asia_pacific'], // Kiritimati +14
  ])('%i min → %s', (offset, region) => {
    expect(regionForOffset(offset)).toBe(region);
  });

  it('uses the offset NOW (DST-aware)', () => {
    expect(utcOffsetMinutes('America/Chicago', new Date('2026-07-01T12:00:00Z'))).toBe(-300);
    expect(utcOffsetMinutes('America/Chicago', new Date('2026-12-01T12:00:00Z'))).toBe(-360);
    expect(utcOffsetMinutes('Asia/Kolkata', new Date('2026-10-08T12:00:00Z'))).toBe(330);
    expect(regionForTimeZone('Europe/London', new Date('2026-07-01T12:00:00Z'))).toBe('europe_africa');
    expect(regionForTimeZone('Asia/Dubai', new Date('2026-07-01T12:00:00Z'))).toBe('south_asia');
    expect(regionForTimeZone('Australia/Sydney', new Date('2026-07-01T12:00:00Z'))).toBe('east_asia_pacific');
  });

  it('zonedInstant maps a wall-clock time to the right instant across DST', () => {
    expect(zonedInstant('America/Chicago', '2026-10-31', 21, 0).toISOString()).toBe('2026-11-01T02:00:00.000Z'); // CDT
    expect(zonedInstant('America/Chicago', '2026-11-01', 21, 0).toISOString()).toBe('2026-11-02T03:00:00.000Z'); // CST (DST ended that morning)
    expect(zonedInstant('Europe/Berlin', '2026-10-24', 21, 0).toISOString()).toBe('2026-10-24T19:00:00.000Z'); // CEST
    expect(zonedInstant('Europe/Berlin', '2026-10-25', 21, 0).toISOString()).toBe('2026-10-25T20:00:00.000Z'); // CET
    expect(zonedInstant('America/Chicago', '2027-03-14', 21, 0).toISOString()).toBe('2027-03-15T02:00:00.000Z'); // CDT again
  });
});

describe('Lantern Hour on the region clock', () => {
  it('south_asia runs 21:00–23:00 IST: start inclusive, end exclusive, never outside', () => {
    const at = (iso: string) => lanternWindow('south_asia', new Date(iso));
    expect(at('2026-10-08T15:29:59Z').active).toBe(false); // 20:59:59 IST
    expect(at('2026-10-08T15:30:00Z').active).toBe(true); // 21:00 IST
    expect(at('2026-10-08T17:29:59Z').active).toBe(true); // 22:59:59
    expect(at('2026-10-08T17:30:00Z').active).toBe(false); // 23:00
    const w = at('2026-10-08T16:00:00Z');
    expect(w).toEqual({
      timezone: 'Asia/Kolkata',
      active: true,
      startsAt: new Date('2026-10-08T15:30:00Z'),
      endsAt: new Date('2026-10-08T17:30:00Z'),
    });
  });

  it('before the window → today’s window is next; after it → tomorrow’s', () => {
    const before = lanternWindow('south_asia', new Date('2026-10-08T06:00:00Z'));
    expect(before).toMatchObject({ active: false, startsAt: new Date('2026-10-08T15:30:00Z') });
    const after = lanternWindow('south_asia', new Date('2026-10-08T18:00:00Z'));
    expect(after).toMatchObject({ active: false, startsAt: new Date('2026-10-09T15:30:00Z'), endsAt: new Date('2026-10-09T17:30:00Z') });
  });

  it('americas follows America/Chicago including DST (REQ-ROOM-11)', () => {
    // Summer (CDT, UTC−5): 21:00 = 02:00Z next day.
    expect(isLanternHour('americas', new Date('2026-07-02T02:30:00Z'))).toBe(true);
    expect(isLanternHour('americas', new Date('2026-07-02T03:30:00Z'))).toBe(true);
    expect(isLanternHour('americas', new Date('2026-07-02T04:00:00Z'))).toBe(false); // 23:00 CDT
    // Winter (CST, UTC−6): 02:30Z is 20:30 local → not yet.
    expect(isLanternHour('americas', new Date('2026-12-02T02:30:00Z'))).toBe(false);
    expect(isLanternHour('americas', new Date('2026-12-02T03:00:00Z'))).toBe(true);
    // The day DST ends (Sun 1 Nov 2026): the window is 03:00Z–05:00Z on 2 Nov.
    const w = lanternWindow('americas', new Date('2026-11-02T02:30:00Z'));
    expect(w).toEqual({
      timezone: 'America/Chicago',
      active: false,
      startsAt: new Date('2026-11-02T03:00:00Z'),
      endsAt: new Date('2026-11-02T05:00:00Z'),
    });
    expect(lanternWindow('americas', new Date('2026-11-02T04:59:59Z')).active).toBe(true);
    expect(lanternWindow('americas', new Date('2026-11-02T05:00:00Z')).active).toBe(false);
  });

  it('europe_africa follows Europe/Berlin across the October switch', () => {
    expect(isLanternHour('europe_africa', new Date('2026-10-24T19:00:00Z'))).toBe(true); // 21:00 CEST
    expect(isLanternHour('europe_africa', new Date('2026-10-25T19:30:00Z'))).toBe(false); // 20:30 CET
    expect(isLanternHour('europe_africa', new Date('2026-10-25T20:00:00Z'))).toBe(true); // 21:00 CET
  });

  it('east_asia_pacific follows Asia/Tokyo (no DST)', () => {
    expect(lanternWindow('east_asia_pacific', new Date('2026-10-08T12:30:00Z'))).toMatchObject({
      active: true,
      startsAt: new Date('2026-10-08T12:00:00Z'),
      endsAt: new Date('2026-10-08T14:00:00Z'),
    });
  });

  it('window maths and the wall-clock check always agree', () => {
    for (const region of ['americas', 'europe_africa', 'south_asia', 'east_asia_pacific'] as const) {
      for (let t = Date.parse('2026-10-20T00:00:00Z'); t < Date.parse('2026-11-05T00:00:00Z'); t += 7 * 60_000) {
        const now = new Date(t);
        expect(lanternWindow(region, now).active).toBe(isLanternHour(region, now));
      }
    }
  });

  it('configurable window (matching_config.lantern_start / lantern_end)', () => {
    const w = lanternWindow('south_asia', new Date('2026-10-08T15:00:00Z'), { hour: 20, minute: 30 }, { hour: 22, minute: 0 });
    expect(w).toMatchObject({ active: true, startsAt: new Date('2026-10-08T15:00:00Z'), endsAt: new Date('2026-10-08T16:30:00Z') });
  });
});

describe('room state machine', () => {
  const created = new Date('2026-10-08T10:00:00Z');
  const h = (n: number) => new Date(created.getTime() + n * 3_600_000);
  const clock = { openedAt: null as Date | null, joinsCloseAt: h(20), memoryAt: h(24), purgeAt: h(24 + 7 * 24) };

  it('forming → open (2nd member) ⇄ lantern_hour → closing (20 h) → memory (24 h) → purged (24 h + 7 d)', () => {
    expect(deriveRoomState(clock, h(1), false)).toBe('forming');
    expect(deriveRoomState(clock, h(1), true)).toBe('forming'); // Lantern Hour is for open rooms
    const opened = { ...clock, openedAt: h(2) };
    expect(deriveRoomState(opened, h(3), false)).toBe('open');
    expect(deriveRoomState(opened, h(3), true)).toBe('lantern_hour');
    expect(deriveRoomState(opened, h(20), true)).toBe('closing'); // no joins after 20 h, even in Lantern Hour
    expect(deriveRoomState(clock, h(20), false)).toBe('closing'); // forming → closing too
    expect(deriveRoomState(opened, h(24), false)).toBe('memory');
    expect(deriveRoomState(opened, h(24 + 7 * 24) , false)).toBe('purged');
    expect(deriveRoomState(opened, new Date(h(24).getTime() - 1), false)).toBe('closing');
  });
});
