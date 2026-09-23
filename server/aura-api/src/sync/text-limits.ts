/**
 * User-facing text limits are counted in **characters as people see them** — extended grapheme clusters,
 * the unit the app counts with Dart `characters` — never UTF-16 units, so a Telugu or emoji text the app
 * accepts is never rejected here. (Node's ICU follows Unicode ≥ 15.1, which joins Indic conjuncts into one
 * cluster, so it never counts *more* characters than the app does.)
 */
const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });

export function graphemeCount(s: string): number {
  let n = 0;
  for (const _ of segmenter.segment(s)) n++;
  return n;
}

/**
 * Safety cap in UTF-16 units per allowed character. Real characters stay far below it (the longest emoji
 * ZWJ sequences are ~19 units, Telugu conjunct clusters ~7), but one "character" can otherwise carry an
 * unbounded run of combining marks.
 */
export const MAX_UTF16_UNITS_PER_CHAR = 16;

/** `s` has at most `maxChars` grapheme clusters (and at most `maxChars × 16` UTF-16 units). */
export function fitsChars(s: string, maxChars: number): boolean {
  if (s.length <= maxChars) return true; // never more clusters than code units
  if (s.length > maxChars * MAX_UTF16_UNITS_PER_CHAR) return false;
  return graphemeCount(s) <= maxChars;
}
