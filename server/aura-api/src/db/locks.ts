import type { Queryable } from './db';

/**
 * Per-user transaction-scoped advisory lock. Every write path that reads-then-writes a
 * user's rows (sync push, profile onboarding) takes it first, so they serialise per user —
 * including the very first write, when there is no row to `SELECT … FOR UPDATE` yet.
 */
export async function lockUser(q: Queryable, userId: string): Promise<void> {
  await q.query("select pg_advisory_xact_lock(hashtextextended('aura:user:' || $1, 0))", [userId]);
}
