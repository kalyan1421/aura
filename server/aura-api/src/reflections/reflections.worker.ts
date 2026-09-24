import { Injectable, Logger, Module, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { Queue, Worker, type Job } from 'bullmq';
import type { Pool } from 'pg';
import { AppConfig } from '../config/app-config';
import { pgCode, withTx } from '../db/db';
import { DbService } from '../db/db.service';
import { QUEUE_PREFIX } from '../queues/queue-names';
import { QueuesService } from '../queues/queues.service';
import { redisOptionsFromUrl } from '../queues/redis';
import { appendAudit } from '../safety/audit';
import { COMPOSER_FLAG, REFLECTION_POOLS, loadReflectionConfig } from './reflection-config';
import { holdPending } from './reflections.service';

/**
 * Worker side of F6 (its own BullMQ queue, like the admin pager, so the module is self-contained). Every 30 s:
 *  1. **fail closed** — a reflection still `pending` after `pending_timeout_s` (its API process died mid-decision) is
 *     held for a human with a queue item. Nothing is ever released by a timeout (REQ-REF-03);
 *  2. **expiry** — held / pending reflections in a room that has become a memory expire unpublished (PRD F6 "expires
 *     unpublished if the room becomes a memory first"): the text is scrubbed and their hold item closes (reports about
 *     behaviour — crisis, minors, violations, users' — stay open; their evidence snapshot keeps the text);
 *  3. **kill switch** — a language pool with more than `auto_pause_held` held reflections is paused
 *     (`reflections_composer.payload.pausedPools`), audited as `system`; AK resumes it in the console.
 * Logs counts only (never ids or text).
 */
export const REFLECTIONS_QUEUE = 'reflections';
const TICK_EVERY_MS = 30_000;
const TICK_SCHEDULER = 'aura-reflections-tick';

export interface ReflectionsTickSummary {
  heldStuck: number;
  expired: number;
  poolsPaused: string[];
  errors: string[];
}

export async function runReflectionsTick(pool: Pool, masterKey: Buffer, now = new Date()): Promise<ReflectionsTickSummary> {
  const s: ReflectionsTickSummary = { heldStuck: 0, expired: 0, poolsPaused: [], errors: [] };
  const fail = (err: unknown): void => {
    const kind = pgCode(err) ?? (err instanceof Error ? err.name : 'error');
    if (!s.errors.includes(kind)) s.errors.push(kind);
  };
  const cfg = await loadReflectionConfig(pool);

  // 1. stuck pending → held
  const stuck = await pool.query<{ id: string }>(
    `select id from public.reflections where status = 'pending' and created_at < now() - make_interval(secs => $1) limit 200`,
    [cfg.pendingTimeoutS],
  );
  for (const { id } of stuck.rows) {
    try {
      if (await holdPending({ withTx: (fn) => withTx(pool, fn) }, id, 'timeout', masterKey, now)) s.heldStuck += 1;
    } catch (err) {
      fail(err);
    }
  }

  // 2. held / pending in memory rooms → expired
  try {
    await withTx(pool, async (tx) => {
      const expired = await tx.query<{ id: string }>(
        `update public.reflections r
            set status = 'expired', body_ct = null, body_key = null, text_hash = null, stage = 'system',
                decided_at = now(), decided_by = 'system:room_memory'
          from public.rooms rm
         where rm.id = r.room_id and rm.memory_at <= now() and r.status in ('held', 'pending')
         returning r.id`,
      );
      s.expired = expired.rows.length;
      if (s.expired) {
        await tx.query(
          `update public.reports set status = 'dismissed', resolved_at = now(), resolved_by = 'system:room_memory'
            where target_reflection_id = any($1::uuid[]) and status = 'open' and source = 'auto' and auto_signal = 'reflection_hold'`,
          [expired.rows.map((x) => x.id)],
        );
      }
    });
  } catch (err) {
    fail(err);
  }

  // 3. auto-pause a pool over the held threshold
  try {
    await withTx(pool, async (tx) => {
      const held = await tx.query<{ language_pool: string; n: number }>(
        `select language_pool, count(*)::int as n from public.reflections where status = 'held' group by language_pool`,
      );
      const over = held.rows.filter((x) => x.n > cfg.autoPauseHeld && (REFLECTION_POOLS as readonly string[]).includes(x.language_pool));
      if (!over.length) return;
      const flag = (await tx.query<{ payload: Record<string, unknown> | null }>('select payload from public.feature_flags where key = $1 for update', [COMPOSER_FLAG])).rows[0];
      if (!flag) return;
      const paused = new Set(Array.isArray(flag.payload?.pausedPools) ? (flag.payload?.pausedPools as string[]) : []);
      const newly = over.filter((x) => !paused.has(x.language_pool));
      if (!newly.length) return;
      for (const x of newly) paused.add(x.language_pool);
      const list = [...paused].sort();
      await tx.query(`update public.feature_flags set payload = coalesce(payload, '{}'::jsonb) || jsonb_build_object('pausedPools', $2::jsonb) where key = $1`, [
        COMPOSER_FLAG,
        JSON.stringify(list),
      ]);
      for (const x of newly) {
        await appendAudit(tx, {
          actor: 'system',
          action: 'auto_reflections_pool_pause',
          reasonCode: 'held_over_threshold',
          detail: { flag: COMPOSER_FLAG, pool: x.language_pool, held: x.n, threshold: cfg.autoPauseHeld },
        });
        s.poolsPaused.push(x.language_pool);
      }
    });
  } catch (err) {
    fail(err);
  }
  return s;
}

@Injectable()
export class ReflectionsWorkerHost implements OnApplicationBootstrap, OnApplicationShutdown {
  private readonly logger = new Logger('ReflectionsWorker');
  private queue: Queue | null = null;
  private worker: Worker | null = null;

  constructor(
    private readonly app: AppConfig,
    private readonly queues: QueuesService,
    private readonly db: DbService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    this.queue = new Queue(REFLECTIONS_QUEUE, { connection: this.queues.redis, prefix: QUEUE_PREFIX });
    this.worker = new Worker(REFLECTIONS_QUEUE, (job) => this.handle(job), {
      connection: redisOptionsFromUrl(this.app.redisUrl),
      prefix: QUEUE_PREFIX,
      concurrency: 1,
    });
    this.worker.on('failed', (job, err) => this.logger.warn(`job ${job?.name} failed: ${err.name}`));
    this.worker.on('error', (err) => this.logger.warn(`worker: ${err.message}`));
    await this.queue.upsertJobScheduler(TICK_SCHEDULER, { every: TICK_EVERY_MS }, { name: 'tick', data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } });
    await this.worker.waitUntilReady();
    this.logger.log(`reflections worker ready (tick every ${TICK_EVERY_MS / 1000}s: stuck pending → held, memory → expired, pool auto-pause)`);
  }

  private async handle(job: Job): Promise<void> {
    if (job.name !== 'tick') return;
    const s = await runReflectionsTick(this.db.pool, this.app.masterKey);
    if (s.heldStuck || s.expired || s.poolsPaused.length || s.errors.length) {
      const line =
        `reflections: heldStuck=${s.heldStuck} expired=${s.expired}` +
        `${s.poolsPaused.length ? ` poolsPaused=${s.poolsPaused.join(',')}` : ''}${s.errors.length ? ` errors=${s.errors.join(',')}` : ''}`;
      if (s.errors.length || s.poolsPaused.length || s.heldStuck) this.logger.warn(line);
      else this.logger.log(line);
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await Promise.allSettled([this.worker?.close(), this.queue?.close()]);
  }
}

/** Imported by the worker process (src/worker.module.ts). */
@Module({ providers: [ReflectionsWorkerHost] })
export class ReflectionsWorkerModule {}
