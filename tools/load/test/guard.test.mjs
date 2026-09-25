// node --test tools/load/test/ — the target guard must never let a non-local / production target through by accident.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { assertRunId, assertSafeTargets, emailFor, GuardError, hostOf } from '../lib/guard.js';

const local = { supabaseUrl: 'http://127.0.0.1:55521', apiUrl: 'http://localhost:3323', dbUrl: 'postgresql://postgres:postgres@127.0.0.1:55522/postgres' };

test('local targets pass', () => {
  assert.equal(assertSafeTargets(local).mode, 'local');
  assert.equal(assertSafeTargets({ apiUrl: 'http://[::1]:3323' }).mode, 'local');
});

test('hosts are parsed from http, ws and postgres URLs (credentials ignored)', () => {
  assert.equal(hostOf('postgresql://u:p@db.example.com:5432/x'), 'db.example.com');
  assert.equal(hostOf('wss://abc.supabase.co/realtime/v1'), 'abc.supabase.co');
  assert.throws(() => hostOf('not a url'), GuardError);
});

test('any remote target is refused without --staging', () => {
  assert.throws(() => assertSafeTargets({ ...local, apiUrl: 'https://api-staging.example.com' }), /non-local/);
  assert.throws(() => assertSafeTargets({ ...local, dbUrl: 'postgresql://u:p@10.0.0.5/db' }), /non-local/);
});

test('staging needs a non-production marker and the exact host ack', () => {
  const t = { supabaseUrl: 'https://abcd.supabase.co', apiUrl: 'https://api-staging.example.com', staging: true };
  assert.throws(() => assertSafeTargets(t), /AURA_LOAD_STAGING_ACK/);
  assert.throws(() => assertSafeTargets({ ...t, stagingAck: 'api-staging.example.com' }), /AURA_LOAD_STAGING_SUPABASE_HOST/);
  const ok = assertSafeTargets({ ...t, stagingAck: 'api-staging.example.com', stagingSupabaseHosts: 'abcd.supabase.co' });
  assert.equal(ok.mode, 'staging');
  assert.throws(() => assertSafeTargets({ ...t, apiUrl: 'https://api.example.com', stagingAck: 'api.example.com' }), /non-production marker/);
});

test('production is refused even with every opt-in', () => {
  const t = { staging: true, stagingAck: 'api.prod.example.com', stagingSupabaseHosts: 'abcd.supabase.co' };
  assert.throws(() => assertSafeTargets({ ...t, apiUrl: 'https://api.prod.example.com' }), /PRODUCTION/);
  assert.throws(() => assertSafeTargets({ ...t, apiUrl: 'https://production-api.example.com' }), /PRODUCTION/);
  assert.throws(
    () => assertSafeTargets({ apiUrl: 'https://api-staging.example.com', supabaseUrl: 'https://zzzz.supabase.co', staging: true, stagingAck: 'api-staging.example.com', stagingSupabaseHosts: 'zzzz.supabase.co', prodHosts: 'zzzz.supabase.co' }),
    /PRODUCTION/,
  );
});

test('run ids and emails are strict', () => {
  assert.equal(assertRunId('r09241830ab1'), 'r09241830ab1');
  assert.throws(() => assertRunId('r%'), GuardError);
  assert.throws(() => assertRunId("x'; drop"), GuardError);
  assert.equal(emailFor('abcd', 7), 'load-abcd-7@aura.test');
});
