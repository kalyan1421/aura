/**
 * Gesture limits (PRD F5 "Abuse and safety hooks" [ASSUMPTION]), per sender account:
 *   1 per 2 s (across rooms) · 40 per room per hour · the same gesture to the same member ≤ 3 per 10 min.
 * Over a limit → dropped silently (the sender sees "sent"). 3 limit hits in 24 h → the account's gestures are
 * shadow-muted for 24 h and a spam-lane item is queued (F9 strike signal). The SQL side counts; this decides.
 */
export interface GestureLimitConfig {
  minIntervalMs: number;
  roomHourMax: number;
  sameTargetMax: number;
  sameTargetWindowMin: number;
  limitHitsToMute: number;
  shadowMuteHours: number;
}

export interface SenderHistory {
  /**
   * Milliseconds since the sender's latest counted gesture in any room (over-limit attempts don't count), measured
   * on the DB clock that stamps gestures; null = none yet.
   */
  msSinceLast: number | null;
  /** Counted gestures by this membership in the last hour. */
  roomLastHour: number;
  /** Counted gestures of this type to this member in the last `sameTargetWindowMin` (0 for room gestures). */
  sameTargetRecent: number;
}

export type LimitBreach = 'interval' | 'room_hour' | 'same_target';

export function gestureLimitBreach(h: SenderHistory, cfg: GestureLimitConfig): LimitBreach | null {
  if (h.msSinceLast !== null && h.msSinceLast < cfg.minIntervalMs) return 'interval';
  if (h.roomLastHour >= cfg.roomHourMax) return 'room_hour';
  if (h.sameTargetRecent >= cfg.sameTargetMax) return 'same_target';
  return null;
}

/** After recording one more hit: does it reach the shadow-mute threshold (and no mute is active yet)? */
export function shouldShadowMute(hitsIn24hIncludingThis: number, alreadyMuted: boolean, cfg: GestureLimitConfig): boolean {
  return !alreadyMuted && hitsIn24hIncludingThis >= cfg.limitHitsToMute;
}
