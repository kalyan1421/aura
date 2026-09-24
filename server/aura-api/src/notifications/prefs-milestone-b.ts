import type { Queryable } from '../db/db';
import type { NotificationPrefsValues } from './policy';

/**
 * The Milestone B columns of `public.notification_prefs` (migration 20261005000023; contracts/api/v1-notifications.md
 * §6): per-type toggles for gestures received, Lantern Hour (`lantern_opt_in`, from foundations) and welcome back,
 * the opt-in wind-down reminder, and per-habit nudge times. Kept apart from the Milestone A statement in
 * notification-prefs.ts so the two can grow independently; prefsFromRow reads both.
 */

/** The select list (`alias.` prefixed when given), matching prefsFromRow's optional Milestone B fields. */
export function milestoneBPrefsSql(alias: string): string {
  const a = alias ? `${alias}.` : '';
  return (
    `${a}gestures_enabled, ${a}lantern_opt_in, ${a}wind_down_enabled, ${a}wind_down_time::text as wind_down_time, ` +
    `${a}wind_down_in_quiet_ok, ${a}welcome_back_enabled, ${a}habit_nudges`
  );
}

/** Writes the Milestone B values on the user's (existing) prefs row. */
export async function saveMilestoneBPrefs(q: Queryable, userId: string, v: NotificationPrefsValues): Promise<void> {
  await q.query(
    `update public.notification_prefs set
       gestures_enabled = $2, lantern_opt_in = $3, wind_down_enabled = $4, wind_down_time = $5::time,
       wind_down_in_quiet_ok = $6, welcome_back_enabled = $7, habit_nudges = $8::jsonb
     where user_id = $1`,
    [
      userId,
      v.gestures,
      v.lanternHour,
      v.windDownEnabled,
      v.windDownTime,
      v.windDownInQuietHours,
      v.welcomeBack,
      JSON.stringify(v.habitNudges),
    ],
  );
}
