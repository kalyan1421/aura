/** BullMQ queue registry. Producers live in the API, processors in the worker (src/worker.ts). */
export const QUEUE_NAMES = ['capsule-unlock', 'room-lifecycle', 'moderation', 'notifications'] as const;
export type QueueName = (typeof QUEUE_NAMES)[number];

/** Internal queue carrying the repeatable no-op heartbeat (proves the worker is consuming). */
export const HEARTBEAT_QUEUE = 'heartbeat';
export const HEARTBEAT_EVERY_MS = 60_000;

/** Internal queue for housekeeping. Jobs are told apart by name (one scheduler each). */
export const MAINTENANCE_QUEUE = 'maintenance';
/** Job `maintenance`: purge expired sync_mutations. 03:17 UTC daily. */
export const MAINTENANCE_JOB = 'maintenance';
export const MAINTENANCE_CRON = '17 3 * * *';
/** Job `account-purge`: purge accounts whose 7-day deletion grace has ended (F8 REQ-ACC-11). Hourly at :41 UTC. */
export const ACCOUNT_PURGE_JOB = 'account-purge';
export const ACCOUNT_PURGE_CRON = '41 * * * *';
/**
 * Job `retention` (src/queues/retention.ts): moderation audit rows past `safety_config.moderation_audit_retention_days`
 * (3 years [LEGAL]) and — only once a period is configured — closed reports. 03:29 UTC daily.
 */
export const RETENTION_JOB = 'retention';
export const RETENTION_CRON = '29 3 * * *';

/**
 * Job `room-lifecycle-tick` on the `room-lifecycle` queue (F5, src/rooms/room-lifecycle.ts): room state transitions
 * incl. Lantern Hour (broadcast once), "here now" sweep, purge at 24 h + 7 d (evidence copied first), evidence expiry.
 * Every minute at :00, so 21:00 / 23:00 on each region clock are broadcast within seconds.
 */
export const ROOM_LIFECYCLE_JOB = 'room-lifecycle-tick';
export const ROOM_LIFECYCLE_CRON = '* * * * *';

/** Prefix keeps Aura's keys apart from other apps on a shared Redis. */
export const QUEUE_PREFIX = 'aura';
