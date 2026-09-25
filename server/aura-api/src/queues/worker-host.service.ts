import { Injectable, Logger, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Worker, type Job } from 'bullmq';
import { PURGE_BATCH, purgeDueAccounts } from '../account/account-purge';
import { AppleTokenVault } from '../account/apple-tokens';
import { PrivateMediaStore } from '../account/private-media';
import { CapsuleUnlockService } from '../capsules/capsule-unlock.service';
import { AppConfig } from '../config/app-config';
import { DbService } from '../db/db.service';
import { NotificationDispatcher } from '../notifications/notification-dispatcher';
import { runRoomLifecycle } from '../rooms/room-lifecycle';
import { purgeOldSyncMutations } from './maintenance';
import { PROCESSORS, type Processor } from './processors';
import { runRetention } from './retention';
import {
  ACCOUNT_PURGE_CRON,
  ACCOUNT_PURGE_JOB,
  HEARTBEAT_EVERY_MS,
  HEARTBEAT_QUEUE,
  MAINTENANCE_CRON,
  MAINTENANCE_JOB,
  MAINTENANCE_QUEUE,
  QUEUE_NAMES,
  QUEUE_PREFIX,
  RETENTION_CRON,
  RETENTION_JOB,
  ROOM_LIFECYCLE_CRON,
  ROOM_LIFECYCLE_JOB,
  type QueueName,
} from './queue-names';
import { QueuesService } from './queues.service';
import { redisOptionsFromUrl } from './redis';
import { errorText } from '../common/log-scrub';

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
    private readonly media: PrivateMediaStore,
    /** F4: `capsule-unlock` queue (unlock jobs + the 10-min sweep) — CapsuleUnlockModule. */
    private readonly capsuleUnlock: CapsuleUnlockService,
    /**
     * F14 `notifications` queue — NotificationsModule: pushes under the global rules → FCM (log-only without a
     * service account), plus the daily-reminder sweep (1 min) and zone reconcile (10 min).
     */
    private readonly notifications: NotificationDispatcher,
    /** F8 REQ-ACC-11: revokes Sign in with Apple tokens during the account purge (QueuesModule, APPLE_* env). */
    private readonly apple: AppleTokenVault,
  ) {}

  /** Real processors for the queues that have one; the rest keep their skeleton (processors.ts). */
  private processorFor(name: QueueName): (job: Job, token?: string) => Promise<void> {
    if (name === 'capsule-unlock') return (job: Job, token?: string) => this.capsuleUnlock.handle(job, token);
    if (name === 'notifications') return (job: Job, token?: string) => this.notifications.handle(job, token);
    if (name === 'room-lifecycle') return (job: Job) => this.roomLifecycle(job);
    const skeleton: Processor = PROCESSORS[name];
    return skeleton;
  }

  get queueNames(): string[] {
    return this.workers.map((w) => w.name);
  }

  get running(): boolean {
    return this.workers.length > 0 && this.workers.every((w) => w.isRunning());
  }

  async onApplicationBootstrap(): Promise<void> {
    const connection = redisOptionsFromUrl(this.config.redisUrl);
    for (const name of QUEUE_NAMES) {
      this.workers.push(new Worker(name, this.processorFor(name), { connection, prefix: QUEUE_PREFIX, concurrency: 4 }));
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
      new Worker(MAINTENANCE_QUEUE, (job) => this.maintenance(job), { connection, prefix: QUEUE_PREFIX, concurrency: 1 }),
    );
    for (const w of this.workers) {
      w.on('failed', (job, err) => this.logger.warn(`[${w.name}] job ${job?.name} id=${job?.id} failed: ${errorText(err)}`));
      w.on('error', (err) => this.logger.warn(`[${w.name}] ${errorText(err)}`));
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
        { name: MAINTENANCE_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      );
    await this.queues
      .queue(MAINTENANCE_QUEUE)
      .upsertJobScheduler(
        'aura-account-purge',
        { pattern: ACCOUNT_PURGE_CRON, tz: 'UTC' },
        { name: ACCOUNT_PURGE_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      );
    await this.queues
      .queue(MAINTENANCE_QUEUE)
      .upsertJobScheduler(
        'aura-retention',
        { pattern: RETENTION_CRON, tz: 'UTC' },
        { name: RETENTION_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      ); // moderation audit log (3 years) + closed reports (only once a period is configured)
    await this.capsuleUnlock.ensureSweepScheduler(); // F4 unlock-push sweep, every 10 min
    await this.notifications.ensureSchedulers(); // F14 daily-reminder sweep (1 min) + zone reconcile (10 min)
    await this.queues
      .queue('room-lifecycle')
      .upsertJobScheduler(
        'aura-room-lifecycle',
        { pattern: ROOM_LIFECYCLE_CRON, tz: 'UTC' },
        { name: ROOM_LIFECYCLE_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      ); // F5 lifecycle + Lantern Hour, every minute at :00
    if (!this.media.configured) {
      this.logger.warn('SUPABASE_SERVICE_ROLE_KEY is not set: account purges that find private-media objects are deferred');
    }
    if (!this.apple.configured) {
      this.logger.warn(
        'APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY / APPLE_CLIENT_ID are not set: purges that find a stored ' +
          'Sign in with Apple token wait up to 72 h for them, then drop it unrevoked',
      );
    }
    await Promise.all(this.workers.map((w) => w.waitUntilReady()));
    this.logger.log(`workers ready: ${this.queueNames.join(', ')} (heartbeat every ${HEARTBEAT_EVERY_MS / 1000}s)`);
  }

  /** Maintenance jobs (one queue, told apart by name). Logs counts only — never user ids or paths. */
  private async maintenance(job: Job): Promise<void> {
    if (job.name === ACCOUNT_PURGE_JOB) {
      const s = await purgeDueAccounts(this.db.pool, this.media, PURGE_BATCH, this.capsuleUnlock, this.apple);
      const line =
        `account-purge: due=${s.due} purged=${s.purged} deferred=${s.deferred} failed=${s.failed} ` +
        `rows=${s.rows} media=${s.mediaObjects} appleRevoked=${s.appleRevoked} appleAbandoned=${s.appleAbandoned}` +
        `${s.errors.length ? ` errors=${s.errors.join(',')}` : ''}`;
      if (s.failed || s.deferred || s.appleAbandoned) this.logger.warn(line);
      else this.logger.log(line);
      return;
    }
    if (job.name === RETENTION_JOB) {
      const r = await runRetention(this.db);
      this.logger.log(
        `retention: auditPruned=${r.auditPruned} reportsPruned=${r.reportsPruned} ` +
          `closedReports=${r.closedReportRetentionDays === null ? 'kept (no retention configured)' : `${r.closedReportRetentionDays}d`}`,
      );
      return;
    }
    const removed = await purgeOldSyncMutations(this.db);
    this.logger.log(`maintenance: purged ${removed} expired sync_mutations`);
  }

  /** F5 `room-lifecycle` queue (src/rooms/room-lifecycle.ts). Logs counts only — never room ids or pseudonyms. */
  private async roomLifecycle(job: Job): Promise<void> {
    if (job.name !== ROOM_LIFECYCLE_JOB) return;
    const s = await runRoomLifecycle(this.db.pool);
    if (s.transitions || s.purged || s.evidenceExpired || s.errors.length) {
      const line =
        `room-lifecycle: transitions=${s.transitions} presence=${s.presence} purged=${s.purged} ` +
        `evidenceCopied=${s.evidenceCopied} evidenceExpired=${s.evidenceExpired}${s.errors.length ? ` errors=${s.errors.join(',')}` : ''}`;
      if (s.errors.length) this.logger.warn(line);
      else this.logger.log(line);
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled(this.workers.map((w) => w.close()));
  }
}
