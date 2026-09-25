import { Injectable, Logger, Module, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Queue, Worker, type Job } from 'bullmq';
import { AppConfig } from '../config/app-config';
import { DbService } from '../db/db.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { NotificationsService } from '../notifications/notifications.service';
import { QUEUE_PREFIX } from '../queues/queue-names';
import { QueuesService } from '../queues/queues.service';
import { redisOptionsFromUrl } from '../queues/redis';
import { UserMailWorkerHost, UserMailWorkerModule } from '../user-mail/user-mail.worker';
import { BillingCoreModule } from './billing.module';
import { expireOpenGifts } from './gifts';
import { StoreSync, errCode } from './store-sync.service';
import { claimTrialReminders, releaseTrialReminder } from './trial-reminder';

/**
 * Worker side of F12 (its own BullMQ queue `billing`, self-contained like the reflections worker):
 *  - `tick` every 10 min: trial-ending reminders (PRD 12: the push, then its email twin via src/user-mail), retry
 *    of failed / unhandled store notifications, a rolling reconcile of live subscriptions not confirmed with their
 *    store in 20 h (so every one is re-read at least daily — REQ-PAY-10 "reconciliation repairs a dropped
 *    notification"), entitlements whose period ran out, gift checks past their 7-day window;
 *  - `daily` 03:41 UTC: Play Voided Purchases API (refunds / chargebacks), Google one-time purchases still to be
 *    acknowledged or consumed (3-day rule), store_notifications older than 400 days pruned `[ASSUMPTION]`.
 * Logs counts and reason codes only.
 */
export const BILLING_QUEUE = 'billing';
export const BILLING_TICK_MS = 10 * 60_000;
export const BILLING_DAILY_CRON = '41 3 * * *';
export const NOTIFICATION_LOG_RETENTION_DAYS = 400;

@Injectable()
export class BillingWorkerHost implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger('BillingWorker');
  private queue: Queue | null = null;
  private worker: Worker | null = null;

  constructor(
    private readonly app: AppConfig,
    private readonly queues: QueuesService,
    private readonly db: DbService,
    private readonly sync: StoreSync,
    private readonly notifications: NotificationsService,
    private readonly userMail: UserMailWorkerHost,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    this.queue = new Queue(BILLING_QUEUE, { connection: this.queues.redis, prefix: QUEUE_PREFIX });
    this.worker = new Worker(BILLING_QUEUE, (job) => this.handle(job), {
      connection: redisOptionsFromUrl(this.app.redisUrl),
      prefix: QUEUE_PREFIX,
      concurrency: 1,
    });
    this.worker.on('failed', (job, err) => this.logger.warn(`job ${job?.name} failed: ${errCode(err)}`));
    this.worker.on('error', (err) => this.logger.warn(`worker: ${err.message}`));
    const opts = { removeOnComplete: 10, removeOnFail: 50 };
    await this.queue.upsertJobScheduler('aura-billing-tick', { every: BILLING_TICK_MS }, { name: 'tick', data: {}, opts });
    await this.queue.upsertJobScheduler('aura-billing-daily', { pattern: BILLING_DAILY_CRON, tz: 'UTC' }, { name: 'daily', data: {}, opts });
    await this.worker.waitUntilReady();
    this.logger.log('billing worker ready (tick every 10 min, daily 03:41 UTC)');
  }

  async handle(job: Job, now = new Date()): Promise<void> {
    if (job.name === 'tick') await this.tick(now);
    else if (job.name === 'daily') await this.daily(now);
  }

  async tick(now: Date): Promise<Record<string, number>> {
    const out: Record<string, number> = {};
    const due = await claimTrialReminders(this.db, now);
    let queued = 0;
    for (const d of due) {
      try {
        await this.notifications.enqueue(d.userId, 'trial_ending', d.subscriptionId);
        queued += 1;
      } catch {
        await releaseTrialReminder(this.db, d.userId);
      }
    }
    out.trialReminders = queued;
    // The email twin of the push (PRD 12: push + in-app card + email): every claimed reminder without an email yet.
    out.trialEmails = await this.userMail.sweepTrialEmails(now).catch(() => 0);
    const n = await this.sync.retryNotifications(now);
    out.notificationsRetried = n.retried;
    const r = await this.sync.reconcileSubscriptions(now, 50);
    out.reconciled = r.checked;
    out.reconcileFailed = r.failed;
    out.entitlementsExpired = await this.sync.sweepEntitlements(now);
    out.giftsExpired = await expireOpenGifts(this.db, now);
    if (Object.values(out).some((v) => v > 0)) {
      this.logger.log(`tick: ${Object.entries(out).map(([k, v]) => `${k}=${v}`).join(' ')}`);
    }
    return out;
  }

  async daily(now: Date): Promise<Record<string, number>> {
    const out: Record<string, number> = {};
    try {
      const v = await this.sync.pollVoided(now);
      out.voided = v.voided;
      out.voidedApplied = v.applied;
    } catch (err) {
      this.logger.warn(`voided purchases: ${errCode(err)}`);
    }
    const g = await this.sync.reconcileGooglePurchases(now);
    out.googlePurchases = g.checked;
    const pruned = await this.db.query('delete from public.store_notifications where received_at < $1', [
      new Date(now.getTime() - NOTIFICATION_LOG_RETENTION_DAYS * 86_400_000),
    ]);
    out.notificationsPruned = pruned.rowCount ?? 0;
    this.logger.log(`daily: ${Object.entries(out).map(([k, v]) => `${k}=${v}`).join(' ')}`);
    return out;
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled([this.worker?.close(), this.queue?.close()]);
  }
}

/** Imported by the worker process (src/worker.module.ts). */
@Module({ imports: [BillingCoreModule, NotificationsModule, UserMailWorkerModule], providers: [BillingWorkerHost] })
export class BillingWorkerModule {}
