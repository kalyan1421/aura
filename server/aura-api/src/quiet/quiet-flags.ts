import type { Queryable } from '../db/db';
import type { TzRegion } from '../rooms/regions';

/**
 * Per-region kill switches (PRD 19 "from C Quiet Together and the Lantern Hour wind-down, per region"): the flag off
 * pauses every region; `payload.pausedRegions` pauses single ones. A missing flag counts as on (kill switches only ever
 * take things away). Read inside the caller's transaction (one PK lookup), so a switch decides at once.
 */
export function isPaused(row: { enabled: boolean; payload: unknown } | undefined, region: TzRegion): boolean {
  if (!row) return false;
  if (!row.enabled) return true;
  const paused = (row.payload as { pausedRegions?: unknown } | null)?.pausedRegions;
  return Array.isArray(paused) && paused.includes(region);
}

export async function regionPaused(q: Queryable, flag: string, region: TzRegion): Promise<boolean> {
  const r = await q.query<{ enabled: boolean; payload: unknown }>('select enabled, payload from public.feature_flags where key = $1', [flag]);
  return isPaused(r.rows[0], region);
}
