import { zonedInstant } from '../capsules/capsule-rules';
import { addDays, auraDay, localDate, ROLLOVER_HOUR, wallClock } from '../rules';
import { CAP_EXEMPT, DAILY_PUSH_CAP, priorityOf, TYPE_RULES } from './catalogue';
import type { NotificationType } from './notification-types';
import type { TrialEndingFacts } from './trial-ending';

/**
 * The global push rules (PRD 12-notifications) as pure functions — the worker's delivery path feeds them facts read
 * from the DB, so every rule is unit-testable without one:
 *   1. quiet hours (default 23:00–08:00 local, editable); a daily reminder the user confirmed inside them is honoured;
 *   2. at most 2 pushes per local (Aura) day across types, precedence capsule unlocked > daily reminder > …;
 *   4. discreet mode (rendering, push-copy.ts); 8. per-type toggles + a master switch;
 *   plus: never to an account with a scheduled deletion or to signed-out installs (no token), the daily reminder is
 *   skipped once the user checked in that Aura day, a capsule push only while the capsule is still sealed, the
 *   pool-open push only while the pool is still open (and, capped, it waits for the next day instead of dropping).
 */

/** A user's effective settings (`public.notification_prefs`, or these defaults when there is no row). */
export interface NotificationPrefsValues {
  enabled: boolean;
  reminderEnabled: boolean;
  /** `HH:MM`, local time in the profile zone; null = never picked. */
  reminderTime: string | null;
  /** One-time confirmation: send the reminder even though its time is inside quiet hours. */
  reminderInQuietHours: boolean;
  capsuleUnlocked: boolean;
  quietStart: string;
  quietEnd: string;
  discreet: boolean;
  // ---- Milestone B (contracts/api/v1-notifications.md §6) ----
  /** "Gestures received" (batched, 1 per room per day). */
  gestures: boolean;
  /** Lantern Hour (opt-in): when the timezone region's Lantern Hour starts. Column `lantern_opt_in`. */
  lanternHour: boolean;
  /** Wind-down reminder (opt-in, REQ-NTF-04): off until a time is picked. */
  windDownEnabled: boolean;
  /** `HH:MM`, local time in the profile zone; null = never picked. */
  windDownTime: string | null;
  /** Rule 1's one-time confirmation for a wind-down time inside quiet hours. */
  windDownInQuietHours: boolean;
  /** "Welcome back" after 7 and 21 quiet days. */
  welcomeBack: boolean;
  /** Habit nudges (opt-in): habit id → local `HH:MM`. A habit with a time is opted in. */
  habitNudges: Readonly<Record<string, string>>;
}

/**
 * PRD defaults: everything on except the daily reminder, which starts when the person picks a time (the permission
 * explainer after the first check-in; suggested 20:00 `[ASSUMPTION]`, set by the app); quiet 23:00–08:00.
 */
export const DEFAULT_NOTIFICATION_PREFS: Readonly<NotificationPrefsValues> = Object.freeze({
  enabled: true,
  reminderEnabled: false,
  reminderTime: null,
  reminderInQuietHours: false,
  capsuleUnlocked: true,
  quietStart: '23:00',
  quietEnd: '08:00',
  discreet: false,
  gestures: true,
  lanternHour: false,
  windDownEnabled: false,
  windDownTime: null,
  windDownInQuietHours: false,
  welcomeBack: true,
  habitNudges: Object.freeze({}),
});

/** The reminder time the app suggests (PRD catalogue "suggested 8 pm" `[ASSUMPTION]`). */
export const SUGGESTED_REMINDER_TIME = '20:00';

/** The wind-down time the app suggests (PRD catalogue "suggested 10:30 pm" `[ASSUMPTION]`). */
export const SUGGESTED_WIND_DOWN_TIME = '22:30';

const HM_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;
export const isHm = (v: unknown): v is string => typeof v === 'string' && HM_RE.test(v);

/** `HH:MM` → minutes after midnight. */
export function hmToMinutes(hm: string): number {
  const m = HM_RE.exec(hm);
  if (!m) throw new RangeError(`not HH:MM: ${hm}`);
  return Number(m[1]) * 60 + Number(m[2]);
}

/** Postgres `time` text (`HH:MM:SS`) → `HH:MM` (null stays null). */
export const pgTimeToHm = (t: string | null): string | null => (t === null ? null : t.slice(0, 5));

/** Wall-clock minutes after midnight of `now` in `tz`. */
export function minutesOfDay(now: Date, tz: string): number {
  const w = wallClock(now, tz);
  return w.hour * 60 + w.minute;
}

/**
 * Inside quiet hours `[start, end)` in `tz`? The window may wrap midnight (23:00–08:00). `start == end` means none
 * (a person may turn quiet hours off by making them empty).
 */
export function inQuietHours(now: Date, tz: string, start: string, end: string): boolean {
  const s = hmToMinutes(start);
  const e = hmToMinutes(end);
  if (s === e) return false;
  const m = minutesOfDay(now, tz);
  return s < e ? m >= s && m < e : m >= s || m < e;
}

/** The next instant strictly after `now` at which the wall clock in `tz` reads `hm` (DST-safe, see zonedInstant). */
export function nextWallTime(now: Date, tz: string, hm: string): Date {
  const minutes = hmToMinutes(hm);
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  const today = localDate(now, tz);
  const t = zonedInstant(today, h, m, tz);
  if (t.getTime() > now.getTime()) return t;
  return zonedInstant(addDays(today, 1), h, m, tz);
}

/** The next daily-reminder instant after `now` (null when the reminder is off). */
export function nextReminderAt(now: Date, tz: string, prefs: NotificationPrefsValues): Date | null {
  if (!prefs.enabled || !prefs.reminderEnabled || !prefs.reminderTime) return null;
  return nextWallTime(now, tz, prefs.reminderTime);
}

/** The user's current Aura day (04:00 rollover): the "local day" the daily cap counts in. */
export const auraDayOf = (now: Date, tz: string): string => auraDay(now, tz);

/** When the current Aura day ends (the next 04:00 local). */
export function endOfAuraDay(now: Date, tz: string): Date {
  return zonedInstant(addDays(auraDay(now, tz), 1), ROLLOVER_HOUR, 0, tz);
}

export type SkipReason =
  | 'no_profile'
  | 'pending_deletion'
  | 'no_device'
  | 'disabled'
  | 'type_disabled'
  | 'expired'
  | 'checked_in'
  | 'not_sealed'
  | 'already_sent'
  | 'quiet_hours'
  | 'capped'
  /** rooms_pool_open: the pool closed again before the push went out. */
  | 'pool_closed'
  /** wind_down_reminder: a Sanctuary activity was finished this evening (REQ-NTF-04). */
  | 'sanctuary_opened'
  /** lantern_hour: already in a room this Aura day. */
  | 'in_room_today'
  /** lantern_hour / gestures_received: rooms are switched off, or the account may not use them (ban, pause). */
  | 'rooms_closed'
  /** gestures_received: nothing left to tell (the gestures are gone). */
  | 'nothing_new'
  /** welcome_back: the person came back before it went out. */
  | 'active_again'
  /** habit_nudge: every nudged habit is done today (or none is due yet). */
  | 'nothing_due'
  /** trial_ending (F12): converted, lapsed, auto-renew turned off, or moved to another account. */
  | 'trial_changed'
  /** daily_reminder, rule 7: 5+ ignored in a row → every other day (sent the previous Aura day). */
  | 'reminder_backoff'
  /** daily_reminder, rule 7: 14+ ignored in a row → stopped until a check-in (welcome-back takes over). */
  | 'reminder_paused';

export type Decision = { action: 'send' } | { action: 'skip'; reason: SkipReason } | { action: 'defer'; until: Date };

/** Everything the rules need to decide one push (read by NotificationDelivery). */
export interface DeliveryFacts {
  type: NotificationType;
  now: Date;
  /** When the push was requested (BullMQ `job.timestamp`); deferrals keep it. */
  createdAt: Date;
  /** Profile timezone; null = no profile (never onboarded, or purged). */
  tz: string | null;
  prefs: NotificationPrefsValues;
  pendingDeletion: boolean;
  /** Registered installs of the account (signed-out installs have no token). */
  devices: number;
  /** Push types already sent on the current Aura day. */
  sentToday: readonly string[];
  /** Higher-priority kinds still expected later this Aura day: their slots are kept (precedence). */
  expectedLater: readonly string[];
  /** daily_reminder: a live check-in exists for the current Aura day. */
  checkedInToday?: boolean;
  /**
   * daily_reminder, rule 7: reminders in a row with no check-in after them, counting the last one sent (0 once a
   * check-in arrived after it), and whether the last one went out on the previous Aura day.
   */
  reminderIgnored?: number;
  reminderSentYesterday?: boolean;
  /** capsule_unlocked: the capsule is still sealed (exists, not opened, not deleted). */
  capsuleSealed?: boolean;
  /** rooms_pool_open: the pool's flag is still on. */
  poolOpen?: boolean;
  /** wind_down_reminder: a Sanctuary session record finished this evening. */
  sanctuaryThisEvening?: boolean;
  /** lantern_hour / gestures_received: rooms are on and the account may use them. */
  roomsOpen?: boolean;
  /** lantern_hour: joined a room this Aura day. */
  inRoomToday?: boolean;
  /** gestures_received: distinct people who sent gestures to the person in that room this Aura day. */
  gestureCount?: number;
  /** welcome_back: the account wrote something after the push was requested. */
  activeAgain?: boolean;
  /** habit_nudge: preset keys (or `custom`) of the nudged habits that are due and not done today. */
  dueHabits?: readonly string[];
  /** trial_ending (F12, trial-ending.ts): the subscription's trial facts. */
  trialEnding?: TrialEndingFacts;
}

const countsTowardCap = (kind: string): boolean => !CAP_EXEMPT.includes(kind);

/** Pushes already counted today (cap-exempt kinds excluded). */
export const cappedSentCount = (sentToday: readonly string[]): number => sentToday.filter(countsTowardCap).length;

/** Slots kept for higher-priority kinds that are still expected today and not sent yet. */
export function reservedSlots(type: string, sentToday: readonly string[], expectedLater: readonly string[]): number {
  const p = priorityOf(type);
  return new Set(expectedLater.filter((k) => priorityOf(k) < p && !sentToday.includes(k) && countsTowardCap(k))).size;
}

/** How many more pushes of `type` today's cap allows right now (the atomic reservation re-checks it in SQL). */
export function capBudget(type: string, sentToday: readonly string[], expectedLater: readonly string[]): number {
  if (!countsTowardCap(type)) return Number.POSITIVE_INFINITY;
  return DAILY_PUSH_CAP - reservedSlots(type, sentToday, expectedLater) - cappedSentCount(sentToday);
}

/** Per-type toggles (rule 8). The pool-open push has none of its own: the person's "Tell me when they open" tap is it. */
const typeEnabled = (type: NotificationType, p: NotificationPrefsValues): boolean => {
  switch (type) {
    case 'daily_reminder':
      return p.reminderEnabled && p.reminderTime !== null;
    case 'capsule_unlocked':
      return p.capsuleUnlocked;
    case 'rooms_pool_open':
      return true;
    case 'gestures_received':
      return p.gestures;
    case 'lantern_hour':
      return p.lanternHour;
    case 'wind_down_reminder':
      return p.windDownEnabled && p.windDownTime !== null;
    case 'welcome_back':
      return p.welcomeBack;
    case 'habit_nudge':
      return Object.keys(p.habitNudges).length > 0;
    case 'trial_ending':
      return true; // F12: a transactional fact about a paid product; the master switch still applies
  }
};

/** Decide one push. Pure: the same facts always give the same answer. */
export function decide(f: DeliveryFacts): Decision {
  const rules = TYPE_RULES[f.type];
  const skip = (reason: SkipReason): Decision => ({ action: 'skip', reason });
  if (f.tz === null) return skip('no_profile');
  if (f.pendingDeletion) return skip('pending_deletion');
  if (f.devices === 0) return skip('no_device');
  if (!f.prefs.enabled) return skip('disabled');
  if (!typeEnabled(f.type, f.prefs)) return skip('type_disabled');
  if (f.now.getTime() - f.createdAt.getTime() > rules.maxAgeMs) return skip('expired');
  if (f.type === 'daily_reminder' && f.checkedInToday) return skip('checked_in');
  const smart = smartTimingSkip(f);
  if (smart) return skip(smart);
  if (f.type === 'capsule_unlocked' && !f.capsuleSealed) return skip('not_sealed');
  if (f.type === 'rooms_pool_open' && !f.poolOpen) return skip('pool_closed');
  const b = milestoneBSkip(f);
  if (b) return skip(b);
  if (f.sentToday.filter((t) => t === f.type).length >= rules.perDay) return skip('already_sent');

  if (inQuietHours(f.now, f.tz, f.prefs.quietStart, f.prefs.quietEnd)) {
    // Rule 1: nothing system-initiated inside quiet hours. The one exception is a reminder the user deliberately
    // placed there (night shifts) after the one-time confirmation in the app.
    const userScheduled =
      (f.type === 'daily_reminder' && f.prefs.reminderInQuietHours) ||
      (f.type === 'wind_down_reminder' && f.prefs.windDownInQuietHours);
    if (!userScheduled) {
      if (rules.quiet === 'skip') return skip('quiet_hours');
      const until = nextWallTime(f.now, f.tz, f.prefs.quietEnd);
      if (until.getTime() - f.createdAt.getTime() > rules.maxAgeMs) return skip('quiet_hours');
      return { action: 'defer', until };
    }
  }

  if (capBudget(f.type, f.sentToday, f.expectedLater) <= 0) return cappedDecision(f);
  return { action: 'send' };
}

/** The type-specific checks of the Milestone B kinds (PRD 12 catalogue "Trigger" column). */
function milestoneBSkip(f: DeliveryFacts): SkipReason | null {
  switch (f.type) {
    case 'wind_down_reminder':
      return f.sanctuaryThisEvening ? 'sanctuary_opened' : null;
    case 'lantern_hour':
      if (!f.roomsOpen) return 'rooms_closed';
      return f.inRoomToday ? 'in_room_today' : null;
    case 'gestures_received':
      if (!f.roomsOpen) return 'rooms_closed';
      return (f.gestureCount ?? 0) > 0 ? null : 'nothing_new';
    case 'welcome_back':
      return f.activeAgain ? 'active_again' : null;
    case 'habit_nudge':
      return (f.dueHabits ?? []).length > 0 ? null : 'nothing_due';
    case 'trial_ending':
      return f.trialEnding?.stillEnding ? null : 'trial_changed';
    default:
      return null;
  }
}

/** Today's cap is used: dropped, or (TypeRules.capped `defer`) moved to the start of the next Aura day. */
export function cappedDecision(f: Pick<DeliveryFacts, 'type' | 'now' | 'createdAt' | 'tz'>): Decision {
  const rules = TYPE_RULES[f.type];
  if (rules.capped !== 'defer' || f.tz === null) return { action: 'skip', reason: 'capped' };
  const until = endOfAuraDay(f.now, f.tz);
  if (until.getTime() - f.createdAt.getTime() > rules.maxAgeMs) return { action: 'skip', reason: 'capped' };
  return { action: 'defer', until };
}

/**
 * PRD 12 rule 7 "Smart timing": reminder ignored 5 days in a row → every other day; 14 ignored → stop and leave it to
 * welcome-back; any check-in restores the schedule (contracts/api/v1-notifications.md "Smart timing"). Pure.
 */
export const SMART_TIMING = { everyOtherDayFrom: 5, stopFrom: 14 } as const;

export function smartTimingSkip(f: Pick<DeliveryFacts, 'type' | 'reminderIgnored' | 'reminderSentYesterday'>): SkipReason | null {
  if (f.type !== 'daily_reminder' || f.reminderIgnored === undefined) return null;
  if (f.reminderIgnored >= SMART_TIMING.stopFrom) return 'reminder_paused';
  if (f.reminderIgnored >= SMART_TIMING.everyOtherDayFrom && f.reminderSentYesterday) return 'reminder_backoff';
  return null;
}

/**
 * The ignored count before a reminder: 0 when nothing was sent yet or a check-in reached the server after the last
 * one; otherwise the stored count + 1 (the last one was ignored too).
 */
export function ignoredSoFar(stored: number, lastSentAt: Date | null, checkedInSince: boolean): number {
  if (lastSentAt === null || checkedInSince) return 0;
  return stored + 1;
}
