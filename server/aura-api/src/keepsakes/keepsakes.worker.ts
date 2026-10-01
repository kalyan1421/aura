import { Injectable, Logger, Module, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Queue, Worker, type Job } from 'bullmq';
import { AppConfig } from '../config/app-config';
import { DbService } from '../db/db.service';
import { QUEUE_PREFIX } from '../queues/queue-names';
import { QueuesService } from '../queues/queues.service';
import { sharedWorkerConnection } from '../queues/redis';
import { runFullSweep, runRecentSweep, type SweepSummary } from './sweep';
import { errorText } from '../common/log-scrub';

/**
 * Worker side of F13 keepsakes (its own BullMQ queue, like the ripples tick, so the feature stays self-contained):
 * every 5 minutes, award the people with records newer than the last tick (with a 10-minute overlap: awarding is
 * idempotent); the first tick after start-up and then once a day, everyone (past activity when F13 ships, and
 * anything a tick missed). Lantern Hour and Breath Ripples records are purged after 7 days, far longer than a tick.
 * Logs counts only.
 */
export const KEEPSAKES_QUEUE = 'keepsakes';
const TICK_EVERY_MS = 5 * 60_000;
const OVERLAP_MS = 10 * 60_000;
const FULL_EVERY_MS = 24 * 3600_000;
const TICK_SCHEDULER = 'aura-keepsakes-tick';

@Injectable()
export class KeepsakesWorkerHost implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger('KeepsakesWorker');
  private queue: Queue | null = null;
  private worker: Worker | null = null;
  private lastTickAt: Date | null = null;
  private lastFullAt: Date | null = null;

  constructor(
    private readonly app: AppConfig,
    private readonly queues: QueuesService,
    private readonly db: DbService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    this.queue = new Queue(KEEPSAKES_QUEUE, { connection: this.queues.redis, prefix: QUEUE_PREFIX });
    this.worker = new Worker(KEEPSAKES_QUEUE, (job) => this.handle(job), {
      connection: sharedWorkerConnection(this.app.redisUrl),
      prefix: QUEUE_PREFIX,
      concurrency: 1,
    });
    this.worker.on('failed', (job, err) => this.logger.warn(`job ${job?.name} failed: ${err.name}`));
    this.worker.on('error', (err) => this.logger.warn(`worker: ${errorText(err)}`));
    await this.queue.upsertJobScheduler(TICK_SCHEDULER, { every: TICK_EVERY_MS }, { name: 'tick', data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } });
    await this.worker.waitUntilReady();
    this.logger.log(`keepsakes worker ready (tick every ${TICK_EVERY_MS / 60_000} min; everyone daily)`);
  }

  private async handle(job: Job): Promise<void> {
    if (job.name !== 'tick') return;
    const now = new Date();
    const full = !this.lastFullAt || now.getTime() - this.lastFullAt.getTime() >= FULL_EVERY_MS;
    const since = this.lastTickAt ? new Date(this.lastTickAt.getTime() - OVERLAP_MS) : null;
    const s: SweepSummary = full || !since ? await runFullSweep(this.db.pool, now) : await runRecentSweep(this.db.pool, since, now);
    this.lastTickAt = now;
    if (full) this.lastFullAt = now;
    if (s.added || s.nights || s.errors) {
      const line = `keepsakes${full ? ' (everyone)' : ''}: people=${s.people} added=${s.added} nights=${s.nights}${s.errors ? ` errors=${s.errors}` : ''}`;
      if (s.errors) this.logger.warn(line);
      else this.logger.log(line);
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled([this.worker?.close(), this.queue?.close()]);
  }
}

/** Imported by the worker process (src/worker.module.ts). */
@Module({ providers: [KeepsakesWorkerHost] })
export class KeepsakesWorkerModule {}
