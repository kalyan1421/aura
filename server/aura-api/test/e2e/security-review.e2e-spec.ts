/**
 * Milestone B security review of the NestJS / RPC boundary (docs/security/milestone-b-review.md), end to end against the
 * live local Supabase (PostgREST, Storage, GoTrue) — what an app user's own access token can reach WITHOUT NestJS:
 *   * PostgREST: no writes to personal tables, only own rows, no admin / definer RPCs, no server-only tables;
 *   * Storage: nothing in private-media is listable or readable with a user token; signed uploads are capped (SR-3);
 *   * GoTrue: a second TOTP factor cannot be enrolled at AAL1 once one is verified (the console's enrol action relies on
 *     it — SR-6).
 * Unique users per run; no global rows (flags, configs, rate-limit keys) are touched.
 */
import { createHmac, randomBytes } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { uuidv7 } from '../../src/common/uuid';
import { bootApp, createUser, deleteUser, localAnonKey, localServiceKey, SUPABASE_URL, type TestUser } from './support';

const ADULT_DOB = '1996-04-12';

function base32Decode(s: string): Buffer {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const c of s.replace(/=+$/, '').toUpperCase()) {
    const i = alphabet.indexOf(c);
    if (i < 0) continue;
    value = (value << 5) | i;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

function totp(secret: string, at = Date.now()): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(at / 30_000)));
  const h = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const o = h[h.length - 1] & 0xf;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

describe('security review: what a user token reaches without NestJS (e2e)', () => {
  let app: INestApplication;
  const users: TestUser[] = [];
  let alice: TestUser;
  let bob: TestUser;

  const http = () => request(app.getHttpServer());
  const rest = (u: TestUser, path: string, init: RequestInit = {}) =>
    fetch(`${SUPABASE_URL}/rest/v1${path}`, {
      ...init,
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${u.token}`, 'Content-Type': 'application/json', ...(init.headers ?? {}) },
    });

  async function appUser(label: string): Promise<TestUser> {
    const u = await createUser(`sr-${label}`);
    users.push(u);
    await http()
      .post('/v1/profile')
      .set('Authorization', `Bearer ${u.token}`)
      .send({ birthDate: ADULT_DOB, uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' })
      .expect(200);
    return u;
  }

  beforeAll(async () => {
    app = await bootApp();
    alice = await appUser('alice');
    bob = await appUser('bob');
  }, 60_000);

  afterAll(async () => {
    for (const u of users) await deleteUser(u.id);
    await app?.close();
  });

  // ------------------------------------------------------------------ PostgREST
  it('PostgREST: a user cannot write a personal table directly, even their own row (all writes go through /v1/sync/push)', async () => {
    const insert = await rest(alice, '/check_ins', {
      method: 'POST',
      body: JSON.stringify({
        id: uuidv7(), user_id: alice.id, mood_id: 'calm', quadrant: 'moonlight', local_day: '2026-09-24', device_ts: new Date().toISOString(),
      }),
    });
    expect(insert.ok).toBe(false);
    expect([401, 403]).toContain(insert.status);
    const update = await rest(alice, `/profiles?user_id=eq.${alice.id}`, { method: 'PATCH', body: JSON.stringify({ birth_date: '2015-01-01' }) });
    expect(update.ok).toBe(false);
    const del = await rest(alice, `/avatar_state?user_id=eq.${alice.id}`, { method: 'DELETE' });
    expect(del.ok).toBe(false);
  });

  it('PostgREST: select-own only — another account’s profile (and DOB) is invisible', async () => {
    const all = await rest(alice, '/profiles?select=user_id,birth_date');
    expect(all.status).toBe(200);
    const rows = (await all.json()) as Array<{ user_id: string }>;
    expect(rows.map((r) => r.user_id)).toEqual([alice.id]);
    const other = await rest(alice, `/profiles?select=birth_date&user_id=eq.${bob.id}`);
    expect(await other.json()).toEqual([]);
  });

  it('PostgREST: server-only tables and admin / definer RPCs are refused to a user token', async () => {
    for (const table of ['user_data_keys', 'sync_mutations', 'reports', 'room_members', 'admin_staff', 'subscriptions']) {
      const r = await rest(alice, `/${table}?select=*&limit=1`);
      expect({ table, ok: r.ok }).toEqual({ table, ok: false });
    }
    for (const [fn, args] of [
      ['admin_staff_list', {}],
      ['user_is_minor', { uid: bob.id }],
      ['admin_account_age_days', { uid: bob.id }],
      ['deletion_case_lookup', { p_token_hash: 'x'.repeat(64) }],
    ] as const) {
      const r = await rest(alice, `/rpc/${fn}`, { method: 'POST', body: JSON.stringify(args) });
      expect({ fn, ok: r.ok }).toEqual({ fn, ok: false });
    }
    // The one client-callable pair answers only for the caller's own membership.
    const own = await rest(alice, '/rpc/realtime_topic_allowed', { method: 'POST', body: JSON.stringify({ topic: `room:${uuidv7()}` }) });
    expect(own.status).toBe(200);
    expect(await own.json()).toBe(false);
  });

  // ------------------------------------------------------------------ Storage
  it('Storage: private-media cannot be listed or read with a user token, not even the user’s own prefix', async () => {
    const list = await fetch(`${SUPABASE_URL}/storage/v1/object/list/private-media`, {
      method: 'POST',
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${alice.token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ prefix: `${alice.id}/`, limit: 10 }),
    });
    const listed = list.ok ? ((await list.json()) as unknown[]) : [];
    expect(listed).toEqual([]);
    const read = await fetch(`${SUPABASE_URL}/storage/v1/object/authenticated/private-media/${alice.id}/voice/${uuidv7()}`, {
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${alice.token}` },
    });
    expect(read.ok).toBe(false);
    const upload = await fetch(`${SUPABASE_URL}/storage/v1/object/private-media/${alice.id}/voice/${uuidv7()}`, {
      method: 'POST',
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${alice.token}`, 'Content-Type': 'application/octet-stream' },
      body: Buffer.from('ciphertext'),
    });
    expect(upload.ok).toBe(false);
  });

  it('SR-3: a signed upload URL cannot carry more than the bucket cap (6 MiB), whatever `bytes` the client declared', async () => {
    const signed = await http()
      .post('/v1/media/upload-url')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ kind: 'voice', recordId: uuidv7(), bytes: 16 });
    if (signed.status === 503) return; // no SUPABASE_SERVICE_ROLE_KEY in this environment: nothing is signed at all
    expect(signed.status).toBe(200);
    const tooBig = await fetch(signed.body.uploadUrl as string, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/octet-stream' },
      body: randomBytes(6 * 1024 * 1024 + 1),
    });
    expect(tooBig.ok).toBe(false);
    expect([400, 413]).toContain(tooBig.status);
  }, 30_000);

  // ------------------------------------------------------------------ GoTrue MFA (console enrolment relies on this)
  it('SR-6: once a TOTP factor is verified, a fresh first-factor (AAL1) session cannot enroll another one', async () => {
    const mfaUser = await createUser('sr-mfa');
    const { id, email } = mfaUser;
    const password = mfaUser.password as string;
    users.push({ id, email, token: '' });
    const signIn = async (): Promise<string> => {
      const r = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: { apikey: localAnonKey(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      return ((await r.json()) as { access_token: string }).access_token;
    };
    const gotrue = (path: string, token: string, body?: unknown) =>
      fetch(`${SUPABASE_URL}/auth/v1${path}`, {
        method: 'POST',
        headers: { apikey: localAnonKey(), Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: body === undefined ? undefined : JSON.stringify(body),
      });

    const aal1 = await signIn();
    const factor = (await (await gotrue('/factors', aal1, { factor_type: 'totp', friendly_name: 'first' })).json()) as { id: string; totp: { secret: string } };
    const challenge = (await (await gotrue(`/factors/${factor.id}/challenge`, aal1)).json()) as { id: string };
    expect((await gotrue(`/factors/${factor.id}/verify`, aal1, { challenge_id: challenge.id, code: totp(factor.totp.secret) })).status).toBe(200);

    const attacker = await signIn(); // e.g. a phished Workspace password: first factor only
    const second = await gotrue('/factors', attacker, { factor_type: 'totp', friendly_name: 'attacker' });
    expect(second.status).toBe(403);
    expect(((await second.json()) as { error_code?: string }).error_code).toBe('insufficient_aal');
  }, 30_000);
});
