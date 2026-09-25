import type { Queryable } from '../db/db';
import { PRIVATE_MEDIA_BUCKET } from '../account/private-media';

/**
 * Data minimisation for private media (contracts/api/v1.md "Media", v1-capsules.md §5): an upload whose record never
 * reached the server — a voice note whose check-in push was refused (e.g. `backfill_too_old`), a capsule seal refused
 * for good — used to stay in the bucket until the account purge. The app uploads first and pushes the record right
 * after, and keeps its own copy if the record goes without it, so an object that still has no record a month later
 * is an orphan: this removes it.
 *
 *  - voice: `<user_id>/voice/<check-in id>` with no check-in of that id pointing at it;
 *  - capsule media: `<user_id>/capsules/<capsule id>/<slot>` with no capsule of that id at all (a deleted capsule
 *    keeps its tombstone row and removes its own folder).
 * Anything else in the bucket is left alone. Logs counts only (callers), never names.
 */
export const ORPHAN_MEDIA_AFTER_DAYS = 30;
export const ORPHAN_MEDIA_BATCH = 500;

const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

/** Orphaned object names (oldest first), at most `limit`. */
export async function findOrphanMedia(q: Queryable, olderThanDays = ORPHAN_MEDIA_AFTER_DAYS, limit = ORPHAN_MEDIA_BATCH): Promise<string[]> {
  const r = await q.query<{ name: string }>(
    `select o.name
       from storage.objects o
      where o.bucket_id = $1
        and o.created_at < now() - make_interval(days => $2)
        and (
              (o.name ~ $4 and not exists (
                 select 1 from public.check_ins c
                  where c.user_id = split_part(o.name, '/', 1)::uuid and c.id = split_part(o.name, '/', 3)::uuid
                    and c.voice_path = o.name))
           or (o.name ~ $5 and not exists (
                 select 1 from public.capsules k
                  where k.user_id = split_part(o.name, '/', 1)::uuid and k.id = split_part(o.name, '/', 3)::uuid))
        )
      order by o.created_at
      limit $3`,
    [PRIVATE_MEDIA_BUCKET, olderThanDays, limit, `^${UUID}/voice/${UUID}$`, `^${UUID}/capsules/${UUID}/[^/]+$`],
  );
  return r.rows.map((x) => x.name);
}

export interface OrphanMediaStore {
  readonly configured: boolean;
  remove(names: string[]): Promise<number>;
}

/** One sweep: finds orphans and removes them through Storage (skipped without a service key). */
export async function sweepOrphanMedia(q: Queryable, media: OrphanMediaStore): Promise<{ found: number; removed: number }> {
  if (!media.configured) return { found: 0, removed: 0 };
  const names = await findOrphanMedia(q);
  const removed = names.length ? await media.remove(names) : 0;
  return { found: names.length, removed };
}
