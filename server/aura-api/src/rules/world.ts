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

/** W06 — the sky over the personal universe, from the phone's wall-clock hour. Decoration only. */
export type SkyPhase = 'dawn' | 'day' | 'dusk' | 'night';

export function skyPhase(localHour: number): SkyPhase {
  const h = ((Math.trunc(localHour) % 24) + 24) % 24;
  if (h >= 5 && h < 7) return 'dawn';
  if (h >= 7 && h < 17) return 'day';
  if (h >= 17 && h < 19) return 'dusk';
  return 'night';
}

/** The island's stepping stones. */
export const PATH_STONE_COUNT = 16;

/** W06 — stones that glow after today's steps: one per thousand, warmth only, never a penalty. */
export function litStones(steps: number | null): number {
  if (steps === null || !Number.isFinite(steps) || steps <= 0) return 0;
  return Math.min(PATH_STONE_COUNT, Math.floor(steps / 1000));
}

/** T04 — how a world object looked the last time the person saw it. */
export interface WorldLook {
  stage: GrowthStage;
  vitality: Vitality;
}

export type WorldChangeKind = 'sprout' | 'grow' | 'wake';

const STAGE_ORDER: readonly GrowthStage[] = ['seed', ...STAGES];

/**
 * T04 — which world objects deserve a one-time moment since the person last saw the world. A `null` `seen` is the baseline
 * (never a moment); at most one change per key, in `current` order; a lower stage or starting to rest is never a change.
 * Device-only presentation; no endpoint uses it.
 */
export function worldChanges(
  seen: Record<string, WorldLook> | null,
  current: readonly (WorldLook & { key: string })[],
): { key: string; kind: WorldChangeKind }[] {
  if (seen === null) return [];
  const out: { key: string; kind: WorldChangeKind }[] = [];
  for (const c of current) {
    const before = Object.prototype.hasOwnProperty.call(seen, c.key) ? seen[c.key] : undefined;
    let kind: WorldChangeKind | null = null;
    if (before === undefined) kind = 'sprout';
    else if (STAGE_ORDER.indexOf(c.stage) > STAGE_ORDER.indexOf(before.stage)) kind = 'grow';
    else if (before.vitality !== 'thriving' && c.vitality === 'thriving') kind = 'wake';
    if (kind !== null) out.push({ key: c.key, kind });
  }
  return out;
}
