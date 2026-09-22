/** RULES.md §4 — stage & constellation from all-time Starlight. */
export const STAGES = ['spark', 'ember', 'glow', 'radiance', 'constellation'] as const;
export type Stage = (typeof STAGES)[number];

const THRESHOLDS: ReadonlyArray<readonly [Stage, number]> = [
  ['constellation', 3000],
  ['radiance', 1200],
  ['glow', 400],
  ['ember', 100],
  ['spark', 0],
];

export function stageFor(total: number): Stage {
  for (const [stage, min] of THRESHOLDS) if (total >= min) return stage;
  return 'spark';
}

export const MAX_CONSTELLATION_STARS = 12;

export function constellationStars(total: number): number {
  return total >= 3000 ? Math.min(MAX_CONSTELLATION_STARS, Math.floor((total - 3000) / 500)) : 0;
}
