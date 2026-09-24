import type { Queryable } from '../db/db';
import { Injectable, Logger } from '@nestjs/common';
import { MediaStoreError, PrivateMediaStore } from '../account/private-media';
import { CatalogueService } from '../catalogue/catalogue.service';
import type { Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { addDays, localDate, type Quadrant } from '../rules';
import { reject } from '../sync/mutation-rejected';
import type { Mutation } from '../sync/sync.schema';
import { addYears, armedAtFor, cooldownUntilFor, isValidUnlockDate, UNLOCK_MAX_YEARS } from './capsule-rules';
import { CapsuleUnlockService } from './capsule-unlock.service';
import { CapsulesRepository, type CapsuleRow } from './capsules.repository';
import {
  capsuleDeletePayloadSchema,
  cyclePayloadSchema,
  MAX_ACTIVE_TRIGGER_CAPSULES,
  MAX_PENDING_DATE_CAPSULES,
  sealPayloadSchema,
  SERVER_UNLOCK_SLACK_DAYS,
} from './capsules.schema';

/** What a capsule op needs from the running push (one transaction, per-user lock already held). */
export interface CapsuleCtx {
  tx: Tx;
  userId: string;
  /** Profile timezone (the seal's zone when the mutation carries no `tz`). */
  tz: string;
  now: Date;
}

/** Side effects collected during the push, run only after it commits (a rolled-back push changes nothing). */
export interface CapsuleEffects {
  /** Date capsules sealed → schedule their unlock push. */
  schedule: string[];
  /** Date capsules opened / deleted → cancel their unlock job. */
  unschedule: string[];
  /** Capsules deleted → delete their media objects. */
  removeMedia: string[];
}
export type CapsuleEffectsMark = readonly [number, number, number];

export const newCapsuleEffects = (): CapsuleEffects => ({ schedule: [], unschedule: [], removeMedia: [] });
export const markCapsuleEffects = (fx: CapsuleEffects): CapsuleEffectsMark => [
  fx.schedule.length,
  fx.unschedule.length,
  fx.removeMedia.length,
];
/** A mutation's savepoint rolled back: forget the effects it had queued. */
export function rollbackCapsuleEffects(fx: CapsuleEffects, mark: CapsuleEffectsMark): void {
  fx.schedule.length = mark[0];
  fx.unschedule.length = mark[1];
  fx.removeMedia.length = mark[2];
}

/** Post-commit work (Redis + Storage) must never hold a push hostage for long. */
export const CAPSULE_AFTER_COMMIT_TIMEOUT_MS = 5_000;

const later = (a: Date, b: Date): boolean => a.getTime() > b.getTime();
/** Device claims are never stored ahead of the server clock (a fast clock cannot stretch the cooldown). */
const clampToNow = (t: Date, now: Date): Date => (later(t, now) ? now : t);

class TimeoutError extends Error {
  override readonly name = 'TimeoutError';
}
async function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  try {
    return await Promise.race([
      p,
      new Promise<never>((_, rej) => {
        timer = setTimeout(() => rej(new TimeoutError('timed out')), ms);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
const errorKind = (err: unknown): string =>
  err instanceof MediaStoreError ? err.message : err instanceof Error ? err.name : 'error';

/**
 * Sync entity `capsule` (contracts/api/v1-capsules.md §2): seal / open / fire / rearm / delete, applied inside the
 * sync push transaction. Rejections throw MutationRejected (the push records them and continues). Stores ciphertext
 * and unlock metadata only; never logs ids, content, dates or targets.
 */
@Injectable()
export class CapsuleSyncHandler {
  private readonly logger = new Logger('Capsules');

  constructor(
    private readonly repo: CapsulesRepository,
    private readonly catalogue: CatalogueService,
    private readonly unlock: CapsuleUnlockService,
    private readonly media: PrivateMediaStore,
    private readonly db: DbService,
  ) {}

  /** Free = 3 active trigger capsules; Aura Plus = unlimited (F12, the server-owned entitlement). */
  async maxActiveTriggers(q: Queryable, userId: string): Promise<number> {
    return (await this.repo.plusActive(q, userId)) ? Number.POSITIVE_INFINITY : MAX_ACTIVE_TRIGGER_CAPSULES;
  }

  async apply(ctx: CapsuleCtx, m: Mutation, fx: CapsuleEffects): Promise<void> {
    if (!m.deviceTs) return reject('invalid_payload');
    const at = new Date(m.deviceTs);
    switch (m.op) {
      case 'seal':
        return this.seal(ctx, m, at, fx);
      case 'open':
        return this.open(ctx, m, at, fx);
      case 'fire':
        return this.fire(ctx, m, at);
      case 'rearm':
        return this.rearm(ctx, m, at);
      case 'delete':
        return this.remove(ctx, m, fx);
      default:
        return reject('unknown_op');
    }
  }

  private parse<T>(schema: { safeParse(v: unknown): { success: true; data: T } | { success: false } }, m: Mutation): T {
    const r = schema.safeParse(m.payload);
    if (!r.success) return reject('invalid_payload');
    return r.data;
  }

  /** §2.1 — create; content and unlock metadata never change afterwards. */
  private async seal(ctx: CapsuleCtx, m: Mutation, at: Date, fx: CapsuleEffects): Promise<void> {
    const p = this.parse(sealPayloadSchema, m);
    let moodId: string | null = null;
    let quadrant: Quadrant | null = null;
    if (p.unlockType === 'mood') {
      moodId = p.triggerMoodId ?? null;
      quadrant = p.triggerQuadrant ?? null;
      if ((moodId === null) === (quadrant === null)) reject('invalid_payload'); // exactly one target
      if (moodId !== null && !(await this.catalogue.moodQuadrant(moodId))) reject('unknown_mood');
    }
    const unlockLocalDate = p.unlockType === 'date' ? p.unlockLocalDate : null;

    const existing = await this.repo.lockById(ctx.tx, p.id);
    if (existing) {
      if (existing.userId !== ctx.userId) reject('id_conflict');
      if (existing.deletedAt) reject('capsule_deleted');
      const resend =
        existing.payloadCt === p.payloadCt &&
        existing.unlockType === p.unlockType &&
        existing.unlockLocalDate === unlockLocalDate &&
        existing.triggerMoodId === moodId &&
        existing.triggerQuadrant === quadrant;
      if (resend) return; // the same seal again (new mutation id): nothing to change
      return reject('capsule_sealed');
    }

    if (p.unlockType === 'date') {
      const tz = m.tz ?? ctx.tz;
      if (!isValidUnlockDate(at, tz, p.unlockLocalDate)) reject('invalid_unlock_date');
      // Broken-clock guard (server only): never more than 5 years (+ slack) past the server's own date.
      const serverMax = addDays(addYears(localDate(ctx.now, tz), UNLOCK_MAX_YEARS), SERVER_UNLOCK_SLACK_DAYS);
      if (p.unlockLocalDate > serverMax) reject('invalid_unlock_date');
      if ((await this.repo.countPendingDates(ctx.tx, ctx.userId)) >= MAX_PENDING_DATE_CAPSULES) reject('date_capsule_limit');
    } else if ((await this.repo.countActiveTriggers(ctx.tx, ctx.userId)) >= (await this.maxActiveTriggers(ctx.tx, ctx.userId))) {
      reject('trigger_capsule_limit');
    }

    await this.repo.insert(ctx.tx, {
      id: p.id,
      userId: ctx.userId,
      unlockType: p.unlockType,
      unlockLocalDate,
      triggerMoodId: moodId,
      triggerQuadrant: quadrant,
      payloadCt: p.payloadCt,
      sealedAt: at,
      armedAt: p.unlockType === 'mood' ? armedAtFor(at) : null,
    });
    if (p.unlockType === 'date') fx.schedule.push(p.id);
  }

  /** §2.2 — one-way; the server records the real (server) time. Early opens are tolerated. */
  private async open(ctx: CapsuleCtx, m: Mutation, at: Date, fx: CapsuleEffects): Promise<void> {
    const p = this.parse(cyclePayloadSchema, m);
    const c = await this.current(ctx, p.id, p.cycle);
    if (c.openedAt) return; // the first open wins
    let fired: { firedAt: Date; cooldownUntil: Date } | null = null;
    if (c.unlockType === 'mood' && !c.firedAt) {
      // Opening a trigger capsule that was never reported fired: the open is the fire.
      if (!c.armedAt || at < c.armedAt) reject('capsule_not_armed');
      const firedAt = clampToNow(at, ctx.now);
      fired = { firedAt, cooldownUntil: cooldownUntilFor(firedAt) };
    }
    await this.repo.markOpened(ctx.tx, c.id, ctx.now, at, fired);
    if (c.unlockType === 'date') {
      await this.repo.deleteSchedules(ctx.tx, [c.id]);
      fx.unschedule.push(c.id);
    }
  }

  /** §2.3 — at most once per cycle; when two devices fired it offline, the earliest wins. */
  private async fire(ctx: CapsuleCtx, m: Mutation, at: Date): Promise<void> {
    const p = this.parse(cyclePayloadSchema, m);
    const c = await this.current(ctx, p.id, p.cycle);
    if (c.unlockType !== 'mood') reject('not_a_trigger_capsule');
    if (!c.armedAt || at < c.armedAt) reject('capsule_not_armed');
    const firedAt = clampToNow(at, ctx.now);
    if (c.firedAt && !later(c.firedAt, firedAt)) return; // an earlier (or the same) fire already stands
    await this.repo.setFired(ctx.tx, c.id, firedAt, cooldownUntilFor(firedAt));
  }

  /** §2.4 — "Keep for next time": a new cycle; counts toward the active-trigger limit again. */
  private async rearm(ctx: CapsuleCtx, m: Mutation, at: Date): Promise<void> {
    const p = this.parse(cyclePayloadSchema, m);
    const c = await this.current(ctx, p.id, p.cycle);
    if (c.unlockType !== 'mood') reject('not_a_trigger_capsule');
    if (!c.openedAt) reject('capsule_not_opened');
    if ((await this.repo.countActiveTriggers(ctx.tx, ctx.userId, c.id)) >= (await this.maxActiveTriggers(ctx.tx, ctx.userId))) {
      reject('trigger_capsule_limit');
    }
    await this.repo.rearm(ctx.tx, c.id, clampToNow(at, ctx.now));
  }

  /** §2.5 — tombstone (delete always wins); unknown / foreign / already deleted → silent no-op. */
  private async remove(ctx: CapsuleCtx, m: Mutation, fx: CapsuleEffects): Promise<void> {
    const { id } = this.parse(capsuleDeletePayloadSchema, m);
    const c = await this.repo.lockById(ctx.tx, id);
    if (!c || c.userId !== ctx.userId || c.deletedAt) return;
    await this.repo.tombstone(ctx.tx, c.id, ctx.now);
    await this.repo.deleteSchedules(ctx.tx, [c.id]);
    if (c.unlockType === 'date') fx.unschedule.push(c.id);
    fx.removeMedia.push(c.id);
  }

  /** The caller's live capsule in the given cycle, locked — or the matching rejection. */
  private async current(ctx: CapsuleCtx, id: string, cycle: number): Promise<CapsuleRow> {
    const c = await this.repo.lockById(ctx.tx, id);
    if (!c || c.userId !== ctx.userId) return reject('capsule_not_found');
    if (c.deletedAt) return reject('capsule_deleted');
    if (c.cycle !== cycle) return reject('stale_cycle');
    return c;
  }

  /**
   * After the push committed: cancel unlock jobs of opened/deleted date capsules, schedule the new ones, delete
   * deleted capsules' media. Best-effort and time-boxed: failures are logged (counts and error kinds only) and never
   * change the push result — the worker sweep schedules whatever was missed, a stale job finds its capsule opened or
   * deleted and does nothing, and leftover media goes with the account purge.
   */
  async afterCommit(userId: string, fx: CapsuleEffects): Promise<void> {
    const unschedule = [...new Set(fx.unschedule)];
    const schedule = [...new Set(fx.schedule)];
    const removeMedia = [...new Set(fx.removeMedia)];
    // Independent, so concurrent (one 5 s budget): schedule() only ever picks capsules that are still pending after the
    // commit, unschedule() only opened/deleted ones.
    await Promise.all([
      unschedule.length > 0 ? this.bestEffort('unlock-job cancel', unschedule.length, () => this.unlock.unschedule(unschedule)) : null,
      schedule.length > 0 ? this.bestEffort('unlock-job schedule', schedule.length, () => this.unlock.schedule(schedule)) : null,
      removeMedia.length > 0 ? this.removeMedia(userId, removeMedia) : null,
    ]);
  }

  private async removeMedia(userId: string, capsuleIds: string[]): Promise<void> {
    if (!this.media.configured) {
      this.logger.warn(`capsule media cleanup skipped for ${capsuleIds.length} capsule(s): SUPABASE_SERVICE_ROLE_KEY is not set`);
      return;
    }
    await this.bestEffort('capsule media cleanup', capsuleIds.length, async () => {
      const names = await this.repo.listCapsuleObjects(this.db, userId, capsuleIds);
      if (names.length > 0) await this.media.remove(names, { timeoutMs: CAPSULE_AFTER_COMMIT_TIMEOUT_MS });
    });
  }

  private async bestEffort(what: string, n: number, fn: () => Promise<unknown>): Promise<void> {
    try {
      await withTimeout(fn(), CAPSULE_AFTER_COMMIT_TIMEOUT_MS);
    } catch (err) {
      this.logger.warn(`${what} failed for ${n} capsule(s): ${errorKind(err)}`);
    }
  }
}
