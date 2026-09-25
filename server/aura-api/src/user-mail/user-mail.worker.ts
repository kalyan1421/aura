import { Inject, Injectable, Logger, Module, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { DelayedError, Queue, Worker, type Job } from 'bullmq';
import { AdminCoreModule } from '../admin/admin-core.module';
import { BillingCoreModule } from '../billing/billing.module';
import type { BillingConfig } from '../billing/billing.config';
import { BILLING_CONFIG } from '../billing/billing.tokens';
import { AppConfig } from '../config/app-config';
import { isUuid } from '../common/uuid';
import { DbService } from '../db/db.service';
import { QUEUE_PREFIX } from '../queues/queue-names';
import { QueuesService } from '../queues/queues.service';
import { redisOptionsFromUrl } from '../queues/redis';
import { TRIAL_EMAIL_MAX_ATTEMPTS, TrialEmailSender, dueTrialEmails } from './trial-email.sender';
import { errorText } from '../common/log-scrub';

/**
 * App-user mail, worker side (its own BullMQ queue `user-mail`). v1 sends exactly one kind: the trial-ending email
 * (PRD 12), queued by the billing sweep right after it queues the `trial_ending` push (src/billing/billing.worker.ts
 * `tick`). One job per trial (job id `trial-email-<subscription>`); quiet hours move the job to later; transport
 * failures retry with backoff; the `trial_ending_emails` ledger makes every path at most once. Job data is two ids —
 * never the address or any copy. Logs counts and reason codes only.
 */
export const USER_MAIL_QUEUE = 'user-mail';
export const TRIAL_EMAIL_JOB = 'trial-ending-email';

export interface TrialEmailJobData {
  subscriptionId: string;
  userId: string;
}

export const trialEmailJobId = (subscriptionId: string): string => `trial-email-${subscriptionId.toLowerCase()}`;

@Injectable()
export class UserMailWorkerHost implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger('UserMail');
  private queue: Queue | null = null;
  private worker: Worker | null = null;

  constructor(
    private readonly app: AppConfig,
    private readonly queues: QueuesService,
    private readonly db: DbService,
    private readonly sender: TrialEmailSender,
    @Inject(BILLING_CONFIG) private readonly billing: BillingConfig,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    this.queue = new Queue(USER_MAIL_QUEUE, { connection: this.queues.redis, prefix: QUEUE_PREFIX });
    this.worker = new Worker(USER_MAIL_QUEUE, (job, token) => this.handle(job, token), {
      connection: redisOptionsFromUrl(this.app.redisUrl),
      prefix: QUEUE_PREFIX,
      concurrency: 2,
    });
    this.worker.on('failed', (job, err) => this.logger.warn(`job ${job?.name} failed: ${errorText(err, 80)}`));
    this.worker.on('error', (err) => this.logger.warn(`worker: ${errorText(err)}`));
    await this.worker.waitUntilReady();
    this.logger.log('user mail worker ready (trial-ending email)');
  }

  /**
   * Queues the email for every trial whose reminder is claimed and has no email yet (see `dueTrialEmails`). Called by
   * the billing tick after the pushes; a job already queued (or waiting out quiet hours) is not queued twice.
   */
  async sweepTrialEmails(now: Date): Promise<number> {
    if (!this.queue) return 0;
    const due = await dueTrialEmails(this.db, now);
    let queued = 0;
    for (const d of due) {
      try {
        await this.queue.add(TRIAL_EMAIL_JOB, d satisfies TrialEmailJobData, {
          jobId: trialEmailJobId(d.subscriptionId),
          attempts: TRIAL_EMAIL_MAX_ATTEMPTS,
          backoff: { type: 'exponential', delay: 60_000 },
          removeOnComplete: 100,
          removeOnFail: 200,
        });
        queued += 1;
      } catch {
        // Redis down: the next tick finds the trial again (no email row yet).
      }
    }
    return queued;
  }

  async handle(job: Job, token?: string, now = new Date()): Promise<string> {
    if (job.name !== TRIAL_EMAIL_JOB) return 'unknown_job';
    const { subscriptionId, userId } = (job.data ?? {}) as Partial<TrialEmailJobData>;
    if (!isUuid(subscriptionId) || !isUuid(userId)) return 'bad_job';
    const r = await this.sender.process(subscriptionId, userId, now, { packageName: this.billing.googlePackageName });
    switch (r.outcome) {
      case 'deferred':
        // Quiet hours: wait on the queue (not an attempt), then decide again.
        await job.moveToDelayed(r.until.getTime(), token);
        throw new DelayedError();
      case 'failed':
        if (r.retry) throw new Error(`trial email not sent: ${r.code}`);
        return `failed:${r.code}`;
      case 'skipped':
        return `skipped:${r.reason}`;
      default:
        return r.outcome;
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled([this.worker?.close(), this.queue?.close()]);
  }
}

/**
 * Worker only (imported by BillingWorkerModule, whose tick queues the emails). Mail goes through the console's SMTP
 * transport (AdminCoreModule's MAILER: `SMTP_URL`, `MAIL_FROM`; Mailpit locally).
 */
@Module({
  imports: [AdminCoreModule, BillingCoreModule],
  providers: [TrialEmailSender, UserMailWorkerHost],
  exports: [TrialEmailSender, UserMailWorkerHost],
})
export class UserMailWorkerModule {}
