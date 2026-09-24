import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import type { Queryable, Tx } from '../db/db';
import { reject } from '../sync/mutation-rejected';
import type { Mutation } from '../sync/sync.schema';
import { UUID_RE } from '../common/uuid';
import { milestoneBPrefsSql, saveMilestoneBPrefs } from './prefs-milestone-b';
import { planSchedules } from './schedules';
import {
  DEFAULT_NOTIFICATION_PREFS,
  isHm,
  nextReminderAt,
  pgTimeToHm,
  type NotificationPrefsValues,
} from './policy';

/**
 * Sync entity `notification_prefs` (contracts/api/v1-notifications.md): the app's Settings › Notifications, written
 * only through `POST /v1/sync/push` (PRD 16-offline: "settings use the same path"), op `upsert`, a PATCH of the
 * fields that changed. Conflict rule (16-offline "settings: last-write-wins per field"): each field keeps the device
 * time of its last applied write (`field_ts`, clamped to server time so a fast clock can't pin a field); a write
 * older than a field's stamp leaves that field alone. Every applied change re-plans the next daily reminder in the
 * profile zone, inside the push transaction.
 */
export const NOTIFICATION_PREFS_ENTITY = 'notification_prefs';

/** Payload field (camelCase, the app's) → column. */
export const PREF_COLUMNS = {
  enabled: 'enabled',
  reminderEnabled: 'reminder_enabled',
  reminderTime: 'reminder_time',
  reminderInQuietHours: 'reminder_in_quiet_ok',
  capsuleUnlocked: 'capsule_enabled',
  quietStart: 'quiet_start',
  quietEnd: 'quiet_end',
  discreet: 'discreet',
  // Milestone B (contracts/api/v1-notifications.md §6).
  gestures: 'gestures_enabled',
  lanternHour: 'lantern_opt_in',
  windDownEnabled: 'wind_down_enabled',
  windDownTime: 'wind_down_time',
  windDownInQuietHours: 'wind_down_in_quiet_ok',
  welcomeBack: 'welcome_back_enabled',
  habitNudges: 'habit_nudges',
} as const satisfies Record<keyof NotificationPrefsValues, string>;
export type PrefField = keyof typeof PREF_COLUMNS;
export const PREF_FIELDS = Object.keys(PREF_COLUMNS) as PrefField[];

const hm = z.string().refine(isHm, 'must be HH:MM (24 h)');

/** Habit nudges: at most this many habits (6 presets + 3 custom fit; the table's check allows 16). */
export const MAX_HABIT_NUDGES = 16;
const habitNudgesSchema = z
  .record(z.string().regex(UUID_RE, 'habit ids are UUIDs').transform((k) => k.toLowerCase()), hm)
  .refine((m) => Object.keys(m).length <= MAX_HABIT_NUDGES, `at most ${MAX_HABIT_NUDGES} habits`);

/** A patch: any subset of the settings (unknown keys are ignored, so newer apps can add fields). */
export const prefsPatchSchema = z
  .object({
    enabled: z.boolean(),
    reminderEnabled: z.boolean(),
    reminderTime: hm.nullable(),
    reminderInQuietHours: z.boolean(),
    capsuleUnlocked: z.boolean(),
    quietStart: hm,
    quietEnd: hm,
    discreet: z.boolean(),
    gestures: z.boolean(),
    lanternHour: z.boolean(),
    windDownEnabled: z.boolean(),
    windDownTime: hm.nullable(),
    windDownInQuietHours: z.boolean(),
    welcomeBack: z.boolean(),
    habitNudges: habitNudgesSchema,
  })
  .partial()
  .refine((p) => PREF_FIELDS.some((f) => p[f] !== undefined), 'at least one setting');
export type PrefsPatch = z.infer<typeof prefsPatchSchema>;

/** Stored values + per-field stamps (ISO instants). */
export interface StoredPrefs {
  values: NotificationPrefsValues;
  fieldTs: Partial<Record<PrefField, string>>;
}

/**
 * Per-field LWW. A field is written when the patch carries it and `at` is not older than the field's stamp (ties →
 * the later-received write wins, like 16-offline's `server_ts` tie-break). Pure.
 */
export function mergePrefs(current: StoredPrefs, patch: PrefsPatch, at: Date): { next: StoredPrefs; changed: PrefField[] } {
  const values: NotificationPrefsValues = { ...current.values };
  const fieldTs = { ...current.fieldTs };
  const changed: PrefField[] = [];
  for (const f of PREF_FIELDS) {
    const v = patch[f];
    if (v === undefined) continue;
    const stamp = fieldTs[f];
    if (stamp !== undefined && Date.parse(stamp) > at.getTime()) continue; // an older write: this field stays
    (values as unknown as Record<string, unknown>)[f] = v;
    fieldTs[f] = at.toISOString();
    changed.push(f);
  }
  return { next: { values, fieldTs }, changed };
}

interface PrefsRow {
  enabled: boolean;
  reminder_enabled: boolean;
  reminder_time: string | null;
  reminder_in_quiet_ok: boolean;
  capsule_enabled: boolean;
  quiet_start: string;
  quiet_end: string;
  discreet: boolean;
  field_ts: Record<string, unknown> | null;
  // Milestone B columns: absent when a caller selects only the Milestone A ones (→ defaults).
  gestures_enabled?: boolean;
  lantern_opt_in?: boolean;
  wind_down_enabled?: boolean;
  wind_down_time?: string | null;
  wind_down_in_quiet_ok?: boolean;
  welcome_back_enabled?: boolean;
  habit_nudges?: Record<string, unknown> | null;
}

/** `habit_nudges` jsonb → a clean map (anything malformed is dropped). */
export function habitNudgesFrom(v: unknown): Record<string, string> {
  const out: Record<string, string> = {};
  if (!v || typeof v !== 'object' || Array.isArray(v)) return out;
  for (const [k, t] of Object.entries(v as Record<string, unknown>)) {
    if (UUID_RE.test(k) && isHm(t)) out[k.toLowerCase()] = t;
  }
  return out;
}

/** Row → values (`time` columns come back as `HH:MM:SS`). */
export function prefsFromRow(r: PrefsRow | undefined): StoredPrefs {
  if (!r) return { values: { ...DEFAULT_NOTIFICATION_PREFS }, fieldTs: {} };
  const fieldTs: Partial<Record<PrefField, string>> = {};
  for (const f of PREF_FIELDS) {
    const s = r.field_ts?.[f];
    if (typeof s === 'string' && !Number.isNaN(Date.parse(s))) fieldTs[f] = s;
  }
  return {
    values: {
      enabled: r.enabled,
      reminderEnabled: r.reminder_enabled,
      reminderTime: pgTimeToHm(r.reminder_time),
      reminderInQuietHours: r.reminder_in_quiet_ok,
      capsuleUnlocked: r.capsule_enabled,
      quietStart: pgTimeToHm(r.quiet_start) ?? DEFAULT_NOTIFICATION_PREFS.quietStart,
      quietEnd: pgTimeToHm(r.quiet_end) ?? DEFAULT_NOTIFICATION_PREFS.quietEnd,
      discreet: r.discreet,
      gestures: r.gestures_enabled ?? DEFAULT_NOTIFICATION_PREFS.gestures,
      lanternHour: r.lantern_opt_in ?? DEFAULT_NOTIFICATION_PREFS.lanternHour,
      windDownEnabled: r.wind_down_enabled ?? DEFAULT_NOTIFICATION_PREFS.windDownEnabled,
      windDownTime: pgTimeToHm(r.wind_down_time ?? null),
      windDownInQuietHours: r.wind_down_in_quiet_ok ?? DEFAULT_NOTIFICATION_PREFS.windDownInQuietHours,
      welcomeBack: r.welcome_back_enabled ?? DEFAULT_NOTIFICATION_PREFS.welcomeBack,
      habitNudges: habitNudgesFrom(r.habit_nudges),
    },
    fieldTs,
  };
}

export const PREFS_COLUMNS_SQL =
  'enabled, reminder_enabled, reminder_time::text as reminder_time, reminder_in_quiet_ok, capsule_enabled, ' +
  'quiet_start::text as quiet_start, quiet_end::text as quiet_end, discreet, field_ts, ' +
  milestoneBPrefsSql('');

/** The user's settings (defaults when no row). */
export async function loadPrefs(q: Queryable, userId: string, forUpdate = false): Promise<StoredPrefs> {
  const r = await q.query<PrefsRow>(
    `select ${PREFS_COLUMNS_SQL} from public.notification_prefs where user_id = $1${forUpdate ? ' for update' : ''}`,
    [userId],
  );
  return prefsFromRow(r.rows[0]);
}

/** What the push transaction needs (SyncService's context satisfies it). */
export interface PrefsCtx {
  tx: Tx;
  userId: string;
  /** Profile timezone: the daily reminder is planned in it. */
  tz: string;
  now: Date;
}

/**
 * `notification_prefs` upsert inside the sync push (SyncModule). Rejections: `invalid_payload` (shape, missing
 * `deviceTs`, a time that isn't HH:MM, no known field). A patch whose every field is older than what is stored is
 * still `applied` (nothing changes, like a replay).
 */
@Injectable()
export class NotificationPrefsSyncHandler {
  async apply(ctx: PrefsCtx, m: Mutation): Promise<void> {
    if (m.op !== 'upsert') return reject('unknown_op');
    if (!m.deviceTs) return reject('invalid_payload');
    const parsed = prefsPatchSchema.safeParse(m.payload);
    if (!parsed.success) return reject('invalid_payload');
    const deviceTs = new Date(m.deviceTs);
    const at = deviceTs.getTime() > ctx.now.getTime() ? ctx.now : deviceTs; // a fast clock never pins a field

    const current = await loadPrefs(ctx.tx, ctx.userId, true);
    const { next, changed } = mergePrefs(current, parsed.data, at);
    if (changed.length === 0) return;
    const v = next.values;
    const nextAt = nextReminderAt(ctx.now, ctx.tz, v);
    await ctx.tx.query(
      `insert into public.notification_prefs as np
         (user_id, enabled, reminder_enabled, reminder_time, reminder_in_quiet_ok, capsule_enabled,
          quiet_start, quiet_end, discreet, field_ts, reminder_next_at, reminder_tz, updated_at)
       values ($1, $2, $3, $4::time, $5, $6, $7::time, $8::time, $9, $10::jsonb, $11, $12, now())
       on conflict (user_id) do update set
         enabled = excluded.enabled, reminder_enabled = excluded.reminder_enabled,
         reminder_time = excluded.reminder_time, reminder_in_quiet_ok = excluded.reminder_in_quiet_ok,
         capsule_enabled = excluded.capsule_enabled, quiet_start = excluded.quiet_start,
         quiet_end = excluded.quiet_end, discreet = excluded.discreet, field_ts = excluded.field_ts,
         reminder_next_at = excluded.reminder_next_at, reminder_tz = excluded.reminder_tz, updated_at = now()`,
      [
        ctx.userId,
        v.enabled,
        v.reminderEnabled,
        v.reminderTime,
        v.reminderInQuietHours,
        v.capsuleUnlocked,
        v.quietStart,
        v.quietEnd,
        v.discreet,
        JSON.stringify(next.fieldTs),
        nextAt,
        nextAt ? ctx.tz : null,
      ],
    );
    // Milestone B: its columns on the (now existing) row, then the user-timed pushes re-planned (schedules.ts).
    await saveMilestoneBPrefs(ctx.tx, ctx.userId, v);
    await planSchedules(ctx.tx, ctx.userId, ctx.tz, ctx.now, v);
  }
}
