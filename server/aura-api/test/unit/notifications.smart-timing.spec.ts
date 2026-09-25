import { decide, ignoredSoFar, SMART_TIMING, smartTimingSkip, type DeliveryFacts } from '../../src/notifications/policy';
import { prefsFromRow } from '../../src/notifications/notification-prefs';

/** PRD 12 rule 7 "Smart timing": 5 ignored → every other day; 14 → stop; any check-in restores the schedule. */
describe('daily reminder smart timing (rule 7)', () => {
  it('counts ignored reminders in a row; any check-in after the last one resets it', () => {
    expect(ignoredSoFar(0, null, false)).toBe(0); // nothing sent yet
    expect(ignoredSoFar(0, new Date('2026-10-08T14:30:00Z'), false)).toBe(1);
    expect(ignoredSoFar(6, new Date('2026-10-08T14:30:00Z'), false)).toBe(7);
    expect(ignoredSoFar(13, new Date('2026-10-08T14:30:00Z'), true)).toBe(0); // a check-in restores it
  });

  it('daily below 5; every other day from 5; stopped from 14', () => {
    const f = (reminderIgnored: number, reminderSentYesterday: boolean) =>
      smartTimingSkip({ type: 'daily_reminder', reminderIgnored, reminderSentYesterday });
    expect(f(4, true)).toBeNull();
    expect(f(SMART_TIMING.everyOtherDayFrom, true)).toBe('reminder_backoff');
    expect(f(SMART_TIMING.everyOtherDayFrom, false)).toBeNull(); // the "other" day
    expect(f(13, false)).toBeNull();
    expect(f(SMART_TIMING.stopFrom, false)).toBe('reminder_paused');
    expect(f(40, true)).toBe('reminder_paused');
  });

  it('only the daily reminder backs off', () => {
    expect(smartTimingSkip({ type: 'capsule_unlocked', reminderIgnored: 30, reminderSentYesterday: true })).toBeNull();
    expect(smartTimingSkip({ type: 'daily_reminder' })).toBeNull(); // unknown history: send
  });

  it('decide(): a checked-in day still skips as checked_in first; otherwise the back-off applies', () => {
    const base: DeliveryFacts = {
      type: 'daily_reminder',
      now: new Date('2026-10-09T14:30:00Z'),
      createdAt: new Date('2026-10-09T14:30:00Z'),
      tz: 'Asia/Kolkata',
      prefs: { ...prefsFromRow(undefined).values, enabled: true, reminderEnabled: true, reminderTime: '20:00' },
      pendingDeletion: false,
      devices: 1,
      sentToday: [],
      expectedLater: [],
      checkedInToday: false,
      reminderIgnored: 5,
      reminderSentYesterday: true,
    };
    expect(decide(base)).toEqual({ action: 'skip', reason: 'reminder_backoff' });
    expect(decide({ ...base, checkedInToday: true })).toEqual({ action: 'skip', reason: 'checked_in' });
    expect(decide({ ...base, reminderSentYesterday: false })).toEqual({ action: 'send' });
    expect(decide({ ...base, reminderIgnored: 14, reminderSentYesterday: false })).toEqual({ action: 'skip', reason: 'reminder_paused' });
  });
});
