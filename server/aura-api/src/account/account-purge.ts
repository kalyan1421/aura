import type { Pool } from 'pg';
import { pgCode, withTx } from '../db/db';
import { lockUser } from '../db/locks';
import { isDeletionDue } from './account.repository';
import { MediaStoreUnavailableError, type PrivateMediaStore } from './private-media';

/**
 * Every public table holding one user's personal rows, children before parents (habit_logs → habits).
 * All of them also cascade from auth.users; deleting them explicitly first means the personal data is
 * gone even if a later step has to be retried. `account_deletions` is not listed: it is the retry
 * marker and disappears with the auth user. The e2e suite fails if a public table with a `user_id`
 * column is missing here — add new personal tables to this list.
 */
export const PERSONAL_TABLES = [
  'habit_logs',
  'habits',
  'check_ins',
  'starlight_ledger',
  'active_days',
  'avatar_state',
  'streak_state',
  'sync_mutations',
  'user_data_keys',
  'device_tokens',
  'notification_prefs',
  'user_consents',
  'profiles',
] as const;

/** Accounts handled per run (the job runs hourly; the rest wait for the next run). */
export const PURGE_BATCH = 500;

export type AccountPurgeOutcome =
  | { status: 'purged'; rows: number; mediaObjects: number }
  | { status: 'skipped' };

/**
 * Purges one account whose grace period has ended. Idempotent and safe to re-run after a failure at any
 * step: the `account_deletions` row survives until the very last step, so the next run resumes.
 *   1. one transaction: every personal row (profile incl. DOB, check-ins, habits, logs, ledger, state,
 *      sync mutations, wrapped data key, device tokens, prefs, consents);
 *   2. the user's private-media objects, through the Storage API;
 *   3. one transaction: auth leftovers keyed by the user id without an FK (GoTrue audit-log entries,
 *      PKCE flow state, session-less refresh tokens), then the auth.users row — which cascades
 *      identities, sessions, MFA factors, one-time tokens and the `account_deletions` row itself.
 * Both transactions hold the per-user advisory lock and re-check "due" on the DB clock, so a cancel can
 * never interleave (see AccountRepository.cancel).
 */
export async function purgeAccount(pool: Pool, media: PrivateMediaStore, userId: string): Promise<AccountPurgeOutcome> {
  const rows = await withTx(pool, async (tx) => {
    await lockUser(tx, userId);
    if (!(await isDeletionDue(tx, userId))) return null;
    let n = 0;
    for (const table of PERSONAL_TABLES) {
      const r = await tx.query(`delete from public.${table} where user_id = $1`, [userId]);
      n += r.rowCount ?? 0;
    }
    return n;
  });
  if (rows === null) return { status: 'skipped' };

  const names = await media.listUserObjects(pool, userId);
  const mediaObjects = await media.remove(names);
  if ((await media.listUserObjects(pool, userId)).length > 0) throw new Error('private-media objects remain after delete');

  const deleted = await withTx(pool, async (tx) => {
    await lockUser(tx, userId);
    if (!(await isDeletionDue(tx, userId))) return false;
    await tx.query(
      `delete from auth.audit_log_entries
        where payload->>'actor_id' = $1 or payload->'traits'->>'user_id' = $1`,
      [userId],
    );
    await tx.query('delete from auth.flow_state where user_id = $1', [userId]);
    await tx.query('delete from auth.refresh_tokens where user_id = $1', [userId]);
    await tx.query('delete from auth.users where id = $1', [userId]);
    return true;
  });
  return deleted ? { status: 'purged', rows, mediaObjects } : { status: 'skipped' };
}

export interface PurgeSummary {
  /** Accounts whose grace period had ended when the run started. */
  due: number;
  purged: number;
  /** Media exists but the Storage API key is missing — retried next run. */
  deferred: number;
  failed: number;
  /** Personal rows / media objects removed across purged accounts. */
  rows: number;
  mediaObjects: number;
  /** SQLSTATEs / error names of failures (never messages: they could carry ids or paths). */
  errors: string[];
}

/**
 * Worker `maintenance` queue, job `account-purge` (hourly). Each account is independent: one failure
 * never blocks the others. Returns counts only — callers log them, never user ids.
 */
export async function purgeDueAccounts(pool: Pool, media: PrivateMediaStore, limit = PURGE_BATCH): Promise<PurgeSummary> {
  const due = await pool.query<{ user_id: string }>(
    `select user_id from public.account_deletions
      where scheduled_for <= now() order by scheduled_for limit $1`,
    [limit],
  );
  const s: PurgeSummary = { due: due.rowCount ?? 0, purged: 0, deferred: 0, failed: 0, rows: 0, mediaObjects: 0, errors: [] };
  for (const { user_id } of due.rows) {
    try {
      const out = await purgeAccount(pool, media, user_id);
      if (out.status === 'purged') {
        s.purged += 1;
        s.rows += out.rows;
        s.mediaObjects += out.mediaObjects;
      }
    } catch (err) {
      if (err instanceof MediaStoreUnavailableError) {
        s.deferred += 1;
        continue;
      }
      s.failed += 1;
      const kind = pgCode(err) ?? (err instanceof Error ? err.name : 'error');
      if (!s.errors.includes(kind)) s.errors.push(kind);
    }
  }
  return s;
}
