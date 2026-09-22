/** RULES.md §5 — ringCount (Breathe) / glowLevel (Sleep on time): thresholds 5 / 20 / 50 → 0–3. */
export const TRAIT_THRESHOLDS = [5, 20, 50] as const;

export function traitLevel(completions: number): 0 | 1 | 2 | 3 {
  return TRAIT_THRESHOLDS.filter((t) => completions >= t).length as 0 | 1 | 2 | 3;
}
