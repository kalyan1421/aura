import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { pgCode } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { AccountRepository } from './account.repository';
import { deletionDateFor, deletionRequestSchema, type AccountStatus } from './account.schema';

const deletionInProgress = (): ApiError =>
  ApiError.conflict(
    'account_deletion_in_progress',
    'The 7-day grace period has ended and this account is being deleted; it can no longer be kept.',
  );

/**
 * F8 REQ-ACC-11 — schedule / inspect / cancel the account deletion. The purge itself runs in the worker
 * (src/account/account-purge.ts). Works with or without a profile row.
 */
@Injectable()
export class AccountService {
  constructor(
    private readonly db: DbService,
    private readonly repo: AccountRepository,
  ) {}

  async status(userId: string): Promise<AccountStatus> {
    const row = await this.repo.find(this.db, userId);
    return { deletionScheduledFor: row ? row.scheduledFor.toISOString() : null };
  }

  /**
   * Idempotent: the first request fixes the date (+7 days); repeats return it unchanged. Every device
   * token of the account is removed on each call (no pushes during the grace period).
   */
  async requestDeletion(userId: string, body: unknown, now = new Date()): Promise<{ deletionScheduledFor: string }> {
    parseOrThrow(deletionRequestSchema, body);
    try {
      return await this.db.withTx(async (tx) => {
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
}
