import type { Queryable } from '../db/db';

/**
 * sync_mutations is an idempotency window, not an archive. Credit eligibility ends at 30 days and
 * clients retry within seconds to days, so ids older than 90 days are never replayed in practice;
 * even if one were, check-in/habit upserts are idempotent at the entity level (no re-credit).
 */
export const SYNC_MUTATION_RETENTION_DAYS = 90;
const PURGE_BATCH = 10_000;

/** Deletes expired idempotency rows in batches (short locks); returns how many were removed. */
export async function purgeOldSyncMutations(
  q: Queryable,
  retentionDays = SYNC_MUTATION_RETENTION_DAYS,
  batch = PURGE_BATCH,
): Promise<number> {
  let removed = 0;
  for (;;) {
    const r = await q.query(
      `delete from public.sync_mutations
        where ctid in (select ctid from public.sync_mutations
                        where applied_at < now() - make_interval(days => $1) limit $2)`,
      [retentionDays, batch],
    );
    const n = r.rowCount ?? 0;
    removed += n;
    if (n < batch) return removed;
  }
}

/**
 * PRD 16 delta pull: tombstones are only needed until every phone has pulled past them. A phone whose cursor is older
 * than this re-reads everything instead (apps/mobile `PullService.pullDelta`), so they can go after 400 days.
 */
export const SYNC_TOMBSTONE_RETENTION_DAYS = 400;

export async function purgeOldSyncTombstones(q: Queryable, retentionDays = SYNC_TOMBSTONE_RETENTION_DAYS, batch = PURGE_BATCH): Promise<number> {
  let removed = 0;
  for (;;) {
    const r = await q.query(
      `delete from public.sync_tombstones
        where ctid in (select ctid from public.sync_tombstones
                        where deleted_at < now() - make_interval(days => $1) limit $2)`,
      [retentionDays, batch],
    );
    const n = r.rowCount ?? 0;
    removed += n;
    if (n < batch) return removed;
  }
}
