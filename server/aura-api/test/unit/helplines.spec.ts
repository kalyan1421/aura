/**
 * The signed helpline directory (src/remote-config/helplines; contracts/safety/helplines.schema.json; PRD 18
 * "Helplines by country"): the generated baseline matches the contract file, the schema rules (what is shown is what
 * is dialled, a line for everyone in every region, the bundled regions stay), the resolution vectors the app
 * re-derives, the diff that gates removing numbers, and the committed dev-signed fixture (the app verifies the same
 * bytes, apps/mobile/test/remote_helplines_test.dart).
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  baselineHelplines,
  diffHelplines,
  helplinesProblems,
  parseHelplines,
  requiredCountries,
  resolutionVectors,
  type HelplinesDocument,
} from '../../src/remote-config/helplines/document';
import { BundleSigner, BundleVerifyError, canonicalJson, trustedKeys, verifyBundle } from '../../src/remote-config/signing';

const SAFETY = resolve(__dirname, '..', '..', '..', '..', 'contracts', 'safety');
const readJson = (name: string): unknown => JSON.parse(readFileSync(resolve(SAFETY, name), 'utf8'));
const DEV_KEYS = trustedKeys([BundleSigner.dev().publicKeyBase64]);

/** A copy of the baseline with `edit` applied (a version the console could upload). */
function edited(edit: (d: HelplinesDocument) => void, version = 2): HelplinesDocument {
  const d = baselineHelplines();
  d.version = version;
  edit(d);
  return d;
}

describe('helpline directory: baseline', () => {
  it('the generated server copy is contracts/safety/helplines.v1.json (run apps/mobile/tool/gen_helplines.py)', () => {
    expect(baselineHelplines()).toEqual(readJson('helplines.v1.json'));
  });

  it('is valid, and India + US are the regions every version must keep', () => {
    expect(helplinesProblems(readJson('helplines.v1.json'))).toEqual([]);
    expect(requiredCountries()).toEqual(['IN', 'US']);
  });

  it('resolves like the PRD (06c F9 / REQ-SAFE-02): IN 14416, 1-800-891-4416, 112 (+1098 under 18); US 988; else nothing', () => {
    expect(resolutionVectors(baselineHelplines())).toEqual([
      { country: 'IN', minor: false, dials: ['14416', '18008914416', '112'] },
      { country: 'IN', minor: true, dials: ['14416', '18008914416', '1098', '112'] },
      { country: 'US', minor: false, dials: ['988'] },
      { country: 'US', minor: true, dials: ['988'] },
      { country: 'ZZ', minor: false, dials: [] },
    ]);
  });
});

describe('helpline directory: schema rules', () => {
  const problemsOf = (edit: (d: HelplinesDocument) => void): string[] => helplinesProblems(edited(edit));

  it('a new region and a changed number are fine', () => {
    expect(
      problemsOf((d) => {
        d.countries.IN[0].number = '1-4416';
        d.countries.IN[0].dial = '14416';
        d.countries.GB = [{ id: 'gb.samaritans', number: '116 123', dial: '116123', audience: 'everyone', names: { en: 'Samaritans' } }];
      }),
    ).toEqual([]);
  });

  it.each<[string, (d: HelplinesDocument) => void, RegExp]>([
    ['shown ≠ dialled', (d) => (d.countries.IN[0].dial = '14417'), /digits of number must be exactly dial/],
    ['a letter in the dial string', (d) => (d.countries.US[0].dial = '98a'), /dial must be/],
    ['a bundled region dropped', (d) => delete d.countries.US, /US: every region the app bundles/],
    ['only a minors line', (d) => (d.countries.US[0].audience = 'minors'), /US: needs at least one line for everyone/],
    ['an unknown audience', (d) => ((d.countries.US[0] as { audience: string }).audience = 'adults'), /audience must be/],
    ['an id of another region', (d) => (d.countries.US[0].id = 'in.988'), /id must be 'us\./],
    ['a duplicate id', (d) => d.countries.IN.push({ ...d.countries.IN[0] }), /duplicate id/],
    ['no English name', (d) => ((d.countries.US[0].names as Record<string, string>) = { te: 'x' }), /names needs en/],
    ['an unknown locale', (d) => ((d.countries.US[0].names as Record<string, string>).fr = 'x'), /unknown locale/],
    ['a control character in a name', (d) => (d.countries.US[0].names.en = 'Life\nline'), /no control characters/],
    ['an empty region', (d) => (d.countries.GB = []), /GB: 1–10 lines/],
    ['a lower-case region', (d) => ((d.countries as Record<string, unknown>).gb = d.countries.US), /ISO 3166-1/],
    ['the wrong name', (d) => (d.name = 'aura.crisis_lexicon'), /name must be/],
  ])('refuses %s', (_what, edit, problem) => {
    const problems = problemsOf(edit);
    expect(problems.some((p) => problem.test(p))).toBe(true);
  });

  it('parseHelplines throws with the problems', () => {
    expect(() => parseHelplines({ name: 'aura.helplines', version: 0, countries: {} })).toThrow(/version must be a positive integer/);
  });
});

describe('helpline directory: diff (what publishing gates on)', () => {
  it('a changed number removes the old one from phones', () => {
    const d = diffHelplines(
      baselineHelplines(),
      edited((x) => {
        x.countries.US[0].number = '1-800-273-8255';
        x.countries.US[0].dial = '18002738255';
      }),
      1,
    );
    expect(d).toMatchObject({ from: 1, changed: ['us.988'], added: [], removed: [], countriesRemoved: [] });
    expect(d.numbersRemoved).toBeGreaterThan(0);
  });

  it('adding a line or a region removes nothing', () => {
    const d = diffHelplines(
      baselineHelplines(),
      edited((x) => {
        x.countries.GB = [{ id: 'gb.samaritans', number: '116 123', dial: '116123', audience: 'everyone', names: { en: 'Samaritans' } }];
      }),
      null,
    );
    expect(d).toMatchObject({ added: ['gb.samaritans'], numbersRemoved: 0, countriesRemoved: [] });
  });

  it('a renamed line is a change, not a removal', () => {
    const d = diffHelplines(baselineHelplines(), edited((x) => (x.countries.US[0].names.te = 'కొత్త పేరు')), 1);
    expect(d).toMatchObject({ changed: ['us.988'], numbersRemoved: 0 });
  });
});

describe('helpline directory: signed envelope', () => {
  const dev = BundleSigner.dev();

  it('the committed dev-signed fixture verifies as kind helplines, with the directory and its vectors', () => {
    const payload = verifyBundle(readJson('fixtures/helplines.v1.dev-signed.json'), DEV_KEYS, 'helplines');
    expect(payload.content).toEqual(baselineHelplines());
    expect(canonicalJson(payload.vectors)).toBe(canonicalJson(resolutionVectors(baselineHelplines())));
  });

  it('a helplines bundle is never accepted where a lexicon is expected, nor the other way round', () => {
    const b = dev.sign({ kind: 'helplines', seq: 5, issuedAt: 'x', version: 1, content: baselineHelplines(), vectors: [] });
    expect(() => verifyBundle(b, DEV_KEYS, 'crisis_lexicon')).toThrow(new BundleVerifyError('wrong_kind'));
    const lexicon = readJson('fixtures/crisis_lexicon.v1.dev-signed.json');
    expect(() => verifyBundle(lexicon, DEV_KEYS, 'helplines')).toThrow(new BundleVerifyError('wrong_kind'));
  });

  it('a directory with one number changed after signing fails the signature', () => {
    const b = dev.sign({ kind: 'helplines', seq: 5, issuedAt: 'x', version: 1, content: baselineHelplines(), vectors: [] });
    const json = JSON.parse(Buffer.from(b.payload, 'base64').toString('utf8')) as { content: HelplinesDocument };
    json.content.countries.IN[0].dial = '9999999999';
    json.content.countries.IN[0].number = '9999999999';
    const tampered = { ...b, payload: Buffer.from(canonicalJson(json), 'utf8').toString('base64') };
    expect(() => verifyBundle(tampered, DEV_KEYS, 'helplines')).toThrow(new BundleVerifyError('bad_signature'));
  });
});
