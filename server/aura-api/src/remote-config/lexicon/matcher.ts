import { normalizeForLexicon } from './normalize';

/**
 * The crisis lexicon matcher (PRD F9 "L1"; contracts/safety/README.md "Matching"), a line-by-line port of the app's
 * `CrisisLexicon` (apps/mobile/lib/src/features/support/crisis_lexicon.dart). Both must return the verdict of every
 * case in contracts/safety/crisis_lexicon.vectors.json. NestJS uses it to check a lexicon version before it is signed
 * and published (and, from Milestone B, on reflections in the worker). Text is never logged.
 */
export type LexiconVerdict = 'none' | 'soft' | 'crisis';
export const LEXICON_VERDICTS: readonly LexiconVerdict[] = ['none', 'soft', 'crisis'];

/** One entry as the matcher needs it: `forms` is the phrase, then its variants. */
export interface MatcherEntry {
  kind: 'crisis' | 'soft';
  stem: boolean;
  forms: readonly string[];
}

interface Form {
  words: string[];
  soft: boolean;
  /** The last word may carry suffixes (agglutinative romanized stems). */
  stem: boolean;
}

interface Hit {
  /** UTF-16 offsets in the normalized text (the same unit as Dart string indices). */
  start: number;
  end: number;
  soft: boolean;
}

const ASCII = /^[\x00-\x7f]*$/;
const WORD = /[a-z0-9]+/g;
const CLAUSE_BREAK = /[.!?;:।॥\n]/;
const HAS_DIGIT = /[0-9]/;
const HAS_LETTER = /[a-z]/;
const DIGIT_LETTERS: Readonly<Record<string, string>> = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't' };

/** Inside a word that mixes letters and digits, digits read as the letters they stand in for (`k1ll` → `kill`). */
function readDigits(word: string): string {
  if (!HAS_DIGIT.test(word) || !HAS_LETTER.test(word)) return word;
  return word.replace(/[0-9]/g, (d) => DIGIT_LETTERS[d] ?? d);
}

function words(text: string): Array<{ value: string; start: number; end: number }> {
  return [...text.matchAll(WORD)].map((m) => ({ value: readDigits(m[0]), start: m.index ?? 0, end: (m.index ?? 0) + m[0].length }));
}

export class CrisisLexiconMatcher {
  /** Word forms by their first word (the whole form when not a one-word stem). */
  private readonly byFirstWord = new Map<string, Form[]>();
  /** One-word stems, matched as a prefix of any word. */
  private readonly oneWordStems: Form[] = [];
  /** Forms in other scripts (Telugu, later Devanagari), matched as substrings. */
  private readonly scriptForms: Array<{ text: string; soft: boolean }> = [];

  constructor(entries: readonly MatcherEntry[]) {
    for (const e of entries) {
      const soft = e.kind === 'soft';
      for (const form of e.forms) {
        const n = normalizeForLexicon(form).replace(/\n/g, ' ');
        if (n.length === 0) continue;
        if (!ASCII.test(n)) {
          this.scriptForms.push({ text: n, soft });
          continue;
        }
        const ws = words(n).map((w) => w.value);
        if (ws.length === 0) continue;
        this.index(ws, soft, e.stem);
        // Written as one word ("wanttodie", "killmyself").
        if (ws.length > 1) this.index([ws.join('')], soft, e.stem);
      }
    }
  }

  private index(ws: string[], soft: boolean, stem: boolean): void {
    const form: Form = { words: ws, soft, stem };
    if (stem && ws.length === 1) {
      this.oneWordStems.push(form);
    } else {
      const list = this.byFirstWord.get(ws[0]);
      if (list) list.push(form);
      else this.byFirstWord.set(ws[0], [form]);
    }
  }

  verdict(text: string): LexiconVerdict {
    const normalized = normalizeForLexicon(text);
    if (normalized.length === 0) return 'none';
    const hits = [...this.wordHits(normalized), ...this.scriptHits(normalized)];
    const soft = hits.filter((h) => h.soft);
    const crisis = hits.some((c) => !c.soft && !soft.some((s) => s.start < c.end && c.start < s.end));
    if (crisis) return 'crisis';
    return soft.length === 0 ? 'none' : 'soft';
  }

  private wordHits(normalized: string): Hit[] {
    const ws = words(normalized);
    const out: Hit[] = [];
    if (ws.length === 0) return out;
    // Whether a clause ends between word i and word i + 1.
    const breakAfter = (i: number): boolean => CLAUSE_BREAK.test(normalized.substring(ws[i].end, ws[i + 1].start));

    for (let i = 0; i < ws.length; i++) {
      for (const form of this.byFirstWord.get(ws[i].value) ?? []) {
        const n = form.words.length;
        if (i + n > ws.length) continue;
        let matches = true;
        for (let k = 1; k < n && matches; k++) {
          const want = form.words[k];
          const have = ws[i + k].value;
          matches = form.stem && k === n - 1 ? have.startsWith(want) : have === want;
        }
        if (!matches) continue;
        // An idiom never spans a clause break (it would explain away the crisis words of another sentence).
        if (form.soft) {
          let crossesClause = false;
          for (let k = i; k < i + n - 1; k++) crossesClause = crossesClause || breakAfter(k);
          if (crossesClause) continue;
        }
        out.push({ start: ws[i].start, end: ws[i + n - 1].end, soft: form.soft });
      }
      for (const form of this.oneWordStems) {
        if (ws[i].value.startsWith(form.words[0])) out.push({ start: ws[i].start, end: ws[i].end, soft: form.soft });
      }
    }
    return out;
  }

  private scriptHits(normalized: string): Hit[] {
    // Line breaks read as spaces here; offsets stay the same.
    const flat = normalized.replace(/\n/g, ' ');
    const out: Hit[] = [];
    for (const form of this.scriptForms) {
      for (let at = flat.indexOf(form.text); at >= 0; at = flat.indexOf(form.text, at + 1)) {
        const end = at + form.text.length;
        if (form.soft && normalized.substring(at, end).includes('\n')) continue;
        out.push({ start: at, end, soft: form.soft });
      }
    }
    return out;
  }
}
