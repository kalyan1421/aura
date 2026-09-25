#!/usr/bin/env node
/**
 * Creates and onboards the synthetic users of one load run, then writes `<out>/users.json` for k6 (SharedArray).
 *
 * Every account is `load-<runid>-<n>@aura.test` (cleanup.sql matches exactly that pattern for the run id). Per user,
 * the same calls a real install makes before its first room (supabase/LOCAL.md + contracts/api/v1.md, v1-rooms.md):
 *   1. Auth admin API: create the user (service role, email confirmed)   POST /auth/v1/admin/users
 *   2. Password grant → a real GoTrue-issued ES256 access token          POST /auth/v1/token?grant_type=password
 *   3. Onboarding: profile (adult DOB, en, the run's timezone)           POST /v1/profile
 *   4. Community guidelines (REQ-SAFE-04) before any stranger surface     POST /v1/safety/guidelines/accept
 *   5. Echo opt-out, so no unlinked echo recording can outlive cleanup   PUT  /v1/ripples/echo-consent {enabled:false}
 *
 * Zero dependencies (Node ≥ 22 fetch). Never prints tokens or passwords; users.json is written 0600 under .runs/.
 *
 *   node provision.mjs --runid <id> --count 50 --out .runs/<id> [--concurrency 16] [--dry-run]
 *   env: SUPABASE_URL, API_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, LOAD_TZ (default Asia/Kolkata),
 *        AURA_LOAD_STAGING / AURA_LOAD_STAGING_ACK / AURA_LOAD_STAGING_SUPABASE_HOST / AURA_LOAD_PROD_HOSTS (lib/guard.js)
 */
import { randomBytes } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { assertRunId, assertSafeTargets, emailFor, redact } from './lib/guard.js';

const arg = (name, dflt) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > 0 && process.argv[i + 1] !== undefined && !process.argv[i + 1].startsWith('--') ? process.argv[i + 1] : dflt;
};
const flag = (name) => process.argv.includes(`--${name}`);

const runid = assertRunId(arg('runid', process.env.RUNID));
const count = Number(arg('count', process.env.COUNT ?? 50));
const outDir = arg('out', join('.runs', runid));
const concurrency = Number(arg('concurrency', process.env.PROVISION_CONCURRENCY ?? 16));
const dryRun = flag('dry-run');
const SUPABASE_URL = (process.env.SUPABASE_URL ?? 'http://127.0.0.1:55521').replace(/\/+$/, '');
const API_URL = (process.env.API_URL ?? 'http://127.0.0.1:3323').replace(/\/+$/, '');
const ANON = process.env.SUPABASE_ANON_KEY ?? '';
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';
const TZ = process.env.LOAD_TZ ?? 'Asia/Kolkata';

if (!Number.isInteger(count) || count < 1 || count > 5000) throw new Error('--count must be 1..5000');
const guard = assertSafeTargets({
  supabaseUrl: SUPABASE_URL,
  apiUrl: API_URL,
  staging: process.env.AURA_LOAD_STAGING === '1',
  stagingAck: process.env.AURA_LOAD_STAGING_ACK,
  stagingSupabaseHosts: process.env.AURA_LOAD_STAGING_SUPABASE_HOST,
  prodHosts: process.env.AURA_LOAD_PROD_HOSTS,
});

console.log(
  `provision: run ${runid} · ${count} users (${emailFor(runid, 0)} … ${emailFor(runid, count - 1)}) · ${guard.mode} · ` +
    `supabase ${redact(SUPABASE_URL)} · api ${redact(API_URL)} · tz ${TZ} · concurrency ${concurrency}`,
);
if (dryRun) {
  console.log(`provision: dry run — would make ${count * 5} requests (5 per user) and write ${join(outDir, 'users.json')}`);
  process.exit(0);
}
if (!ANON || !SERVICE) throw new Error('SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are required (run.sh reads them from `supabase status -o env`)');

// ------------------------------------------------------------------ timing
const timings = {};
async function timed(step, fn) {
  const t0 = performance.now();
  try {
    return await fn();
  } finally {
    (timings[step] ??= []).push(performance.now() - t0);
  }
}
const pct = (xs, p) => {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  return Math.round(s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))]);
};

async function json(res, what) {
  const text = await res.text();
  if (!res.ok) throw new Error(`${what}: HTTP ${res.status} ${text.slice(0, 200)}`);
  return text ? JSON.parse(text) : {};
}

const api = (token, method, path, body) =>
  fetch(`${API_URL}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

// ------------------------------------------------------------------ one user
async function provisionOne(n) {
  const email = emailFor(runid, n);
  const password = `load-${randomBytes(18).toString('base64url')}`;
  const created = await timed('auth_admin_create', () =>
    fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
      method: 'POST',
      headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { aura_load_run: runid } }),
    }).then((r) => json(r, `create ${email}`)),
  );
  const session = await timed('auth_password_grant', () =>
    fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { apikey: ANON, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    }).then((r) => json(r, `sign in ${email}`)),
  );
  const token = session.access_token;
  const year = 1980 + (n % 25); // adults only: under-18 accounts would get the (invisible) stricter paths
  await timed('POST /v1/profile', () =>
    api(token, 'POST', '/v1/profile', { birthDate: `${year}-0${1 + (n % 9)}-1${n % 10}`, uiLocale: 'en', timezone: TZ, country: 'IN' }).then((r) =>
      json(r, 'profile'),
    ),
  );
  await timed('POST /v1/safety/guidelines/accept', async () => {
    let r = await api(token, 'POST', '/v1/safety/guidelines/accept', { version: 1 });
    if (r.status === 409) {
      const b = await r.json();
      if (typeof b.version !== 'number') throw new Error(`guidelines: 409 without version`);
      r = await api(token, 'POST', '/v1/safety/guidelines/accept', { version: b.version });
    }
    return json(r, 'guidelines');
  });
  await timed('PUT /v1/ripples/echo-consent', () => api(token, 'PUT', '/v1/ripples/echo-consent', { enabled: false }).then((r) => json(r, 'echo consent')));
  return { n, id: created.id, email, token, expiresAt: Date.now() + (session.expires_in ?? 3600) * 1000 };
}

// ------------------------------------------------------------------ pool
const users = new Array(count);
let next = 0;
let failed = 0;
const errors = [];
const started = performance.now();
async function worker() {
  for (;;) {
    const n = next++;
    if (n >= count) return;
    try {
      users[n] = await provisionOne(n);
    } catch (e) {
      failed += 1;
      if (errors.length < 5) errors.push(String(e.message ?? e));
    }
    if ((n + 1) % 100 === 0) process.stdout.write(`provision: ${n + 1}/${count}\n`);
  }
}
await Promise.all(Array.from({ length: Math.min(concurrency, count) }, worker));
const elapsedS = (performance.now() - started) / 1000;

mkdirSync(outDir, { recursive: true, mode: 0o700 });
const ok = users.filter(Boolean);
writeFileSync(join(outDir, 'users.json'), JSON.stringify(ok), { mode: 0o600 });
const stats = Object.fromEntries(Object.entries(timings).map(([k, xs]) => [k, { n: xs.length, p50: pct(xs, 50), p95: pct(xs, 95), max: pct(xs, 100) }]));
writeFileSync(join(outDir, 'provision.json'), JSON.stringify({ runid, requested: count, ok: ok.length, failed, elapsedS, concurrency, tz: TZ, steps: stats, errors }, null, 2));
console.log(`provision: ${ok.length}/${count} users ready in ${elapsedS.toFixed(1)} s (${failed} failed)`);
for (const [k, s] of Object.entries(stats)) console.log(`  ${k.padEnd(36)} p50 ${s.p50} ms · p95 ${s.p95} ms · max ${s.max} ms`);
if (errors.length) console.log(`  first errors:\n    ${errors.join('\n    ')}`);
if (ok.length === 0) process.exit(1);
