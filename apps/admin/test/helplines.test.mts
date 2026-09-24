/** Helpline directory pages: history labels and how a refused publish reads (numbers that would disappear). */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { HELPLINES_ACTION_LABEL, label, refusalLines } from '../src/lib/format.ts';

test('history actions read as words', () => {
  assert.equal(label(HELPLINES_ACTION_LABEL, 'helplines_upload'), 'Stored');
  assert.equal(label(HELPLINES_ACTION_LABEL, 'helplines_publish'), 'Published');
  assert.equal(label(HELPLINES_ACTION_LABEL, 'helplines_rollback'), 'Rolled back');
});

test('a refusal lists schema problems line by line', () => {
  assert.deepEqual(refusalLines(['in.tele_manas: the digits of number must be exactly dial (what is shown is what is dialled)', 'US: every region the app bundles must stay listed (phones refuse a directory without it)']), [
    'in.tele_manas: the digits of number must be exactly dial (what is shown is what is dialled)',
    'US: every region the app bundles must stay listed (phones refuse a directory without it)',
  ]);
});
