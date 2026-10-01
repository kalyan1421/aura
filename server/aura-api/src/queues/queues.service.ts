import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import { AppConfig } from '../config/app-config';
import { HEARTBEAT_QUEUE, MAINTENANCE_QUEUE, QUEUE_NAMES, QUEUE_PREFIX, type QueueName } from './queue-names';
import { closeSharedWorkerConnections, redisOptionsFromUrl } from './redis';

/** One shared Redis connection + producer handles for every Aura queue. */
@Injectable()
export class QueuesService implements OnModuleDestroy {
  private readonly logger = new Logger('Queues');
  readonly redis: IORedis;
  private readonly queues = new Map<string, Queue>();

  constructor(config: AppConfig) {
    // Producers must fail fast while Redis is down (an HTTP request must never hang on an enqueue).
    // `maxRetriesPerRequest: null` is only for Workers' blocking connections (worker-host.service.ts).
    this.redis = new IORedis({ ...redisOptionsFromUrl(config.redisUrl), maxRetriesPerRequest: 1, keepAlive: 10_000 });
    this.redis.on('error', (e) => this.logger.warn(`redis: ${e.message}`));
    for (const name of [...QUEUE_NAMES, HEARTBEAT_QUEUE, MAINTENANCE_QUEUE]) {
      this.queues.set(name, new Queue(name, { connection: this.redis, prefix: QUEUE_PREFIX }));
    }
  }

  queue(name: QueueName | typeof HEARTBEAT_QUEUE | typeof MAINTENANCE_QUEUE): Queue {
    const q = this.queues.get(name);
    if (!q) throw new Error(`unknown queue ${name}`);
    return q;
  }

  async ping(): Promise<void> {
    const r = await this.redis.ping();
    if (r !== 'PONG') throw new Error(`unexpected PING reply ${r}`);
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.allSettled([...this.queues.values()].map((q) => q.close()));
    this.redis.disconnect();
    closeSharedWorkerConnections();
  }
}
