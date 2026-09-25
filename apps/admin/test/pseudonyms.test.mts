/** Room pseudonym blocklist form (PRD 19 Configuration): only name-shaped input reaches the API. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isPseudonymShaped } from '../src/lib/pseudonyms.ts';

test('two words of letters', () => {
  assert.equal(isPseudonymShaped('Quiet Comet'), true);
  assert.equal(isPseudonymShaped('  quiet   comet '), true);
});

test('never digits, handles, one word or three', () => {
  assert.equal(isPseudonymShaped('Quiet'), false);
  assert.equal(isPseudonymShaped('Quiet Comet Nova'), false);
  assert.equal(isPseudonymShaped('call 98765'), false);
  assert.equal(isPseudonymShaped('@quiet comet'), false);
});
