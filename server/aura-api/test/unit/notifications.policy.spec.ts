/**
 * F14 global rules as pure functions (src/notifications/policy.ts, PRD 12-notifications): quiet hours (incl. the
 * user-scheduled exception), the 2/day cap with precedence (REQ-NTF-02), toggles, pending deletion, and the
 * daily-reminder planning helpers.
 */
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { capsuleNoticeId, collapseKeyFor, DAILY_PUSH_CAP, higherThan, PRECEDENCE } from '../../src/notifications/catalogue';
import {
  auraDayOf,
  capBudget,
  decide,
  DEFAULT_NOTIFICATION_PREFS,
  endOfAuraDay,
  inQuietHours,
  nextReminderAt,
  nextWallTime,
  reservedSlots,
  type DeliveryFacts,
  type NotificationPrefsValues,
} from '../../src/notifications/policy';

const IST = 'Asia/Kolkata';
const at = (day: string, hh: number, mm = 0, tz = IST): Date => zonedInstant(day, hh, mm, tz);
const DAY = '2026-10-08';
const H = 3600_000;

const prefs = (over: Partial<NotificationPrefsValues> = {}): NotificationPrefsValues => ({
  ...DEFAULT_NOTIFICATION_PREFS,
  reminderEnabled: true,
  reminderTime: '20:00',
  ...over,
});

const facts = (over: Partial<DeliveryFacts> = {}): DeliveryFacts => {
  const now = over.now ?? at(DAY, 20);
  return {
    type: 'daily_reminder',
    now,
    createdAt: now,
    tz: IST,
    prefs: prefs(),
    pendingDeletion: false,
    devices: 1,
    sentToday: [],
    expectedLater: [],
    checkedInToday: false,
    capsuleSealed: true,
    ...over,
  };
};

describe('quiet hours (rule 1)', () => {
  it('the default window 23:00–08:00 wraps midnight: [start, end)', () => {
    const q = (hh: number, mm = 0) => inQuietHours(at(DAY, hh, mm), IST, '23:00', '08:00');
    expect(q(22, 59)).toBe(false);
    expect(q(23, 0)).toBe(true);
    expect(q(2, 0)).toBe(true);
    expect(q(7, 59)).toBe(true);
    expect(q(8, 0)).toBe(false);
    expect(q(20, 0)).toBe(false);
  });

  it('a daytime window (night-shift sleeper) and an empty window (start = end → none)', () => {
    expect(inQuietHours(at(DAY, 10), IST, '08:00', '16:00')).toBe(true);
    expect(inQuietHours(at(DAY, 16), IST, '08:00', '16:00')).toBe(false);
    for (const hh of [0, 8, 12, 23]) expect(inQuietHours(at(DAY, hh), IST, '22:00', '22:00')).toBe(false);
  });

  it('is judged on the wall clock of the profile zone', () => {
    const instant = at(DAY, 23, 30); // 23:30 IST = 14:00 in New York
    expect(inQuietHours(instant, IST, '23:00', '08:00')).toBe(true);
    expect(inQuietHours(instant, 'America/New_York', '23:00', '08:00')).toBe(false);
  });

  it('a system push inside quiet hours: the capsule waits for their end, the reminder is skipped', () => {
    const ten = at(DAY, 10);
    const capsule = decide(facts({ type: 'capsule_unlocked', now: ten, prefs: prefs({ quietStart: '22:00', quietEnd: '11:00' }) }));
    expect(capsule).toEqual({ action: 'defer', until: at(DAY, 11) });
    expect(decide(facts({ now: at(DAY, 23, 30), prefs: prefs({ reminderTime: '23:30' }) }))).toEqual({ action: 'skip', reason: 'quiet_hours' });
  });

  it('REQ-NTF-02 negative: no system push fires 23:00–08:00 — unless the user scheduled the reminder there', () => {
    for (const hh of [23, 0, 3, 7]) {
      const now = at(hh === 23 ? DAY : '2026-10-09', hh, 30);
      expect(decide(facts({ type: 'capsule_unlocked', now })).action).not.toBe('send');
      expect(decide(facts({ now, prefs: prefs({ reminderTime: `${String(hh).padStart(2, '0')}:30` }) })).action).toBe('skip');
      // the one-time confirmation in the app: a night-shift reminder is honoured
      expect(decide(facts({ now, prefs: prefs({ reminderTime: `${String(hh).padStart(2, '0')}:30`, reminderInQuietHours: true }) }))).toEqual({
        action: 'send',
      });
    }
  });

  it('the user-scheduled exception is the reminder only (never a capsule push)', () => {
    const now = at('2026-10-09', 2);
    const d = decide(facts({ type: 'capsule_unlocked', now, prefs: prefs({ reminderInQuietHours: true }) }));
    expect(d).toEqual({ action: 'defer', until: at('2026-10-09', 8) });
  });

  it('a deferral that would outlive the push (capsule > 26 h after its request) is dropped instead', () => {
    const now = at('2026-10-09', 2);
    const d = decide(facts({ type: 'capsule_unlocked', now, createdAt: new Date(now.getTime() - 22 * H) }));
    expect(d).toEqual({ action: 'skip', reason: 'quiet_hours' });
  });
});

describe('daily cap with precedence (rule 2, REQ-NTF-02)', () => {
  it('a third push in one local day is never sent', () => {
    const sent = ['daily_reminder', 'gestures_received'];
    expect(decide(facts({ type: 'capsule_unlocked', now: at(DAY, 21), sentToday: sent }))).toEqual({ action: 'skip', reason: 'capped' });
    expect(DAILY_PUSH_CAP).toBe(2);
  });

  it('two different types in a day are fine (capsule at 10:00, reminder at 20:00)', () => {
    expect(decide(facts({ type: 'capsule_unlocked', now: at(DAY, 10) }))).toEqual({ action: 'send' });
    expect(decide(facts({ now: at(DAY, 20), sentToday: ['capsule_unlocked'] }))).toEqual({ action: 'send' });
  });

  it('precedence: a lower push yields its slot to a higher one still expected later today', () => {
    // one push already out; a capsule unlock is due later today → the reminder would take the last slot: dropped
    expect(decide(facts({ sentToday: ['gestures_received'], expectedLater: ['capsule_unlocked'] }))).toEqual({
      action: 'skip',
      reason: 'capped',
    });
    // nothing else sent yet: both fit
    expect(decide(facts({ expectedLater: ['capsule_unlocked'] }))).toEqual({ action: 'send' });
    // the higher push already went out: its slot is not kept twice
    expect(decide(facts({ sentToday: ['capsule_unlocked'], expectedLater: ['capsule_unlocked'] }))).toEqual({ action: 'send' });
    // lower-priority expectations never hold a slot against a higher push
    expect(decide(facts({ type: 'capsule_unlocked', now: at(DAY, 10), sentToday: ['gestures_received'], expectedLater: ['daily_reminder'] }))).toEqual({
      action: 'send',
    });
  });

  it('the precedence order is the PRD one', () => {
    expect(PRECEDENCE).toEqual([
      'capsule_unlocked',
      'daily_reminder',
      'gestures_received',
      'lantern_hour',
      'wind_down_reminder',
      'habit_nudge',
      'welcome_back',
    ]);
    expect(higherThan('daily_reminder')).toEqual(['capsule_unlocked']);
    expect(higherThan('capsule_unlocked')).toEqual([]);
    expect(reservedSlots('lantern_hour', ['capsule_unlocked'], ['capsule_unlocked', 'daily_reminder', 'habit_nudge'])).toBe(1);
    expect(capBudget('daily_reminder', [], [])).toBe(2);
    expect(capBudget('daily_reminder', ['gestures_received'], ['capsule_unlocked'])).toBe(0);
  });

  it('each type at most once per Aura day (per-type cap = catalogue "1/day")', () => {
    expect(decide(facts({ sentToday: ['daily_reminder'] }))).toEqual({ action: 'skip', reason: 'already_sent' });
    expect(decide(facts({ type: 'capsule_unlocked', now: at(DAY, 10), sentToday: ['capsule_unlocked'] }))).toEqual({
      action: 'skip',
      reason: 'already_sent',
    });
  });
});

describe('toggles, account state and freshness', () => {
  it('the master switch and the per-type toggles (rule 8)', () => {
    expect(decide(facts({ prefs: prefs({ enabled: false }) }))).toEqual({ action: 'skip', reason: 'disabled' });
    expect(decide(facts({ prefs: prefs({ reminderEnabled: false }) }))).toEqual({ action: 'skip', reason: 'type_disabled' });
    expect(decide(facts({ prefs: prefs({ reminderTime: null }) }))).toEqual({ action: 'skip', reason: 'type_disabled' });
    expect(decide(facts({ type: 'capsule_unlocked', now: at(DAY, 10), prefs: prefs({ capsuleUnlocked: false }) }))).toEqual({
      action: 'skip',
      reason: 'type_disabled',
    });
    // the capsule push doesn't need the reminder
    expect(decide(facts({ type: 'capsule_unlocked', now: at(DAY, 10), prefs: { ...DEFAULT_NOTIFICATION_PREFS } }))).toEqual({ action: 'send' });
  });

  it('never to an account with a scheduled deletion, a signed-out account (no token) or one without a profile', () => {
    expect(decide(facts({ pendingDeletion: true }))).toEqual({ action: 'skip', reason: 'pending_deletion' });
    expect(decide(facts({ devices: 0 }))).toEqual({ action: 'skip', reason: 'no_device' });
    expect(decide(facts({ tz: null }))).toEqual({ action: 'skip', reason: 'no_profile' });
  });

  it('the reminder is skipped once the user checked in that Aura day; a capsule push only while sealed', () => {
    expect(decide(facts({ checkedInToday: true }))).toEqual({ action: 'skip', reason: 'checked_in' });
    expect(decide(facts({ type: 'capsule_unlocked', now: at(DAY, 10), capsuleSealed: false }))).toEqual({
      action: 'skip',
      reason: 'not_sealed',
    });
  });

  it('stale pushes are dropped (reminder > 2 h, capsule > 26 h after the request)', () => {
    const now = at(DAY, 20);
    expect(decide(facts({ now, createdAt: new Date(now.getTime() - 2 * H - 1) }))).toEqual({ action: 'skip', reason: 'expired' });
    expect(decide(facts({ now, createdAt: new Date(now.getTime() - 2 * H) }))).toEqual({ action: 'send' });
    const ten = at(DAY, 10);
    expect(decide(facts({ type: 'capsule_unlocked', now: ten, createdAt: new Date(ten.getTime() - 27 * H) }))).toEqual({
      action: 'skip',
      reason: 'expired',
    });
  });
});

describe('reminder planning', () => {
  it('the next reminder is strictly after now, in the given zone', () => {
    expect(nextReminderAt(at(DAY, 19, 59), IST, prefs())).toEqual(at(DAY, 20));
    expect(nextReminderAt(at(DAY, 20), IST, prefs())).toEqual(at('2026-10-09', 20));
    expect(nextReminderAt(at(DAY, 20), 'America/New_York', prefs())).toEqual(at(DAY, 20, 0, 'America/New_York'));
    expect(nextReminderAt(at(DAY, 12), IST, prefs({ reminderEnabled: false }))).toBeNull();
    expect(nextReminderAt(at(DAY, 12), IST, prefs({ enabled: false }))).toBeNull();
    expect(nextReminderAt(at(DAY, 12), IST, prefs({ reminderTime: null }))).toBeNull();
  });

  it('DST: a wall time inside the spring-forward gap moves forward by the gap; the next day is back to normal', () => {
    const ny = 'America/New_York';
    const beforeGap = new Date('2027-03-14T05:00:00Z'); // 00:00 EST, DST starts at 02:00
    expect(nextWallTime(beforeGap, ny, '02:30').toISOString()).toBe('2027-03-14T07:30:00.000Z'); // 03:30 EDT
    expect(nextWallTime(new Date('2027-03-14T08:00:00Z'), ny, '02:30').toISOString()).toBe('2027-03-15T06:30:00.000Z');
  });

  it('the cap counts per Aura day (04:00 rollover), which ends at the next 04:00 local', () => {
    expect(auraDayOf(at('2026-10-09', 3, 59), IST)).toBe(DAY);
    expect(auraDayOf(at('2026-10-09', 4), IST)).toBe('2026-10-09');
    expect(endOfAuraDay(at(DAY, 20), IST)).toEqual(at('2026-10-09', 4));
    expect(endOfAuraDay(at('2026-10-09', 2), IST)).toEqual(at('2026-10-09', 4));
  });
});

describe('collapse keys (shared with the app)', () => {
  it("a capsule's key is the app's local notice id for its unlock date: 0x18000000 + days since 1970", () => {
    expect(capsuleNoticeId('1970-01-01')).toBe(0x18000000);
    expect(capsuleNoticeId('2027-10-08')).toBe(0x18000000 + Date.UTC(2027, 9, 8) / 86_400_000);
    expect(capsuleNoticeId('2027-10-09') - capsuleNoticeId('2027-10-08')).toBe(1);
    expect(capsuleNoticeId('2031-10-08')).toBeLessThan(0x7fffffff);
    expect(collapseKeyFor('capsule_unlocked', '2027-10-08')).toBe(String(capsuleNoticeId('2027-10-08')));
    expect(collapseKeyFor('capsule_unlocked', null)).toBe('capsule_unlocked');
    expect(collapseKeyFor('daily_reminder')).toBe('daily_reminder');
    expect(() => capsuleNoticeId('8 Oct')).toThrow(TypeError);
  });
});
