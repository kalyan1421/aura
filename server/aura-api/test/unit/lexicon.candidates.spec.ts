/**
 * contracts/safety/candidates/crisis_lexicon.hi.draft.json — candidate Hindi / Hinglish crisis terms for the native and
 * safe-messaging review (PRD 21 A9, REQ-SAFE-03). They are NOT active: this checks that (1) the draft is technically
 * ready to adopt (valid entries under the lexicon rules, its own cases pass with the real matcher, and the current
 * contract vectors still pass with it merged in), and (2) nothing of it has leaked into the signed baseline.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  baselineLexicon,
  contractVectors,
  failingVectors,
  lexiconProblems,
  matcherFor,
  parseVectors,
  type LexiconDocument,
  type LexiconEntry,
} from '../../src/remote-config/lexicon/document';

const DRAFT = resolve(__dirname, '..', '..', '..', '..', 'contracts', 'safety', 'candidates', 'crisis_lexicon.hi.draft.json');
const draft = JSON.parse(readFileSync(DRAFT, 'utf8')) as { status: string; entries: LexiconEntry[]; cases: unknown };

/** What the baseline would look like once the reviewed draft is adopted (test only). */
function merged(): LexiconDocument {
  const base = baselineLexicon();
  return {
    ...base,
    version: base.version + 1,
    languages: {
      ...base.languages,
      hi: { script: 'Devanagari', status: 'alpha' },
      'hi-Latn': { script: 'Latin', status: 'alpha' },
    },
    entries: [...base.entries, ...draft.entries],
  };
}

describe('Hindi / Hinglish crisis lexicon candidates (draft, not active)', () => {
  it('is marked as a draft and covers only hi and hi-Latn', () => {
    expect(draft.status).toMatch(/NOT ACTIVE/);
    expect(new Set(draft.entries.map((e) => e.language))).toEqual(new Set(['hi', 'hi-Latn']));
    expect(draft.entries.every((e) => e.id.startsWith(`${e.language}.`))).toBe(true);
  });

  it('is valid under the lexicon rules once merged (scripts, ids, kinds, forms)', () => {
    expect(lexiconProblems(merged())).toEqual([]);
  });

  it('its own cases pass with the real matcher, and every current contract vector still does', () => {
    const matcher = matcherFor(merged());
    expect(failingVectors(matcher, parseVectors(draft.cases))).toEqual([]);
    expect(failingVectors(matcher, contractVectors())).toEqual([]);
  });

  it('nothing of it is in the signed baseline; Hindi and Hinglish stay placeholders there', () => {
    const base = baselineLexicon();
    const ids = new Set(base.entries.map((e) => e.id));
    expect(draft.entries.filter((e) => ids.has(e.id))).toEqual([]);
    expect(base.entries.filter((e) => e.language === 'hi' || e.language === 'hi-Latn')).toEqual([]);
    expect((base.languages.hi as { status: string }).status).toBe('placeholder');
    expect((base.languages['hi-Latn'] as { status: string }).status).toBe('placeholder');
  });
});
