import type { QuietConfig } from './quiet-config';
import { quietTopic, RHYTHM_MODES, type QuietMode } from './quiet-types';
import { soundscapeFor, type SoundscapeStem } from './soundscapes';

/**
 * Contract shapes (contracts/api/v1-quiet.md "Shared shapes"). Built field by field from the session row and a
 * count — never by spreading rows — so no member list, member id, pseudonym, account id, age, mood or silhouette can
 * reach a client (DS-10, REQ-QUIET-01; a unit test pins the exact keys).
 */
export interface QuietSessionRow {
  id: string;
  mode: QuietMode;
  tz_region: string;
  t0: Date;
  ends_at: Date;
  soundscape_seed: number;
  capacity: number;
  created_at: Date;
}

export interface QuietSessionView {
  sessionId: string;
  mode: QuietMode;
  t0: string;
  t0Ms: number;
  endsAt: string;
  endsAtMs: number;
  /** Live people in this session, including the caller ("12 here"). Never fewer than 1 for the caller. */
  count: number;
  soundscape: { seed: number; stems: SoundscapeStem[] };
  rhythm: { focusMin: number; breakMin: number } | null;
  gestures: { minIntervalMs: number; perHour: number };
  heartbeatMs: number;
  realtime: { topic: string };
  serverTime: string;
  serverTimeMs: number;
}

export function sessionView(s: QuietSessionRow, count: number, cfg: QuietConfig, now: Date): QuietSessionView {
  return {
    sessionId: s.id,
    mode: s.mode,
    t0: s.t0.toISOString(),
    t0Ms: s.t0.getTime(),
    endsAt: s.ends_at.toISOString(),
    endsAtMs: s.ends_at.getTime(),
    count: Math.max(1, Math.floor(count)),
    soundscape: { seed: s.soundscape_seed, stems: soundscapeFor(s.mode, s.soundscape_seed) },
    rhythm: RHYTHM_MODES.has(s.mode) ? { focusMin: cfg.focusMin, breakMin: cfg.breakMin } : null,
    gestures: { minIntervalMs: cfg.gestures.minIntervalMs, perHour: cfg.gestures.hourMax },
    heartbeatMs: cfg.heartbeatMs,
    realtime: { topic: quietTopic(s.id) },
    serverTime: now.toISOString(),
    serverTimeMs: now.getTime(),
  };
}
