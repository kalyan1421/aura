/** Display helpers: SLA wording (text carries the state, not only colour), durations, IST times. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { DELETION_STATUS_LABEL, REASON_LABEL, VERDICT_LABEL, durationText, ist, label, LANE_LABEL, queueSessionText, refusalLines, shortHash, slaText } from '../src/lib/format.ts';

const NOW = Date.parse('2026-10-12T21:30:00.000Z');
const at = (min: number): string => new Date(NOW + min * 60_000).toISOString();

test('durations', () => {
  assert.equal(durationText(0), '0 min');
  assert.equal(durationText(45), '45 min');
  assert.equal(durationText(125), '2 h 5 min');
  assert.equal(durationText(180), '3 h');
  assert.equal(durationText(3 * 1440 + 4 * 60), '3 d 4 h');
  assert.equal(durationText(-30), '30 min');
});

test('SLA text and state', () => {
  assert.deepEqual(slaText(at(178), NOW), { text: '2 h 58 min left', state: 'ok' });
  assert.deepEqual(slaText(at(30), NOW), { text: '30 min left', state: 'soon' });
  assert.deepEqual(slaText(at(-12), NOW), { text: 'overdue by 12 min', state: 'overdue' });
  assert.deepEqual(slaText(at(-12), NOW, true), { text: 'closed', state: 'closed' });
});

test('IST formatting and fallbacks', () => {
  assert.match(ist('2026-10-12T21:30:00.000Z'), /13 Oct.*3:00\s?am IST/i);
  assert.equal(ist(null), '—');
  assert.equal(ist('not a date'), '—');
});

test('labels and hashes', () => {
  assert.equal(label(LANE_LABEL, 'minors_grooming'), 'L1 Minors & grooming');
  assert.equal(label(LANE_LABEL, 'new_lane'), 'new lane');
  assert.equal(shortHash('0123456789abcdef0123'), '0123456789ab');
  assert.equal(shortHash(null), '—');
});

test('report reason 9 keeps its label (targeting a young person)', () => {
  assert.equal(label(REASON_LABEL, 'targeting_minor'), 'Targeting a young person');
});

test('queue session and deletion case wording', () => {
  assert.equal(queueSessionText(null), null);
  assert.equal(queueSessionText({ active: false, capped: false, minutesLeft: 120, breakUntil: null }), null);
  assert.equal(queueSessionText({ active: true, capped: false, minutesLeft: 75, breakUntil: null }), '1 h 15 min left in this queue session');
  assert.match(queueSessionText({ active: true, capped: true, minutesLeft: 0, breakUntil: '2026-10-12T16:10:00.000Z' }) ?? '', /limit reached .* 9:40\s?pm IST/i);
  assert.equal(label(DELETION_STATUS_LABEL, 'awaiting_verification'), 'Waiting for the account holder');
});

test('lexicon refusals become short lines; verdicts say what the app shows', () => {
  assert.deepEqual(refusalLines(['entries[3]: phrase is empty']), ['entries[3]: phrase is empty']);
  assert.deepEqual(refusalLines([{ index: 2, expected: 'crisis', actual: 'none', source: 'version', why: undefined }]), [
    'index: 2 · expected: crisis · actual: none · source: version',
  ]);
  assert.deepEqual(refusalLines(undefined), []);
  assert.deepEqual(refusalLines({ not: 'a list' }), []);
  const many = refusalLines(Array.from({ length: 40 }, (_, i) => `p${i}`), 30);
  assert.equal(many.length, 31);
  assert.equal(many[30], '…and 10 more');
  assert.match(label(VERDICT_LABEL, 'crisis'), /support sheet/);
});
