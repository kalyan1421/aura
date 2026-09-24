import { Injectable, Logger } from '@nestjs/common';
import { zonedInstant } from '../capsules/capsule-rules';
import { DbService } from '../db/db.service';
import { QueuesService } from '../queues/queues.service';
import { auraDay, ROLLOVER_HOUR } from '../rules';
import { NotificationsService } from './notifications.service';

/**
 * "Gestures received" (PRD 12 catalogue: "Gesture sent to you in a room · Push (batched) + in-app · 1 push per room
 * per day"; copy "3 people in your room sent you warmth."). contracts/api/v1-notifications.md §9.
 *
 * `gestures-sweep` (every 5 min, `notifications` queue) reads the gestures sent TO a member (not room-wide ones, never
 * dropped ones — over-limit, shadow-muted, blocked, muted, hidden) in the last {@link GESTURE_LOOKBACK_MS}. A
 * (recipient, room) pair is ready once a gesture of the recipient's current Aura day is at least
 * {@link GESTURE_BATCH_WINDOW_MS} old: gestures arriving close together travel as one push. The pair's row in
 * `public.gesture_push_log` (recipient, room, Aura day) is written in the same transaction as the enqueue, so each room
 * gives at most one push a day (Redis refusing → rolled back, retried next sweep). The job carries only the room id
 * (opaque); delivery counts the distinct senders itself (never their pseudonyms) and renders "Someone …" / "{count}
 * people in your room sent you warmth." Everything else is the global rules: toggle, quiet hours (dropped: the room
 * shows the gestures), the 2/day cap. The room itself keeps showing the gestures (the in-app side).
 */
export const GESTURES_SWEEP_JOB = 'gestures-sweep';
export const GESTURES_SCHEDULER_ID = 'aura-gestures-sweep';
export const GESTURES_SWEEP_EVERY_MS = 5 * 60_000;
export const GESTURE_BATCH_WINDOW_MS = 10 * 60_000;
export const GESTURE_LOOKBACK_MS = 6 * 3600_000;
export const GESTURES_BATCH = 500;

/** When the Aura day containing `now` began in `tz` (04:00 local). */
export function auraDayStart(now: Date, tz: string): Date {
  return zonedInstant(auraDay(now, tz), ROLLOVER_HOUR, 0, tz);
}

export interface GesturesSweepSummary {
  candidates: number;
  enqueued: number;
}

@Injectable()
export class GesturesPushSweep {
  private readonly logger = new Logger('GesturesPush');

  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
    private readonly notifications: NotificationsService,
  ) {}

  async ensureScheduler(): Promise<void> {
    await this.queues
      .queue('notifications')
      .upsertJobScheduler(
        GESTURES_SCHEDULER_ID,
        { every: GESTURES_SWEEP_EVERY_MS },
        { name: GESTURES_SWEEP_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      );
  }

  /** One pass. `only` limits it to these recipients (e2e suites on a shared database); the worker passes nothing. */
  async sweep(now = new Date(), only: readonly string[] | null = null): Promise<GesturesSweepSummary> {
    const r = await this.db.query<{ user_id: string; room_id: string; timezone: string; ready_at: Date }>(
      `select m.user_id, g.room_id, p.timezone, max(g.created_at) as ready_at
         from public.room_gestures g
         join public.room_members m on m.room_id = g.room_id and m.member_id = g.to_member_id
         join public.profiles p on p.user_id = m.user_id
         left join public.notification_prefs np on np.user_id = m.user_id
        where g.to_member_id is not null and g.dropped is null
          and g.created_at > $1::timestamptz - make_interval(secs => $2::double precision)
          and g.created_at <= $1::timestamptz - make_interval(secs => $3::double precision)
          and coalesce(np.enabled, true) and coalesce(np.gestures_enabled, true)
          and not exists (select 1 from public.account_deletions d where d.user_id = m.user_id)
          and ($5::uuid[] is null or m.user_id = any($5::uuid[]))
          and not exists (select 1 from public.gesture_push_log l
                           where l.user_id = m.user_id and l.room_id = g.room_id
                             and l.created_at > $1::timestamptz - make_interval(secs => $2::double precision))
        group by m.user_id, g.room_id, p.timezone
        limit $4`,
      [now, GESTURE_LOOKBACK_MS / 1000, GESTURE_BATCH_WINDOW_MS / 1000, GESTURES_BATCH, only],
    );
    const out: GesturesSweepSummary = { candidates: r.rowCount ?? 0, enqueued: 0 };
    for (const row of r.rows) {
      // Only today's gestures count (yesterday's evening room had its own day).
      if (row.ready_at.getTime() < auraDayStart(now, row.timezone).getTime()) continue;
      const day = auraDay(now, row.timezone);
      try {
        const sent = await this.db.withTx(async (tx) => {
          const logged = await tx.query(
            `insert into public.gesture_push_log (user_id, room_id, local_day) values ($1, $2, $3::date)
             on conflict do nothing`,
            [row.user_id, row.room_id, day],
          );
          if ((logged.rowCount ?? 0) === 0) return false;
          await this.notifications.enqueue(row.user_id, 'gestures_received', row.room_id, { dedupeKey: `${row.room_id}:${day}` });
          return true;
        });
        if (sent) out.enqueued += 1;
      } catch (err) {
        this.logger.warn(`gestures push enqueue failed (${err instanceof Error ? err.name : 'error'}); retried next sweep`);
      }
    }
    if (out.enqueued) this.logger.log(`gestures sweep: candidates=${out.candidates} enqueued=${out.enqueued}`);
    return out;
  }
}
