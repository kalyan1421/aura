import { LEXICON_COMBINING_CLASSES, LEXICON_COMPOSITIONS, LEXICON_DECOMPOSITIONS } from './lexicon-contract.data';

/**
 * Text as the crisis lexicon compares it (contracts/safety/README.md "Matching", step 1) — the same steps, in the same
 * order and with the same Unicode tables as the app's `normalizeForLexicon` (apps/mobile, crisis_lexicon.dart), so both
 * sides give the same verdict for the same text:
 *   1. strip invisible format characters;
 *   2. NFC for Latin, Devanagari and Telugu only (the generated tables — never the engine's full `normalize('NFC')`,
 *      which would compose Latin letters and marks the app leaves apart and then drops);
 *   3. drop combining diacritics U+0300–U+036F, delete apostrophes, lower-case;
 *   4. collapse whitespace runs (a run with a line break becomes one line break) and trim.
 * Only for matching: never stored, never logged.
 */
export function normalizeForLexicon(text: string): string {
  const runes: number[] = [];
  for (const ch of text) {
    const cp = ch.codePointAt(0) as number;
    if (isInvisible(cp)) continue;
    const parts = LEXICON_DECOMPOSITIONS.get(cp);
    if (parts) runes.push(...parts);
    else runes.push(cp);
  }
  reorderMarks(runes);
  let folded = '';
  for (const cp of compose(runes)) {
    if (cp >= 0x0300 && cp <= 0x036f) continue; // díe → die
    if (APOSTROPHES.has(cp)) continue; // can't → cant
    folded += String.fromCodePoint(cp);
  }
  return trimLikeDart(folded.toLowerCase().replace(/\s+/g, (m) => (LINE_BREAK.test(m) ? '\n' : ' ')));
}

const LINE_BREAK = /[\n\r\u0085\u2028\u2029]/;

/** `'` `’` `‘` `ʼ` `` ` `` `´` */
const APOSTROPHES: ReadonlySet<number> = new Set([0x0027, 0x2019, 0x2018, 0x02bc, 0x0060, 0x00b4]);

/** Zero-width and other invisible format characters (README step 1.1). */
function isInvisible(cp: number): boolean {
  return (
    (cp >= 0x200b && cp <= 0x200f) ||
    (cp >= 0x202a && cp <= 0x202e) ||
    (cp >= 0x2060 && cp <= 0x2064) ||
    (cp >= 0x2066 && cp <= 0x2069) ||
    cp === 0xfeff ||
    cp === 0x00ad ||
    cp === 0x180e
  );
}

/** Dart's `String.trim()` set (Unicode White_Space + BOM), which unlike JS's also trims U+0085. */
const DART_TRIM = /^[\t\n\v\f\r \u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+|[\t\n\v\f\r \u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+$/g;

function trimLikeDart(s: string): string {
  return s.replace(DART_TRIM, '');
}

const classOf = (cp: number): number => LEXICON_COMBINING_CLASSES.get(cp) ?? 0;

/** Canonical ordering: a stable sort of each run of combining marks by combining class. */
function reorderMarks(runes: number[]): void {
  for (let i = 1; i < runes.length; i++) {
    const c = classOf(runes[i]);
    if (c === 0) continue;
    let j = i;
    while (j > 0) {
      const before = classOf(runes[j - 1]);
      if (before <= c) break;
      const t = runes[j - 1];
      runes[j - 1] = runes[j];
      runes[j] = t;
      j--;
    }
  }
}

/** Canonical composition over decomposed, ordered text (Devanagari and Telugu pairs only). */
function compose(runes: readonly number[]): number[] {
  const out: number[] = [];
  let starter = -1;
  let lastClass = 0;
  for (const cp of runes) {
    const c = classOf(cp);
    if (starter >= 0) {
      const adjacent = starter === out.length - 1;
      const composite = LEXICON_COMPOSITIONS.get(out[starter] * 0x200000 + cp);
      if (composite !== undefined && (adjacent || (lastClass !== 0 && lastClass < c))) {
        out[starter] = composite;
        continue;
      }
    }
    if (c === 0) starter = out.length;
    lastClass = c;
    out.push(cp);
  }
  return out;
}
