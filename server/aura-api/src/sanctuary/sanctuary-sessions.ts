import { Injectable, Module } from '@nestjs/common';
import { z } from 'zod';
import { UUID_RE } from '../common/uuid';
import type { Tx } from '../db/db';
import { auraDay, daysBetween, isLocalDay, MAX_FUTURE_SKEW_MS } from '../rules';
import { reject } from '../sync/mutation-rejected';
import type { Mutation } from '../sync/sync.schema';

/**
 * F15 Sanctuary session records (PRD 06d "A finished activity writes one content-free session record (activity,
 * pattern, duration, Aura day) through POST /v1/sync/push"; 10-data-model `sanctuary_sessions`). contracts/api/v1.md
 * "Sanctuary sessions". Migration 20261005000023.
 *
 * Sync entity `sanctuary_session`, op `upsert` only (a record is written once and never edited or deleted by the app):
 *
 *   { "id": "<mutation uuidv7>", "entity": "sanctuary_session", "op": "upsert",
 *     "deviceTs": "<when it finished>", "localDay": "<the Aura day it started>", "tz": "Asia/Kolkata",
 *     "payload": { "id": "<record uuidv7>", "activity": "breathe", "variant": "calm", "durationS": 64 } }
 *
 * Content-free by construction: `activity` and `variant` come from closed lists (below, mirrored by the table's
 * check constraint), `durationS` is a whole number of seconds. Nothing typed, said or picked inside an activity exists
 * in the payload. Idempotent on the record id: re-sending the same record (a new mutation id after a lost reply) is
 * `applied` and changes nothing; the id of someone else's record is `id_conflict`.
 */
export const SANCTUARY_SESSION_ENTITY = 'sanctuary_session';

/** Activity → the variants it may carry (the app's features, mapped in apps/mobile sanctuary_session_log.dart). */
export const SESSION_VARIANTS = {
  /** Breathe and the one-tap breathing minutes: the pattern (Calm 4/6, Box 4-4-4-4, 4-7-8). */
  breathe: ['calm', 'box', '478'],
  /** Grounding library + Storm's minute: three slow breaths (`land`), hand on heart, 5-4-3-2-1, gratitude. */
  grounding: ['land', 'heart', 'senses', 'gratitude'],
  /** Moonlight's minute: one quiet minute with the orb. */
  stillness: ['orb'],
  /** Sunrise's minute: replay one good moment. */
  savour: ['moment'],
  /** Sounds (F15, Milestone B): the timer chosen, or open-ended. */
  sounds: ['open', 'timer_15', 'timer_30', 'timer_60'],
  /** The night wind-down sequence. */
  night_wind_down: ['v1'],
} as const satisfies Record<string, readonly string[]>;
export type SessionActivity = keyof typeof SESSION_VARIANTS;
export const SESSION_ACTIVITIES = Object.keys(SESSION_VARIANTS) as SessionActivity[];

/** 1 s … 12 h (a long Sounds session; anything longer is not a real session). */
export const MIN_SESSION_S = 1;
export const MAX_SESSION_S = 12 * 3600;

/**
 * The record's `localDay` is the Aura day the activity STARTED; `deviceTs` is when it finished (≤ 12 h later), so it is
 * at most one Aura day behind the finish's Aura day in the stamping zone — or up to 2 days ahead, from a device zone
 * ahead of the profile's (the same slack check-ins get, sync.service MAX_AHEAD_DAYS).
 */
export const SESSION_MAX_BEHIND_DAYS = 1;
export const SESSION_MAX_AHEAD_DAYS = 2;

const uuid = z.string().regex(UUID_RE, 'must be a UUID').transform((s) => s.toLowerCase());

export const sessionPayloadSchema = z
  .object({
    id: uuid,
    activity: z.enum(SESSION_ACTIVITIES as [SessionActivity, ...SessionActivity[]]),
    variant: z.string(),
    durationS: z.number(),
  })
  .refine((p) => (SESSION_VARIANTS[p.activity] as readonly string[]).includes(p.variant), {
    message: 'variant not allowed for this activity',
    path: ['variant'],
  });
export type SessionPayload = z.infer<typeof sessionPayloadSchema>;

const timedSchema = z.object({
  deviceTs: z.iso.datetime({ offset: true }),
  localDay: z.string().refine(isLocalDay, 'must be a real date YYYY-MM-DD'),
});

/**
 * Validates one mutation (pure). Rejections: `unknown_op` (not `upsert`), `invalid_payload` (shape, unknown activity,
 * a variant the activity doesn't have, missing `deviceTs` / `localDay`), `invalid_duration` (not a whole number of
 * seconds in 1…43 200), `invalid_local_day` (the day doesn't fit the finish time, see above), `device_ts_in_future`
 * (finished more than 5 min after the server's now: the ledger's clock-skew bound).
 */
export function validateSession(
  m: Pick<Mutation, 'op' | 'deviceTs' | 'localDay' | 'tz' | 'payload'>,
  profileTz: string,
  now: Date,
): { payload: SessionPayload; deviceTs: string; localDay: string } {
  if (m.op !== 'upsert') return reject('unknown_op');
  const t = timedSchema.safeParse({ deviceTs: m.deviceTs, localDay: m.localDay });
  if (!t.success) return reject('invalid_payload');
  const p = sessionPayloadSchema.safeParse(m.payload);
  if (!p.success) return reject('invalid_payload');
  const d = p.data.durationS;
  if (!Number.isInteger(d) || d < MIN_SESSION_S || d > MAX_SESSION_S) return reject('invalid_duration');
  const { deviceTs, localDay } = t.data;
  if (Date.parse(deviceTs) > now.getTime() + MAX_FUTURE_SKEW_MS) return reject('device_ts_in_future');
  const behind = daysBetween(localDay, auraDay(deviceTs, m.tz ?? profileTz)); // > 0: started on an earlier day
  if (behind > SESSION_MAX_BEHIND_DAYS || behind < -SESSION_MAX_AHEAD_DAYS) return reject('invalid_local_day');
  return { payload: p.data, deviceTs, localDay };
}

/** `sanctuary_session` upsert inside the sync push (SyncModule). */
@Injectable()
export class SanctuarySessionSyncHandler {
  async apply(ctx: { tx: Tx; userId: string; tz: string; now: Date }, m: Mutation): Promise<void> {
    const { payload: p, deviceTs, localDay } = validateSession(m, ctx.tz, ctx.now);
    const inserted = await ctx.tx.query(
      `insert into public.sanctuary_sessions (id, user_id, activity, variant, duration_s, local_day, device_ts)
       values ($1, $2, $3, $4, $5, $6::date, $7::timestamptz)
       on conflict (id) do nothing`,
      [p.id, ctx.userId, p.activity, p.variant, p.durationS, localDay, deviceTs],
    );
    if ((inserted.rowCount ?? 0) > 0) return;
    const owner = await ctx.tx.query<{ user_id: string }>('select user_id from public.sanctuary_sessions where id = $1', [p.id]);
    if (owner.rows[0]?.user_id !== ctx.userId) return reject('id_conflict');
    // The same record sent again (lost reply, new mutation id): already stored, nothing changes.
  }
}

/** F15 Sanctuary: the `sanctuary_session` sync entity (imported by SyncModule). */
@Module({
  providers: [SanctuarySessionSyncHandler],
  exports: [SanctuarySessionSyncHandler],
})
export class SanctuaryModule {}
