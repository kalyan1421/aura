import { BASELINE_LEXICON, CONTRACT_VECTORS } from './lexicon-contract.data';
import { CrisisLexiconMatcher, LEXICON_VERDICTS, type LexiconVerdict, type MatcherEntry } from './matcher';

/**
 * A crisis lexicon version in the contracts/safety schema (`crisis_lexicon.v1.json`), its validation — the same rules
 * as apps/mobile/tool/gen_lexicon.py and the app's check of a downloaded bundle — and the vector run every version must
 * pass before NestJS signs it. Error messages name the entry id and the rule, never user text.
 */
export const LEXICON_NAME = 'aura.crisis_lexicon';

/** Language → script, exactly the five the contract declares (Hindi and Hinglish may be empty). */
export const LEXICON_LANGUAGES: Readonly<Record<string, 'Latin' | 'Telugu' | 'Devanagari'>> = {
  en: 'Latin',
  te: 'Telugu',
  'te-Latn': 'Latin',
  hi: 'Devanagari',
  'hi-Latn': 'Latin',
};

/** The languages the app ships at alpha: each must keep at least one crisis entry in every published version. */
export const SHIPPED_LANGUAGES = ['en', 'te', 'te-Latn'] as const;

const SCRIPT_RANGES = { Telugu: [0x0c00, 0x0c7f], Devanagari: [0x0900, 0x097f] } as const;
const LATIN_FORM = /^[A-Za-z0-9 '’-]+$/;

export interface LexiconEntry {
  id: string;
  language: string;
  kind: 'crisis' | 'soft';
  phrase: string;
  variants?: string[];
  stem?: boolean;
}

/** The whole document: `name`, `version`, `languages`, `entries` are required; the rest (review notes…) is kept as is. */
export interface LexiconDocument {
  name: string;
  version: number;
  languages: Record<string, unknown>;
  entries: LexiconEntry[];
  [key: string]: unknown;
}

export interface LexiconVector {
  text: string;
  verdict: LexiconVerdict;
  why?: string;
}

export class LexiconInvalidError extends Error {
  constructor(readonly problems: string[]) {
    super(`lexicon is invalid: ${problems[0] ?? 'unknown problem'}`);
    this.name = 'LexiconInvalidError';
  }
}

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

export function formsOf(e: LexiconEntry): string[] {
  return [e.phrase, ...(e.variants ?? [])];
}

/** Every problem found (empty = valid). The same rules as gen_lexicon.py `validate()`. */
export function lexiconProblems(doc: unknown): string[] {
  const problems: string[] = [];
  if (!isObject(doc)) return ['the lexicon must be a JSON object'];
  if (doc.name !== LEXICON_NAME) problems.push(`name must be '${LEXICON_NAME}'`);
  const version = doc.version;
  if (typeof version !== 'number' || !Number.isInteger(version) || version < 1 || version > 1_000_000) {
    problems.push('version must be a positive integer');
  }
  const declared = isObject(doc.languages) ? Object.keys(doc.languages).sort() : [];
  const expected = Object.keys(LEXICON_LANGUAGES).sort();
  if (declared.join(',') !== expected.join(',')) problems.push(`languages must be exactly ${expected.join(', ')}`);
  const entries = doc.entries;
  if (!Array.isArray(entries) || entries.length === 0) {
    problems.push('entries must be a non-empty list');
    return problems;
  }
  if (entries.length > 5000) problems.push('at most 5000 entries');
  const seen = new Set<string>();
  for (const [i, raw] of entries.entries()) {
    if (!isObject(raw)) {
      problems.push(`entry #${i}: must be an object`);
      continue;
    }
    const id = raw.id;
    const where = typeof id === 'string' ? `entry '${id.slice(0, 80)}'` : `entry #${i}`;
    if (typeof id !== 'string' || seen.has(id)) {
      problems.push(`${where}: missing or duplicate id`);
      continue;
    }
    seen.add(id);
    const lang = raw.language;
    if (typeof lang !== 'string' || !(lang in LEXICON_LANGUAGES)) {
      problems.push(`${where}: unknown language`);
      continue;
    }
    const escaped = lang.replace(/[.*+?^${}()|[\]\\-]/g, '\\$&');
    if (!new RegExp(`^${escaped}\\.[a-z0-9_]+$`).test(id)) problems.push(`${where}: id must be '<language>.<snake_case>'`);
    if (raw.kind !== 'crisis' && raw.kind !== 'soft') problems.push(`${where}: kind must be 'crisis' or 'soft'`);
    if (raw.stem !== undefined && typeof raw.stem !== 'boolean') problems.push(`${where}: stem must be true or false`);
    if (raw.variants !== undefined && !Array.isArray(raw.variants)) {
      problems.push(`${where}: variants must be a list`);
      continue;
    }
    const forms = [raw.phrase, ...((raw.variants as unknown[] | undefined) ?? [])];
    if (forms.some((f) => typeof f !== 'string')) {
      problems.push(`${where}: phrase and variants must be strings`);
      continue;
    }
    const strings = forms as string[];
    const normalized = strings.map((f) => f.normalize('NFC'));
    if (new Set(normalized).size !== normalized.length) problems.push(`${where}: a variant repeats`);
    const script = LEXICON_LANGUAGES[lang];
    for (const form of strings) {
      if (form.trim().length === 0) {
        problems.push(`${where}: empty phrase or variant`);
      } else if (form.length > 200) {
        problems.push(`${where}: a form is longer than 200 characters`);
      } else if (script === 'Latin') {
        if (!LATIN_FORM.test(form)) problems.push(`${where}: a form is not plain Latin script`);
      } else {
        const [lo, hi] = SCRIPT_RANGES[script];
        const ok = [...form.normalize('NFC')]
          .filter((c) => !/\s/.test(c))
          .every((c) => {
            const cp = c.codePointAt(0) as number;
            return (cp >= lo && cp <= hi) || cp === 0x200c || cp === 0x200d;
          });
        if (!ok) problems.push(`${where}: a form is not ${script} script`);
      }
    }
  }
  return problems;
}

/** The validated document (throws LexiconInvalidError listing every problem). */
export function parseLexicon(doc: unknown): LexiconDocument {
  const problems = lexiconProblems(doc);
  if (problems.length) throw new LexiconInvalidError(problems);
  return doc as LexiconDocument;
}

export function matcherFor(doc: LexiconDocument): CrisisLexiconMatcher {
  const entries: MatcherEntry[] = doc.entries.map((e) => ({ kind: e.kind, stem: e.stem === true, forms: formsOf(e) }));
  return new CrisisLexiconMatcher(entries);
}

/** Vectors in the contract shape; anything else is refused (a version's own test cases use the same shape). */
export function parseVectors(raw: unknown): LexiconVector[] {
  if (!Array.isArray(raw)) throw new LexiconInvalidError(['vectors must be a list']);
  if (raw.length > 2000) throw new LexiconInvalidError(['at most 2000 vectors']);
  return raw.map((v, i) => {
    if (!isObject(v) || typeof v.text !== 'string' || !LEXICON_VERDICTS.includes(v.verdict as LexiconVerdict)) {
      throw new LexiconInvalidError([`vector #${i}: needs text and a verdict (none, soft or crisis)`]);
    }
    if (v.text.length > 2000) throw new LexiconInvalidError([`vector #${i}: text is longer than 2000 characters`]);
    return { text: v.text, verdict: v.verdict as LexiconVerdict, ...(typeof v.why === 'string' ? { why: v.why.slice(0, 200) } : {}) };
  });
}

export interface VectorFailure {
  index: number;
  expected: LexiconVerdict;
  actual: LexiconVerdict;
  why?: string;
}

/** The vectors this matcher gets wrong (empty = all pass). Failures carry indexes and verdicts, never the text. */
export function failingVectors(matcher: CrisisLexiconMatcher, vectors: readonly LexiconVector[]): VectorFailure[] {
  const out: VectorFailure[] = [];
  vectors.forEach((v, index) => {
    const actual = matcher.verdict(v.text);
    if (actual !== v.verdict) out.push({ index, expected: v.verdict, actual, ...(v.why ? { why: v.why } : {}) });
  });
  return out;
}

/** The bundled baseline (contracts/safety/crisis_lexicon.v1.json, generated copy). */
export function baselineLexicon(): LexiconDocument {
  return parseLexicon(structuredClone(BASELINE_LEXICON));
}

/** contracts/safety/crisis_lexicon.vectors.json `cases` (generated copy). */
export function contractVectors(): LexiconVector[] {
  const doc = CONTRACT_VECTORS as { cases?: unknown };
  return parseVectors(doc.cases);
}

/** Crisis forms (normalized) of a document, for "removes crisis terms" checks at publish. */
export function crisisForms(doc: LexiconDocument): Set<string> {
  const out = new Set<string>();
  for (const e of doc.entries) {
    if (e.kind !== 'crisis') continue;
    for (const f of formsOf(e)) out.add(`${e.language}\u0000${f.normalize('NFC').toLowerCase()}`);
  }
  return out;
}

/** Languages among SHIPPED_LANGUAGES without a single crisis entry. */
export function languagesWithoutCrisis(doc: LexiconDocument): string[] {
  return SHIPPED_LANGUAGES.filter((l) => !doc.entries.some((e) => e.language === l && e.kind === 'crisis'));
}
