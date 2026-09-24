import { z } from 'zod';
import { UUID_RE } from '../common/uuid';
import { isLocalDay, isValidTimeZone } from '../rules';

export const MAX_MUTATIONS = 200;
export const MAX_NOTE_CT_CHARS = 16_384;
export const MAX_TAGS = 10;
/** PRD F1: custom tags ≤ 20 characters (grapheme clusters, see text-limits.ts) → else `tag_too_long`. */
export const MAX_TAG_CHARS = 20;
/** PRD F2: habit names ≤ 30 characters (grapheme clusters) → else `habit_name_too_long`. */
export const MAX_HABIT_NAME_CHARS = 30;

/**
 * F14: `notification_prefs` (op `upsert`, a patch of settings) — contracts/api/v1-notifications.md. F5:
 * `room_pool_waitlist` (op `upsert` / `delete`, `{pool}`: "Tell me when they open").
 */
export const ENTITIES = [
  'check_in',
  'habit',
  'habit_log',
  'capsule',
  'notification_prefs',
  'room_pool_waitlist',
  'sanctuary_session', // F15: one content-free record per finished Sanctuary activity (src/sanctuary)
] as const;
export type Entity = (typeof ENTITIES)[number];
/**
 * `upsert` / `delete` for check-ins and habits; F4 capsules use `seal` / `open` / `fire` / `rearm` / `delete`
 * (contracts/api/v1-capsules.md). An op the entity doesn't support → `unknown_op`.
 */
export const OPS = ['upsert', 'delete', 'seal', 'open', 'fire', 'rearm'] as const;
export type Op = (typeof OPS)[number];

const uuid = z.string().regex(UUID_RE, 'must be a UUID').transform((s) => s.toLowerCase());
const localDay = z.string().refine(isLocalDay, 'must be a real date YYYY-MM-DD');
const deviceTs = z.iso.datetime({ offset: true });

export const pushRequestSchema = z.object({
  deviceId: z.string().regex(UUID_RE, 'must be a UUID'),
  mutations: z.array(z.unknown()),
});

/** Envelope of one mutation (payload validated per entity afterwards). */
export const mutationSchema = z.object({
  id: uuid,
  entity: z.enum(ENTITIES),
  op: z.enum(OPS),
  deviceTs: deviceTs.optional(),
  localDay: localDay.optional(),
  /** IANA zone the device used to stamp `localDay`; falls back to the profile tz when absent. */
  tz: z.string().trim().refine(isValidTimeZone, 'must be an IANA time zone').optional(),
  payload: z.record(z.string(), z.unknown()),
});
export type Mutation = z.infer<typeof mutationSchema>;

/** Upserts are timed events: both fields are required. */
export const timedSchema = z.object({ deviceTs, localDay });

export const deletePayloadSchema = z.object({ id: uuid });

export const checkInPayloadSchema = z.object({
  id: uuid,
  moodId: z.string().min(1).max(64),
  // Length is counted in grapheme clusters by SyncService (`tag_too_long`), not by zod's UTF-16 `.max()`.
  tags: z
    .array(z.string().trim().min(1))
    .max(MAX_TAGS)
    .default([])
    .transform((t) => [...new Set(t)]),
  noteCt: z
    .string()
    .max(MAX_NOTE_CT_CHARS)
    .regex(/^[A-Za-z0-9+/_-]+={0,2}$/, 'must be base64 ciphertext')
    .nullish()
    .transform((v) => v ?? null),
  source: z.enum(['app', 'widget']).default('app'),
  /**
   * F1 voice note: `"<user_id>/voice/<id>"` sets it, `null` clears it (the object is deleted best-effort),
   * absent keeps the stored value (an older build never drops a voice note). The path rule needs the
   * caller's id, so SyncService checks it (`invalid_voice_path` for anything else, whatever its type).
   */
  voicePath: z.unknown().optional(),
  /**
   * When the user made this edit (device clock). The mutation's `deviceTs` stays the ORIGINAL check-in time
   * (if the first upsert never reached the server, the edit is applied as the insert and judged as the
   * original event); `editedAt` is what the 24 h edit window is judged by. Ignored on inserts.
   */
  editedAt: deviceTs.nullish().transform((v) => v ?? undefined),
});
export type CheckInPayload = z.infer<typeof checkInPayloadSchema>;

// Habit name length is counted in grapheme clusters by SyncService (`habit_name_too_long`).
const optionalName = z
  .string()
  .trim()
  .min(1)
  .nullish()
  .transform((v) => v ?? null);

export const habitPayloadSchema = z.discriminatedUnion('kind', [
  z.object({
    id: uuid,
    kind: z.literal('preset'),
    presetKey: z.string().min(1).max(64),
    name: optionalName,
    active: z.boolean().default(true),
  }),
  z.object({
    id: uuid,
    kind: z.literal('custom'),
    presetKey: z.null().optional(),
    name: z.string().trim().min(1),
    active: z.boolean().default(true),
  }),
]);
export type HabitPayload = z.infer<typeof habitPayloadSchema>;

export const habitLogPayloadSchema = z.object({ id: uuid, habitId: uuid });
export type HabitLogPayload = z.infer<typeof habitLogPayloadSchema>;

export type MutationStatus = 'applied' | 'duplicate' | 'rejected';
export interface MutationResult {
  id: string;
  status: MutationStatus;
  reason?: string;
}
