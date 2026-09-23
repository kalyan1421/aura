import type { Pool } from 'pg';
import { pgCode, withTx } from '../db/db';
import { lockUser } from '../db/locks';
import { isDeletionDue } from './account.repository';
import { AppleUnavailableError } from './apple-sign-in';
import { AppleTokenUnreadableError, type AppleRevokeOutcome } from './apple-tokens';
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
  'capsules', // F4 (tombstones too); capsule_unlock_schedule cascades; media lives under <user_id>/capsules/
  'starlight_ledger',
  'active_days',
  'avatar_state',
  'streak_state',
  'sync_mutations',
  'user_data_keys',
  'device_tokens',
  // REQ-ADM-14: the (hashed) app installs the account used; bans themselves (device_bans) hold no account link.
  'device_installs',
  'notification_prefs',
  'user_consents',
  // F5 rooms: memberships (pseudonyms, heartbeats, survey marks); their gestures — incl. limit-hit rows — and mutes
  // in both directions cascade from room_members.
  'room_members',
  // F9: the account's own sanctions and strikes.
  'sanctions',
  'strikes',
  // F8 REQ-ACC-04/10: the invisible under-18 flag from a platform age signal.
  'minor_signals',
  // F8 REQ-ACC-11: the sealed Sign in with Apple refresh token — removed by step 1b, after it is revoked at Apple
  // (`APPLE_TOKEN_TABLE`), never by the plain delete in step 1.
  'apple_auth_tokens',
  // F9 REQ-SAFE-04: which community-guidelines version the account accepted
  // (also cascades from profiles).
  'guidelines_acceptances',
  'profiles',
] as const;

/** Revoked at Apple before its row goes (step 1b of `purgeAccount`), so step 1 leaves it alone. */
export const APPLE_TOKEN_TABLE = 'apple_auth_tokens';

/**
 * How long after the grace period a purge keeps waiting for Apple (unreachable, or no APPLE_* configuration on the
 * worker) before it drops the stored token unrevoked and finishes. The rest of the personal rows are already gone
 * while it waits; 7 days' grace + 72 h stays far inside the PRD's 30 days.
 */
export const APPLE_REVOKE_RETRY_HOURS = 72;

/**
 * Rows that point at the account through columns other than `user_id` (F5/F9), cleared in the same transaction:
 * blocks go in both directions; reports stay in their moderation lane but lose the link to the deleted account,
 * whether it filed the report or was its subject (the evidence snapshot below keeps what the law requires).
 * `moderation_actions` needs nothing: it only holds an HMAC of the account id (hashed audit rows, 19 admin console).
 */
export const ACCOUNT_REFERENCE_CLEANUP = [
  'delete from public.blocks where blocker_user_id = $1 or blocked_user_id = $1',
  'update public.reports set reporter_user_id = null where reporter_user_id = $1',
  'update public.reports set target_user_id = null where target_user_id = $1',
] as const;

/**
 * [LEGAL] The ONLY public tables whose rows may still reference a purged account (PRD DS-4 "legal holds excepted";
 * F9 REQ-SAFE-14; 19 admin console REQ-ADM-11 "rows under evidence hold survive until hold_until"):
 * - `evidence_holds` — snapshots of reported content ABOUT the account (its `account_ids` are the subjects of the
 *   report, never the reporter). Reason: F9 180-day evidence preservation and mandatory reporting (POCSO / IT Rules,
 *   removed-content records). Retention: until `hold_until` = capture + 180 days (`safety_config.evidence_hold_days`),
 *   extended only by a moderator for a mandatory report; the room-lifecycle worker then deletes the row. The lawyer
 *   confirms the period (PRD 21, action A3).
 * The purge never deletes these rows; the e2e suite fails if any other public row still references a purged account.
 */
export const LEGAL_HOLD_TABLES = ['evidence_holds'] as const;

/** Accounts handled per run (the job runs hourly; the rest wait for the next run). */
export const PURGE_BATCH = 500;

/** What happened to the account's Sign in with Apple token in this run. */
export type ApplePurgeStep = 'none' | 'revoked' | 'abandoned';

export type AccountPurgeOutcome =
  | { status: 'purged'; rows: number; mediaObjects: number; apple: ApplePurgeStep }
  | { status: 'skipped' };

/** Revokes and drops the stored Sign in with Apple token (the worker passes AppleTokenVault). */
export interface AppleTokenRevoker {
  /** Throws when Apple can't be used right now (retried) or the token can never be revoked (AppleTokenUnreadableError). */
  revokeStored(q: Pool, userId: string): Promise<AppleRevokeOutcome>;
  drop(q: Pool, userId: string): Promise<number>;
}

/** Apple couldn't revoke the token yet: the account is deferred (personal rows already gone) and retried next run. */
export class AppleRevokeDeferredError extends Error {
  constructor() {
    super('Sign in with Apple token not revoked yet; the purge resumes next run');
    this.name = 'AppleRevokeDeferredError';
  }
}

/**
 * Cancels pending F4 unlock jobs (the worker passes CapsuleUnlockService). Optional and best-effort: a job left
 * behind carries only a capsule id and finds no capsule when it runs.
 */
export interface UnlockJobCanceller {
  unschedule(capsuleIds: string[]): Promise<unknown>;
}

/**
 * Purges one account whose grace period has ended. Idempotent and safe to re-run after a failure at any
 * step: the `account_deletions` row survives until the very last step, so the next run resumes.
 *   1. one transaction: every personal row (profile incl. DOB, check-ins, capsules, habits, logs, ledger,
 *      state, sync mutations, wrapped data key, device tokens, prefs, consents, room memberships with their
 *      gestures and mutes, sanctions, strikes), blocks both ways, the account's links on reports
 *      (`ACCOUNT_REFERENCE_CLEANUP`) — `LEGAL_HOLD_TABLES` rows stay; then (best-effort) the pending capsule
 *      unlock jobs in Redis;
 *  1b. the Sign in with Apple token: revoked at Apple, then its row deleted (`revokeAppleToken`; may defer);
 *   2. the user's private-media objects (voice notes, capsule media), through the Storage API;
 *   3. one transaction: auth leftovers keyed by the user id without an FK (GoTrue audit-log entries,
 *      PKCE flow state, session-less refresh tokens), then the auth.users row — which cascades
 *      identities, sessions, MFA factors, one-time tokens and the `account_deletions` row itself.
 * Both transactions hold the per-user advisory lock and re-check "due" on the DB clock, so a cancel can
 * never interleave (see AccountRepository.cancel).
 */
export async function purgeAccount(
  pool: Pool,
  media: PrivateMediaStore,
  userId: string,
  unlockJobs?: UnlockJobCanceller,
  apple?: AppleTokenRevoker,
): Promise<AccountPurgeOutcome> {
  const step1 = await withTx(pool, async (tx) => {
    await lockUser(tx, userId);
    if (!(await isDeletionDue(tx, userId))) return null;
    const pending = await tx.query<{ id: string }>(
      `select id from public.capsules
        where user_id = $1 and unlock_type = 'date' and deleted_at is null and opened_at is null`,
      [userId],
    );
    let n = 0;
    for (const table of PERSONAL_TABLES) {
      if (table === APPLE_TOKEN_TABLE) continue; // step 1b
      const r = await tx.query(`delete from public.${table} where user_id = $1`, [userId]);
      n += r.rowCount ?? 0;
    }
    for (const sql of ACCOUNT_REFERENCE_CLEANUP) {
      const r = await tx.query(sql, [userId]);
      n += r.rowCount ?? 0;
    }
    return { rows: n, pendingCapsules: pending.rows.map((x) => x.id) };
  });
  if (step1 === null) return { status: 'skipped' };
  const { rows } = step1;
  if (unlockJobs && step1.pendingCapsules.length > 0) {
    await unlockJobs.unschedule(step1.pendingCapsules).catch(() => undefined); // the rows are gone either way
  }

  const appleStep = await revokeAppleToken(pool, userId, apple);

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
  return deleted ? { status: 'purged', rows, mediaObjects, apple: appleStep } : { status: 'skipped' };
}

/**
 * Step 1b (App Review 5.1.1(v), PRD "Apple token revoked"): revoke the stored Sign in with Apple token at Apple, then
 * drop its row. Apple unreachable / not configured on the worker → AppleRevokeDeferredError (retried next run) until
 * `APPLE_REVOKE_RETRY_HOURS` after the grace period, then the token is dropped unrevoked ('abandoned', logged as a
 * count). A token that can't be opened or that Apple refuses to revoke is dropped at once. Without a revoker (callers
 * that don't pass one) the row is simply dropped.
 */
async function revokeAppleToken(pool: Pool, userId: string, apple?: AppleTokenRevoker): Promise<ApplePurgeStep> {
  if (!apple) {
    const r = await pool.query(`delete from public.${APPLE_TOKEN_TABLE} where user_id = $1`, [userId]);
    return (r.rowCount ?? 0) > 0 ? 'abandoned' : 'none';
  }
  try {
    const out = await apple.revokeStored(pool, userId);
    return out === 'none' ? 'none' : out === 'revoked' ? 'revoked' : 'abandoned';
  } catch (err) {
    if (err instanceof AppleUnavailableError) {
      const waiting = await pool.query(
        `select 1 from public.account_deletions
          where user_id = $1 and scheduled_for > now() - make_interval(hours => $2)`,
        [userId, APPLE_REVOKE_RETRY_HOURS],
      );
      if ((waiting.rowCount ?? 0) > 0) throw new AppleRevokeDeferredError();
    } else if (!(err instanceof AppleTokenUnreadableError)) {
      throw err; // e.g. a database error: counted as failed, retried next run
    }
    return (await apple.drop(pool, userId)) > 0 ? 'abandoned' : 'none';
  }
}

export interface PurgeSummary {
  /** Accounts whose grace period had ended when the run started. */
  due: number;
  purged: number;
  /** Media exists but the Storage API key is missing, or Apple can't revoke yet — retried next run. */
  deferred: number;
  failed: number;
  /** Personal rows / media objects removed across purged accounts. */
  rows: number;
  mediaObjects: number;
  /** Sign in with Apple tokens revoked at Apple / dropped unrevoked (gave up, or unusable) by the purged accounts. */
  appleRevoked: number;
  appleAbandoned: number;
  /** SQLSTATEs / error names of failures (never messages: they could carry ids or paths). */
  errors: string[];
}

/**
 * Worker `maintenance` queue, job `account-purge` (hourly). Each account is independent: one failure
 * never blocks the others. Returns counts only — callers log them, never user ids.
 */
export async function purgeDueAccounts(
  pool: Pool,
  media: PrivateMediaStore,
  limit = PURGE_BATCH,
  unlockJobs?: UnlockJobCanceller,
  apple?: AppleTokenRevoker,
): Promise<PurgeSummary> {
  const due = await pool.query<{ user_id: string }>(
    `select user_id from public.account_deletions
      where scheduled_for <= now() order by scheduled_for limit $1`,
    [limit],
  );
  const s: PurgeSummary = {
    due: due.rowCount ?? 0,
    purged: 0,
    deferred: 0,
    failed: 0,
    rows: 0,
    mediaObjects: 0,
    appleRevoked: 0,
    appleAbandoned: 0,
    errors: [],
  };
  for (const { user_id } of due.rows) {
    try {
      const out = await purgeAccount(pool, media, user_id, unlockJobs, apple);
      if (out.status === 'purged') {
        s.purged += 1;
        s.rows += out.rows;
        s.mediaObjects += out.mediaObjects;
        if (out.apple === 'revoked') s.appleRevoked += 1;
        if (out.apple === 'abandoned') s.appleAbandoned += 1;
      }
    } catch (err) {
      if (err instanceof MediaStoreUnavailableError || err instanceof AppleRevokeDeferredError) {
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
