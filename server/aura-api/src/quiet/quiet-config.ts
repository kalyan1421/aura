import type { Queryable } from '../db/db';
import { parseClockTime, type ClockTime } from '../rooms/regions';

/** `public.quiet_config` (single row, tunable without a release). Read per request: one PK lookup. */
export interface QuietConfig {
  blockMin: number;
  capacity: number;
  /** A region with fewer live people than this (in the mode's current block) merges into the busiest region. */
  thinLiveMin: number;
  /** A member counts ("12 here") while seen in the last `liveWindowS`. */
  liveWindowS: number;
  heartbeatMs: number;
  /** Memberships not seen for this long are closed by the worker (leaving costs nothing). */
  staleAfterMin: number;
  focusMin: number;
  breakMin: number;
  gestures: {
    minIntervalMs: number;
    hourMax: number;
    limitHitsToMute: number;
    shadowMuteHours: number;
  };
  retentionD: number;
  windDown: {
    start: ClockTime;
    lengthMin: number;
    inhaleMs: number;
    exhaleMs: number;
  };
}

interface Row {
  block_min: number;
  capacity: number;
  thin_live_min: number;
  live_window_s: number;
  heartbeat_ms: number;
  stale_after_min: number;
  focus_min: number;
  break_min: number;
  gesture_min_interval_ms: number;
  gesture_hour_max: number;
  gesture_limit_hits_to_mute: number;
  gesture_shadow_mute_h: number;
  retention_d: number;
  wind_down_start: string;
  wind_down_min: number;
  wind_down_inhale_ms: number;
  wind_down_exhale_ms: number;
}

function fromRow(r: Row): QuietConfig {
  return {
    blockMin: r.block_min,
    capacity: r.capacity,
    thinLiveMin: r.thin_live_min,
    liveWindowS: r.live_window_s,
    heartbeatMs: r.heartbeat_ms,
    staleAfterMin: r.stale_after_min,
    focusMin: r.focus_min,
    breakMin: r.break_min,
    gestures: {
      minIntervalMs: r.gesture_min_interval_ms,
      hourMax: r.gesture_hour_max,
      limitHitsToMute: r.gesture_limit_hits_to_mute,
      shadowMuteHours: r.gesture_shadow_mute_h,
    },
    retentionD: r.retention_d,
    windDown: {
      start: parseClockTime(r.wind_down_start),
      lengthMin: r.wind_down_min,
      inhaleMs: r.wind_down_inhale_ms,
      exhaleMs: r.wind_down_exhale_ms,
    },
  };
}

/** Defaults = the migration's column defaults (used only if the row is missing). */
export const DEFAULT_QUIET_CONFIG: QuietConfig = fromRow({
  block_min: 60,
  capacity: 50,
  thin_live_min: 3,
  live_window_s: 90,
  heartbeat_ms: 30_000,
  stale_after_min: 10,
  focus_min: 25,
  break_min: 5,
  gesture_min_interval_ms: 10_000,
  gesture_hour_max: 20,
  gesture_limit_hits_to_mute: 3,
  gesture_shadow_mute_h: 24,
  retention_d: 7,
  wind_down_start: '22:30:00',
  wind_down_min: 20,
  wind_down_inhale_ms: 4000,
  wind_down_exhale_ms: 6000,
});

export async function loadQuietConfig(q: Queryable): Promise<QuietConfig> {
  const r = await q.query<Row>('select * from public.quiet_config where id');
  return r.rows[0] ? fromRow(r.rows[0]) : DEFAULT_QUIET_CONFIG;
}
