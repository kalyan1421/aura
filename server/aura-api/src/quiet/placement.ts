import { pairKey } from '../ripples/matcher';
import { TZ_REGIONS, type TzRegion } from '../rooms/regions';

/**
 * Pure Quiet Together placement (PRD F16 "Matching and realtime"; contracts/api/v1-quiet.md §1.1). The SQL side locks
 * the mode's block and feeds the sessions of the current block; this decides where the joiner sits.
 *
 * - **Partition** `mode × tz_region`. A region with fewer than `thinLiveMin` live people in this mode's block merges
 *   into the busiest region (ties → the default region, `south_asia`), as in F5. Not split by language.
 * - Inside the partition: the fullest session that still has room (below `capacity` current members) and holds
 *   **nobody the joiner has a block with, in either direction**; else a new session opens.
 */
export interface QuietCandidate {
  sessionId: string;
  region: TzRegion;
  /** Live people now (seen within the live window). */
  live: number;
  /** Current (not left) members' account ids: capacity and the block check. */
  memberUserIds: readonly string[];
  createdAtMs: number;
}

export interface PlacementConfig {
  capacity: number;
  thinLiveMin: number;
  defaultRegion: TzRegion;
}

export interface Placement {
  region: TzRegion;
  /** null = open a new session in `region`. */
  sessionId: string | null;
  merged: boolean;
}

export function planQuietPlacement(
  joiner: { userId: string; homeRegion: TzRegion },
  candidates: readonly QuietCandidate[],
  blocked: ReadonlySet<string>,
  cfg: PlacementConfig,
): Placement {
  const liveIn = (region: TzRegion): number => candidates.filter((c) => c.region === region).reduce((n, c) => n + c.live, 0);
  let region = joiner.homeRegion;
  if (liveIn(region) < cfg.thinLiveMin) {
    const order: TzRegion[] = [cfg.defaultRegion, ...TZ_REGIONS.filter((r) => r !== cfg.defaultRegion)];
    let busiest = order[0];
    for (const r of order) if (liveIn(r) > liveIn(busiest)) busiest = r;
    if (liveIn(busiest) > liveIn(region)) region = busiest;
  }
  const fits = candidates
    .filter((c) => c.region === region)
    .filter((c) => c.memberUserIds.length < cfg.capacity)
    .filter((c) => c.memberUserIds.every((u) => u !== joiner.userId && !blocked.has(pairKey(u, joiner.userId))))
    .sort((a, b) => b.live - a.live || b.memberUserIds.length - a.memberUserIds.length || a.createdAtMs - b.createdAtMs || (a.sessionId < b.sessionId ? -1 : 1));
  return { region, sessionId: fits[0]?.sessionId ?? null, merged: region !== joiner.homeRegion };
}
