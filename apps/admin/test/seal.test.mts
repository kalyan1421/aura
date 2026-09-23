/** Sealed session cookies: round trip, tamper detection, wrong key, foreign formats. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { seal, unseal } from '../src/lib/seal.ts';

const SECRET = 'a'.repeat(48);

test('round trip', async () => {
  const value = { v: 1, stage: 'aal2', at: 'token', started: 123 };
  const sealed = await seal(value, SECRET);
  assert.match(sealed, /^v1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  assert.deepEqual(await unseal(sealed, SECRET), value);
});

test('fresh IV each time: the same value never seals the same', async () => {
  assert.notEqual(await seal({ a: 1 }, SECRET), await seal({ a: 1 }, SECRET));
});

test('tampered, truncated, wrong-key and foreign values open to null', async () => {
  const sealed = await seal({ stage: 'aal2' }, SECRET);
  const [v, iv, ct] = sealed.split('.');
  const flipped = `${v}.${iv}.${ct.slice(0, -2)}${ct.slice(-2) === 'AA' ? 'AB' : 'AA'}`;
  assert.equal(await unseal(flipped, SECRET), null);
  assert.equal(await unseal(`${v}.${iv}`, SECRET), null);
  assert.equal(await unseal(sealed, 'b'.repeat(48)), null);
  assert.equal(await unseal('eyJhbGciOi.not.ours', SECRET), null);
  assert.equal(await unseal(undefined, SECRET), null);
  assert.equal(await unseal('', SECRET), null);
});
