import type { AndroidChannelId, NotificationType } from './notification-types';

/**
 * PRD 12-notifications global rule 2: when the daily cap binds, this order decides (highest first). Only the first two
 * ship at Milestone A; the rest are listed so the cap and precedence logic already treat them correctly. A kind the
 * PRD's list doesn't name (`rooms_pool_open`) ranks last; being a one-off the person asked for, it waits for the next
 * day when capped instead of being dropped (TYPE_RULES `capped: 'defer'`).
 */
export const PRECEDENCE = [
  'capsule_unlocked',
  'daily_reminder',
  'gestures_received',
  'lantern_hour',
  'wind_down_reminder',
  'habit_nudge',
  'welcome_back',
] as const;
export type NotificationKind = (typeof PRECEDENCE)[number];

/** Rule 2: at most 2 pushes per local (Aura) day, all types combined (the trial-ending reminder is exempt). */
export const DAILY_PUSH_CAP = 2;

/** Push kinds that never count toward the daily cap (rule 2). None ships yet; the trial-ending reminder will. */
export const CAP_EXEMPT: readonly string[] = [];

export const priorityOf = (kind: string): number => {
  const i = (PRECEDENCE as readonly string[]).indexOf(kind);
  return i < 0 ? PRECEDENCE.length : i;
};

/** Kinds that outrank `kind` (lower index = higher priority). */
export const higherThan = (kind: string): NotificationKind[] => PRECEDENCE.filter((k) => priorityOf(k) < priorityOf(kind));

export interface TypeRules {
  /** Per-type cap per Aura day (catalogue "Cap" column). */
  perDay: number;
  /**
   * A system push that falls inside quiet hours: `defer` waits for their end (still worth sending later that day),
   * `skip` drops it. The daily reminder is the user's own choice of time: it is skipped, unless the user confirmed a
   * time inside quiet hours (rule 1's night-shift exception).
   */
  quiet: 'defer' | 'skip';
  /** A job older than this (worker outage, long deferral) is not sent. */
  maxAgeMs: number;
  channel: AndroidChannelId;
  /** FCM/APNs time to live: stale nudges are never delivered days later. */
  ttlSeconds: number;
  /**
   * When today's cap (rule 2) is already used: `skip` drops it (the default), `defer` waits for the next Aura day — for
   * a one-off the person asked for, which is still true tomorrow ("Dropped items stay as in-app cards").
   */
  capped?: 'skip' | 'defer';
}

const H = 3600_000;

export const TYPE_RULES: Readonly<Record<NotificationType, TypeRules>> = {
  // The capsule job fires at 10:00 local and is dropped past 24 h late (v1-capsules.md §6); +2 h of deferral slack.
  capsule_unlocked: { perDay: 1, quiet: 'defer', maxAgeMs: 26 * H, channel: 'capsules', ttlSeconds: 24 * 3600 },
  daily_reminder: { perDay: 1, quiet: 'skip', maxAgeMs: 2 * H, channel: 'reminders', ttlSeconds: 2 * 3600 },
  // "Tell me when they open": one push the person asked for, whenever the pool opens — waits out quiet hours and a
  // full day, and is dropped after 3 days (the pool screen tells them too).
  rooms_pool_open: { perDay: 1, quiet: 'defer', maxAgeMs: 72 * H, channel: 'rooms', ttlSeconds: 24 * 3600, capped: 'defer' },
};

/** Base of the capsule notice ids (apps/mobile features/capsules/capsule_notifications.dart `capsuleNoticeId`). */
export const CAPSULE_NOTICE_ID_BASE = 0x18000000;

/**
 * The id of the app's local "ready to open" notice for an unlock date — one per date, shared with apps/mobile
 * (`capsuleNoticeId(LocalDay)`): `0x18000000 + days since 1970-01-01`. The server push for a capsule unlocking that
 * date uses its decimal string as the APNs collapse id and the Android tag, so on iOS the push and the offline notice
 * replace each other (same request identifier) and on Android the app cancels its own notice when the push arrives
 * (features/push). It reveals nothing the delivery time doesn't: the push is sent at 10:00 on that very date.
 */
export function capsuleNoticeId(unlockLocalDate: string): number {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(unlockLocalDate);
  if (!m) throw new TypeError('capsuleNoticeId: not YYYY-MM-DD');
  return CAPSULE_NOTICE_ID_BASE + Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])) / 86_400_000;
}

/**
 * Replace-key per push: one visible daily reminder; for a capsule, the local notice id of its unlock date (several
 * capsules on one date share one notice, like the server's one push per user per date). Without the date (a capsule
 * that can't be read), a key per type.
 */
export function collapseKeyFor(type: NotificationType, unlockLocalDate: string | null = null): string {
  if (type === 'capsule_unlocked' && unlockLocalDate) return String(capsuleNoticeId(unlockLocalDate));
  return type;
}
