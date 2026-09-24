import type { Queryable } from '../db/db';

/** `public.ripple_config` (single row, tunable without a release). Read per request: one PK lookup. */
export interface RippleConfig {
  seatCount: number;
  earlyStartS: number;
  earlyStartMinHumans: number;
  maxWaitS: number;
  inviteWindowS: number;
  invitesPerWindow: number;
  inviteLimitWindowMin: number;
  ticketStaleS: number;
  pollMs: number;
  startLeadMs: number;
  settleMs: number;
  inhaleMs: number;
  exhaleMs: number;
  cycles: number;
  fadeMs: number;
  pacerVersion: number;
  echoMinCycles: number;
  echoMinCompletion: number;
  echoMaxMedianOffsetMs: number;
  echoLibraryMin: number;
  echoRetentionD: number;
  sessionRetentionD: number;
  eventsPerSecondCap: number;
  pulseMinIntervalMs: number;
  gestureMinIntervalMs: number;
  heartbeatMs: number;
  disconnectAfterMs: number;
  echoAfterMs: number;
  rejoinWindowMs: number;
}

/** Defaults = the migration's column defaults (used only if the row is missing). */
export const DEFAULT_RIPPLE_CONFIG: RippleConfig = {
  seatCount: 4,
  earlyStartS: 8,
  earlyStartMinHumans: 2,
  maxWaitS: 20,
  inviteWindowS: 20,
  invitesPerWindow: 1,
  inviteLimitWindowMin: 10,
  ticketStaleS: 6,
  pollMs: 2000,
  startLeadMs: 0,
  settleMs: 10_000,
  inhaleMs: 4000,
  exhaleMs: 6000,
  cycles: 16,
  fadeMs: 10_000,
  pacerVersion: 1,
  echoMinCycles: 12,
  echoMinCompletion: 0.9,
  echoMaxMedianOffsetMs: 600,
  echoLibraryMin: 50,
  echoRetentionD: 90,
  sessionRetentionD: 7,
  eventsPerSecondCap: 10,
  pulseMinIntervalMs: 3000,
  gestureMinIntervalMs: 5000,
  heartbeatMs: 2000,
  disconnectAfterMs: 3000,
  echoAfterMs: 10_000,
  rejoinWindowMs: 10_000,
};

/** The whole session: settle-in + cycles × (inhale + exhale) + fade-out (180 s at the defaults). */
export const sessionLengthMs = (c: Pick<RippleConfig, 'settleMs' | 'inhaleMs' | 'exhaleMs' | 'cycles' | 'fadeMs'>): number =>
  c.settleMs + c.cycles * (c.inhaleMs + c.exhaleMs) + c.fadeMs;

interface Row {
  seat_count: number;
  early_start_s: number;
  early_start_min_humans: number;
  max_wait_s: number;
  invite_window_s: number;
  invites_per_window: number;
  invite_limit_window_min: number;
  ticket_stale_s: number;
  poll_ms: number;
  start_lead_ms: number;
  settle_ms: number;
  inhale_ms: number;
  exhale_ms: number;
  cycles: number;
  fade_ms: number;
  pacer_version: number;
  echo_min_cycles: number;
  echo_min_completion: string;
  echo_max_median_offset_ms: number;
  echo_library_min: number;
  echo_retention_d: number;
  session_retention_d: number;
  events_per_s_cap: number;
  pulse_min_interval_ms: number;
  gesture_min_interval_ms: number;
  heartbeat_ms: number;
  disconnect_after_ms: number;
  echo_after_ms: number;
  rejoin_window_ms: number;
}

export async function loadRippleConfig(q: Queryable): Promise<RippleConfig> {
  const r = await q.query<Row>('select * from public.ripple_config where id');
  const x = r.rows[0];
  if (!x) return DEFAULT_RIPPLE_CONFIG;
  return {
    seatCount: x.seat_count,
    earlyStartS: x.early_start_s,
    earlyStartMinHumans: x.early_start_min_humans,
    maxWaitS: x.max_wait_s,
    inviteWindowS: x.invite_window_s,
    invitesPerWindow: x.invites_per_window,
    inviteLimitWindowMin: x.invite_limit_window_min,
    ticketStaleS: x.ticket_stale_s,
    pollMs: x.poll_ms,
    startLeadMs: x.start_lead_ms,
    settleMs: x.settle_ms,
    inhaleMs: x.inhale_ms,
    exhaleMs: x.exhale_ms,
    cycles: x.cycles,
    fadeMs: x.fade_ms,
    pacerVersion: x.pacer_version,
    echoMinCycles: x.echo_min_cycles,
    echoMinCompletion: Number(x.echo_min_completion),
    echoMaxMedianOffsetMs: x.echo_max_median_offset_ms,
    echoLibraryMin: x.echo_library_min,
    echoRetentionD: x.echo_retention_d,
    sessionRetentionD: x.session_retention_d,
    eventsPerSecondCap: x.events_per_s_cap,
    pulseMinIntervalMs: x.pulse_min_interval_ms,
    gestureMinIntervalMs: x.gesture_min_interval_ms,
    heartbeatMs: x.heartbeat_ms,
    disconnectAfterMs: x.disconnect_after_ms,
    echoAfterMs: x.echo_after_ms,
    rejoinWindowMs: x.rejoin_window_ms,
  };
}
