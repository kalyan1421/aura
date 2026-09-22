import { Injectable, Logger, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Worker } from 'bullmq';
import { AppConfig } from '../config/app-config';
import { DbService } from '../db/db.service';
import { purgeOldSyncMutations } from './maintenance';
import { PROCESSORS } from './processors';
import {
  HEARTBEAT_EVERY_MS,
  HEARTBEAT_QUEUE,
  MAINTENANCE_CRON,
  MAINTENANCE_QUEUE,
  QUEUE_NAMES,
  QUEUE_PREFIX,
} from './queue-names';
import { QueuesService } from './queues.service';
import { redisOptionsFromUrl } from './redis';

/** Runs one BullMQ Worker per queue (worker entrypoint only) and schedules the heartbeat. */
@Injectable()
export class WorkerHostService implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger('WorkerHost');
  private readonly workers: Worker[] = [];
  lastHeartbeatAt: Date | null = null;

  constructor(
    private readonly config: AppConfig,
    private readonly queues: QueuesService,
    private readonly db: DbService,
  ) {}

  get queueNames(): string[] {
    return this.workers.map((w) => w.name);
  }

  get running(): boolean {
    return this.workers.length > 0 && this.workers.every((w) => w.isRunning());
  }

  async onApplicationBootstrap(): Promise<void> {
    const connection = redisOptionsFromUrl(this.config.redisUrl);
    for (const name of QUEUE_NAMES) {
      this.workers.push(new Worker(name, PROCESSORS[name], { connection, prefix: QUEUE_PREFIX, concurrency: 4 }));
    }
    this.workers.push(
      new Worker(
        HEARTBEAT_QUEUE,
        async () => {
          this.lastHeartbeatAt = new Date();
          this.logger.debug('heartbeat');
        },
        { connection, prefix: QUEUE_PREFIX, concurrency: 1 },
      ),
    );
    this.workers.push(
      new Worker(
        MAINTENANCE_QUEUE,
        async () => {
          const removed = await purgeOldSyncMutations(this.db);
          this.logger.log(`maintenance: purged ${removed} expired sync_mutations`);
        },
        { connection, prefix: QUEUE_PREFIX, concurrency: 1 },
      ),
    );
    for (const w of this.workers) {
      w.on('failed', (job, err) => this.logger.warn(`[${w.name}] job ${job?.name} id=${job?.id} failed: ${err.message}`));
      w.on('error', (err) => this.logger.warn(`[${w.name}] ${err.message}`));
    }
    // Idempotent: upserting the scheduler never duplicates the repeatable job.
    await this.queues
      .queue(HEARTBEAT_QUEUE)
      .upsertJobScheduler(
        'aura-heartbeat',
        { every: HEARTBEAT_EVERY_MS },
        { name: 'heartbeat', data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      );
    await this.queues
      .queue(MAINTENANCE_QUEUE)
      .upsertJobScheduler(
        'aura-maintenance',
        { pattern: MAINTENANCE_CRON, tz: 'UTC' },
        { name: 'maintenance', data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      );
    await Promise.all(this.workers.map((w) => w.waitUntilReady()));
    this.logger.log(`workers ready: ${this.queueNames.join(', ')} (heartbeat every ${HEARTBEAT_EVERY_MS / 1000}s)`);
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled(this.workers.map((w) => w.close()));
  }
}
