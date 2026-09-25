/** Same-origin check for route handlers (evidence export): opaque or malformed origins are refused, never a 500. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isSameOrigin } from '../src/lib/origin.ts';

test('same host → allowed; another host → refused', () => {
  assert.equal(isSameOrigin('https://console.aura.example', 'console.aura.example'), true);
  assert.equal(isSameOrigin('https://evil.example', 'console.aura.example'), false);
  assert.equal(isSameOrigin('http://localhost:3320', 'localhost:3320'), true);
});

test('missing, opaque (null) and malformed origins are refused without throwing', () => {
  assert.equal(isSameOrigin(null, 'console.aura.example'), false);
  assert.equal(isSameOrigin('null', 'console.aura.example'), false);
  assert.equal(isSameOrigin('not a url', 'console.aura.example'), false);
  assert.equal(isSameOrigin('https://console.aura.example', null), false);
});
