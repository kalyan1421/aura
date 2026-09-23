import { zonedInstant } from '../capsules/capsule-rules';
import { addDays, auraDay, localDate, ROLLOVER_HOUR, wallClock } from '../rules';
import { CAP_EXEMPT, DAILY_PUSH_CAP, priorityOf, TYPE_RULES } from './catalogue';
import type { NotificationType } from './notification-types';

/**
 * The global push rules (PRD 12-notifications) as pure functions — the worker's delivery path feeds them facts read
 * from the DB, so every rule is unit-testable without one:
 *   1. quiet hours (default 23:00–08:00 local, editable); a daily reminder the user confirmed inside them is honoured;
 *   2. at most 2 pushes per local (Aura) day across types, precedence capsule unlocked > daily reminder > …;
 *   4. discreet mode (rendering, push-copy.ts); 8. per-type toggles + a master switch;
 *   plus: never to an account with a scheduled deletion or to signed-out installs (no token), the daily reminder is
 *   skipped once the user checked in that Aura day, a capsule push only while the capsule is still sealed.
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
});

/** The reminder time the app suggests (PRD catalogue "suggested 8 pm" `[ASSUMPTION]`). */
export const SUGGESTED_REMINDER_TIME = '20:00';

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
  | 'capped';

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
  /** capsule_unlocked: the capsule is still sealed (exists, not opened, not deleted). */
  capsuleSealed?: boolean;
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

const typeEnabled = (type: NotificationType, p: NotificationPrefsValues): boolean =>
  type === 'daily_reminder' ? p.reminderEnabled && p.reminderTime !== null : p.capsuleUnlocked;

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
  if (f.type === 'capsule_unlocked' && !f.capsuleSealed) return skip('not_sealed');
  if (f.sentToday.filter((t) => t === f.type).length >= rules.perDay) return skip('already_sent');

  if (inQuietHours(f.now, f.tz, f.prefs.quietStart, f.prefs.quietEnd)) {
    // Rule 1: nothing system-initiated inside quiet hours. The one exception is a reminder the user deliberately
    // placed there (night shifts) after the one-time confirmation in the app.
    const userScheduled = f.type === 'daily_reminder' && f.prefs.reminderInQuietHours;
    if (!userScheduled) {
      if (rules.quiet === 'skip') return skip('quiet_hours');
      const until = nextWallTime(f.now, f.tz, f.prefs.quietEnd);
      if (until.getTime() - f.createdAt.getTime() > rules.maxAgeMs) return skip('quiet_hours');
      return { action: 'defer', until };
    }
  }

  if (capBudget(f.type, f.sentToday, f.expectedLater) <= 0) return skip('capped');
  return { action: 'send' };
}
