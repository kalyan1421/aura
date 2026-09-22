import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';
import type { QueueName } from './queue-names';

/**
 * Skeleton processors — they log job metadata only (never `job.data`: it may carry
 * capsule/room content). Real handlers land with their features.
 */
export type Processor = (job: Job) => Promise<void>;

const logOnly =
  (queue: QueueName): Processor =>
  async (job) => {
    new Logger(`queue:${queue}`).log(`job ${job.name} id=${job.id} attempt=${job.attemptsMade + 1} (skeleton, no-op)`);
  };

export const PROCESSORS: Record<QueueName, Processor> = {
  'capsule-unlock': logOnly('capsule-unlock'),
  'room-lifecycle': logOnly('room-lifecycle'),
  moderation: logOnly('moderation'),
  notifications: logOnly('notifications'),
};
