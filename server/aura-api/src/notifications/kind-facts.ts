import { zonedInstant } from '../capsules/capsule-rules';
import type { Queryable } from '../db/db';
import { auraDay, ROLLOVER_HOUR } from '../rules';
import { higherThan } from './catalogue';
import { auraDayStart } from './gestures-push';
import type { NotificationJobData, NotificationType } from './notification-types';
import { endOfAuraDay, hmToMinutes, minutesOfDay, type DeliveryFacts, type NotificationPrefsValues } from './policy';

/**
 * What delivery reads for the Milestone B kinds (PRD 12 catalogue "Trigger" column; policy.ts milestoneBSkip decides):
 *
 *  - `wind_down_reminder` — "skipped if Sanctuary was already opened that evening": a Sanctuary session record
 *    (sanctuary_sessions, content-free) finished since {@link EVENING_START_HOUR}:00 of the current Aura day. The server
 *    only learns of finished activities (nothing records a visit); the app also keeps its in-app notice quiet when
 *    Sanctuary was opened on the phone that evening.
 *  - `lantern_hour` — "skipped if already in a room today": a membership joined this Aura day; plus rooms on
 *    (`rooms_enabled`) and no ban / social ban / rooms pause.
 *  - `gestures_received` — the distinct people who sent the person a gesture in that room this Aura day (not
 *    dropped); no ban / social ban / rooms pause.
 *  - `welcome_back` — "came back" = any write since the push was requested (notification_activity).
 *  - `habit_nudge` — the nudged habits whose time has come today and that aren't logged for the Aura day yet
 *    (preset key, or `custom` — a custom habit's name is never read).
 * Plus, for each, the higher-priority pushes still expected later this Aura day (precedence keeps their slots, rule 2).
 */

/** "That evening" for the wind-down reminder starts here (local), `[ASSUMPTION]`. */
export const EVENING_START_HOUR = 18;

export const MILESTONE_B_TYPES: readonly NotificationType[] = [
  'gestures_received',
  'lantern_hour',
  'wind_down_reminder',
  'habit_nudge',
  'welcome_back',
];

/** Sanctions that keep someone out of rooms (the same list as the pool-open push). */
export const ROOMS_CLOSED_KINDS = ['account_ban', 'social_ban', 'rooms_pause'];

/** Minutes since the Aura day began (04:00 local = 0): orders times within one Aura day. */
export const auraMinutes = (minutes: number): number => (minutes - ROLLOVER_HOUR * 60 + 1440) % 1440;

/** The nudged habits whose time has come in the current Aura day (pure). */
export function dueNudgeHabits(now: Date, tz: string, nudges: Readonly<Record<string, string>>): string[] {
  const nowRel = auraMinutes(minutesOfDay(now, tz));
  return Object.entries(nudges)
    .filter(([, t]) => auraMinutes(hmToMinutes(t)) <= nowRel)
    .map(([id]) => id);
}

/** Start of "this evening" for the wind-down reminder: 18:00 on the current Aura day's date. */
export function eveningStart(now: Date, tz: string): Date {
  return zonedInstant(auraDay(now, tz), EVENING_START_HOUR, 0, tz);
}

async function any(q: Queryable, sql: string, params: unknown[]): Promise<boolean> {
  const r = await q.query(sql, params);
  return (r.rowCount ?? 0) > 0;
}

async function roomsClosedFor(q: Queryable, userId: string): Promise<boolean> {
  return any(
    q,
    `select 1 from public.sanctions s
      where s.user_id = $1 and s.kind = any($2::text[]) and s.lifted_at is null
        and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now())
      limit 1`,
    [userId, ROOMS_CLOSED_KINDS],
  );
}

/** A kill switch from the table (missing = on). */
async function switchOn(q: Queryable, key: string): Promise<boolean> {
  const r = await q.query<{ enabled: boolean }>('select enabled from public.feature_flags where key = $1', [key]);
  return r.rows[0] ? r.rows[0].enabled : true;
}

/**
 * Higher-priority kinds still expected later in this Aura day (their slots are kept, rule 2 precedence): a date capsule
 * due, the daily reminder planned (and no check-in yet), a planned Lantern Hour / wind-down / habit nudge. Gestures
 * can't be foreseen.
 */
export async function expectedLaterFor(
  q: Queryable,
  userId: string,
  type: NotificationType,
  now: Date,
  tz: string,
  prefs: NotificationPrefsValues,
): Promise<string[]> {
  const higher = higherThan(type) as string[];
  if (higher.length === 0) return [];
  const dayEnd = endOfAuraDay(now, tz);
  const out: string[] = [];
  if (higher.includes('capsule_unlocked') && prefs.capsuleUnlocked) {
    const due = await any(
      q,
      `select 1 from public.capsule_unlock_schedule s
         join public.capsules c on c.id = s.capsule_id
        where c.user_id = $1 and s.notified_at is null and c.deleted_at is null and c.opened_at is null
          and s.notify_at > $2 and s.notify_at < $3
        limit 1`,
      [userId, now, dayEnd],
    );
    if (due) out.push('capsule_unlocked');
  }
  if (higher.includes('daily_reminder') && prefs.enabled && prefs.reminderEnabled) {
    const planned = await any(
      q,
      `select 1 from public.notification_prefs np
        where np.user_id = $1 and np.reminder_next_at > $2 and np.reminder_next_at < $3
          and not exists (select 1 from public.check_ins c where c.user_id = $1 and c.local_day = $4::date and not c.backfill)`,
      [userId, now, dayEnd, auraDay(now, tz)],
    );
    if (planned) out.push('daily_reminder');
  }
  const scheduled = higher.filter((k) => k === 'lantern_hour' || k === 'wind_down_reminder' || k === 'habit_nudge');
  if (scheduled.length > 0) {
    const r = await q.query<{ kind: string }>(
      `select kind from public.notification_schedule
        where user_id = $1 and kind = any($2::text[]) and next_at > $3 and next_at < $4`,
      [userId, scheduled, now, dayEnd],
    );
    for (const row of r.rows) out.push(row.kind);
  }
  return out;
}

/** Fills `facts` for a Milestone B push (no-op for other types). */
export async function fillMilestoneBFacts(q: Queryable, n: NotificationJobData, facts: DeliveryFacts, now: Date, tz: string): Promise<void> {
  if (!MILESTONE_B_TYPES.includes(n.type)) return;
  const day = auraDay(now, tz);
  switch (n.type) {
    case 'wind_down_reminder':
      facts.sanctuaryThisEvening = await any(
        q,
        'select 1 from public.sanctuary_sessions where user_id = $1 and device_ts >= $2 limit 1',
        [n.userId, eveningStart(now, tz)],
      );
      break;
    case 'lantern_hour':
      facts.roomsOpen = (await switchOn(q, 'rooms_enabled')) && !(await roomsClosedFor(q, n.userId));
      facts.inRoomToday = await any(q, 'select 1 from public.room_members where user_id = $1 and joined_at >= $2 limit 1', [
        n.userId,
        auraDayStart(now, tz),
      ]);
      break;
    case 'gestures_received': {
      facts.roomsOpen = !(await roomsClosedFor(q, n.userId));
      if (n.id === null) {
        facts.gestureCount = 0;
        break;
      }
      const r = await q.query<{ n: number }>(
        `select count(distinct g.from_member_id)::int as n
           from public.room_gestures g
           join public.room_members m on m.room_id = g.room_id and m.member_id = g.to_member_id
          where g.room_id = $1 and m.user_id = $2 and g.dropped is null and g.created_at >= $3`,
        [n.id, n.userId, auraDayStart(now, tz)],
      );
      facts.gestureCount = r.rows[0]?.n ?? 0;
      break;
    }
    case 'welcome_back':
      facts.activeAgain = await any(
        q,
        'select 1 from public.notification_activity where user_id = $1 and last_active_at > $2',
        [n.userId, facts.createdAt],
      );
      break;
    case 'habit_nudge': {
      const due = dueNudgeHabits(now, tz, facts.prefs.habitNudges);
      if (due.length === 0) {
        facts.dueHabits = [];
        break;
      }
      const r = await q.query<{ preset_key: string | null }>(
        `select h.preset_key from public.habits h
          where h.user_id = $1 and h.active and h.id = any($2::uuid[])
            and not exists (select 1 from public.habit_logs l where l.habit_id = h.id and l.local_day = $3::date)
          order by h.created_at`,
        [n.userId, due, day],
      );
      facts.dueHabits = r.rows.map((x) => x.preset_key ?? 'custom');
      break;
    }
    default:
      break;
  }
  facts.expectedLater = await expectedLaterFor(q, n.userId, n.type, now, tz, facts.prefs);
}
