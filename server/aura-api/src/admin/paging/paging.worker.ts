import { Injectable, Logger, Module, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Queue, Worker, type Job } from 'bullmq';
import { AppConfig } from '../../config/app-config';
import { QUEUE_PREFIX } from '../../queues/queue-names';
import { QueuesService } from '../../queues/queues.service';
import { redisOptionsFromUrl } from '../../queues/redis';
import { AdminConfig } from '../admin-config';
import { AdminCoreModule } from '../admin-core.module';
import { GrievanceMail } from '../grievance-mail';
import { PagingService } from './paging.service';

/** The pager's own BullMQ queue (kept apart from the shared registry in src/queues so this module is self-contained). */
export const ADMIN_PAGING_QUEUE = 'admin-paging';
const TICK_EVERY_MS = 30_000;
const TICK_SCHEDULER = 'aura-admin-paging-tick';
const WEEKLY_SCHEDULER = 'aura-admin-weekly-test-page';

/**
 * Worker side of the pager: every 30 s it raises pages for items that need one (sweep), delivers due rounds
 * (repeats and the 5-minute escalation) and retries grievance acknowledgements that did not go out; weekly it raises
 * the test page (REQ-ADM-15 "weekly test page logged"). Logs counts and codes only.
 */
@Injectable()
export class PagingWorkerHost implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger('PagerWorker');
  private queue: Queue | null = null;
  private worker: Worker | null = null;

  constructor(
    private readonly app: AppConfig,
    private readonly queues: QueuesService,
    private readonly paging: PagingService,
    private readonly mail: GrievanceMail,
    private readonly config: AdminConfig,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    this.queue = new Queue(ADMIN_PAGING_QUEUE, { connection: this.queues.redis, prefix: QUEUE_PREFIX });
    this.worker = new Worker(ADMIN_PAGING_QUEUE, (job) => this.handle(job), {
      connection: redisOptionsFromUrl(this.app.redisUrl),
      prefix: QUEUE_PREFIX,
      concurrency: 1,
    });
    this.worker.on('failed', (job, err) => this.logger.warn(`job ${job?.name} failed: ${err.name}`));
    this.worker.on('error', (err) => this.logger.warn(`worker: ${err.message}`));
    const opts = { removeOnComplete: 10, removeOnFail: 50 };
    await this.queue.upsertJobScheduler(TICK_SCHEDULER, { every: TICK_EVERY_MS }, { name: 'tick', data: {}, opts });
    const cron = this.config.paging.weeklyTestCron;
    if (cron) {
      await this.queue.upsertJobScheduler(WEEKLY_SCHEDULER, { pattern: cron, tz: this.config.paging.weeklyTestTz }, { name: 'weekly-test', data: {}, opts });
    } else {
      await this.queue.removeJobScheduler(WEEKLY_SCHEDULER);
    }
    await this.worker.waitUntilReady();
    const channels = this.paging.channelSummary.map((c) => c.name).join(', ') || 'none';
    this.logger.log(`pager ready (tick every ${TICK_EVERY_MS / 1000}s; channels: ${channels})`);
  }

  private async handle(job: Job): Promise<void> {
    if (job.name === 'weekly-test') {
      await this.paging.raiseTest('test_weekly');
      await this.paging.runDue();
      return;
    }
    if (job.name !== 'tick') return;
    const raised = await this.paging.sweep();
    const s = await this.paging.runDue();
    const acks = await this.mail.retryPendingAcks();
    if (raised || s.claimed || acks) {
      this.logger.log(
        `pager: raised=${raised} claimed=${s.claimed} delivered=${s.delivered} failed=${s.failed} resolved=${s.resolved} ` +
          `expired=${s.expired} grievanceAcks=${acks}`,
      );
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled([this.worker?.close(), this.queue?.close()]);
  }
}

/** Imported by the worker process (src/worker.module.ts). */
@Module({ imports: [AdminCoreModule], providers: [PagingWorkerHost] })
export class AdminWorkerModule {}
