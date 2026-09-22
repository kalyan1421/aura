/** BullMQ queue registry. Producers live in the API, processors in the worker (src/worker.ts). */
export const QUEUE_NAMES = ['capsule-unlock', 'room-lifecycle', 'moderation', 'notifications'] as const;
export type QueueName = (typeof QUEUE_NAMES)[number];

/** Internal queue carrying the repeatable no-op heartbeat (proves the worker is consuming). */
export const HEARTBEAT_QUEUE = 'heartbeat';
export const HEARTBEAT_EVERY_MS = 60_000;

/** Internal queue for daily housekeeping (e.g. purging expired sync_mutations). 03:17 UTC daily. */
export const MAINTENANCE_QUEUE = 'maintenance';
export const MAINTENANCE_CRON = '17 3 * * *';

/** Prefix keeps Aura's keys apart from other apps on a shared Redis. */
export const QUEUE_PREFIX = 'aura';
