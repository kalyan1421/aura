import { z } from 'zod';
import { UUID_RE } from '../common/uuid';
import { isLocalDay, QUADRANTS } from '../rules';

/** Ops of sync entity `capsule` (contracts/api/v1-capsules.md §2). */
export const CAPSULE_OPS = ['seal', 'open', 'fire', 'rearm', 'delete'] as const;
export type CapsuleOp = (typeof CAPSULE_OPS)[number];

/** `payloadCt`: base64/base64url ciphertext (title, text ≤ 2,000 chars, media refs, hard-moment flag) ≤ 128 KiB. */
export const MAX_CAPSULE_CT_CHARS = 131_072;
/** PRD F4 limits: Free keeps 3 active trigger capsules; Plus is unlimited (capsule-sync.ts: an active Plus entitlement lifts it). */
export const MAX_ACTIVE_TRIGGER_CAPSULES = 3;
/** Fair-use cap on pending (sealed, unopened) date capsules `[ASSUMPTION]`. */
export const MAX_PENDING_DATE_CAPSULES = 200;
/** Server-only guard against broken device clocks: unlock date ≤ server today + 5 years + this many days. */
export const SERVER_UNLOCK_SLACK_DAYS = 2;

const uuid = z
  .string()
  .regex(UUID_RE, 'must be a UUID')
  .transform((s) => s.toLowerCase());
/** Must be absent or null (a field that does not belong to this unlock type). */
const absent = z.null().optional();

const payloadCt = z
  .string()
  .min(1)
  .max(MAX_CAPSULE_CT_CHARS)
  .regex(/^[A-Za-z0-9+/_-]+={0,2}$/, 'must be base64 ciphertext');

export const sealPayloadSchema = z.discriminatedUnion('unlockType', [
  z.object({
    id: uuid,
    payloadCt,
    unlockType: z.literal('date'),
    unlockLocalDate: z.string().refine(isLocalDay, 'must be a real date YYYY-MM-DD'),
    triggerMoodId: absent,
    triggerQuadrant: absent,
  }),
  z.object({
    id: uuid,
    payloadCt,
    unlockType: z.literal('mood'),
    unlockLocalDate: absent,
    // Exactly one of the two (checked by CapsuleSyncHandler → invalid_payload).
    triggerMoodId: z.string().min(1).max(64).nullish(),
    triggerQuadrant: z.enum(QUADRANTS).nullish(),
  }),
]);
export type SealPayload = z.infer<typeof sealPayloadSchema>;

/** `open` / `fire` / `rearm`: the capsule and the cycle the op applies to (0 until the first re-arm). */
export const cyclePayloadSchema = z.object({
  id: uuid,
  cycle: z.number().int().min(0).max(1_000_000).default(0),
});

export const capsuleDeletePayloadSchema = z.object({ id: uuid });
