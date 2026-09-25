import { Injectable, Logger } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { QueuesService } from '../queues/queues.service';
import { NotificationsService } from './notifications.service';
import { prefsFromRow } from './notification-prefs';
import { auraDayOf, nextReminderAt } from './policy';

/**
 * The daily check-in reminder's schedule (PRD 12-notifications catalogue: user-chosen time, suggested 20:00; skipped
 * once the user checked in that Aura day — decided at delivery).
 *
 * `notification_prefs.reminder_next_at` holds each user's next reminder instant, planned in the PROFILE timezone
 * (re-planned in the sync push whenever a setting changes). Two repeatable jobs on the `notifications` queue:
 *   - `reminder-sweep` (every minute): claims rows whose instant has come (`reminder_next_at <= now`, indexed),
 *     moves them to the next day's instant and enqueues one `daily_reminder` push each (deduplicated per user + Aura
 *     day). More than 2 h late (worker outage) → not sent, just moved on. Timing is ±1 min; the PRD allows ±15.
 *   - `reminder-reconcile` (every 10 min, like the capsule sweep): re-plans rows whose profile timezone changed since
 *     they were planned (the app re-sends `POST /v1/profile` when the device zone changes, so a move takes effect
 *     within ~10 min) and repairs rows whose plan is missing or no longer wanted.
 * Smart timing (rule 7: back off after ignored reminders) is decided at delivery (policy.ts `smartTimingSkip`): the
 * sweep keeps planning one a day; delivery skips it while the person is ignoring them.
 */
export const REMINDER_SWEEP_JOB = 'reminder-sweep';
export const REMINDER_RECONCILE_JOB = 'reminder-reconcile';
export const REMINDER_SWEEP_SCHEDULER_ID = 'aura-reminder-sweep';
export const REMINDER_RECONCILE_SCHEDULER_ID = 'aura-reminder-reconcile';
export const REMINDER_SWEEP_EVERY_MS = 60_000;
export const REMINDER_RECONCILE_EVERY_MS = 10 * 60_000;
/** A reminder this late (worker outage) is dropped: a nudge at the wrong time is worse than none. */
export const REMINDER_MAX_LATE_MS = 2 * 3600_000;
export const REMINDER_BATCH = 500;

export interface ReminderSweepSummary {
  due: number;
  enqueued: number;
  /** Too late to send, or the zone changed since planning: moved on without a push. */
  moved: number;
}

interface DueRow {
  user_id: string;
  reminder_next_at: Date;
  reminder_tz: string | null;
  timezone: string;
  enabled: boolean;
  reminder_enabled: boolean;
  reminder_time: string | null;
  reminder_in_quiet_ok: boolean;
  capsule_enabled: boolean;
  quiet_start: string;
  quiet_end: string;
  discreet: boolean;
}

const PLAN_COLUMNS = `np.enabled, np.reminder_enabled, np.reminder_time::text as reminder_time, np.reminder_in_quiet_ok,
  np.capsule_enabled, np.quiet_start::text as quiet_start, np.quiet_end::text as quiet_end, np.discreet`;

const valuesOf = (r: DueRow) => prefsFromRow({ ...r, field_ts: null }).values;

@Injectable()
export class ReminderScheduler {
  private readonly logger = new Logger('Reminders');

  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Worker bootstrap: register both repeatable jobs (idempotent). */
  async ensureSchedulers(): Promise<void> {
    const q = this.queues.queue('notifications');
    const opts = { removeOnComplete: 10, removeOnFail: 50 };
    await q.upsertJobScheduler(REMINDER_SWEEP_SCHEDULER_ID, { every: REMINDER_SWEEP_EVERY_MS }, { name: REMINDER_SWEEP_JOB, data: {}, opts });
    await q.upsertJobScheduler(
      REMINDER_RECONCILE_SCHEDULER_ID,
      { every: REMINDER_RECONCILE_EVERY_MS },
      { name: REMINDER_RECONCILE_JOB, data: {}, opts },
    );
  }

  /** Claims due reminders and enqueues their pushes. Accounts with a scheduled deletion are left out. */
  async sweep(now = new Date()): Promise<ReminderSweepSummary> {
    const due = await this.db.query<DueRow>(
      `select np.user_id, np.reminder_next_at, np.reminder_tz, p.timezone, ${PLAN_COLUMNS}
         from public.notification_prefs np
         join public.profiles p on p.user_id = np.user_id
        where np.reminder_next_at <= $1
          and not exists (select 1 from public.account_deletions d where d.user_id = np.user_id)
        order by np.reminder_next_at
        limit $2`,
      [now, REMINDER_BATCH],
    );
    const out: ReminderSweepSummary = { due: due.rowCount ?? 0, enqueued: 0, moved: 0 };
    for (const row of due.rows) {
      const tz = row.timezone;
      const next = nextReminderAt(now, tz, valuesOf(row));
      // Claim: only the sweep that moves this exact plan on sends it (overlapping sweeps can't double-send).
      const claimed = await this.db.query(
        `update public.notification_prefs set reminder_next_at = $2, reminder_tz = $3
          where user_id = $1 and reminder_next_at = $4`,
        [row.user_id, next, next ? tz : null, row.reminder_next_at],
      );
      if ((claimed.rowCount ?? 0) === 0) continue;
      const late = now.getTime() - row.reminder_next_at.getTime() > REMINDER_MAX_LATE_MS;
      const zoneMoved = row.reminder_tz !== null && row.reminder_tz !== tz; // planned in another zone: re-planned only
      if (next === null || late || zoneMoved) {
        out.moved += 1;
        continue;
      }
      try {
        await this.notifications.enqueue(row.user_id, 'daily_reminder', null, {
          dedupeKey: auraDayOf(row.reminder_next_at, tz),
        });
        out.enqueued += 1;
      } catch (err) {
        // Redis refused: put the plan back so the next sweep tries again.
        await this.db.query(
          'update public.notification_prefs set reminder_next_at = $2 where user_id = $1 and reminder_next_at = $3',
          [row.user_id, row.reminder_next_at, next],
        );
        this.logger.warn(`reminder enqueue failed (${err instanceof Error ? err.name : 'error'}); retried next sweep`);
      }
    }
    return out;
  }

  /**
   * Re-plans reminders whose profile zone changed since planning, plans enabled reminders that have no plan, and
   * clears plans that are no longer wanted. Returns how many rows changed.
   */
  async reconcile(now = new Date()): Promise<number> {
    const rows = await this.db.query<DueRow>(
      `select np.user_id, np.reminder_next_at, np.reminder_tz, p.timezone, ${PLAN_COLUMNS}
         from public.notification_prefs np
         join public.profiles p on p.user_id = np.user_id
        where (np.enabled and np.reminder_enabled and np.reminder_time is not null
               and (np.reminder_next_at is null or np.reminder_tz is distinct from p.timezone))
           or ((not np.enabled or not np.reminder_enabled or np.reminder_time is null) and np.reminder_next_at is not null)
        limit $1`,
      [REMINDER_BATCH],
    );
    let changed = 0;
    for (const row of rows.rows) {
      const next = nextReminderAt(now, row.timezone, valuesOf(row));
      const r = await this.db.query(
        `update public.notification_prefs set reminder_next_at = $2, reminder_tz = $3
          where user_id = $1 and reminder_next_at is not distinct from $4`,
        [row.user_id, next, next ? row.timezone : null, row.reminder_next_at],
      );
      changed += r.rowCount ?? 0;
    }
    return changed;
  }
}
