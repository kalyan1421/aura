import { Inject, Injectable, Logger } from '@nestjs/common';
import { MediaStoreError, PrivateMediaStore } from '../account/private-media';
import {
  CapsuleSyncHandler,
  markCapsuleEffects,
  newCapsuleEffects,
  rollbackCapsuleEffects,
  type CapsuleEffects,
} from '../capsules/capsule-sync';
import { ApiError } from '../common/api-error';
import { describeZodError } from '../common/zod';
import { isUuid, uuidv5 } from '../common/uuid';
import { CatalogueService } from '../catalogue/catalogue.service';
import type { Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { voiceObjectPath } from '../media/media-paths';
import { NotificationPrefsSyncHandler } from '../notifications/notification-prefs';
import { PoolWaitlistSyncHandler } from '../notifications/pool-waitlist';
import { ProfileService } from '../profile/profile.service';
import { SanctuarySessionSyncHandler } from '../sanctuary/sanctuary-sessions';
import type { Snapshot } from '../progression/snapshot';
import { ProgressionService } from '../progression/progression.service';
import { auraDay, awardFor, daysBetween, isEligible, MAX_FUTURE_SKEW_MS, type StarlightEvent } from '../rules';
import { reject, rejectionReason } from './mutation-rejected';
import { fitsChars } from './text-limits';
import { SyncRepository, type LedgerReason } from './sync.repository';
import {
  checkInPayloadSchema,
  deletePayloadSchema,
  habitLogPayloadSchema,
  habitPayloadSchema,
  MAX_HABIT_NAME_CHARS,
  MAX_MUTATIONS,
  MAX_TAG_CHARS,
  mutationSchema,
  pushRequestSchema,
  timedSchema,
  type CheckInPayload,
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

/** PRD F1 "Edit for 24 h, delete anytime": an edit's deviceTs must be within 24 h of the check-in's. */
export const CHECK_IN_EDIT_WINDOW_MS = 24 * 3600_000;
/** An edit stamped further than this ahead of server time is refused: the ledger's clock-tamper bound (RULES.md §2). */
export const EDIT_MAX_FUTURE_SKEW_MS = MAX_FUTURE_SKEW_MS;

/** Post-commit voice-object cleanup must never hold a push hostage for long. */
export const VOICE_CLEANUP_TIMEOUT_MS = 5_000;

interface Ctx {
  tx: Tx;
  userId: string;
  tz: string;
  now: Date;
  /** Voice objects whose reference an applied mutation removed (edit to null / delete); deleted after commit. */
  voiceCleanup: string[];
  /** F4 capsule side effects (unlock-job scheduling, media cleanup); run after commit. */
  capsuleFx: CapsuleEffects;
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
    /** Storage API client (global QueuesModule) — best-effort voice-object cleanup. */
    private readonly media: PrivateMediaStore,
    /**
     * F4 entity `capsule` (contracts/api/v1-capsules.md), from CapsulesModule. Always injected by Nest (explicit
     * token, so a missing provider fails at boot); optional in the signature only for unit tests that build the
     * service by hand — without it capsule mutations are `unknown_entity`.
     */
    @Inject(CapsuleSyncHandler) private readonly capsules?: CapsuleSyncHandler,
    /**
     * F14 entity `notification_prefs` (contracts/api/v1-notifications.md), from NotificationsModule. Same injection
     * rule as `capsules`: without it (hand-built unit tests) the entity is `unknown_entity`.
     */
    @Inject(NotificationPrefsSyncHandler) private readonly notificationPrefs?: NotificationPrefsSyncHandler,
    /** F5 entity `room_pool_waitlist` ("Tell me when they open"), from NotificationsModule. Same injection rule. */
    @Inject(PoolWaitlistSyncHandler) private readonly poolWaitlist?: PoolWaitlistSyncHandler,
    /** F15 entity `sanctuary_session` (content-free session records), from SanctuaryModule. Same injection rule. */
    @Inject(SanctuarySessionSyncHandler) private readonly sanctuarySessions?: SanctuarySessionSyncHandler,
  ) {}

  async push(userId: string, body: unknown, now = new Date()): Promise<PushResponse> {
    const mutationsLen = (body as { mutations?: unknown })?.mutations;
    if (Array.isArray(mutationsLen) && mutationsLen.length > MAX_MUTATIONS) {
      throw ApiError.badRequest('too_many_mutations', `At most ${MAX_MUTATIONS} mutations per push.`);
    }
    const parsed = pushRequestSchema.safeParse(body);
    if (!parsed.success) throw ApiError.badRequest('invalid_request', describeZodError(parsed.error));
    const { timezone: tz } = await this.profiles.require(userId);

    const { results, snapshot, orphans, capsuleFx } = await this.db.withTx(async (tx) => {
      await this.repo.lockUser(tx, userId);
      const ctx: Ctx = { tx, userId, tz, now, voiceCleanup: [], capsuleFx: newCapsuleEffects() };
      const results: MutationResult[] = [];
      for (const raw of parsed.data.mutations) results.push(await this.applyOne(ctx, raw));
      const snapshot = await this.progression.recompute(tx, userId, tz, now);
      return { results, snapshot, orphans: await this.unreferenced(ctx), capsuleFx: ctx.capsuleFx };
    });
    await this.removeVoiceObjects(orphans); // only after commit: a rolled-back push never loses a recording
    await this.capsules?.afterCommit(userId, capsuleFx); // best-effort, never changes the result
    return { results, snapshot };
  }

  /**
   * Candidates no check-in of the user references any more at the end of the push (a later mutation in
   * the same batch may have set the path again), restricted to the caller's own voice prefix.
   */
  private async unreferenced(ctx: Ctx): Promise<string[]> {
    const prefix = voiceObjectPath(ctx.userId, '');
    const candidates = [...new Set(ctx.voiceCleanup)].filter((p) => p.startsWith(prefix));
    if (candidates.length === 0) return [];
    const stillUsed = await this.repo.referencedVoicePaths(ctx.tx, ctx.userId, candidates);
    return candidates.filter((p) => !stillUsed.has(p));
  }

  /**
   * Best-effort: failures are logged (counts and error kinds only — never paths or ids) and never fail the
   * push; whatever is left under the user's prefix goes with the account purge.
   */
  private async removeVoiceObjects(paths: string[]): Promise<void> {
    if (paths.length === 0) return;
    if (!this.media.configured) {
      this.logger.warn(`voice cleanup skipped for ${paths.length} object(s): SUPABASE_SERVICE_ROLE_KEY is not set`);
      return;
    }
    try {
      await this.media.remove(paths, { timeoutMs: VOICE_CLEANUP_TIMEOUT_MS });
    } catch (err) {
      // MediaStoreError carries only the HTTP status; other errors are reduced to their name.
      const kind = err instanceof MediaStoreError ? err.message : err instanceof Error ? err.name : 'error';
      this.logger.warn(`voice cleanup failed for ${paths.length} object(s): ${kind}`);
    }
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
    const cleanupMark = ctx.voiceCleanup.length;
    const capsuleMark = markCapsuleEffects(ctx.capsuleFx);
    try {
      await ctx.tx.savepoint(() => this.dispatch(ctx, raw));
    } catch (err) {
      ctx.voiceCleanup.length = cleanupMark; // the savepoint rolled back: nothing of this mutation stays
      rollbackCapsuleEffects(ctx.capsuleFx, capsuleMark);
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
        return this.deleteCheckIn(ctx, m);
      case 'habit:upsert':
        return this.upsertHabit(ctx, m);
      case 'habit:delete':
        return this.repo.deleteHabit(ctx.tx, ctx.userId, this.payload(deletePayloadSchema, m).id);
      case 'habit_log:upsert':
        return this.upsertHabitLog(ctx, m);
      case 'habit_log:delete':
        return this.repo.deleteHabitLog(ctx.tx, ctx.userId, this.payload(deletePayloadSchema, m).id);
      case 'capsule:seal':
      case 'capsule:open':
      case 'capsule:fire':
      case 'capsule:rearm':
      case 'capsule:delete':
        if (!this.capsules) return reject('unknown_entity');
        return this.capsules.apply(ctx, m, ctx.capsuleFx);
      case 'notification_prefs:upsert':
        if (!this.notificationPrefs) return reject('unknown_entity');
        return this.notificationPrefs.apply(ctx, m);
      case 'room_pool_waitlist:upsert':
      case 'room_pool_waitlist:delete':
        if (!this.poolWaitlist) return reject('unknown_entity');
        return this.poolWaitlist.apply(ctx, m);
      case 'sanctuary_session:upsert':
      case 'sanctuary_session:delete':
        if (!this.sanctuarySessions) return reject('unknown_entity');
        return this.sanctuarySessions.apply(ctx, m); // op `upsert` only (`delete` → unknown_op)
      default:
        return reject('unknown_op'); // a valid op the entity doesn't support (e.g. capsule:upsert, check_in:seal)
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

  /**
   * `voicePath` of a check-in upsert: absent → undefined (keep), null → null (clear), otherwise it must be
   * `<caller user_id>/voice/<check-in id>` (returned canonical, lower-case) or the mutation is rejected.
   */
  private voicePathOf(ctx: Ctx, p: CheckInPayload): string | null | undefined {
    const v = p.voicePath;
    if (v === undefined || v === null) return v;
    const expected = voiceObjectPath(ctx.userId, p.id);
    if (typeof v === 'string' && v.toLowerCase() === expected) return expected;
    return reject('invalid_voice_path');
  }

  private async upsertCheckIn(ctx: Ctx, m: Mutation): Promise<void> {
    const p = this.payload(checkInPayloadSchema, m);
    if (p.tags.some((t) => !fitsChars(t, MAX_TAG_CHARS))) reject('tag_too_long');
    const voicePath = this.voicePathOf(ctx, p);
    const quadrant = await this.catalogue.moodQuadrant(p.moodId);
    if (!quadrant) return reject('unknown_mood');

    const existing = await this.repo.lockCheckIn(ctx.tx, p.id);
    if (existing && existing.userId !== ctx.userId) return reject('id_conflict');
    if (existing) {
      this.checkEditWindow(ctx, p.editedAt ?? m.deviceTs, existing.deviceTs);
      await this.repo.updateCheckIn(ctx.tx, ctx.userId, p, quadrant, voicePath); // edit: no new credit
      if (voicePath === null && existing.voicePath) ctx.voiceCleanup.push(existing.voicePath);
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
      voicePath: voicePath ?? null,
    });
    if (t.eligible) await this.credit(ctx, 'checkin', p.id, null, t.localDay, { type: 'checkin' });
  }

  /**
   * Edits (upsert of an existing id) are judged by when the edit was made — `payload.editedAt`, else the
   * mutation's `deviceTs` — never by receive time, so an edit made offline at 23 h and synced at 30 h still
   * applies: it must lie within 24 h of the check-in's stored `device_ts` and not more than 5 min (the
   * ledger's clock-skew bound) ahead of server time → else `edit_window_closed`. Neither timestamp →
   * `invalid_payload`. Deletes are allowed any time; inserts never look at `editedAt`.
   */
  private checkEditWindow(ctx: Ctx, editedAt: string | undefined, storedDeviceTs: Date): void {
    if (!editedAt) return reject('invalid_payload');
    const editTs = Date.parse(editedAt);
    if (editTs > ctx.now.getTime() + EDIT_MAX_FUTURE_SKEW_MS) reject('edit_window_closed');
    if (Math.abs(editTs - storedDeviceTs.getTime()) > CHECK_IN_EDIT_WINDOW_MS) reject('edit_window_closed');
  }

  /** Scoped by user_id (someone else's id is a silent no-op); its voice object follows after commit. */
  private async deleteCheckIn(ctx: Ctx, m: Mutation): Promise<void> {
    const deleted = await this.repo.deleteCheckIn(ctx.tx, ctx.userId, this.payload(deletePayloadSchema, m).id);
    if (deleted?.voicePath) ctx.voiceCleanup.push(deleted.voicePath);
  }

  private async upsertHabit(ctx: Ctx, m: Mutation): Promise<void> {
    const p = this.payload(habitPayloadSchema, m);
    if (p.name !== null && !fitsChars(p.name, MAX_HABIT_NAME_CHARS)) reject('habit_name_too_long');
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
