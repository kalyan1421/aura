import type { Queryable } from '../db/db';
import type { GestureLimitConfig } from './gesture-limits';
import { DEFAULT_LANTERN_CONFIG, type LanternConfig } from './lantern-rules';
import type { LadderConfig, PartitionConfig } from './matching';
import { isTzRegion, parseClockTime, type ClockTime, type TzRegion } from './regions';

/** `public.matching_config` (single row, tunable without a release). Read per request: one PK lookup. */
export interface MatchingConfig {
  ladder: LadderConfig;
  partition: PartitionConfig;
  gestures: GestureLimitConfig;
  liveWindowS: number;
  partitionLiveWindowMin: number;
  roomCapacity: number;
  joinCutoffH: number;
  memoryAfterH: number;
  purgeAfterD: number;
  joinsPerQuadrant24h: number;
  lanternStart: ClockTime;
  lanternEnd: ClockTime;
  /** Room lanterns and Tonight's intention (Milestone B): tunables + the two kill switches. */
  lanterns: LanternConfig;
}

interface Row {
  step1_exact_mood: boolean;
  live_window_s: number;
  partition_live_window_min: number;
  partition_live_min: number;
  adjacent_live_min: number;
  spawn_live_threshold: number;
  thin_join_threshold: number;
  default_region: string;
  room_capacity: number;
  join_cutoff_h: number;
  memory_after_h: number;
  purge_after_d: number;
  joins_per_quadrant_24h: number;
  gesture_min_interval_ms: number;
  gesture_room_hour_max: number;
  gesture_same_target_max: number;
  gesture_same_target_window_min: number;
  gesture_limit_hits_to_mute: number;
  gesture_shadow_mute_h: number;
  lantern_start: string;
  lantern_end: string;
  // Migration 20261005000022 (numeric columns arrive as strings) + the kill-switch flags joined in by the loader.
  lantern_units_per_member?: string | number | null;
  lantern_min_units_per_level?: number | null;
  lantern_breath_cycle_weight?: string | number | null;
  lanterns_flag?: boolean | null;
  intention_flag?: boolean | null;
}

const num = (v: unknown, fallback: number): number => {
  const n = typeof v === 'number' ? v : typeof v === 'string' ? Number(v) : NaN;
  return Number.isFinite(n) ? n : fallback;
};

/** Defaults = the migration's column defaults (used only if the row is missing). */
export const DEFAULT_MATCHING_CONFIG: MatchingConfig = fromRow({
  step1_exact_mood: false,
  live_window_s: 120,
  partition_live_window_min: 15,
  partition_live_min: 3,
  adjacent_live_min: 3,
  spawn_live_threshold: 12,
  thin_join_threshold: 12,
  default_region: 'south_asia',
  room_capacity: 24,
  join_cutoff_h: 20,
  memory_after_h: 24,
  purge_after_d: 7,
  joins_per_quadrant_24h: 3,
  gesture_min_interval_ms: 2000,
  gesture_room_hour_max: 40,
  gesture_same_target_max: 3,
  gesture_same_target_window_min: 10,
  gesture_limit_hits_to_mute: 3,
  gesture_shadow_mute_h: 24,
  lantern_start: '21:00:00',
  lantern_end: '23:00:00',
});

function fromRow(r: Row): MatchingConfig {
  const defaultRegion: TzRegion = isTzRegion(r.default_region) ? r.default_region : 'south_asia';
  return {
    ladder: {
      step1ExactMood: r.step1_exact_mood,
      partitionLiveMin: r.partition_live_min,
      adjacentLiveMin: r.adjacent_live_min,
      spawnLiveThreshold: r.spawn_live_threshold,
    },
    partition: { thinJoinThreshold: r.thin_join_threshold, defaultRegion },
    gestures: {
      minIntervalMs: r.gesture_min_interval_ms,
      roomHourMax: r.gesture_room_hour_max,
      sameTargetMax: r.gesture_same_target_max,
      sameTargetWindowMin: r.gesture_same_target_window_min,
      limitHitsToMute: r.gesture_limit_hits_to_mute,
      shadowMuteHours: r.gesture_shadow_mute_h,
    },
    liveWindowS: r.live_window_s,
    partitionLiveWindowMin: r.partition_live_window_min,
    roomCapacity: r.room_capacity,
    joinCutoffH: r.join_cutoff_h,
    memoryAfterH: r.memory_after_h,
    purgeAfterD: r.purge_after_d,
    joinsPerQuadrant24h: r.joins_per_quadrant_24h,
    lanternStart: parseClockTime(r.lantern_start),
    lanternEnd: parseClockTime(r.lantern_end),
    lanterns: {
      // A missing flag counts as on (kill switches only ever take things away).
      enabled: r.lanterns_flag !== false,
      intentionEnabled: r.intention_flag !== false,
      unitsPerMember: num(r.lantern_units_per_member, DEFAULT_LANTERN_CONFIG.unitsPerMember),
      minUnitsPerLevel: num(r.lantern_min_units_per_level, DEFAULT_LANTERN_CONFIG.minUnitsPerLevel),
      breathCycleWeight: num(r.lantern_breath_cycle_weight, DEFAULT_LANTERN_CONFIG.breathCycleWeight),
    },
  };
}

export async function loadMatchingConfig(q: Queryable): Promise<MatchingConfig> {
  const r = await q.query<Row>(
    `select mc.*,
            (select f.enabled from public.feature_flags f where f.key = 'room_lanterns_enabled') as lanterns_flag,
            (select f.enabled from public.feature_flags f where f.key = 'room_intention_enabled') as intention_flag
       from public.matching_config mc where mc.id`,
  );
  return r.rows[0] ? fromRow(r.rows[0]) : DEFAULT_MATCHING_CONFIG;
}
