import { Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import type { Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { QueuesService } from '../queues/queues.service';
import { reject } from '../sync/mutation-rejected';
import type { Mutation } from '../sync/sync.schema';
import { NotificationsService } from './notifications.service';

/**
 * "Tell me when they open" (PRD 06b F5 language pools; 14-states "language pool not open yet": "Join English room" /
 * "Tell me when they open"). contracts/api/v1-notifications.md "room_pool_waitlist" / "rooms_pool_open".
 *
 *  - Sync entity `room_pool_waitlist` (the one write path, PRD 16-offline): `upsert {pool: "hi"}` records the tap
 *    (a repeat keeps the first time), `delete {pool}` withdraws it. Rows live in `public.room_pool_waitlist`
 *    (migration 20261005000019), server-only, purged with the account.
 *  - `pool-open-sweep` (worker, every minute on the `notifications` queue): while a pool's flag is on
 *    (`rooms_pool_hi`), each waiting row is claimed and DELETED in one transaction together with enqueueing its one
 *    `rooms_pool_open` push — the opt-in is used up whether or not the push is then allowed out. Accounts with a
 *    scheduled deletion or closed (an active account / social ban or rooms pause) get none. A flag flipped off and on
 *    again sends nothing twice (the rows are gone); someone who taps again while it's off is told at the next opening.
 *  - Delivery applies every global rule (NotificationDelivery): master switch, quiet hours (deferred, not dropped),
 *    the 2/day cap (deferred to the next day), the Android "Rooms & Lantern Hour" channel, content-free payload
 *    and generic copy in the app language; it re-checks the flag, so a pool closed again meanwhile sends nothing.
 */
export const ROOM_POOL_WAITLIST_ENTITY = 'room_pool_waitlist';

/** Language pools that open later, and the flag that opens each (rooms.language_pool). */
export const POOL_FLAGS = { hi: 'rooms_pool_hi' } as const;
export type WaitlistPool = keyof typeof POOL_FLAGS;
export const WAITLIST_POOLS = Object.keys(POOL_FLAGS) as WaitlistPool[];

export const POOL_OPEN_SWEEP_JOB = 'pool-open-sweep';
export const POOL_OPEN_SWEEP_SCHEDULER_ID = 'aura-pool-open-sweep';
export const POOL_OPEN_SWEEP_EVERY_MS = 60_000;
export const POOL_OPEN_BATCH = 500;
/** Covers a crash between enqueueing and commit (the next sweep re-enqueues; BullMQ drops the duplicate). */
export const POOL_OPEN_DEDUPE_TTL_MS = 3600_000;

/** Sanctions that close the account or keep it out of rooms: no "rooms are open" push. */
const CLOSED_KINDS = ['account_ban', 'social_ban', 'rooms_pause'];

export const waitlistPayloadSchema = z.object({ pool: z.enum(WAITLIST_POOLS as [WaitlistPool, ...WaitlistPool[]]) });

/** `room_pool_waitlist` upsert / delete inside the sync push (SyncModule). */
@Injectable()
export class PoolWaitlistSyncHandler {
  async apply(ctx: { tx: Tx; userId: string }, m: Mutation): Promise<void> {
    const parsed = waitlistPayloadSchema.safeParse(m.payload);
    if (!parsed.success) return reject('invalid_payload');
    const { pool } = parsed.data;
    switch (m.op) {
      case 'upsert':
        await ctx.tx.query(
          `insert into public.room_pool_waitlist (user_id, pool) values ($1, $2) on conflict (user_id, pool) do nothing`,
          [ctx.userId, pool],
        );
        return;
      case 'delete':
        await ctx.tx.query('delete from public.room_pool_waitlist where user_id = $1 and pool = $2', [ctx.userId, pool]);
        return;
      default:
        return reject('unknown_op');
    }
  }
}

export interface PoolOpenSweepSummary {
  /** Rows claimed (and deleted) across open pools. */
  claimed: number;
  enqueued: number;
  /** Claimed without a push: deletion scheduled, closed account, no profile. */
  skipped: number;
}

@Injectable()
export class PoolOpenSweep {
  private readonly logger = new Logger('PoolOpen');

  constructor(
    private readonly db: DbService,
    private readonly queues: QueuesService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Worker bootstrap: the repeatable sweep (idempotent). */
  async ensureScheduler(): Promise<void> {
    await this.queues
      .queue('notifications')
      .upsertJobScheduler(
        POOL_OPEN_SWEEP_SCHEDULER_ID,
        { every: POOL_OPEN_SWEEP_EVERY_MS },
        { name: POOL_OPEN_SWEEP_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } },
      );
  }

  /** One pass: every open pool, in batches, until its waitlist is empty. */
  async sweep(): Promise<PoolOpenSweepSummary> {
    const out: PoolOpenSweepSummary = { claimed: 0, enqueued: 0, skipped: 0 };
    for (const pool of WAITLIST_POOLS) {
      if (!(await this.flagOn(POOL_FLAGS[pool]))) continue;
      for (;;) {
        const batch = await this.claimBatch(pool);
        out.claimed += batch.claimed;
        out.enqueued += batch.enqueued;
        out.skipped += batch.skipped;
        if (batch.claimed < POOL_OPEN_BATCH) break;
      }
    }
    if (out.claimed) this.logger.log(`pool-open sweep: claimed=${out.claimed} enqueued=${out.enqueued} skipped=${out.skipped}`);
    return out;
  }

  /**
   * Claims up to a batch of waiting rows (SKIP LOCKED: overlapping sweeps split the work) and deletes them, enqueueing
   * each eligible push before the commit: if Redis refuses, the transaction rolls back and the rows wait for the next
   * sweep; if the commit fails after enqueueing, the next sweep's enqueue is a BullMQ duplicate and is dropped.
   */
  private async claimBatch(pool: WaitlistPool): Promise<PoolOpenSweepSummary> {
    return this.db.withTx(async (tx) => {
      const r = await tx.query<{ user_id: string; eligible: boolean }>(
        `with claimed as (
           select user_id from public.room_pool_waitlist where pool = $1
            order by requested_at limit $2 for update skip locked
         )
         delete from public.room_pool_waitlist w using claimed c
          where w.pool = $1 and w.user_id = c.user_id
         returning w.user_id,
           (exists (select 1 from public.profiles p where p.user_id = w.user_id)
            and not exists (select 1 from public.account_deletions d where d.user_id = w.user_id)
            and not exists (select 1 from public.sanctions s
                             where s.user_id = w.user_id and s.kind = any($3::text[]) and s.lifted_at is null
                               and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now()))) as eligible`,
        [pool, POOL_OPEN_BATCH, CLOSED_KINDS],
      );
      let enqueued = 0;
      for (const row of r.rows) {
        if (!row.eligible) continue;
        await this.notifications.enqueue(row.user_id, 'rooms_pool_open', null, {
          dedupeKey: `pool:${pool}`,
          dedupeTtlMs: POOL_OPEN_DEDUPE_TTL_MS,
        });
        enqueued += 1;
      }
      return { claimed: r.rowCount ?? 0, enqueued, skipped: (r.rowCount ?? 0) - enqueued };
    });
  }

  private async flagOn(key: string): Promise<boolean> {
    const r = await this.db.query<{ enabled: boolean }>('select enabled from public.feature_flags where key = $1', [key]);
    return r.rows[0]?.enabled === true;
  }
}
