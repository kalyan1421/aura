import type { Queryable } from '../db/db';

/**
 * Server-side Plus gates (PRD F12 "Plus adds": unlimited mood-trigger capsules, 10-minute capsule voice). Reads the
 * NestJS-owned `entitlements` row (kept current by StoreSync and the billing worker); a period that ran out counts as
 * off even before the worker's sweep. Plain function (no DI) so capsules and media can use it.
 */
export async function hasPlus(q: Queryable, userId: string, now = new Date()): Promise<boolean> {
  const r = await q.query<{ on: boolean }>(
    'select (plus_active and plus_until > $2) as on from public.entitlements where user_id = $1',
    [userId, now],
  );
  return r.rows[0]?.on === true;
}

/** Capsule voice ciphertext limit with Plus (10:00 of AAC at ≤ 64 kbps ≈ 4.8 MB, plus the envelope). */
export const PLUS_CAPSULE_VOICE_BYTES = 6_291_456;
