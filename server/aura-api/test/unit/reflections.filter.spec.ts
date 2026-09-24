/**
 * F6 reflection text rules (src/reflections/filter) against the shared contract: the generated data copy is in sync
 * with contracts/safety/reflection_filter.v1.json, and every case of reflection_filter.vectors.json passes — the same
 * cases the app's Dart implementation passes (apps/mobile/test/reflections_filter_test.dart).
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { checkReflectionText, normalizeForFilter } from '../../src/reflections/filter/reflection-filter';
import { REFLECTION_FILTER_DATA } from '../../src/reflections/filter/reflection-filter.data';

const SAFETY = resolve(__dirname, '..', '..', '..', '..', 'contracts', 'safety');
const readJson = (name: string): unknown => JSON.parse(readFileSync(resolve(SAFETY, name), 'utf8'));

interface Case {
  text: string;
  strict?: boolean;
  contact: 'none' | 'contact_details' | 'link';
  grooming: boolean;
  note?: string;
}

describe('reflection filter contract', () => {
  it('the generated data equals contracts/safety/reflection_filter.v1.json (node src/reflections/filter/gen-data.js)', () => {
    expect(REFLECTION_FILTER_DATA).toEqual(readJson('reflection_filter.v1.json'));
  });

  const vectors = readJson('reflection_filter.vectors.json') as { filterVersion: number; cases: Case[] };

  it('the vectors are written for this version and cover every rule family', () => {
    expect(vectors.filterVersion).toBe(REFLECTION_FILTER_DATA.version);
    expect(vectors.cases.length).toBeGreaterThan(50);
    const kinds = new Set(vectors.cases.map((c) => `${c.contact}/${c.grooming}`));
    for (const k of ['none/false', 'contact_details/false', 'link/false', 'none/true', 'contact_details/true']) expect(kinds).toContain(k);
  });

  it.each(vectors.cases.map((c) => [`${JSON.stringify(c.text)}${c.strict ? ' (strict)' : ''}`, c] as const))('%s', (_label, c) => {
    const r = checkReflectionText(c.text, { strict: c.strict === true });
    expect({ contact: r.contact, grooming: r.grooming }).toEqual({ contact: c.contact, grooming: c.grooming });
  });

  it('every phrase and variant of every entry matches on its own, in its own list', () => {
    for (const e of REFLECTION_FILTER_DATA.contactPhrases) {
      for (const f of [e.phrase, ...e.variants]) {
        const r = checkReflectionText(`well ${f} ok`);
        expect([f, r.contact]).toEqual([f, 'contact_details']);
        expect(r.hits).toContain(e.id);
      }
    }
    for (const e of REFLECTION_FILTER_DATA.groomingPhrases) {
      for (const f of [e.phrase, ...e.variants]) {
        const r = checkReflectionText(`well ${f} ok`);
        expect([f, r.grooming]).toEqual([f, true]);
        expect(r.hits).toContain(e.id);
      }
    }
  });

  it('seven number words in any of the five languages read as a phone number', () => {
    for (const [lang, words] of Object.entries(REFLECTION_FILTER_DATA.numberWords)) {
      const seven = Array.from({ length: 7 }, (_, i) => words[i % words.length]).join(' ');
      expect([lang, checkReflectionText(seven).contact]).toEqual([lang, 'contact_details']);
      const six = Array.from({ length: 6 }, (_, i) => words[i % words.length]).join(' ');
      expect([lang, checkReflectionText(six).contact, checkReflectionText(six, { strict: true }).contact]).toEqual([lang, 'none', 'contact_details']);
    }
  });

  it('hits are rule ids, never the matched words', () => {
    const r = checkReflectionText('my number is 98765 43210, insta: quiet.comet');
    expect(r.hits).toEqual(expect.arrayContaining(['phone_digits', 'app_handle', 'en.my_number']));
    for (const h of r.hits) expect(h).toMatch(/^[a-z_]+$|^[a-z]{2}(-Latn)?\.[a-z_]+$/);
  });

  it('normalizes like the crisis lexicon, plus Indic and fullwidth digits', () => {
    expect(normalizeForFilter('  Don’t  ９౮८ ')).toBe('dont 988');
  });
});
