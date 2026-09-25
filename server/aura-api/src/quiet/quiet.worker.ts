import { Injectable, Logger, Module, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Queue, Worker, type Job } from 'bullmq';
import { AppConfig } from '../config/app-config';
import { DbService } from '../db/db.service';
import { QUEUE_PREFIX } from '../queues/queue-names';
import { QueuesService } from '../queues/queues.service';
import { redisOptionsFromUrl } from '../queues/redis';
import { runQuietLifecycle } from './quiet-lifecycle';
import { errorText } from '../common/log-scrub';

/**
 * Worker side of F16 (its own BullMQ queue, like the ripples tick, so the module is self-contained): every 30 s,
 * `runQuietLifecycle` (live counts, quiet memberships, retention). Logs counts only.
 */
export const QUIET_QUEUE = 'quiet';
const TICK_EVERY_MS = 30_000;
const TICK_SCHEDULER = 'aura-quiet-tick';

@Injectable()
export class QuietWorkerHost implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger('QuietWorker');
  private queue: Queue | null = null;
  private worker: Worker | null = null;

  constructor(
    private readonly app: AppConfig,
    private readonly queues: QueuesService,
    private readonly db: DbService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    this.queue = new Queue(QUIET_QUEUE, { connection: this.queues.redis, prefix: QUEUE_PREFIX });
    this.worker = new Worker(QUIET_QUEUE, (job) => this.handle(job), {
      connection: redisOptionsFromUrl(this.app.redisUrl),
      prefix: QUEUE_PREFIX,
      concurrency: 1,
    });
    this.worker.on('failed', (job, err) => this.logger.warn(`job ${job?.name} failed: ${err.name}`));
    this.worker.on('error', (err) => this.logger.warn(`worker: ${errorText(err)}`));
    await this.queue.upsertJobScheduler(TICK_SCHEDULER, { every: TICK_EVERY_MS }, { name: 'tick', data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } });
    await this.worker.waitUntilReady();
    this.logger.log(`quiet worker ready (tick every ${TICK_EVERY_MS / 1000}s: live counts, quiet memberships, retention)`);
  }

  private async handle(job: Job): Promise<void> {
    if (job.name !== 'tick') return;
    const s = await runQuietLifecycle(this.db.pool);
    if (s.closed || s.purged || s.errors.length) {
      const line = `quiet: counts=${s.counts} closed=${s.closed} purged=${s.purged}${s.errors.length ? ` errors=${s.errors.join(',')}` : ''}`;
      if (s.errors.length) this.logger.warn(line);
      else this.logger.log(line);
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled([this.worker?.close(), this.queue?.close()]);
  }
}

/** Imported by the worker process (src/worker.module.ts). */
@Module({ providers: [QuietWorkerHost] })
export class QuietWorkerModule {}
