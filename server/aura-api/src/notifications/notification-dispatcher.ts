import { Inject, Injectable, Logger } from '@nestjs/common';
import { DelayedError, type Job } from 'bullmq';
import { NotificationDelivery } from './delivery.service';
import { NOTIFICATION_JOB, parseNotificationJob } from './notification-types';
import { POOL_OPEN_SWEEP_JOB, PoolOpenSweep } from './pool-waitlist';
import { REMINDER_RECONCILE_JOB, REMINDER_SWEEP_JOB, ReminderScheduler } from './reminder.service';

/** Deferred pushes (quiet hours) spread over this window after the quiet hours end, so they don't all land at 08:00. */
export const DEFER_JITTER_MS = 10 * 60_000;

/**
 * Worker side of the `notifications` queue (WorkerHostService): `push` jobs go through NotificationDelivery (every
 * global rule, then the transport); `reminder-sweep` / `reminder-reconcile` run the daily-reminder schedule. A push
 * deferred by quiet hours is re-delayed in place (same job, BullMQ `moveToDelayed`). Logs never carry ids.
 */
@Injectable()
export class NotificationDispatcher {
  private readonly logger = new Logger('Notifications');

  constructor(
    private readonly delivery: NotificationDelivery,
    private readonly reminders: ReminderScheduler,
    /** Always injected by Nest (explicit token); optional only for hand-built unit tests. */
    @Inject(PoolOpenSweep) private readonly poolOpen?: PoolOpenSweep,
  ) {}

  /** Registers the repeatable reminder jobs (worker bootstrap). */
  async ensureSchedulers(): Promise<void> {
    await this.reminders.ensureSchedulers();
    await this.poolOpen?.ensureScheduler();
    this.logger.log(`push transport: ${this.delivery.transportName}`);
  }

  async handle(job: Job, token?: string, now = new Date()): Promise<void> {
    switch (job.name) {
      case NOTIFICATION_JOB:
        return this.push(job, token, now);
      case REMINDER_SWEEP_JOB: {
        const s = await this.reminders.sweep(now);
        if (s.due) this.logger.log(`reminder sweep: due=${s.due} enqueued=${s.enqueued} moved=${s.moved}`);
        return;
      }
      case REMINDER_RECONCILE_JOB: {
        const n = await this.reminders.reconcile(now);
        if (n) this.logger.log(`reminder reconcile: re-planned ${n}`);
        return;
      }
      case POOL_OPEN_SWEEP_JOB:
        await this.poolOpen?.sweep();
        return;
      default:
        this.logger.warn(`ignored unknown notifications job ${job.name}`);
    }
  }

  private async push(job: Job, token: string | undefined, now: Date): Promise<void> {
    const n = parseNotificationJob(job.data);
    if (!n) {
      this.logger.warn(`dropped a malformed notifications job (name=${job.name})`);
      return;
    }
    const out = await this.delivery.deliver(n, now, new Date(job.timestamp || now.getTime()));
    if (out.status === 'deferred') {
      const at = out.until.getTime() + Math.floor(Math.random() * DEFER_JITTER_MS);
      await job.moveToDelayed(at, token);
      throw new DelayedError(); // BullMQ: the job was moved, not failed
    }
    if (out.status === 'skipped') this.logger.debug(`push ${n.type}: skipped (${out.reason})`);
  }
}
