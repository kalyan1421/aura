import { test } from 'node:test';
import assert from 'node:assert/strict';
import { csp, formActionSources } from '../src/lib/csp.ts';

test('form-action allows the Google sign-in redirect chain and nothing else', () => {
  const p = csp('bm9uY2U=', 'https://abc.supabase.co/');
  assert.match(p, /form-action 'self' https:\/\/abc\.supabase\.co https:\/\/accounts\.google\.com(;|$)/);
  assert.match(p, /frame-ancestors 'none'/);
  assert.equal(formActionSources(null), "'self' https://accounts.google.com");
  assert.equal(formActionSources('not a url'), "'self' https://accounts.google.com");
});
