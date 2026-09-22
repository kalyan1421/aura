import { daysBetween } from './dates';

/** RULES.md §8 — Resting Nebula after 3+ aura days without activity. */
export const RESTING_AFTER_DAYS = 3;

export function isResting(lastActiveDay: string | null, currentAuraDay: string): boolean {
  return lastActiveDay !== null && daysBetween(lastActiveDay, currentAuraDay) >= RESTING_AFTER_DAYS;
}
