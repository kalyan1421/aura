import type { Quadrant } from '../rules';
import { TZ_REGIONS, type TzRegion } from './regions';
import type { LanguagePool } from './room-types';

/**
 * Pure matching rules (PRD F5 "Matching and realtime"; contracts/api/v1-rooms.md §4.2). The SQL side feeds these
 * with counts; the service then tries the ranked rooms under row locks and spawns a new room when none fits.
 */

export interface Partition {
  pool: LanguagePool;
  region: TzRegion;
}

export const partitionKey = (p: Partition): string => `${p.pool}:${p.region}`;

export interface PartitionConfig {
  /** Fewer joins than this in 24 h (by people whose home partition it is) = thin. */
  thinJoinThreshold: number;
  /** Busiest-region tie-break (expected `south_asia`). */
  defaultRegion: TzRegion;
}

export interface ResolvedPartition extends Partition {
  /** Placed outside the home partition (another region and/or English instead of the home pool). */
  merged: boolean;
}

/**
 * Thin-partition merge: < 12 joins in 24 h → same pool and quadrant in the busiest region; if still thin,
 * non-English pools use English (home region first, then the busiest English region). Demand is counted by the
 * joiners' HOME partition, so a merged-away partition still accumulates its own demand and un-merges once busy.
 * Everything thin → the last fallback (at alpha: `en` × `south_asia`, i.e. one room per quadrant per day).
 */
export function resolvePartition(home: Partition, demand: ReadonlyMap<string, number>, cfg: PartitionConfig): ResolvedPartition {
  const joins = (p: Partition): number => demand.get(partitionKey(p)) ?? 0;
  const thin = (p: Partition): boolean => joins(p) < cfg.thinJoinThreshold;
  const busiest = (pool: LanguagePool): TzRegion => {
    const order: TzRegion[] = [cfg.defaultRegion, ...TZ_REGIONS.filter((r) => r !== cfg.defaultRegion)];
    let best = order[0];
    for (const region of order) if (joins({ pool, region }) > joins({ pool, region: best })) best = region;
    return best;
  };

  const chain: Partition[] = [home];
  if (thin(home)) {
    const sameLanguage = { pool: home.pool, region: busiest(home.pool) };
    if (sameLanguage.region !== home.region) chain.push(sameLanguage);
    if (thin(sameLanguage) && home.pool !== 'en') {
      chain.push({ pool: 'en', region: home.region });
      const english = { pool: 'en' as const, region: busiest('en') };
      if (english.region !== home.region) chain.push(english);
    }
  }
  const chosen = chain.find((p) => !thin(p)) ?? chain[chain.length - 1];
  return { ...chosen, merged: chosen.pool !== home.pool || chosen.region !== home.region };
}

/** A joinable room (the SQL already applied: < 20 h old, below capacity, no block with the joiner, never joined). */
export interface Candidate {
  roomId: string;
  quadrant: Quadrant;
  seedMoodId: string;
  /** Current members seen within the live window (2 min). */
  live: number;
  /** Everyone who has been a member ("people have been here today"): the 24 h activity measure. */
  total: number;
  createdAt: Date;
}

export interface LadderConfig {
  step1ExactMood: boolean;
  /** Step 3 applies when the partition had fewer distinct live people than this over the last 15 min. */
  partitionLiveMin: number;
  /** Step 3 candidates need at least this many live members. */
  adjacentLiveMin: number;
  /** Outside Lantern Hour, a room with this many live members is full enough: prefer another room / spawn. */
  spawnLiveThreshold: number;
}

export interface LadderInput {
  moodId: string;
  /** Joinable rooms of the resolved partition (the joiner's quadrant). */
  partition: Candidate[];
  /** Joinable rooms of the adjacent quadrant (same pool and region); empty when the joiner already holds one. */
  adjacent: Candidate[];
  /** Distinct people seen in the partition's rooms over the last 15 min. */
  partitionLive15: number;
  /** Lantern Hour on the partition's region clock: rooms fill to capacity first. */
  lanternHour: boolean;
  config: LadderConfig;
}

export type LadderStep = 1 | 2 | 3 | 4;

export interface LadderPlan {
  /** Rooms to try, best first (each tagged with the step that picked it). */
  ranked: Array<{ step: LadderStep; roomId: string }>;
  /** The step reported when none of them can take the joiner and a new room is spawned. */
  spawnStep: LadderStep;
}

const byLiveThenNewest = (a: Candidate, b: Candidate): number =>
  b.live - a.live || b.total - a.total || b.createdAt.getTime() - a.createdAt.getTime();
const byActivityThenNewest = (a: Candidate, b: Candidate): number =>
  b.total - a.total || b.createdAt.getTime() - a.createdAt.getTime();

/**
 * The fallback ladder, steps 1–4 (step 0 — returning to your room — happens before this):
 * 1 exact mood (≥ 1 live; config, off at alpha) → 3 adjacent quadrant (≥ 3 live) when the partition had < 3 live
 * over 15 min → 2 the partition room with the most live members → 4 nothing live: the partition room with the most
 * people today, else a new room. A new room also spawns when, outside Lantern Hour, every live room is full enough
 * (≥ 12 live); in Lantern Hour rooms fill to capacity first. Step 3 never crosses pleasant/unpleasant (the caller only
 * passes the same-side neighbour).
 */
export function planLadder(input: LadderInput): LadderPlan {
  const { config: cfg } = input;
  const fullEnough = (c: Candidate): boolean => !input.lanternHour && c.live >= cfg.spawnLiveThreshold;
  const ranked: Array<{ step: LadderStep; roomId: string }> = [];
  const seen = new Set<string>();
  const push = (step: LadderStep, rooms: Candidate[]): void => {
    for (const c of rooms) {
      if (seen.has(c.roomId)) continue;
      seen.add(c.roomId);
      ranked.push({ step, roomId: c.roomId });
    }
  };

  if (cfg.step1ExactMood) {
    push(1, input.partition.filter((c) => c.seedMoodId === input.moodId && c.live >= 1 && !fullEnough(c)).sort(byLiveThenNewest));
  }
  if (input.partitionLive15 < cfg.partitionLiveMin) {
    push(3, input.adjacent.filter((c) => c.live >= cfg.adjacentLiveMin && !fullEnough(c)).sort(byLiveThenNewest));
  }
  push(2, input.partition.filter((c) => c.live >= 1 && !fullEnough(c)).sort(byLiveThenNewest));

  const liveButFullEnough = input.partition.some((c) => c.live >= 1 && fullEnough(c));
  if (!liveButFullEnough) push(4, input.partition.filter((c) => c.live === 0).sort(byActivityThenNewest));
  return { ranked, spawnStep: liveButFullEnough ? 2 : 4 };
}
