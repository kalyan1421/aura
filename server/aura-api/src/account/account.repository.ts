import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';

export interface DeletionRow {
  requestedAt: Date;
  scheduledFor: Date;
}

export type CancelResult = 'cancelled' | 'none' | 'due';

/**
 * Is a deletion scheduled for this account? One primary-key lookup — the pending-deletion guard runs it
 * on every authenticated request (src/auth/pending-deletion.guard.ts).
 */
export async function isDeletionPending(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query('select 1 from public.account_deletions where user_id = $1', [userId]);
  return (r.rowCount ?? 0) > 0;
}

/**
 * Due = the grace period has ended, judged on the DB clock *now* (`clock_timestamp()`, not the
 * transaction start). Cancel and purge both decide under the per-user advisory lock, so once the
 * purge has started on an account a late "Keep my account" can never leave it half-deleted.
 */
export async function isDeletionDue(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query(
    'select 1 from public.account_deletions where user_id = $1 and scheduled_for <= clock_timestamp()',
    [userId],
  );
  return (r.rowCount ?? 0) > 0;
}

interface Row {
  requested_at: Date;
  scheduled_for: Date;
}

const toRow = (r: Row): DeletionRow => ({ requestedAt: r.requested_at, scheduledFor: r.scheduled_for });

/** `public.account_deletions` (one row per account; server-only table). Never logs user ids. */
@Injectable()
export class AccountRepository {
  async find(q: Queryable, userId: string): Promise<DeletionRow | null> {
    const r = await q.query<Row>(
      'select requested_at, scheduled_for from public.account_deletions where user_id = $1',
      [userId],
    );
    return r.rows[0] ? toRow(r.rows[0]) : null;
  }

  /** Insert unless a schedule exists; the existing row always wins (a repeat never moves the date). */
  async schedule(q: Queryable, userId: string, requestedAt: Date, scheduledFor: Date): Promise<DeletionRow> {
    const r = await q.query<Row>(
      `insert into public.account_deletions (user_id, requested_at, scheduled_for) values ($1, $2, $3)
       on conflict (user_id) do nothing
       returning requested_at, scheduled_for`,
      [userId, requestedAt, scheduledFor],
    );
    if (r.rows[0]) return toRow(r.rows[0]);
    const existing = await this.find(q, userId);
    if (!existing) throw new Error('account deletion schedule vanished');
    return existing;
  }

  /** Removes a schedule that is not yet due. `due` = the grace period is over (the purge owns it now). */
  async cancel(q: Queryable, userId: string): Promise<CancelResult> {
    const r = await q.query(
      'delete from public.account_deletions where user_id = $1 and scheduled_for > clock_timestamp()',
      [userId],
    );
    if ((r.rowCount ?? 0) > 0) return 'cancelled';
    return (await this.find(q, userId)) ? 'due' : 'none';
  }

  /** No pushes during the grace period: every FCM token of the account goes at once. */
  async deleteDeviceTokens(q: Queryable, userId: string): Promise<number> {
    const r = await q.query('delete from public.device_tokens where user_id = $1', [userId]);
    return r.rowCount ?? 0;
  }
}
