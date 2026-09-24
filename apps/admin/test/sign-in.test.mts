/** REQ-ADM-01 sign-in: SSO configuration, the development email code (off by default in production), PKCE. */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { test } from 'node:test';
import { authorizeUrl, challengeFor, newVerifier } from '../src/lib/pkce.ts';
import { signInModes } from '../src/lib/sign-in-modes.ts';

test('the email code is development only: on for NODE_ENV development / test, never in production, closed when unset', () => {
  assert.deepEqual(signInModes({ NODE_ENV: 'development' }), { sso: null, emailCode: true, production: false });
  assert.equal(signInModes({ NODE_ENV: 'test' }).emailCode, true);
  assert.deepEqual(signInModes({ NODE_ENV: 'production' }), { sso: null, emailCode: false, production: true });
  // SR-1 (docs/security/milestone-b-review.md): no override in production; unset / unknown NODE_ENV fails closed.
  assert.equal(signInModes({ NODE_ENV: 'production', ADMIN_ALLOW_EMAIL_LOGIN: 'true' }).emailCode, false);
  assert.equal(signInModes({}).emailCode, false);
  assert.equal(signInModes({ NODE_ENV: 'staging' }).emailCode, false);
  assert.equal(signInModes({ NODE_ENV: 'staging', ADMIN_ALLOW_EMAIL_LOGIN: 'true' }).emailCode, true);
  assert.equal(signInModes({ NODE_ENV: 'development', ADMIN_ALLOW_EMAIL_LOGIN: 'false' }).emailCode, false);
});

test('Google Workspace SSO with the hd hint; a malformed domain is dropped (the API enforces the domain anyway)', () => {
  assert.deepEqual(signInModes({ NODE_ENV: 'production', ADMIN_SSO_PROVIDER: 'Google', ADMIN_SSO_DOMAIN: 'AKVega.com' }).sso, {
    provider: 'google',
    domain: 'akvega.com',
  });
  assert.deepEqual(signInModes({ ADMIN_SSO_PROVIDER: 'google', ADMIN_SSO_DOMAIN: 'not a domain' }).sso, { provider: 'google', domain: null });
  assert.equal(signInModes({ ADMIN_SSO_PROVIDER: 'okta' }).sso, null);
});

test('PKCE: RFC 7636 verifier and S256 challenge', async () => {
  const v = newVerifier();
  assert.match(v, /^[A-Za-z0-9_-]{43,128}$/);
  assert.notEqual(newVerifier(), v);
  const expected = createHash('sha256').update(v).digest('base64url');
  assert.equal(await challengeFor(v), expected);
});

test('the authorize URL: Supabase Google provider, PKCE, callback, hd hint, account chooser — no personal data', async () => {
  const url = new URL(
    authorizeUrl({ supabaseUrl: 'https://proj.supabase.co', redirectTo: 'https://console.akvega.com/login/callback', challenge: 'abc', domain: 'akvega.com' }),
  );
  assert.equal(url.origin + url.pathname, 'https://proj.supabase.co/auth/v1/authorize');
  assert.equal(url.searchParams.get('provider'), 'google');
  assert.equal(url.searchParams.get('redirect_to'), 'https://console.akvega.com/login/callback');
  assert.equal(url.searchParams.get('code_challenge'), 'abc');
  assert.equal(url.searchParams.get('code_challenge_method'), 's256');
  assert.equal(url.searchParams.get('hd'), 'akvega.com');
  assert.equal(url.searchParams.get('prompt'), 'select_account');
  assert.equal([...url.searchParams.keys()].some((k) => /email|login_hint/.test(k)), false);
});
