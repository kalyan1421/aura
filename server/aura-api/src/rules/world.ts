import { daysBetween } from './dates';
import { isResting } from './nebula';

/** RULES.md §13 — presentation-only world objects. Never touches the ledger; no endpoint uses it. */
export type GrowthStage = 'seed' | 'sprout' | 'young' | 'grown' | 'flourishing' | 'ancient';
export type Vitality = 'thriving' | 'dimmed' | 'wilting' | 'dormant';

const STAGES: readonly GrowthStage[] = ['sprout', 'young', 'grown', 'flourishing', 'ancient'];
export const GROWTH_STAGE_THRESHOLDS = [1, 4, 10, 25, 60] as const;
export const MIN_DECAY_AGE_YEARS = 18;

export function growthStage(distinctLoggedDays: number): GrowthStage {
  let stage: GrowthStage = 'seed';
  GROWTH_STAGE_THRESHOLDS.forEach((t, i) => {
    if (distinctLoggedDays >= t) stage = STAGES[i];
  });
  return stage;
}

export function decayEligible(optedIn: boolean, ageYears: number): boolean {
  return optedIn && ageYears >= MIN_DECAY_AGE_YEARS;
}

export interface VitalityInput {
  decayActive: boolean;
  committedFrom: string | null;
  lastLogDay: string | null;
  pausedThrough: string | null;
  today: string;
}

export function habitVitality(i: VitalityInput): Vitality {
  if (!i.decayActive || i.committedFrom === null) return 'thriving';
  let anchor = i.committedFrom;
  for (const d of [i.lastLogDay, i.pausedThrough]) {
    if (d !== null && daysBetween(anchor, d) > 0) anchor = d;
  }
  const gap = daysBetween(anchor, i.today) - 1;
  if (gap >= 7) return 'dormant';
  if (gap >= 4) return 'wilting';
  if (gap >= 2) return 'dimmed';
  return 'thriving';
}

/**
 * W04 — the one-time "Your world is here" card. Resting (§8) and not already shown for this absence
 * (`shownFor` is the `lastActiveDay` it was last shown for). Device-only; no endpoint uses it.
 */
export function showWelcomeBack(lastActiveDay: string | null, today: string, shownFor: string | null): boolean {
  return isResting(lastActiveDay, today) && shownFor !== lastActiveDay;
}
