import { createHash } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { DelayedError, type Job } from 'bullmq';
import { isUuid } from '../common/uuid';
import { pgCode } from '../db/db';
import { DbService } from '../db/db.service';
import { NotificationsService } from '../notifications/notifications.service';
import { QueuesService } from '../queues/queues.service';
import { unlockAt } from './capsule-rules';

/**
 * "Date capsule unlocked" push (PRD Notifications; contracts/api/v1-capsules.md §6). The app's local notification
 * is primary; this is the deduplicated server backup:
 *   - one BullMQ delayed job per pending date capsule on queue `capsule-unlock` (opaque job id `unlockJobId(id)`,
 *     data `{ capsuleId }` only) at 10:00 on the unlock date in the user's CURRENT profile timezone;
 *   - when it runs it re-reads the zone: moved west → re-delayed to the new 10:00; sealed/opened/deleted → nothing;
 *   - a sweep (every 10 min, same queue) re-schedules capsules whose profile timezone changed (moved east →
 *     earlier), schedules capsules whose job was never created, and handles overdue ones whose job was lost;
 *   - at most one push per user per unlock date (NotificationsService dedupe key), never more than 24 h late.
 * `public.capsule_unlock_schedule` records what was scheduled (notify_at, notify_tz) and whether it was sent.
 * Logs carry counts and statuses only — never user ids, capsule ids or dates.
 */
export const CAPSULE_UNLOCK_QUEUE = 'capsule-unlock' as const;
export const UNLOCK_JOB = 'unlock';
export const SWEEP_JOB = 'sweep';
export const SWEEP_SCHEDULER_ID = 'aura-capsule-unlock-sweep';
export const SWEEP_EVERY_MS = 10 * 60_000;
export const SWEEP_BATCH = 500;
/** A job this far past its time without having run (lost job, worker outage) is handled by the sweep. */
export const OVERDUE_AFTER_MS = 15 * 60_000;
/** The push belongs to the unlock day: more than this late (e.g. a seal synced long after its date) → not sent. */
export const MAX_LATE_MS = 24 * 3600_000;
/** A job that runs earlier than this before 10:00 in the current zone (the zone moved west) is re-delayed. */
export const EARLY_TOLERANCE_MS = 60_000;
/** An existing delayed job within this of the wanted time is left alone. */
const SAME_TIME_MS = 5_000;

/**
 * Deterministic job id per capsule (so re-scheduling replaces instead of piling up), but opaque: the worker logs
 * failed job ids, and logs never carry record ids.
 */
export const unlockJobId = (capsuleId: string): string =>
  `unlock-${createHash('sha256').update(`capsule-unlock\n${capsuleId.toLowerCase()}`).digest('hex').slice(0, 32)}`;

const JOB_OPTS = {
  attempts: 5,
  backoff: { type: 'exponential', delay: 60_000 },
  removeOnComplete: true,
  removeOnFail: { age: 7 * 24 * 3600 },
} as const;

export type UnlockOutcome =
  | { status: 'notified' }
  | { status: 'early'; at: Date }
  | { status: 'too_late' }
  | { status: 'already_notified' }
  /** Opened, deleted, not a date capsule, or no profile: no push, bookkeeping dropped. */
  | { status: 'skipped' }
  /** No such capsule (e.g. the account was purged). */
  | { status: 'gone' };

export interface SweepSummary {
  scheduled: number;
  overdue: number;
  notified: number;
}

interface UnlockRow {
  user_id: string;
  unlock_type: 'date' | 'mood';
  unlock_local_date: string | null;
  deleted: boolean;
  opened: boolean;
  timezone: string | null;
  notified_at: Date | null;
}

@Injectable()
export class CapsuleUnlockService {
  private readonly logger = new Logger('CapsuleUnlock');

  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
    private readonly notifications: NotificationsService,
  ) {}

  private queue() {
    return this.queues.queue(CAPSULE_UNLOCK_QUEUE);
  }

  /**
   * (Re)schedule the unlock push of these capsules — only pending date capsules not yet notified; others are
   * ignored. Called by the API after a push that sealed date capsules commits, and by the sweep. Returns how many
   * were scheduled.
   */
  async schedule(capsuleIds: string[], now = new Date()): Promise<number> {
    if (capsuleIds.length === 0) return 0;
    const r = await this.db.query<{ id: string; unlock_local_date: string; timezone: string }>(
      `select c.id, c.unlock_local_date, p.timezone
         from public.capsules c
         join public.profiles p on p.user_id = c.user_id
         left join public.capsule_unlock_schedule s on s.capsule_id = c.id
        where c.id = any($1::uuid[]) and c.unlock_type = 'date' and c.deleted_at is null and c.opened_at is null
          and s.notified_at is null`,
      [capsuleIds],
    );
    let n = 0;
    for (const row of r.rows) {
      const at = unlockAt(row.unlock_local_date, row.timezone);
      await this.putJob(row.id, at, now);
      try {
        await this.upsertSchedule(row.id, at, row.timezone);
      } catch (err) {
        if (pgCode(err) === '23503') continue; // the capsule was purged meanwhile; its job finds nothing
        throw err;
      }
      n += 1;
    }
    return n;
  }

  /** Cancel the pending unlock jobs of these capsules (opened / deleted / purged). Best-effort per job. */
  async unschedule(capsuleIds: string[]): Promise<void> {
    for (const id of capsuleIds) {
      const job = await this.queue().getJob(unlockJobId(id));
      if (!job || (await job.getState()) === 'active') continue; // a running job re-checks the capsule itself
      await job.remove().catch(() => undefined);
    }
  }

  /** The decision for one capsule, at `now` (the job at its time, or the sweep for an overdue one). */
  async process(capsuleId: string, now = new Date()): Promise<UnlockOutcome> {
    const r = await this.db.query<UnlockRow>(
      `select c.user_id, c.unlock_type, c.unlock_local_date, c.deleted_at is not null as deleted,
              c.opened_at is not null as opened, p.timezone, s.notified_at
         from public.capsules c
         left join public.profiles p on p.user_id = c.user_id
         left join public.capsule_unlock_schedule s on s.capsule_id = c.id
        where c.id = $1`,
      [capsuleId],
    );
    const row = r.rows[0];
    if (!row) return { status: 'gone' };
    if (row.unlock_type !== 'date' || row.deleted || row.opened || !row.timezone || !row.unlock_local_date) {
      await this.db.query('delete from public.capsule_unlock_schedule where capsule_id = $1', [capsuleId]);
      return { status: 'skipped' };
    }
    if (row.notified_at) return { status: 'already_notified' };

    const at = unlockAt(row.unlock_local_date, row.timezone);
    if (at.getTime() - now.getTime() > EARLY_TOLERANCE_MS) {
      await this.upsertSchedule(capsuleId, at, row.timezone); // the zone moved west since scheduling
      return { status: 'early', at };
    }
    if (now.getTime() - at.getTime() > MAX_LATE_MS) {
      await this.markNotified(capsuleId, at, row.timezone);
      return { status: 'too_late' };
    }
    // Enqueue first (deduplicated per user + unlock date), then record: a retry after a failed update is harmless.
    await this.notifications.enqueue(row.user_id, 'capsule_unlocked', capsuleId, { dedupeKey: row.unlock_local_date });
    await this.markNotified(capsuleId, at, row.timezone);
    return { status: 'notified' };
  }

  /**
   * Worker: (1) schedule never-scheduled capsules and re-schedule those whose profile timezone changed since;
   * (2) handle capsules whose job should have run more than 15 min ago.
   */
  async sweep(now = new Date()): Promise<SweepSummary> {
    const stale = await this.db.query<{ id: string }>(
      `select c.id
         from public.capsules c
         join public.profiles p on p.user_id = c.user_id
         left join public.capsule_unlock_schedule s on s.capsule_id = c.id
        where c.unlock_type = 'date' and c.deleted_at is null and c.opened_at is null
          and (s.capsule_id is null or (s.notified_at is null and s.notify_tz is distinct from p.timezone))
        order by c.unlock_local_date
        limit $1`,
      [SWEEP_BATCH],
    );
    const scheduled = await this.schedule(
      stale.rows.map((x) => x.id),
      now,
    );
    const overdue = await this.db.query<{ capsule_id: string }>(
      `select capsule_id from public.capsule_unlock_schedule
        where notified_at is null and notify_at < $1
        order by notify_at
        limit $2`,
      [new Date(now.getTime() - OVERDUE_AFTER_MS), SWEEP_BATCH],
    );
    let notified = 0;
    for (const { capsule_id } of overdue.rows) {
      if ((await this.process(capsule_id, now)).status === 'notified') notified += 1;
    }
    return { scheduled, overdue: overdue.rowCount ?? 0, notified };
  }

  /** The `capsule-unlock` queue processor (worker). */
  async handle(job: Job, token?: string): Promise<void> {
    if (job.name === SWEEP_JOB) {
      const s = await this.sweep();
      if (s.scheduled || s.overdue) this.logger.log(`sweep: scheduled=${s.scheduled} overdue=${s.overdue} notified=${s.notified}`);
      return;
    }
    if (job.name !== UNLOCK_JOB) {
      this.logger.warn(`ignored unknown capsule-unlock job ${job.name}`);
      return;
    }
    const capsuleId = (job.data as { capsuleId?: unknown } | undefined)?.capsuleId;
    if (!isUuid(capsuleId)) {
      this.logger.warn('dropped a malformed unlock job');
      return;
    }
    const out = await this.process(capsuleId.toLowerCase());
    if (out.status === 'early') {
      // Same job id, new time: BullMQ's documented way to re-delay a job from inside its processor.
      await job.moveToDelayed(out.at.getTime(), token);
      throw new DelayedError();
    }
    this.logger.debug(`unlock job: ${out.status}`);
  }

  /** Register the repeatable sweep (worker bootstrap; idempotent). */
  async ensureSweepScheduler(): Promise<void> {
    await this.queue().upsertJobScheduler(
      SWEEP_SCHEDULER_ID,
      { every: SWEEP_EVERY_MS },
      { name: SWEEP_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
    );
  }

  private async putJob(capsuleId: string, at: Date, now: Date): Promise<void> {
    const q = this.queue();
    const jobId = unlockJobId(capsuleId);
    const existing = await q.getJob(jobId);
    if (existing) {
      const state = await existing.getState();
      if (state === 'active') return; // running right now: it re-reads the zone itself
      if (state === 'delayed' && Math.abs(existing.timestamp + (existing.delay ?? 0) - at.getTime()) <= SAME_TIME_MS) return;
      await existing.remove();
    }
    await q.add(UNLOCK_JOB, { capsuleId }, { ...JOB_OPTS, jobId, delay: Math.max(0, at.getTime() - now.getTime()) });
  }

  private async upsertSchedule(capsuleId: string, at: Date, tz: string): Promise<void> {
    await this.db.query(
      `insert into public.capsule_unlock_schedule (capsule_id, notify_at, notify_tz) values ($1, $2, $3)
       on conflict (capsule_id) do update
         set notify_at = excluded.notify_at, notify_tz = excluded.notify_tz, updated_at = now()
         where public.capsule_unlock_schedule.notified_at is null`,
      [capsuleId, at, tz],
    );
  }

  private async markNotified(capsuleId: string, at: Date, tz: string): Promise<void> {
    await this.db.query(
      `insert into public.capsule_unlock_schedule (capsule_id, notify_at, notify_tz, notified_at) values ($1, $2, $3, now())
       on conflict (capsule_id) do update
         set notified_at = coalesce(public.capsule_unlock_schedule.notified_at, now()), updated_at = now()`,
      [capsuleId, at, tz],
    );
  }
}
