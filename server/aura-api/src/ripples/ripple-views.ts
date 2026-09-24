import type { RippleConfig } from './ripple-config';
import { gameTopic, type RippleEntry, type SeatKind, type StartRule } from './ripple-types';

/**
 * Stranger-facing shapes (contracts/api/v1-ripples.md "Shared shapes"). The ONLY builders of what other people see:
 * seat numbers, kinds, pseudonyms and pacer timings. Never an account id, member id, age or DOB (DS-10).
 */
export interface SessionRow {
  id: string;
  entry: RippleEntry;
  room_id: string | null;
  start_rule: StartRule;
  t0: Date;
  settle_ms: number;
  inhale_ms: number;
  exhale_ms: number;
  cycles: number;
  fade_ms: number;
  pacer_version: number;
  ends_at: Date;
  ended_at: Date | null;
}

export interface SeatRow {
  id: string;
  seat: number;
  kind: SeatKind;
  user_id: string | null;
  pseudonym: string | null;
  echo_id: string | null;
  left_at: Date | null;
}

export interface SeatView {
  seat: number;
  kind: SeatKind;
  /** Humans: their pseudonym. Echoes and guides: null (the app labels them). */
  label: string | null;
  /** Echoes only: pacer-relative transition offsets in 50 ms steps (null = missed). */
  trace?: Array<number | null>;
}

export interface SessionPayload {
  sessionId: string;
  entry: RippleEntry;
  roomId: string | null;
  startRule: StartRule;
  t0: string;
  t0Ms: number;
  settleMs: number;
  inhaleMs: number;
  exhaleMs: number;
  cycles: number;
  fadeMs: number;
  pacerVersion: number;
  endsAt: string;
  endsAtMs: number;
  seats: SeatView[];
  humans: number;
  echoes: number;
  guides: number;
  ended: boolean;
  realtime: { topic: string };
  limits: {
    eventsPerSecond: number;
    pulseMinMs: number;
    gestureMinMs: number;
    heartbeatMs: number;
    disconnectAfterMs: number;
    echoAfterMs: number;
    rejoinWindowMs: number;
  };
}

export type SessionView = SessionPayload & { mySeat: number; serverTime: string; serverTimeMs: number };

/**
 * The session as its players see it. A human who left is shown as an echo ("your light dims into an echo"), still
 * without a label change being taken from the channel. `traces` = the echo seats' recordings by echo id.
 */
export function sessionPayload(
  s: SessionRow,
  seats: readonly SeatRow[],
  traces: ReadonlyMap<string, Array<number | null>>,
  cfg: RippleConfig,
  now: Date,
): SessionPayload {
  const views: SeatView[] = [...seats]
    .sort((a, b) => a.seat - b.seat)
    .map((x) => {
      if (x.kind === 'human') {
        return x.left_at ? { seat: x.seat, kind: 'echo' as const, label: null } : { seat: x.seat, kind: 'human' as const, label: x.pseudonym };
      }
      if (x.kind === 'echo') return { seat: x.seat, kind: 'echo' as const, label: null, trace: (x.echo_id && traces.get(x.echo_id)) || [] };
      return { seat: x.seat, kind: 'guide' as const, label: null };
    });
  // The intro counts what the session STARTED with (humans are never re-counted as echoes there).
  const humans = seats.filter((x) => x.kind === 'human').length;
  return {
    sessionId: s.id,
    entry: s.entry,
    roomId: s.room_id,
    startRule: s.start_rule,
    t0: s.t0.toISOString(),
    t0Ms: s.t0.getTime(),
    settleMs: s.settle_ms,
    inhaleMs: s.inhale_ms,
    exhaleMs: s.exhale_ms,
    cycles: s.cycles,
    fadeMs: s.fade_ms,
    pacerVersion: s.pacer_version,
    endsAt: s.ends_at.toISOString(),
    endsAtMs: s.ends_at.getTime(),
    seats: views,
    humans,
    echoes: seats.filter((x) => x.kind === 'echo').length,
    guides: seats.filter((x) => x.kind === 'guide').length,
    ended: s.ended_at !== null || s.ends_at.getTime() <= now.getTime(),
    realtime: { topic: gameTopic(s.id) },
    limits: {
      eventsPerSecond: cfg.eventsPerSecondCap,
      pulseMinMs: cfg.pulseMinIntervalMs,
      gestureMinMs: cfg.gestureMinIntervalMs,
      heartbeatMs: cfg.heartbeatMs,
      disconnectAfterMs: cfg.disconnectAfterMs,
      echoAfterMs: cfg.echoAfterMs,
      rejoinWindowMs: cfg.rejoinWindowMs,
    },
  };
}

export function sessionView(payload: SessionPayload, mySeat: number, now: Date): SessionView {
  return { ...payload, mySeat, serverTime: now.toISOString(), serverTimeMs: now.getTime() };
}

export interface InviteView {
  inviteId: string;
  fromPseudonym: string;
  humans: number;
  capacity: number;
  startsAt: string;
  startsAtMs: number;
  /** You opened it. */
  mine: boolean;
}
