import { Injectable, Module } from '@nestjs/common';
import { z } from 'zod';
import { UUID_RE } from '../common/uuid';
import type { Tx } from '../db/db';
import {
  auraDay,
  constellationProblem,
  daysBetween,
  isLocalDay,
  MAX_FUTURE_SKEW_MS,
  MAX_LOOM_CONSTELLATIONS_PER_DAY,
} from '../rules';
import { reject } from '../sync/mutation-rejected';
import type { Mutation } from '../sync/sync.schema';

/**
 * U07 Orbit Loom constellations (RULES.md §14; contracts/api/v1.md "Loom constellations"; migration 20261005000038).
 *
 * Sync entity `loom_constellation`:
 *
 *   { "id": "<mutation uuidv7>", "entity": "loom_constellation", "op": "upsert",
 *     "deviceTs": "<when it was kept>", "localDay": "<that Aura day>", "tz": "Asia/Kolkata",
 *     "payload": { "id": "<constellation uuidv7>", "stars": [[0.2, 0.2], [0.8, 0.25], [0.5, 0.8]],
 *                  "links": [[0, 1], [1, 2]], "meaning": "noticed" } }
 *
 *   { ..., "op": "delete", "payload": { "id": "<constellation uuidv7>" } }
 *
 * Cosmetic by construction: star points, star-index pairs and an optional meaning from a closed list. Nothing awards
 * or removes Starlight, streaks or keepsakes. `upsert` keeps a constellation once (idempotent on its id; nothing ever
 * changes one afterwards); `delete` lets it go (soft delete that erases the shape, so phones pulling by `updated_at`
 * learn it is gone). Someone else's id → `id_conflict`.
 */
export const LOOM_CONSTELLATION_ENTITY = 'loom_constellation';

/** Like Sanctuary sessions: one day of slack behind and two ahead between the device's zone and the profile's. */
export const LOOM_MAX_BEHIND_DAYS = 1;
export const LOOM_MAX_AHEAD_DAYS = 2;

const uuid = z.string().regex(UUID_RE, 'must be a UUID').transform((s) => s.toLowerCase());

export const constellationPayloadSchema = z.object({
  id: uuid,
  stars: z.array(z.array(z.number())).max(64),
  links: z.array(z.array(z.number())).max(64),
  meaning: z.string().nullable().optional(),
});
export type ConstellationPayload = z.infer<typeof constellationPayloadSchema>;

const timedSchema = z.object({
  deviceTs: z.iso.datetime({ offset: true }),
  localDay: z.string().refine(isLocalDay, 'must be a real date YYYY-MM-DD'),
});

/**
 * Validates an `upsert` (pure). Rejections: `invalid_payload` (shape, missing `deviceTs` / `localDay`),
 * `invalid_constellation` (RULES.md §14 `problem`: too few / many stars, outside the sky, too close, bad or
 * duplicate lines, unknown meaning), `device_ts_in_future`, `invalid_local_day` (the day doesn't fit the time).
 */
export function validateConstellation(
  m: Pick<Mutation, 'deviceTs' | 'localDay' | 'tz' | 'payload'>,
  profileTz: string,
  now: Date,
): { payload: ConstellationPayload & { meaning: string | null }; deviceTs: string; localDay: string } {
  const t = timedSchema.safeParse({ deviceTs: m.deviceTs, localDay: m.localDay });
  if (!t.success) return reject('invalid_payload');
  const p = constellationPayloadSchema.safeParse(m.payload);
  if (!p.success) return reject('invalid_payload');
  const meaning = p.data.meaning ?? null;
  if (constellationProblem(p.data.stars, p.data.links, meaning) !== null) return reject('invalid_constellation');
  const { deviceTs, localDay } = t.data;
  if (Date.parse(deviceTs) > now.getTime() + MAX_FUTURE_SKEW_MS) return reject('device_ts_in_future');
  const behind = daysBetween(localDay, auraDay(deviceTs, m.tz ?? profileTz)); // > 0: stamped an earlier day
  if (behind > LOOM_MAX_BEHIND_DAYS || behind < -LOOM_MAX_AHEAD_DAYS) return reject('invalid_local_day');
  return { payload: { ...p.data, meaning }, deviceTs, localDay };
}

type Ctx = { tx: Tx; userId: string; tz: string; now: Date };

/** `loom_constellation` upsert / delete inside the sync push (SyncModule). */
@Injectable()
export class LoomConstellationSyncHandler {
  async apply(ctx: Ctx, m: Mutation): Promise<void> {
    if (m.op === 'upsert') return this.keep(ctx, m);
    if (m.op === 'delete') return this.letGo(ctx, m);
    return reject('unknown_op');
  }

  private async owner(tx: Tx, id: string): Promise<string | undefined> {
    const r = await tx.query<{ user_id: string }>('select user_id from public.loom_constellations where id = $1', [id]);
    return r.rows[0]?.user_id;
  }

  private async keep(ctx: Ctx, m: Mutation): Promise<void> {
    const { payload: p, deviceTs, localDay } = validateConstellation(m, ctx.tz, ctx.now);
    const owner = await this.owner(ctx.tx, p.id);
    if (owner !== undefined) {
      if (owner !== ctx.userId) return reject('id_conflict');
      return; // kept already (a lost reply resent, or it was let go since): nothing changes
    }
    const today = await ctx.tx.query<{ n: number }>(
      `select count(*)::int as n from public.loom_constellations
        where user_id = $1 and local_day = $2::date and deleted_at is null`,
      [ctx.userId, localDay],
    );
    if ((today.rows[0]?.n ?? 0) >= MAX_LOOM_CONSTELLATIONS_PER_DAY) return reject('too_many_constellations');
    await ctx.tx.query(
      `insert into public.loom_constellations (id, user_id, stars, links, meaning, local_day, device_ts)
       values ($1, $2, $3::jsonb, $4::jsonb, $5, $6::date, $7::timestamptz)
       on conflict (id) do nothing`,
      [p.id, ctx.userId, JSON.stringify(p.stars), JSON.stringify(p.links), p.meaning, localDay, deviceTs],
    );
  }

  private async letGo(ctx: Ctx, m: Mutation): Promise<void> {
    const p = z.object({ id: uuid }).safeParse(m.payload);
    if (!p.success) return reject('invalid_payload');
    const owner = await this.owner(ctx.tx, p.data.id);
    if (owner === undefined) return; // never reached the server (or already purged): nothing to let go
    if (owner !== ctx.userId) return reject('id_conflict');
    await ctx.tx.query(
      `update public.loom_constellations
          set deleted_at = coalesce(deleted_at, now()), stars = null, links = null, meaning = null, updated_at = now()
        where id = $1 and user_id = $2 and deleted_at is null`,
      [p.data.id, ctx.userId],
    );
  }
}

/** U07 Orbit Loom: the `loom_constellation` sync entity (imported by SyncModule). */
@Module({
  providers: [LoomConstellationSyncHandler],
  exports: [LoomConstellationSyncHandler],
})
export class ConstellationsModule {}
