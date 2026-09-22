import { z } from 'zod';
import { UUID_RE } from '../common/uuid';
import { isLocalDay, isValidTimeZone } from '../rules';

export const MAX_MUTATIONS = 200;
export const MAX_NOTE_CT_CHARS = 16_384;
export const MAX_TAGS = 10;

export const ENTITIES = ['check_in', 'habit', 'habit_log'] as const;
export type Entity = (typeof ENTITIES)[number];
export const OPS = ['upsert', 'delete'] as const;
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
  tags: z
    .array(z.string().trim().min(1).max(32))
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
});
export type CheckInPayload = z.infer<typeof checkInPayloadSchema>;

const optionalName = z
  .string()
  .trim()
  .min(1)
  .max(40)
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
    name: z.string().trim().min(1).max(40),
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
