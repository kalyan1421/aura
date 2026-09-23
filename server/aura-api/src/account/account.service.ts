import { HttpStatus, Injectable, Logger, Optional } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { pgCode } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { AppleRejectedError, AppleUnavailableError, type AppleGrant } from './apple-sign-in';
import { AppleIdentityMismatchError, AppleTokenVault } from './apple-tokens';
import { AccountRepository, isAccountClosed, isDeletionDue } from './account.repository';
import { appleAuthRequestSchema, deletionDateFor, deletionRequestSchema, type AccountStatus } from './account.schema';

const deletionInProgress = (): ApiError =>
  ApiError.conflict(
    'account_deletion_in_progress',
    'The 7-day grace period has ended and this account is being deleted; it can no longer be kept.',
  );

/** Apple isn't configured on this server or can't be reached: the app ignores it (sign-in is unaffected). */
export const appleUnavailable = (): ApiError =>
  new ApiError(
    HttpStatus.SERVICE_UNAVAILABLE,
    'apple_unavailable',
    'Sign in with Apple token storage is unavailable right now; sign-in is not affected.',
  );

const appleCodeRejected = (): ApiError =>
  ApiError.badRequest('apple_code_rejected', 'Apple refused this authorization code (expired, already used, or for another app).');

const appleIdentityMismatch = (): ApiError =>
  ApiError.conflict('apple_identity_mismatch', "This Apple account isn't the one this account signs in with.");

/** A deletion request waits at most this long for Apple (best effort; the purge revokes anything left). */
export const REQUEST_REVOKE_TIMEOUT_MS = 5_000;

/**
 * F8 REQ-ACC-11 — schedule / inspect / cancel the account deletion; keep and revoke the Sign in with Apple token
 * (App Review 5.1.1(v)). The purge itself runs in the worker (src/account/account-purge.ts). Works with or without a
 * profile row. Never logs user ids, codes or tokens.
 */
@Injectable()
export class AccountService {
  private readonly logger = new Logger('Account');

  constructor(
    private readonly db: DbService,
    private readonly repo: AccountRepository,
    /** Provided globally by QueuesModule (the worker's purge uses the same vault). Absent → Apple is unavailable. */
    @Optional() private readonly apple?: AppleTokenVault,
  ) {}

  async status(userId: string): Promise<AccountStatus> {
    const [row, closed] = await Promise.all([this.repo.find(this.db, userId), isAccountClosed(this.db, userId)]);
    return {
      deletionScheduledFor: row ? row.scheduledFor.toISOString() : null,
      ...(closed ? { accountClosed: true as const } : {}),
    };
  }

  /**
   * Idempotent: the first request fixes the date (+7 days); repeats return it unchanged. Every device
   * token of the account is removed on each call (no pushes during the grace period). Then, best effort, the
   * stored Sign in with Apple token is revoked at Apple (PRD "Apple token revoked"); the purge retries anything left.
   */
  async requestDeletion(userId: string, body: unknown, now = new Date()): Promise<{ deletionScheduledFor: string }> {
    parseOrThrow(deletionRequestSchema, body);
    let out: { deletionScheduledFor: string };
    try {
      out = await this.db.withTx(async (tx) => {
        await lockUser(tx, userId); // serialises with in-flight sync pushes / onboarding and with cancel
        const row = await this.repo.schedule(tx, userId, now, deletionDateFor(now));
        await this.repo.deleteDeviceTokens(tx, userId);
        return { deletionScheduledFor: row.scheduledFor.toISOString() };
      });
    } catch (err) {
      // The auth user no longer exists (e.g. already purged) but the access token hasn't expired yet.
      if (pgCode(err) === '23503') throw ApiError.unauthorized('This account no longer exists.', 'unknown_user');
      throw err;
    }
    await this.revokeAppleBestEffort(userId);
    return out;
  }

  /** "Keep my account": idempotent; after the grace period → `409 account_deletion_in_progress`. */
  async cancelDeletion(userId: string, body: unknown): Promise<{ deletionScheduledFor: null }> {
    parseOrThrow(deletionRequestSchema, body);
    const result = await this.db.withTx(async (tx) => {
      await lockUser(tx, userId); // the purge holds the same lock while it decides
      return this.repo.cancel(tx, userId);
    });
    if (result === 'due') throw deletionInProgress();
    return { deletionScheduledFor: null };
  }

  /**
   * `POST /v1/account/apple-auth`: exchanges the one-time Sign in with Apple authorization code and keeps the refresh
   * token (sealed) so the account deletion can revoke it. `503 apple_unavailable` when Apple isn't configured or can't
   * be reached, `400 apple_code_rejected`, `409 apple_identity_mismatch`; an account whose purge has begun →
   * `409 account_deletion_in_progress` (the fresh token is revoked at once).
   */
  async linkApple(userId: string, body: unknown): Promise<void> {
    const { authorizationCode } = parseOrThrow(appleAuthRequestSchema, body);
    const apple = this.apple;
    if (!apple?.configured) throw appleUnavailable();
    let grant: AppleGrant;
    try {
      grant = await apple.exchange(authorizationCode);
    } catch (err) {
      throw this.appleError(err);
    }
    let due: boolean;
    try {
      due = await this.db.withTx(async (tx) => {
        await lockUser(tx, userId); // the purge decides under the same lock
        if (await isDeletionDue(tx, userId)) return true;
        await apple.store(tx, userId, grant);
        return false;
      });
    } catch (err) {
      if (pgCode(err) === '23503') throw ApiError.unauthorized('This account no longer exists.', 'unknown_user');
      throw this.appleError(err);
    }
    if (due) {
      await apple.discard(grant, { timeoutMs: REQUEST_REVOKE_TIMEOUT_MS });
      throw deletionInProgress();
    }
  }

  private appleError(err: unknown): unknown {
    if (err instanceof AppleRejectedError) return appleCodeRejected();
    if (err instanceof AppleIdentityMismatchError) return appleIdentityMismatch();
    if (err instanceof AppleUnavailableError) {
      this.logger.warn(`apple-auth: Apple unavailable (${err.reason})`);
      return appleUnavailable();
    }
    return err;
  }

  /** Never throws and never blocks the deletion request for long; failures leave the token for the purge. */
  private async revokeAppleBestEffort(userId: string): Promise<void> {
    const apple = this.apple;
    if (!apple) return;
    try {
      await apple.revokeStored(this.db, userId, { timeoutMs: REQUEST_REVOKE_TIMEOUT_MS });
    } catch (err) {
      const kind = err instanceof AppleUnavailableError ? err.reason : err instanceof Error ? err.name : 'error';
      this.logger.warn(`deletion: Apple token not revoked yet (${kind}); the purge retries`);
    }
  }
}
