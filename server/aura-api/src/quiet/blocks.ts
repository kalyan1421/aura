import { REGION_CLOCK, type TzRegion } from '../rooms/regions';
import { wallClock } from '../rules';

/**
 * Quiet Together blocks (PRD F16 "Time-boxed, drop-in"): 60-min blocks **on the hour of the timezone region's clock**
 * (the F5 regions) [ASSUMPTION]. Asia/Kolkata runs at +5:30, so a south_asia block starts at hh:30 UTC. Derived from the
 * region's wall-clock minutes and seconds, which stays right across DST changes (a repeated or skipped hour is still
 * a whole hour on the wall clock).
 */
export interface Block {
  t0: Date;
  endsAt: Date;
}

export function blockFor(region: TzRegion, now: Date, blockMin = 60): Block {
  const w = wallClock(now, REGION_CLOCK[region]);
  const intoHourMs = (w.minute * 60 + w.second) * 1000 + (now.getTime() % 1000 + 1000) % 1000;
  const t0 = new Date(now.getTime() - intoHourMs);
  return { t0, endsAt: new Date(t0.getTime() + blockMin * 60_000) };
}

/** Is `now` inside the block that starts at `t0`? */
export const inBlock = (b: Block, now: Date): boolean => now.getTime() >= b.t0.getTime() && now.getTime() < b.endsAt.getTime();

/**
 * The optional 25/5 focus rhythm (REQ-QUIET-05), following the block: focus :00–:25, break :25–:30, focus :30–:55,
 * break :55–:00. Pure; the phone runs the same rule from `t0` (it is never sent per person, and it is off by default).
 */
export type RhythmPhase = 'focus' | 'break';

export function rhythmAt(t0Ms: number, nowMs: number, focusMin: number, breakMin: number): { phase: RhythmPhase; nextChangeMs: number } {
  const cycle = (focusMin + breakMin) * 60_000;
  const into = (((nowMs - t0Ms) % cycle) + cycle) % cycle;
  const cycleStart = nowMs - into;
  if (into < focusMin * 60_000) return { phase: 'focus', nextChangeMs: cycleStart + focusMin * 60_000 };
  return { phase: 'break', nextChangeMs: cycleStart + cycle };
}
