import { daysBetween } from './dates';

/** RULES.md §7 — glow streak & rest days. */
export interface StreakState {
  glowStreak: number;
  lifetimeGlowDays: number;
  restBank: number;
  earnCounter: number;
  lastActiveDay: string | null;
}

export const MAX_REST_BANK = 3;
export const EARN_EVERY = 4;

/** New users start with 1 welcome rest day. */
export const initialStreak = (): StreakState => ({
  glowStreak: 0,
  lifetimeGlowDays: 0,
  restBank: 1,
  earnCounter: 0,
  lastActiveDay: null,
});

function step(s: StreakState, day: string): StreakState {
  let { glowStreak, restBank, earnCounter } = s;
  if (s.lastActiveDay === null) {
    glowStreak = 1;
  } else {
    const gap = daysBetween(s.lastActiveDay, day) - 1;
    if (gap === 0) {
      glowStreak += 1;
    } else if (gap >= 1 && gap <= restBank) {
      restBank -= gap; // rest days bridge the gap but add nothing
      glowStreak += 1;
    } else {
      glowStreak = 1; // gap > restBank: reset, nothing spent
    }
  }
  if (restBank < MAX_REST_BANK) {
    earnCounter += 1;
    if (earnCounter === EARN_EVERY) {
      restBank += 1;
      earnCounter = 0;
    }
  } // else: bank full → counter paused
  return { glowStreak, lifetimeGlowDays: s.lifetimeGlowDays + 1, restBank, earnCounter, lastActiveDay: day };
}

/** Fold distinct active aura days (any order, duplicates allowed) in ascending order. */
export function foldStreak(initial: StreakState, days: readonly string[]): StreakState {
  const distinct = [...new Set(days)].sort();
  // Days at or before the state's lastActiveDay were already folded in.
  const fresh = initial.lastActiveDay ? distinct.filter((d) => d > initial.lastActiveDay!) : distinct;
  return fresh.reduce(step, { ...initial });
}
