/** Sealed cookies: round trip, tamper detection, wrong key, foreign formats, purpose binding. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { seal, unseal } from '../src/lib/seal.ts';

const SECRET = 'a'.repeat(48);

test('round trip', async () => {
  const value = { v: 1, stage: 'aal2', at: 'token', started: 123 };
  const sealed = await seal(value, SECRET, 'session');
  assert.match(sealed, /^v2\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  assert.deepEqual(await unseal(sealed, SECRET, 'session'), value);
});

test('fresh IV each time: the same value never seals the same', async () => {
  assert.notEqual(await seal({ a: 1 }, SECRET, 'session'), await seal({ a: 1 }, SECRET, 'session'));
});

test('tampered, truncated, wrong-key and foreign values open to null', async () => {
  const sealed = await seal({ stage: 'aal2' }, SECRET, 'session');
  const [v, iv, ct] = sealed.split('.');
  const flipped = `${v}.${iv}.${ct.slice(0, -2)}${ct.slice(-2) === 'AA' ? 'AB' : 'AA'}`;
  assert.equal(await unseal(flipped, SECRET, 'session'), null);
  assert.equal(await unseal(`${v}.${iv}`, SECRET, 'session'), null);
  assert.equal(await unseal(sealed, 'b'.repeat(48), 'session'), null);
  assert.equal(await unseal('eyJhbGciOi.not.ours', SECRET, 'session'), null);
  assert.equal(await unseal(undefined, SECRET, 'session'), null);
  assert.equal(await unseal('', SECRET, 'session'), null);
});

test('bound to its purpose: a PKCE cookie never opens as a session, nor the other way round (review §5.14)', async () => {
  const pkce = await seal({ verifier: 'v', state: 's' }, SECRET, 'pkce');
  assert.equal(await unseal(pkce, SECRET, 'session'), null);
  assert.deepEqual(await unseal(pkce, SECRET, 'pkce'), { verifier: 'v', state: 's' });
  const session = await seal({ stage: 'aal2' }, SECRET, 'session');
  assert.equal(await unseal(session, SECRET, 'pkce'), null);
});

test('v1 values (sealed before the purpose binding) no longer open: one fresh sign-in', async () => {
  const v2 = await seal({ stage: 'aal2' }, SECRET, 'session');
  assert.equal(await unseal(v2.replace(/^v2\./, 'v1.'), SECRET, 'session'), null);
});
