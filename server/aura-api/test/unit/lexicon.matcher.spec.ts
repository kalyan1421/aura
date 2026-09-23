/**
 * The TypeScript crisis lexicon matcher (src/remote-config/lexicon) against the shared contract: the generated copy is
 * in sync with contracts/safety, every contract vector passes (the same cases the app's Dart matcher passes), every
 * phrase and variant gets its entry's kind, and the normalization tricks behave like the app's.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  baselineLexicon,
  contractVectors,
  failingVectors,
  formsOf,
  lexiconProblems,
  matcherFor,
  parseVectors,
} from '../../src/remote-config/lexicon/document';
import { BASELINE_LEXICON, CONTRACT_VECTORS } from '../../src/remote-config/lexicon/lexicon-contract.data';
import { normalizeForLexicon } from '../../src/remote-config/lexicon/normalize';

const SAFETY = resolve(__dirname, '..', '..', '..', '..', 'contracts', 'safety');
const readJson = (name: string): unknown => JSON.parse(readFileSync(resolve(SAFETY, name), 'utf8'));

describe('generated contract copy (python3 apps/mobile/tool/gen_lexicon.py)', () => {
  it('matches contracts/safety/crisis_lexicon.v1.json and the vectors file', () => {
    expect(BASELINE_LEXICON).toEqual(readJson('crisis_lexicon.v1.json'));
    expect(CONTRACT_VECTORS).toEqual(readJson('crisis_lexicon.vectors.json'));
  });

  it('the baseline is a valid lexicon and the vectors are written for it', () => {
    expect(lexiconProblems(BASELINE_LEXICON)).toEqual([]);
    expect((CONTRACT_VECTORS as { lexicon_version: number }).lexicon_version).toBe(baselineLexicon().version);
  });
});

describe('contract vectors', () => {
  const matcher = matcherFor(baselineLexicon());
  const cases = contractVectors();

  it('has cases', () => expect(cases.length).toBeGreaterThan(40));

  it.each(cases.map((c, i) => [i, c.verdict, JSON.stringify(c.text), c.why ?? ''] as const))(
    '#%i %s: %s (%s)',
    (i) => {
      expect(matcher.verdict(cases[i].text)).toBe(cases[i].verdict);
    },
  );

  it('failingVectors reports none for the baseline', () => {
    expect(failingVectors(matcher, cases)).toEqual([]);
  });
});

describe('matcher', () => {
  const doc = baselineLexicon();
  const matcher = matcherFor(doc);

  it("every phrase and variant, on its own, gets its entry's kind", () => {
    for (const e of doc.entries) {
      for (const form of formsOf(e)) expect([e.id, matcher.verdict(form)]).toEqual([e.id, e.kind]);
    }
  });

  it.each([
    ['I want to kill myself', 'crisis'],
    ['I want to die of boredom', 'soft'],
    ['I want to diet before the wedding', 'none'],
    ['నాకు చచ్చిపోవాలని ఉంది', 'crisis'],
    ['navvi navvi chachipoya', 'soft'],
    ['achachipotha', 'none'],
    ["I don't want to kill myself", 'crisis'],
    ['SU\u0130C\u0130DE', 'crisis'],
    ['I want to di\u0301e', 'crisis'],
    ['slept 4 hours, 7 tasks, 0 energy', 'none'],
    ['', 'none'],
    ['   ', 'none'],
  ])('%j → %s', (text, verdict) => {
    expect(matcher.verdict(text)).toBe(verdict);
  });
});

describe('normalizeForLexicon (same as the app)', () => {
  it.each([
    ['  Crème\u200B  BRÛLÉE \t', 'creme brulee'],
    ['a \n\n b', 'a\nb'],
    ['can’t', 'cant'],
    ['క్\u200Dష', 'క్ష'],
    ['\u0c46\u0c56', '\u0c48'], // Telugu ai: the decomposed sign composes
    ['\u0928\u093c', '\u0929'], // Devanagari nukta letter composes
    ['\u0915\u093c', '\u0915\u093c'], // a composition exclusion stays decomposed
    ['e\u0301', 'e'], // Latin marks are dropped, never composed
    ['\u0085x\u0085', 'x'], // Dart's trim set
  ])('%j → %j', (input, output) => {
    expect(normalizeForLexicon(input)).toBe(output);
  });

  it('canonical ordering before composing (nukta after virama)', () => {
    expect(normalizeForLexicon('\u0915\u094d\u093c')).toBe(normalizeForLexicon('\u0915\u093c\u094d'));
  });
});

describe('validation (gen_lexicon.py rules)', () => {
  const base = (): Record<string, unknown> => structuredClone(BASELINE_LEXICON) as Record<string, unknown>;
  const withEntry = (e: Record<string, unknown>): Record<string, unknown> => {
    const d = base();
    (d.entries as unknown[]).push(e);
    return d;
  };

  it.each([
    ['wrong name', { ...base(), name: 'x' }, 'name'],
    ['version 0', { ...base(), version: 0 }, 'version'],
    ['missing languages', { ...base(), languages: { en: {} } }, 'languages'],
    ['no entries', { ...base(), entries: [] }, 'entries'],
    ['duplicate id', withEntry({ id: 'en.kill_myself', language: 'en', kind: 'crisis', phrase: 'x' }), 'duplicate'],
    ['bad id', withEntry({ id: 'te.x', language: 'en', kind: 'crisis', phrase: 'x' }), 'id must be'],
    ['bad kind', withEntry({ id: 'en.x', language: 'en', kind: 'maybe', phrase: 'x' }), 'kind'],
    ['bad stem', withEntry({ id: 'en.x', language: 'en', kind: 'soft', phrase: 'x', stem: 'yes' }), 'stem'],
    ['repeated variant', withEntry({ id: 'en.x', language: 'en', kind: 'soft', phrase: 'x', variants: ['x'] }), 'repeats'],
    ['non-Latin form in en', withEntry({ id: 'en.x', language: 'en', kind: 'soft', phrase: 'చచ్చి' }), 'Latin'],
    ['Latin form in te', withEntry({ id: 'te.x', language: 'te', kind: 'soft', phrase: 'die' }), 'Telugu'],
    ['empty form', withEntry({ id: 'en.x', language: 'en', kind: 'soft', phrase: '  ' }), 'empty'],
  ])('%s is refused', (_, doc, fragment) => {
    const problems = lexiconProblems(doc);
    expect(problems.length).toBeGreaterThan(0);
    expect(problems.join(' | ')).toContain(fragment);
  });

  it('problems never echo the forms themselves', () => {
    const problems = lexiconProblems(withEntry({ id: 'en.secret_form', language: 'en', kind: 'crisis', phrase: 'ಕನ್ನಡ' }));
    expect(problems.join(' ')).not.toContain('ಕನ್ನಡ');
  });

  it('vectors must have text and a known verdict', () => {
    expect(() => parseVectors([{ text: 'x', verdict: 'maybe' }])).toThrow();
    expect(() => parseVectors({})).toThrow();
    expect(parseVectors([{ text: 'x', verdict: 'none', why: 'y' }])).toEqual([{ text: 'x', verdict: 'none', why: 'y' }]);
  });
});
