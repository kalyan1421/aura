import type { Queryable } from '../db/db';

/**
 * The Owner's pseudonym blocklist (PRD 19 "Configuration … an offensive-combination blocklist"; migration
 * 20261005000034), on top of the code blocklist in pseudonyms.ts. Read on every new membership (rooms, Breath Ripples
 * seats) as extra "taken" names, so a blocked combination is never handed out again. Tiny table; read inside the
 * caller's transaction (no cache, so an Owner's change applies to the very next join).
 */
export async function blockedPseudonyms(q: Queryable): Promise<Set<string>> {
  const r = await q.query<{ pseudonym: string }>('select pseudonym from public.pseudonym_blocklist');
  return new Set(r.rows.map((x) => x.pseudonym));
}
