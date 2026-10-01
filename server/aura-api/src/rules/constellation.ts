/**
 * RULES.md §14 — Orbit Loom constellations (U07). Cosmetic: keeping one never touches the ledger; there is no correct
 * shape, score or timer. Mirrors packages/aura_domain/lib/src/rules/constellation.dart; both pass
 * contracts/rules/vectors/constellations.json.
 */
export const MIN_LOOM_STARS = 3;
export const MAX_LOOM_STARS = 7;
export const MAX_LOOM_LINKS = 12;
export const MIN_LOOM_STAR_GAP = 0.05;
export const MAX_LOOM_CONSTELLATIONS_PER_DAY = 5;

/** The optional, neutral meanings (all equal; none suggested or rewarded). */
export const CONSTELLATION_MEANINGS = ['noticed', 'carrying', 'ahead', 'thankful', 'just_because'] as const;
export type ConstellationMeaning = (typeof CONSTELLATION_MEANINGS)[number];

export type ConstellationProblem =
  | 'too_few_stars'
  | 'too_many_stars'
  | 'star_outside_sky'
  | 'stars_too_close'
  | 'too_many_links'
  | 'bad_link'
  | 'duplicate_link'
  | 'unknown_meaning';

/** The first problem with a constellation, or `null` when it is valid (RULES.md §14 `problem`). */
export function constellationProblem(
  stars: readonly (readonly unknown[])[],
  links: readonly (readonly unknown[])[],
  meaning: string | null,
): ConstellationProblem | null {
  if (stars.length < MIN_LOOM_STARS) return 'too_few_stars';
  if (stars.length > MAX_LOOM_STARS) return 'too_many_stars';
  const inSky = (v: unknown): v is number => typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1;
  for (const s of stars) {
    if (s.length !== 2 || !inSky(s[0]) || !inSky(s[1])) return 'star_outside_sky';
  }
  const pts = stars as readonly (readonly [number, number])[];
  for (let i = 0; i < pts.length; i++) {
    for (let j = i + 1; j < pts.length; j++) {
      if (Math.hypot(pts[i][0] - pts[j][0], pts[i][1] - pts[j][1]) < MIN_LOOM_STAR_GAP - 1e-9) return 'stars_too_close';
    }
  }
  if (links.length > MAX_LOOM_LINKS) return 'too_many_links';
  const isIndex = (n: unknown): n is number => typeof n === 'number' && Number.isInteger(n) && n >= 0 && n < pts.length;
  const seen = new Set<string>();
  let duplicate = false;
  for (const l of links) {
    if (l.length !== 2 || !isIndex(l[0]) || !isIndex(l[1]) || l[0] === l[1]) return 'bad_link';
    const key = l[0] < l[1] ? `${l[0]}-${l[1]}` : `${l[1]}-${l[0]}`;
    if (seen.has(key)) duplicate = true;
    seen.add(key);
  }
  if (duplicate) return 'duplicate_link';
  if (meaning !== null && !(CONSTELLATION_MEANINGS as readonly string[]).includes(meaning)) return 'unknown_meaning';
  return null;
}
