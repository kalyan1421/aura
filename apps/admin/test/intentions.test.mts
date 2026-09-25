/** Tonight's intention list pages: form parsing, history lines and night labels (lib/intentions.ts). */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { INTENTION_ACTION_LABEL, addBodyFrom, historySubject, nightLabel, textField, textsFrom } from '../src/lib/intentions.ts';
import { label } from '../src/lib/format.ts';

const WORDS = {
  en: 'Put the phone in another room',
  te: 'ఫోన్ వేరే గదిలో పెడతాను',
  'te-Latn': 'Phone vere gadilo pedataanu',
  hi: 'फ़ोन दूसरे कमरे में',
  'hi-Latn': 'Phone doosre kamre mein',
} as const;

const form = (v: Record<string, string>) => (name: string) => v[name] ?? '';
const withWords = (extra: Record<string, string>, words: Partial<Record<keyof typeof WORDS, string>> = WORDS) => ({
  ...extra,
  ...Object.fromEntries(Object.entries(words).map(([l, t]) => [textField(l as keyof typeof WORDS), t])),
});

test('a new key comes with all five lines', () => {
  const r = addBodyFrom(form(withWords({ pool: 'te', key: 'phone_elsewhere', reasonCode: 'new_intention', enabled: 'yes' })));
  assert.deepEqual(r, { ok: true, body: { pool: 'te', key: 'phone_elsewhere', reasonCode: 'new_intention', enabled: true, texts: WORDS } });
});

test('an existing key can be added without lines (its words are reused), retired by default', () => {
  const r = addBodyFrom(form({ pool: 'hi', key: 'slow_breaths', reasonCode: 'add_to_pool', position: '70' }));
  assert.deepEqual(r, { ok: true, body: { pool: 'hi', key: 'slow_breaths', reasonCode: 'add_to_pool', enabled: false, position: 70 } });
});

test('half-filled words, bad keys, pools, reasons and positions are refused before the API', () => {
  const { hi: _hi, ...four } = WORDS;
  assert.deepEqual(addBodyFrom(form(withWords({ pool: 'en', key: 'abc', reasonCode: 'x' }, four))), {
    ok: false,
    message: 'Every language needs its line (missing: hi).',
  });
  assert.equal(addBodyFrom(form({ pool: 'xx', key: 'abc', reasonCode: 'x' })).ok, false);
  assert.equal(addBodyFrom(form({ pool: 'en', key: 'Bad Key', reasonCode: 'x' })).ok, false);
  assert.equal(addBodyFrom(form({ pool: 'en', key: 'abc', reasonCode: 'Not a code' })).ok, false);
  assert.equal(addBodyFrom(form({ pool: 'en', key: 'abc', reasonCode: 'x', position: '1.5' })).ok, false);
});

test('textsFrom trims and reports what is missing', () => {
  assert.deepEqual(textsFrom(form({})), { texts: null, missing: [] });
  const r = textsFrom(form({ [textField('en')]: '  Lights low  ' }));
  assert.equal(r.texts?.en, 'Lights low');
  assert.deepEqual(r.missing, ['te', 'te-Latn', 'hi', 'hi-Latn']);
});

test('history lines read as words', () => {
  assert.equal(label(INTENTION_ACTION_LABEL, 'intention_preset_retire'), 'Retired');
  assert.equal(label(INTENTION_ACTION_LABEL, 'intention_words_edit'), 'Reworded');
  assert.equal(historySubject({ key: 'slow_breaths', pool: 'hi' }), 'slow_breaths · hi');
  assert.equal(historySubject({ key: 'slow_breaths', changed: ['en', 'te'] }), 'slow_breaths (en, te)');
  assert.equal(historySubject({ key: 'slow_breaths', changed: [] }), 'slow_breaths (no change)');
});

test('nights read as a short date', () => {
  assert.equal(nightLabel('2026-09-24'), 'Thu 24 Sep');
  assert.equal(nightLabel('not-a-date'), 'not-a-date');
});
