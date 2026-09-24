import { Injectable, Logger } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { QueuesService } from '../queues/queues.service';
import { NotificationsService } from './notifications.service';
import { minutesOfDay } from './policy';

/**
 * "Welcome back" (PRD 12 catalogue: "7 days inactive; again at day 21 … 2 per absence, then silence"; copy "No
 * catch-up needed. Aura is here whenever you want a quiet minute."). contracts/api/v1-notifications.md §8.
 *
 * Inactive = the account wrote nothing: no sync push (check-in, habit, capsule, setting, Sanctuary session, …) and no
 * profile / device / room call (`device_installs`). Triggers keep `public.notification_activity.last_active_at`
 * current and reset the absence's push count (`welcome_step`) on any such write; Aura keeps no other "last seen".
 *
 * `welcome-back-sweep` (every 15 min): an account whose absence reached 7 days (1st push) or 21 days (2nd push, and at
 * least 7 days after the 1st) gets one push — sent in its early evening ({@link WELCOME_BACK_FROM_HOUR}–
 * {@link WELCOME_BACK_UNTIL_HOUR} local, `[ASSUMPTION]`: a calm hour, outside default quiet hours). The claim bumps
 * `welcome_step` first, so a push is never repeated; after two, silence until the person writes something again.
 * Absences longer than {@link WELCOME_BACK_MAX_DAYS} days are left alone. Delivery re-checks that the person hasn't
 * come back meanwhile and applies every global rule (toggle, quiet hours, the 2/day cap — lowest precedence).
 */
export const WELCOME_BACK_SWEEP_JOB = 'welcome-back-sweep';
export const WELCOME_BACK_SCHEDULER_ID = 'aura-welcome-back-sweep';
export const WELCOME_BACK_EVERY_MS = 15 * 60_000;
export const WELCOME_BACK_DAYS = [7, 21] as const;
/** At least this long between the two pushes of one absence (an account first seen already 21+ days away). */
export const WELCOME_BACK_MIN_GAP_DAYS = 7;
export const WELCOME_BACK_MAX_DAYS = 60;
export const WELCOME_BACK_FROM_HOUR = 18;
export const WELCOME_BACK_UNTIL_HOUR = 21;
export const WELCOME_BACK_BATCH = 500;

/** Inside the early-evening send window in `tz`? */
export function inWelcomeWindow(now: Date, tz: string): boolean {
  const m = minutesOfDay(now, tz);
  return m >= WELCOME_BACK_FROM_HOUR * 60 && m < WELCOME_BACK_UNTIL_HOUR * 60;
}

export interface WelcomeBackSummary {
  candidates: number;
  enqueued: number;
}

@Injectable()
export class WelcomeBackSweep {
  private readonly logger = new Logger('WelcomeBack');

  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
    private readonly notifications: NotificationsService,
  ) {}

  async ensureScheduler(): Promise<void> {
    await this.queues
      .queue('notifications')
      .upsertJobScheduler(
        WELCOME_BACK_SCHEDULER_ID,
        { every: WELCOME_BACK_EVERY_MS },
        { name: WELCOME_BACK_SWEEP_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      );
  }

  /** One pass. `only` limits it to these accounts (e2e suites on a shared database); the worker passes nothing. */
  async sweep(now = new Date(), only: readonly string[] | null = null): Promise<WelcomeBackSummary> {
    const r = await this.db.query<{
      user_id: string;
      last_active_at: Date;
      /** Full precision (µs): the claim compares with it (a JS Date keeps only ms). */
      last_active_text: string;
      welcome_step: number;
      welcome_sent_at: Date | null;
      timezone: string;
    }>(
      `select a.user_id, a.last_active_at, a.last_active_at::text as last_active_text, a.welcome_step, a.welcome_sent_at, p.timezone
         from public.notification_activity a
         join public.profiles p on p.user_id = a.user_id
         left join public.notification_prefs np on np.user_id = a.user_id
        where a.welcome_step < 2
          and a.last_active_at <= $1::timestamptz - make_interval(days => case a.welcome_step when 0 then $2::int else $3::int end)
          and a.last_active_at > $1::timestamptz - make_interval(days => $4::int)
          and (a.welcome_sent_at is null or a.welcome_sent_at <= $1::timestamptz - make_interval(days => $5::int))
          and coalesce(np.enabled, true) and coalesce(np.welcome_back_enabled, true)
          and not exists (select 1 from public.account_deletions d where d.user_id = a.user_id)
          and ($7::uuid[] is null or a.user_id = any($7::uuid[]))
        order by a.last_active_at
        limit $6`,
      [now, WELCOME_BACK_DAYS[0], WELCOME_BACK_DAYS[1], WELCOME_BACK_MAX_DAYS, WELCOME_BACK_MIN_GAP_DAYS, WELCOME_BACK_BATCH, only],
    );
    const out: WelcomeBackSummary = { candidates: r.rowCount ?? 0, enqueued: 0 };
    for (const row of r.rows) {
      if (!inWelcomeWindow(now, row.timezone)) continue;
      // Claim: only while the absence and its step are what we read (a write meanwhile resets the step).
      const claimed = await this.db.query(
        `update public.notification_activity set welcome_step = welcome_step + 1, welcome_sent_at = $4
          where user_id = $1 and welcome_step = $2 and last_active_at = $3::timestamptz`,
        [row.user_id, row.welcome_step, row.last_active_text, now],
      );
      if ((claimed.rowCount ?? 0) === 0) continue;
      try {
        await this.notifications.enqueue(row.user_id, 'welcome_back', null, {
          dedupeKey: `${row.last_active_at.toISOString()}:${row.welcome_step}`,
        });
        out.enqueued += 1;
      } catch (err) {
        await this.db.query(
          `update public.notification_activity set welcome_step = $2, welcome_sent_at = $4
            where user_id = $1 and welcome_step = $2 + 1 and last_active_at = $3::timestamptz`,
          [row.user_id, row.welcome_step, row.last_active_text, row.welcome_sent_at],
        );
        this.logger.warn(`welcome-back enqueue failed (${err instanceof Error ? err.name : 'error'}); retried next sweep`);
      }
    }
    if (out.enqueued) this.logger.log(`welcome-back sweep: candidates=${out.candidates} enqueued=${out.enqueued}`);
    return out;
  }
}
