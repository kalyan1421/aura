/** Display helpers: SLA wording (text carries the state, not only colour), durations, IST times. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { durationText, ist, label, LANE_LABEL, shortHash, slaText } from '../src/lib/format.ts';

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
