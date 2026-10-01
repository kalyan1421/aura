import { Injectable, Logger, Module, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Queue, Worker, type Job } from 'bullmq';
import { AppConfig } from '../../config/app-config';
import { QUEUE_PREFIX } from '../../queues/queue-names';
import { QueuesService } from '../../queues/queues.service';
import { sharedWorkerConnection } from '../../queues/redis';
import { AdminConfig } from '../admin-config';
import { AdminCoreModule } from '../admin-core.module';
import { AuditExportService } from '../audit-export';
import { GrievanceMail } from '../grievance-mail';
import { PagingService } from './paging.service';
import { errorText } from '../../common/log-scrub';

/**
 * The admin module's own BullMQ queue (kept apart from the shared registry in src/queues so this module is
 * self-contained): the pager's tick and weekly drill, and the nightly audit export.
 */
export const ADMIN_PAGING_QUEUE = 'admin-paging';
const TICK_EVERY_MS = 30_000;
const TICK_SCHEDULER = 'aura-admin-paging-tick';
const WEEKLY_SCHEDULER = 'aura-admin-weekly-test-page';
const AUDIT_EXPORT_SCHEDULER = 'aura-admin-audit-export';

/**
 * Worker side of the admin console:
 * - every 30 s: raise pages for items that need one (sweep — incl. crisis items open 5 min, 24×7), deliver due rounds
 *   (repeats and the 5-minute escalation) and retry grievance acknowledgements that did not go out;
 * - weekly: the test page (REQ-ADM-15 "weekly test page logged");
 * - nightly: the audit-log export (PRD 19 "exported nightly"; `ADMIN_AUDIT_EXPORT_*`), when a destination is configured.
 * Logs counts and codes only.
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
    private readonly exports: AuditExportService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    this.queue = new Queue(ADMIN_PAGING_QUEUE, { connection: this.queues.redis, prefix: QUEUE_PREFIX });
    this.worker = new Worker(ADMIN_PAGING_QUEUE, (job) => this.handle(job), {
      connection: sharedWorkerConnection(this.app.redisUrl),
      prefix: QUEUE_PREFIX,
      concurrency: 1,
    });
    this.worker.on('failed', (job, err) => this.logger.warn(`job ${job?.name} failed: ${err.name}`));
    this.worker.on('error', (err) => this.logger.warn(`worker: ${errorText(err)}`));
    const opts = { removeOnComplete: 10, removeOnFail: 50 };
    await this.queue.upsertJobScheduler(TICK_SCHEDULER, { every: TICK_EVERY_MS }, { name: 'tick', data: {}, opts });
    const cron = this.config.paging.weeklyTestCron;
    if (cron) {
      await this.queue.upsertJobScheduler(WEEKLY_SCHEDULER, { pattern: cron, tz: this.config.paging.weeklyTestTz }, { name: 'weekly-test', data: {}, opts });
    } else {
      await this.queue.removeJobScheduler(WEEKLY_SCHEDULER);
    }
    const exportCron = this.config.auditExport.cron;
    if (exportCron && this.exports.configured) {
      await this.queue.upsertJobScheduler(
        AUDIT_EXPORT_SCHEDULER,
        { pattern: exportCron, tz: this.config.auditExport.tz },
        { name: 'audit-export', data: {}, opts },
      );
    } else {
      await this.queue.removeJobScheduler(AUDIT_EXPORT_SCHEDULER);
      this.logger.warn('nightly audit export is off: set ADMIN_AUDIT_EXPORT_DIR and/or ADMIN_AUDIT_EXPORT_EMAIL (docs/setup/admin-console.md)');
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
    if (job.name === 'audit-export') {
      const r = await this.exports.run('nightly');
      if (r.status === 'exported') {
        this.logger.log(
          `audit export: rows ${r.manifest.fromId}-${r.manifest.toId} (${r.manifest.rows}) → ${r.destinations.join(',')}` +
            `${r.failed.length ? ` (failed: ${r.failed.join(',')})` : ''}; chain ${r.manifest.chainVerified ? 'verified' : 'NOT verified'}`,
        );
      } else if (r.status === 'failed') {
        this.logger.warn(`audit export failed: ${r.failed.join(',')}`);
        throw new Error('audit export failed'); // BullMQ records the failure; the next night exports from the same row
      } else {
        this.logger.log(`audit export skipped (${r.reason})`);
      }
      return;
    }
    if (job.name !== 'tick') return;
    const raised = await this.paging.sweep();
    const s = await this.paging.drain(undefined, 5);
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
