import { Injectable, Logger } from '@nestjs/common';
import type { Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { QueuesService } from '../queues/queues.service';
import {
  DEFAULT_LANTERN_END,
  DEFAULT_LANTERN_START,
  lanternWindow,
  parseClockTime,
  regionForTimeZone,
  type ClockTime,
} from '../rooms/regions';
import { auraDay } from '../rules';
import { prefsFromRow } from './notification-prefs';
import { NotificationsService } from './notifications.service';
import { nextWallTime, type NotificationPrefsValues } from './policy';
import { milestoneBPrefsSql } from './prefs-milestone-b';

/**
 * The user-timed Milestone B pushes (PRD 12 catalogue; contracts/api/v1-notifications.md §7), scheduled like the daily
 * reminder but in one table, `public.notification_schedule` (user, kind → next instant, planned zone):
 *
 *  - `wind_down_reminder` — the person's chosen time (suggested 22:30), opt-in (REQ-NTF-04);
 *  - `lantern_hour` — when the person's timezone region's Lantern Hour starts (21:00 on the region clock, F5; up to
 *    ±2 h from their own 9 pm), opt-in;
 *  - `habit_nudge` — each nudged habit's own time; at most one push a day, bundling the habits due then.
 *
 * Planned in the PROFILE timezone inside the sync push whenever a setting changes (`planSchedules`), and by two
 * repeatable jobs on the `notifications` queue:
 *  - `schedule-sweep` (every minute): claims due rows (the claim moves the row to its next instant, so overlapping
 *    sweeps can't double-send), enqueues one push each (deduplicated per user + kind + Aura day, per time for habit
 *    nudges). Too late (worker outage), planned in another zone, or no longer wanted → moved on without a push.
 *  - `schedule-reconcile` (every 10 min): plans wanted kinds that have no row, re-plans rows whose profile zone changed,
 *    and deletes rows no longer wanted.
 * Delivery then applies every global rule (NotificationDelivery / policy.ts). Logs carry kinds and counts only.
 */
export const SCHEDULED_KINDS = ['wind_down_reminder', 'lantern_hour', 'habit_nudge'] as const;
export type ScheduledKind = (typeof SCHEDULED_KINDS)[number];

export const SCHEDULE_SWEEP_JOB = 'schedule-sweep';
export const SCHEDULE_RECONCILE_JOB = 'schedule-reconcile';
export const SCHEDULE_SWEEP_SCHEDULER_ID = 'aura-schedule-sweep';
export const SCHEDULE_RECONCILE_SCHEDULER_ID = 'aura-schedule-reconcile';
export const SCHEDULE_SWEEP_EVERY_MS = 60_000;
export const SCHEDULE_RECONCILE_EVERY_MS = 10 * 60_000;
export const SCHEDULE_BATCH = 500;

/** A push this late (worker outage) is not sent: the moment has passed. */
export const SCHEDULE_MAX_LATE_MS: Readonly<Record<ScheduledKind, number>> = {
  wind_down_reminder: 2 * 3600_000,
  lantern_hour: 30 * 60_000,
  habit_nudge: 2 * 3600_000,
};

/** The region clock's Lantern Hour window (matching_config, default 21:00–23:00). */
export interface LanternClock {
  start: ClockTime;
  end: ClockTime;
}
export const DEFAULT_LANTERN_CLOCK: LanternClock = { start: DEFAULT_LANTERN_START, end: DEFAULT_LANTERN_END };

/** The next start of Lantern Hour for someone in `tz` strictly after `now` (their region's clock, DST-correct). */
export function nextLanternStart(now: Date, tz: string, clock: LanternClock = DEFAULT_LANTERN_CLOCK): Date {
  const region = regionForTimeZone(tz, now);
  let w = lanternWindow(region, now, clock.start, clock.end);
  if (w.startsAt.getTime() <= now.getTime()) w = lanternWindow(region, w.endsAt, clock.start, clock.end);
  return w.startsAt;
}

/** The next instant of `kind` after `now` for these settings, or null when it is off. Pure. */
export function nextAtFor(
  kind: ScheduledKind,
  now: Date,
  tz: string,
  p: NotificationPrefsValues,
  lantern: LanternClock = DEFAULT_LANTERN_CLOCK,
): Date | null {
  if (!p.enabled) return null;
  switch (kind) {
    case 'wind_down_reminder':
      return p.windDownEnabled && p.windDownTime ? nextWallTime(now, tz, p.windDownTime) : null;
    case 'lantern_hour':
      return p.lanternHour ? nextLanternStart(now, tz, lantern) : null;
    case 'habit_nudge': {
      const times = [...new Set(Object.values(p.habitNudges))];
      if (times.length === 0) return null;
      return times.map((t) => nextWallTime(now, tz, t)).reduce((a, b) => (b.getTime() < a.getTime() ? b : a));
    }
  }
}

/** Dedupe key of one planned push: once per Aura day (habit nudges: per time, since the first may find nothing due). */
export function scheduleDedupeKey(kind: ScheduledKind, dueAt: Date, tz: string): string {
  const day = auraDay(dueAt, tz);
  return kind === 'habit_nudge' ? `${day}:${dueAt.toISOString()}` : day;
}

/** The Lantern Hour window from `matching_config` (defaults when the row or its values are missing). */
export async function loadLanternClock(q: Queryable): Promise<LanternClock> {
  try {
    const r = await q.query<{ lantern_start: string | null; lantern_end: string | null }>(
      'select lantern_start::text as lantern_start, lantern_end::text as lantern_end from public.matching_config where id',
    );
    const row = r.rows[0];
    if (!row?.lantern_start || !row.lantern_end) return DEFAULT_LANTERN_CLOCK;
    return { start: parseClockTime(row.lantern_start), end: parseClockTime(row.lantern_end) };
  } catch {
    return DEFAULT_LANTERN_CLOCK;
  }
}

/**
 * (Re-)plans every scheduled kind of one user: a row per wanted kind at its next instant in `tz`, no row otherwise.
 * Runs inside the sync push that changed the settings (and from reconcile).
 */
export async function planSchedules(
  q: Queryable,
  userId: string,
  tz: string,
  now: Date,
  prefs: NotificationPrefsValues,
  lantern?: LanternClock,
): Promise<void> {
  const clock = prefs.enabled && prefs.lanternHour ? (lantern ?? (await loadLanternClock(q))) : DEFAULT_LANTERN_CLOCK;
  for (const kind of SCHEDULED_KINDS) {
    const next = nextAtFor(kind, now, tz, prefs, clock);
    if (next === null) {
      await q.query('delete from public.notification_schedule where user_id = $1 and kind = $2', [userId, kind]);
    } else {
      await q.query(
        `insert into public.notification_schedule (user_id, kind, next_at, tz, planned_at) values ($1, $2, $3, $4, now())
         on conflict (user_id, kind) do update set next_at = excluded.next_at, tz = excluded.tz, planned_at = now()`,
        [userId, kind, next, tz],
      );
    }
  }
}

/** Milestone A + B prefs columns with the `np.` prefix, for joins (prefsFromRow reads them). */
export const NP_COLUMNS =
  'np.enabled, np.reminder_enabled, np.reminder_time::text as reminder_time, np.reminder_in_quiet_ok, ' +
  'np.capsule_enabled, np.quiet_start::text as quiet_start, np.quiet_end::text as quiet_end, np.discreet, ' +
  milestoneBPrefsSql('np');

interface DueRow {
  user_id: string;
  kind: ScheduledKind;
  next_at: Date;
  planned_tz: string;
  timezone: string;
  [column: string]: unknown;
}

export interface ScheduleSweepSummary {
  due: number;
  enqueued: number;
  /** Too late, zone changed, or no longer wanted: moved on without a push. */
  moved: number;
}

@Injectable()
export class ScheduleSweep {
  private readonly logger = new Logger('Schedules');

  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Worker bootstrap: both repeatable jobs (idempotent). */
  async ensureSchedulers(): Promise<void> {
    const q = this.queues.queue('notifications');
    const opts = { removeOnComplete: 10, removeOnFail: 50 };
    await q.upsertJobScheduler(SCHEDULE_SWEEP_SCHEDULER_ID, { every: SCHEDULE_SWEEP_EVERY_MS }, { name: SCHEDULE_SWEEP_JOB, data: {}, opts });
    await q.upsertJobScheduler(
      SCHEDULE_RECONCILE_SCHEDULER_ID,
      { every: SCHEDULE_RECONCILE_EVERY_MS },
      { name: SCHEDULE_RECONCILE_JOB, data: {}, opts },
    );
  }

  /**
   * Claims due rows and enqueues their pushes. Accounts with a scheduled deletion are left out. `only` limits the pass
   * to these accounts (e2e suites on a shared database); the worker passes nothing.
   */
  async sweep(now = new Date(), only: readonly string[] | null = null): Promise<ScheduleSweepSummary> {
    const due = await this.db.query<DueRow>(
      `select s.user_id, s.kind, s.next_at, s.tz as planned_tz, p.timezone, ${NP_COLUMNS}, np.field_ts
         from public.notification_schedule s
         join public.profiles p on p.user_id = s.user_id
         join public.notification_prefs np on np.user_id = s.user_id
        where s.next_at <= $1
          and ($3::uuid[] is null or s.user_id = any($3::uuid[]))
          and not exists (select 1 from public.account_deletions d where d.user_id = s.user_id)
        order by s.next_at
        limit $2`,
      [now, SCHEDULE_BATCH, only],
    );
    const out: ScheduleSweepSummary = { due: due.rowCount ?? 0, enqueued: 0, moved: 0 };
    const clock = due.rows.some((r) => r.kind === 'lantern_hour') ? await loadLanternClock(this.db) : DEFAULT_LANTERN_CLOCK;
    for (const row of due.rows) {
      const tz = row.timezone;
      const prefs = prefsFromRow(row as never).values;
      const next = nextAtFor(row.kind, now, tz, prefs, clock);
      const claimed =
        next === null
          ? await this.db.query('delete from public.notification_schedule where user_id = $1 and kind = $2 and next_at = $3', [
              row.user_id,
              row.kind,
              row.next_at,
            ])
          : await this.db.query(
              `update public.notification_schedule set next_at = $4, tz = $5, planned_at = now()
                where user_id = $1 and kind = $2 and next_at = $3`,
              [row.user_id, row.kind, row.next_at, next, tz],
            );
      if ((claimed.rowCount ?? 0) === 0) continue; // another sweep (or a settings change) got there first
      const late = now.getTime() - row.next_at.getTime() > SCHEDULE_MAX_LATE_MS[row.kind];
      if (next === null || late || row.planned_tz !== tz) {
        out.moved += 1;
        continue;
      }
      try {
        await this.notifications.enqueue(row.user_id, row.kind, null, {
          dedupeKey: scheduleDedupeKey(row.kind, row.next_at, tz),
        });
        out.enqueued += 1;
      } catch (err) {
        // Redis refused: put the plan back so the next sweep tries again.
        await this.db.query(
          `update public.notification_schedule set next_at = $3 where user_id = $1 and kind = $2 and next_at = $4`,
          [row.user_id, row.kind, row.next_at, next],
        );
        this.logger.warn(`${row.kind} enqueue failed (${err instanceof Error ? err.name : 'error'}); retried next sweep`);
      }
    }
    if (out.due) this.logger.log(`schedule sweep: due=${out.due} enqueued=${out.enqueued} moved=${out.moved}`);
    return out;
  }

  /** Plans missing rows, re-plans rows planned in another zone, deletes unwanted rows. Returns users re-planned. */
  async reconcile(now = new Date()): Promise<number> {
    const rows = await this.db.query<{ user_id: string; timezone: string; [column: string]: unknown }>(
      `with w as (
         select np.user_id, p.timezone, ${NP_COLUMNS}, np.field_ts,
                (np.enabled and np.wind_down_enabled and np.wind_down_time is not null) as wd,
                (np.enabled and np.lantern_opt_in) as lh,
                (np.enabled and np.habit_nudges <> '{}'::jsonb) as hn
           from public.notification_prefs np
           join public.profiles p on p.user_id = np.user_id
       )
       select * from w
        where (w.wd and not exists (select 1 from public.notification_schedule s
                                     where s.user_id = w.user_id and s.kind = 'wind_down_reminder' and s.tz = w.timezone))
           or (w.lh and not exists (select 1 from public.notification_schedule s
                                     where s.user_id = w.user_id and s.kind = 'lantern_hour' and s.tz = w.timezone))
           or (w.hn and not exists (select 1 from public.notification_schedule s
                                     where s.user_id = w.user_id and s.kind = 'habit_nudge' and s.tz = w.timezone))
           or exists (select 1 from public.notification_schedule s
                       where s.user_id = w.user_id
                         and ((s.kind = 'wind_down_reminder' and not w.wd) or (s.kind = 'lantern_hour' and not w.lh)
                              or (s.kind = 'habit_nudge' and not w.hn)))
        limit $1`,
      [SCHEDULE_BATCH],
    );
    if (rows.rows.length === 0) return 0;
    const clock = await loadLanternClock(this.db);
    for (const row of rows.rows) {
      await planSchedules(this.db, row.user_id, row.timezone, now, prefsFromRow(row as never).values, clock);
    }
    return rows.rows.length;
  }
}
