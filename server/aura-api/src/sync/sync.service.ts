import { Injectable, Logger } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { describeZodError } from '../common/zod';
import { isUuid, uuidv5 } from '../common/uuid';
import { CatalogueService } from '../catalogue/catalogue.service';
import type { Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { ProfileService } from '../profile/profile.service';
import type { Snapshot } from '../progression/snapshot';
import { ProgressionService } from '../progression/progression.service';
import { auraDay, awardFor, daysBetween, isEligible, type StarlightEvent } from '../rules';
import { reject, rejectionReason } from './mutation-rejected';
import { SyncRepository, type LedgerReason } from './sync.repository';
import {
  checkInPayloadSchema,
  deletePayloadSchema,
  habitLogPayloadSchema,
  habitPayloadSchema,
  MAX_MUTATIONS,
  mutationSchema,
  pushRequestSchema,
  timedSchema,
  type Mutation,
  type MutationResult,
} from './sync.schema';

/** Backfills (localDay before the event's aura day) are stored for up to 7 days (RULES.md §2). */
export const MAX_BACKFILL_DAYS = 7;
/**
 * A localDay *after* the event's aura day in the profile tz can only come from a device in a
 * zone ahead of the profile's (max 26h apart → ≤ 2 days). Stored uncredited, beyond that rejected.
 */
export const MAX_AHEAD_DAYS = 2;

/** PRD F2: the 6 presets (each at most once per user) + up to 3 active custom habits. */
export const MAX_ACTIVE_CUSTOM_HABITS = 3;

/** Namespace for deterministic habit ledger source ids: uuidv5(`${habitId}:${localDay}`). */
export const HABIT_CREDIT_NS = '6f1f5a4e-2c1b-4d7e-9a53-0b8f3c2d9e71';
export const habitCreditId = (habitId: string, localDay: string): string =>
  uuidv5(`${habitId}:${localDay}`, HABIT_CREDIT_NS);

interface Ctx {
  tx: Tx;
  userId: string;
  tz: string;
  now: Date;
}

interface Timing {
  deviceTs: string;
  localDay: string;
  eligible: boolean;
  backfill: boolean;
}

export interface PushResponse {
  results: MutationResult[];
  snapshot: Snapshot;
}

@Injectable()
export class SyncService {
  private readonly logger = new Logger('Sync');

  constructor(
    private readonly db: DbService,
    private readonly repo: SyncRepository,
    private readonly profiles: ProfileService,
    private readonly catalogue: CatalogueService,
    private readonly progression: ProgressionService,
  ) {}

  async push(userId: string, body: unknown, now = new Date()): Promise<PushResponse> {
    const mutationsLen = (body as { mutations?: unknown })?.mutations;
    if (Array.isArray(mutationsLen) && mutationsLen.length > MAX_MUTATIONS) {
      throw ApiError.badRequest('too_many_mutations', `At most ${MAX_MUTATIONS} mutations per push.`);
    }
    const parsed = pushRequestSchema.safeParse(body);
    if (!parsed.success) throw ApiError.badRequest('invalid_request', describeZodError(parsed.error));
    const { timezone: tz } = await this.profiles.require(userId);

    return this.db.withTx(async (tx) => {
      await this.repo.lockUser(tx, userId);
      const ctx: Ctx = { tx, userId, tz, now };
      const results: MutationResult[] = [];
      for (const raw of parsed.data.mutations) results.push(await this.applyOne(ctx, raw));
      const snapshot = await this.progression.recompute(tx, userId, tz, now);
      return { results, snapshot };
    });
  }

  /** Idempotent, isolated application of one mutation (its own savepoint). */
  private async applyOne(ctx: Ctx, raw: unknown): Promise<MutationResult> {
    const rawId = (raw as { id?: unknown })?.id;
    if (!isUuid(rawId)) {
      // Without a valid id there is no idempotency key to record against.
      return { id: typeof rawId === 'string' ? rawId : '', status: 'rejected', reason: 'invalid_mutation_id' };
    }
    const id = rawId.toLowerCase();
    const entity = String((raw as { entity?: unknown }).entity ?? '');

    const prior = await this.repo.findMutation(ctx.tx, ctx.userId, id);
    if (prior) {
      // Replay. Applied → `duplicate`; rejected → the same deterministic rejection again.
      return prior.status === 'applied'
        ? { id, status: 'duplicate' }
        : { id, status: 'rejected', reason: prior.reason ?? 'rejected' };
    }

    let reason: string | null = null;
    try {
      await ctx.tx.savepoint(() => this.dispatch(ctx, raw));
    } catch (err) {
      const r = rejectionReason(err);
      if (r === undefined) throw err; // infrastructure failure → whole push fails, client retries
      reason = r;
      this.logger.debug(`rejected ${entity} mutation ${id}: ${r}`);
    }
    await this.repo.recordMutation(ctx.tx, {
      userId: ctx.userId,
      mutationId: id,
      entity,
      status: reason ? 'rejected' : 'applied',
      reason,
    });
    return reason ? { id, status: 'rejected', reason } : { id, status: 'applied' };
  }

  private async dispatch(ctx: Ctx, raw: unknown): Promise<void> {
    const env = mutationSchema.safeParse(raw);
    if (!env.success) {
      const field = env.error.issues[0]?.path[0];
      reject(
        field === 'entity' ? 'unknown_entity' : field === 'op' ? 'unknown_op' : field === 'tz' ? 'invalid_tz' : 'invalid_payload',
      );
      return;
    }
    const m = env.data;
    const key = `${m.entity}:${m.op}` as const;
    switch (key) {
      case 'check_in:upsert':
        return this.upsertCheckIn(ctx, m);
      case 'check_in:delete':
        return this.repo.deleteCheckIn(ctx.tx, ctx.userId, this.payload(deletePayloadSchema, m).id);
      case 'habit:upsert':
        return this.upsertHabit(ctx, m);
      case 'habit:delete':
        return this.repo.deleteHabit(ctx.tx, ctx.userId, this.payload(deletePayloadSchema, m).id);
      case 'habit_log:upsert':
        return this.upsertHabitLog(ctx, m);
      case 'habit_log:delete':
        return this.repo.deleteHabitLog(ctx.tx, ctx.userId, this.payload(deletePayloadSchema, m).id);
    }
  }

  private payload<T>(schema: { safeParse(v: unknown): { success: true; data: T } | { success: false } }, m: Mutation): T {
    const r = schema.safeParse(m.payload);
    if (!r.success) return reject('invalid_payload');
    return r.data;
  }

  /**
   * RULES.md §2 timing for a *new* event, judged in the zone the device stamped it in
   * (`m.tz`), so travel never turns a live check-in into a backfill. Edits never re-evaluate timing.
   */
  private timing(ctx: Ctx, m: Mutation): Timing {
    const t = timedSchema.safeParse({ deviceTs: m.deviceTs, localDay: m.localDay });
    if (!t.success) return reject('invalid_payload');
    const { deviceTs, localDay } = t.data;
    const tz = m.tz ?? ctx.tz;
    const behind = daysBetween(localDay, auraDay(deviceTs, tz)); // > 0 ⇒ backfill
    if (behind > MAX_BACKFILL_DAYS) reject('backfill_too_old');
    if (behind < -MAX_AHEAD_DAYS) reject('invalid_local_day');
    return {
      deviceTs,
      localDay,
      backfill: behind > 0,
      eligible: isEligible({ deviceTs, serverNow: ctx.now, tz, localDay }),
    };
  }

  private async upsertCheckIn(ctx: Ctx, m: Mutation): Promise<void> {
    const p = this.payload(checkInPayloadSchema, m);
    const quadrant = await this.catalogue.moodQuadrant(p.moodId);
    if (!quadrant) return reject('unknown_mood');

    const owner = await this.repo.checkInOwner(ctx.tx, p.id);
    if (owner && owner !== ctx.userId) return reject('id_conflict');
    if (owner) {
      await this.repo.updateCheckIn(ctx.tx, ctx.userId, p, quadrant); // edit: no new credit
      return;
    }
    const t = this.timing(ctx, m);
    await this.repo.insertCheckIn(ctx.tx, {
      userId: ctx.userId,
      p,
      quadrant,
      localDay: t.localDay,
      deviceTs: t.deviceTs,
      backfill: t.backfill,
    });
    if (t.eligible) await this.credit(ctx, 'checkin', p.id, null, t.localDay, { type: 'checkin' });
  }

  private async upsertHabit(ctx: Ctx, m: Mutation): Promise<void> {
    const p = this.payload(habitPayloadSchema, m);
    if (p.kind === 'preset') {
      if (!(await this.catalogue.isPresetHabit(p.presetKey))) reject('unknown_preset_habit');
      if (await this.repo.presetHabitTaken(ctx.tx, ctx.userId, p.presetKey, p.id)) reject('duplicate_preset_habit');
    } else if (p.active && (await this.repo.countActiveCustomHabits(ctx.tx, ctx.userId, p.id)) >= MAX_ACTIVE_CUSTOM_HABITS) {
      reject('too_many_custom_habits');
    }
    if (!(await this.repo.upsertHabit(ctx.tx, ctx.userId, p))) reject('id_conflict');
  }

  private async upsertHabitLog(ctx: Ctx, m: Mutation): Promise<void> {
    const p = this.payload(habitLogPayloadSchema, m);
    const habit = await this.repo.findHabit(ctx.tx, ctx.userId, p.habitId);
    if (!habit) return reject('habit_not_found');

    const owner = await this.repo.habitLogOwner(ctx.tx, p.id);
    if (owner && owner !== ctx.userId) return reject('id_conflict');
    if (owner) return; // same log re-sent under a new mutation id: nothing to change

    const t = this.timing(ctx, m);
    const inserted = await this.repo.insertHabitLog(ctx.tx, {
      id: p.id,
      userId: ctx.userId,
      habitId: p.habitId,
      localDay: t.localDay,
      deviceTs: t.deviceTs,
    });
    if (!inserted) return reject('already_logged');
    if (t.eligible) {
      await this.credit(ctx, 'habit', habitCreditId(p.habitId, t.localDay), habit.presetKey, t.localDay, {
        type: 'habit',
        habitId: p.habitId,
      });
    }
  }

  /**
   * Append one ledger row for an eligible event (amount may be 0: 4th+ check-in or capped) and
   * record the active day. Habit credits use a deterministic source id per (habit, aura day), so
   * un-logging and re-logging a habit can never earn twice (RULES.md §3 "once per habitId per day").
   */
  private async credit(
    ctx: Ctx,
    reason: LedgerReason,
    sourceId: string,
    habitKey: string | null,
    localDay: string,
    event: StarlightEvent,
  ): Promise<void> {
    await this.repo.markActive(ctx.tx, ctx.userId, localDay);
    if (await this.repo.ledgerHas(ctx.tx, reason, sourceId)) return;
    const day = await this.repo.dayLedger(ctx.tx, ctx.userId, localDay);
    const amount = awardFor({ checkIns: day.checkIns, total: day.total, creditedHabitIds: new Set() }, event);
    await this.repo.insertLedger(ctx.tx, { userId: ctx.userId, amount, reason, sourceId, habitKey, localDay });
  }
}
