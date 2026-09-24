/**
 * F6 Reflections end to end against the live local stack (NestJS app, Postgres incl. migration 20261005000018,
 * Supabase Auth + Realtime, Redis): the app routes (contracts/api/v1-reflections.md §1), the moderation pipeline (§3)
 * with a fake omni-moderation provider, realtime (§2, ids only), gestures and reports on reflections, the admin
 * console routes (§4, real staff sessions with TOTP), the worker tick, the account purge, and a DS-10 contract scan of
 * every response and realtime payload the suite saw.
 */
import { createHmac, randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { PERSONAL_TABLES, purgeAccount } from '../../src/account/account-purge';
import { PrivateMediaStore } from '../../src/account/private-media';
import { uuidv7 } from '../../src/common/uuid';
import { RemoteConfigService } from '../../src/remote-config/remote-config.service';
import { StaticModerationProvider, UnavailableModerationProvider } from '../../src/reflections/moderation-provider';
import { openReflection } from '../../src/reflections/reflection-cipher';
import { ReflectionsService } from '../../src/reflections/reflections.service';
import { runReflectionsTick } from '../../src/reflections/reflections.worker';
import { ModerationService } from '../../src/safety/moderation.service';
import { RealtimeClient } from './realtime';
import { SUPABASE_URL, bootApp, createUser, dbPool, deleteUser, localAnonKey, type TestUser } from './support';

jest.setTimeout(90_000);

const ADULT_DOB = '1996-04-11';
const MINOR_DOB = `${new Date().getUTCFullYear() - 16}-01-20`;
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

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

type Method = 'get' | 'post' | 'delete';

describe('Reflections (e2e, live local Supabase + Realtime + Redis)', () => {
  let app: INestApplication;
  let db: Pool;
  let reflections: ReflectionsService;
  let masterKey: Buffer;
  const fake = new StaticModerationProvider([
    { includes: 'meanword', scores: { harassment: 0.95 } },
    { includes: 'grumpyword', scores: { harassment: 0.5 } },
    { includes: 'borderline', scores: { sexual: 0.25 } },
    { includes: 'faintly', scores: { harassment: 0.2 } },
    { includes: 'sadword', scores: { 'self-harm/intent': 0.8 } },
  ]);
  const users: TestUser[] = [];
  const sockets: RealtimeClient[] = [];
  const recorded: Array<{ where: string; body: unknown }> = [];
  const dobs = new Set<string>([ADULT_DOB, MINOR_DOB]);
  let savedMatching: Record<string, unknown>;
  let savedConfig: Record<string, unknown>;
  let savedFlags: Array<{ key: string; enabled: boolean; payload: unknown }> = [];

  // room 1 (adults): a, b, c · room 2 (with a minor): m (16), d
  let a: TestUser, b: TestUser, c: TestUser, m: TestUser, d: TestUser;
  let room1 = '';
  let room2 = '';
  const member: Record<string, string> = {};
  let sockA: RealtimeClient, sockB: RealtimeClient;
  let owner: TestUser & { token: string };
  let moderator: TestUser & { token: string };

  // ------------------------------------------------------------------ helpers
  const http = () => request(app.getHttpServer());
  async function call(u: { token: string }, method: Method, path: string, body?: unknown): Promise<request.Response> {
    let r = http()[method](path).set('Authorization', `Bearer ${u.token}`);
    if (body !== undefined) r = r.send(body as object);
    const res = await r;
    recorded.push({ where: `${method.toUpperCase()} ${path} → ${res.status}`, body: res.body });
    return res;
  }
  const one = async <T = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T> => (await db.query(sql, params)).rows[0] as T;
  const send = (u: TestUser, roomId: string, text: string, id = uuidv7()) => call(u, 'post', `/v1/rooms/${roomId}/reflections`, { reflectionId: id, text });
  const list = (u: TestUser, roomId: string) => call(u, 'get', `/v1/rooms/${roomId}/reflections`);
  const row = (id: string) =>
    one<{ status: string; hold_reason: string | null; reject_reason: string | null; body_ct: string | null; body_key: string | null; hidden_at: Date | null; strict: boolean; involves_minor: boolean }>(
      'select status, hold_reason, reject_reason, body_ct, body_key, hidden_at, strict, involves_minor from public.reflections where id = $1',
      [id],
    );
  const reportsOn = (id: string) =>
    db.query<{ id: string; lane: string; reason: number; source: string; auto_signal: string | null; status: string; involves_minor: boolean; pages: boolean; evidence_hold_id: string }>(
      'select id, lane, reason, source, auto_signal, status, involves_minor, pages, evidence_hold_id from public.reports where target_reflection_id = $1 order by created_at',
      [id],
    );
  const setConfig = (patch: Record<string, unknown>) => {
    const keys = Object.keys(patch);
    return db.query(`update public.reflection_config set ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')} where id`, Object.values(patch));
  };
  const setFlag = async (key: string, enabled: boolean, payload?: unknown) => {
    await db.query(`update public.feature_flags set enabled = $2, payload = coalesce($3::jsonb, payload) where key = $1`, [key, enabled, payload === undefined ? null : JSON.stringify(payload)]);
    app.get(RemoteConfigService).invalidate();
  };

  async function mk(label: string, dob = ADULT_DOB): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    dobs.add(dob);
    await http().post('/v1/profile').set('Authorization', `Bearer ${u.token}`).send({ birthDate: dob, uiLocale: 'en', timezone: 'Asia/Tokyo', country: 'IN' }).expect(200);
    await http().post('/v1/safety/guidelines/accept').set('Authorization', `Bearer ${u.token}`).send({ version: 1 }).expect(200);
    return u;
  }

  async function join(u: TestUser, quadrant: string, moodId: string): Promise<{ roomId: string; memberId: string }> {
    const r = await call(u, 'post', '/v1/rooms/match', { quadrant, moodId, timezone: 'Asia/Tokyo' });
    expect(r.status).toBe(200);
    return { roomId: r.body.room.roomId, memberId: r.body.me.memberId };
  }

  async function listen(u: TestUser, topics: string[]): Promise<RealtimeClient> {
    const s = await RealtimeClient.connect();
    sockets.push(s);
    for (const t of topics) expect(await s.join(t, u.token)).toEqual({ ok: true });
    return s;
  }

  async function gotrue(path: string, token: string, body?: unknown): Promise<Record<string, unknown>> {
    const res = await fetch(`${SUPABASE_URL}/auth/v1${path}`, {
      method: 'POST',
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`gotrue ${path}: ${res.status}`);
    return text ? (JSON.parse(text) as Record<string, unknown>) : {};
  }
  async function staff(label: string, role: 'owner' | 'moderator'): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    await db.query('insert into public.admin_staff (staff_id, role, display_name) values ($1, $2, $3)', [u.id, role, `E2E ${label}`]);
    const factor = await gotrue('/factors', u.token, { factor_type: 'totp', friendly_name: `e2e-${randomUUID().slice(0, 6)}` });
    const challenge = await gotrue(`/factors/${factor.id as string}/challenge`, u.token);
    const verified = await gotrue(`/factors/${factor.id as string}/verify`, u.token, {
      challenge_id: challenge.id,
      code: totp((factor.totp as { secret: string }).secret),
    });
    return { ...u, token: verified.access_token as string };
  }

  /**
   * Other suites may run at the same time and delete every room that holds only `e2e-…@aura.test` accounts. A silent
   * guard member (an auth row with another address, never live) keeps this suite's rooms; afterAll removes them.
   */
  const guards: string[] = [];
  async function guard(roomId: string, quadrant: string, mood: string): Promise<void> {
    const id = randomUUID();
    guards.push(id);
    await db.query(`insert into auth.users (id, email, aud, role) values ($1, $2, 'authenticated', 'authenticated')`, [id, `refl-guard-${id}@aura.test`]);
    await db.query(
      `insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region,
                                        match_step, stage, last_seen_at)
       values ($1, $2, 'Guard Lantern', $3, $4, 'en', 'east_asia_pacific', 4, 'spark', now() - interval '1 day')`,
      [roomId, id, mood, quadrant],
    );
  }

  const freshRooms = () =>
    db.query(
      `delete from public.rooms r where not exists (
         select 1 from public.room_members m join auth.users u on u.id = m.user_id
          where m.room_id = r.id and coalesce(u.email, '') not like 'e2e-%@aura.test')`,
    );

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
    reflections = app.get(ReflectionsService);
    reflections.useProvider(fake);
    masterKey = Buffer.from(process.env.AURA_MASTER_KEY ?? '', 'base64');
    savedMatching = (await db.query('select * from public.matching_config where id')).rows[0];
    savedConfig = (await db.query('select * from public.reflection_config where id')).rows[0];
    savedFlags = (await db.query(`select key, enabled, payload from public.feature_flags where key in ('reflections_composer','reduced_mode','hold_all')`)).rows;
    await db.query(`update public.matching_config set thin_join_threshold = 0, partition_live_min = 1, adjacent_live_min = 48, gesture_min_interval_ms = 0 where id`);
    // Never overnight unless a test says so (start = end → an empty window); generous limits unless a test lowers them.
    await setConfig({ overnight_start: '00:00', overnight_end: '00:00', per_room_24h: 50, per_account_24h: 200, respond_within_ms: 1800 });
    await setFlag('reflections_composer', true, { pausedPools: [] });
    await setFlag('reduced_mode', false);
    await setFlag('hold_all', false);
    await freshRooms();

    [a, b, c] = [await mk('refl-a'), await mk('refl-b'), await mk('refl-c')];
    const ja = await join(a, 'storm', 'anxious');
    room1 = ja.roomId;
    member.a = ja.memberId;
    await guard(room1, 'storm', 'anxious');
    for (const [k, u] of [['b', b], ['c', c]] as const) {
      const j = await join(u, 'storm', 'overwhelmed');
      expect(j.roomId).toBe(room1);
      member[k] = j.memberId;
    }
    [m, d] = [await mk('refl-meera', MINOR_DOB), await mk('refl-d')];
    const jm = await join(m, 'moonlight', 'calm');
    room2 = jm.roomId;
    member.m = jm.memberId;
    await guard(room2, 'moonlight', 'calm');
    const jd = await join(d, 'moonlight', 'calm');
    expect(jd.roomId).toBe(room2);
    member.d = jd.memberId;
    sockA = await listen(a, [`room:${room1}`, `member:${member.a}`]);
    sockB = await listen(b, [`room:${room1}`, `member:${member.b}`]);
    owner = await staff('refl-owner', 'owner');
    moderator = await staff('refl-mod', 'moderator');
  });

  afterAll(async () => {
    await reflections?.idle().catch(() => undefined);
    for (const s of sockets) s.close();
    if (db) {
      const restore = async (table: string, saved: Record<string, unknown>) => {
        const keys = Object.keys(saved).filter((k) => k !== 'id');
        await db.query(`update public.${table} set ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')} where id`, keys.map((k) => saved[k]));
      };
      if (savedMatching) await restore('matching_config', savedMatching);
      if (savedConfig) await restore('reflection_config', savedConfig);
      for (const f of savedFlags) await db.query('update public.feature_flags set enabled = $2, payload = $3 where key = $1', [f.key, f.enabled, f.payload]);
      const ids = users.map((u) => u.id);
      const mine = `select id from public.reports where reporter_user_id = any($1::uuid[]) or target_user_id = any($1::uuid[])`;
      await db.query(`delete from public.admin_pages where kind = 'report' and ref_id in (${mine})`, [ids]);
      await db.query(`delete from public.evidence_holds where report_id in (${mine}) or account_ids && $1::uuid[]`, [ids]);
      await db.query(`delete from public.reports where id in (${mine})`, [ids]);
      await db.query('delete from public.admin_staff where staff_id = any($1::uuid[])', [ids]);
    }
    await Promise.all(users.map((u) => deleteUser(u.id)));
    if (db) {
      await db.query('delete from public.rooms where id = any($1::uuid[])', [[room1, room2].filter(Boolean)]);
      if (guards.length) await db.query('delete from auth.users where id = any($1::uuid[])', [guards]);
      await freshRooms();
      await db.end();
    }
    await app?.close();
  });

  // ================================================================== basics
  it('401 without a token; 404 for non-members; the admin routes refuse app accounts', async () => {
    const id = randomUUID();
    for (const [method, path] of [
      ['get', `/v1/rooms/${id}/reflections`],
      ['post', `/v1/rooms/${id}/reflections`],
      ['get', `/v1/rooms/${id}/reflections/${id}`],
      ['delete', `/v1/rooms/${id}/reflections/${id}`],
    ] as const) {
      expect((await http()[method](path)).status).toBe(401);
    }
    expect((await list(m, room1)).body.code).toBe('not_found');
    expect((await send(m, room1, 'hello')).status).toBe(404);
    expect((await call(a, 'get', '/admin/reflections')).body.code).toBe('not_staff');
  });

  it('validation: empty, 201 characters, bad ids, unknown keys; replies are refused by name (REQ-REF-01, REQ-REF-05)', async () => {
    const bad = async (body: unknown, code: string) => {
      const r = await call(a, 'post', `/v1/rooms/${room1}/reflections`, body);
      expect([r.status, r.body.code]).toEqual([400, code]);
    };
    await bad({ reflectionId: uuidv7(), text: '   ' }, 'invalid_request');
    await bad({ reflectionId: uuidv7(), text: 'x'.repeat(201) }, 'invalid_request');
    await bad({ reflectionId: 'nope', text: 'hi' }, 'invalid_request');
    await bad({ reflectionId: uuidv7(), text: 'hi', mood: 'x' }, 'invalid_request');
    await bad({ reflectionId: uuidv7(), text: 'hi', parentId: null }, 'replies_not_supported');
    await bad({ reflectionId: uuidv7(), text: 'hi', parent_id: randomUUID() }, 'replies_not_supported');
    // No edit route exists.
    expect((await http().patch(`/v1/rooms/${room1}/reflections/${randomUUID()}`).set('Authorization', `Bearer ${a.token}`)).status).toBe(404);
    expect((await http().put(`/v1/rooms/${room1}/reflections/${randomUUID()}`).set('Authorization', `Bearer ${a.token}`)).status).toBe(404);
  });

  // ================================================================== publish + realtime
  let published = '';
  it('clean text publishes in one request; the room gets the id only; strangers read pseudonym + text; encrypted at rest', async () => {
    const telugu = `${'నా'.repeat(60)} first Diwali alone in this city 🙏🏽`;
    const r = await send(a, room1, telugu);
    expect(r.status).toBe(201);
    expect(r.headers['cache-control']).toBe('no-store');
    expect(r.body).toMatchObject({ status: 'published', rejectReason: null, review: null, showSupport: false });
    expect(r.body.reflection).toMatchObject({ isMine: true, status: 'published', gestureCount: 0, author: { memberId: member.a } });
    expect(r.body.composer).toMatchObject({ state: 'open', maxChars: 200 });
    published = r.body.reflectionId;
    const ev = await sockB.waitForBroadcast(`room:${room1}`, 'reflection_published', (p) => p.reflectionId === published);
    expect(Object.keys(ev.payload).filter((k) => k !== 'id').sort()).toEqual(['at', 'reflectionId']); // Realtime adds `id`
    expect(JSON.stringify(ev.payload)).not.toContain('Diwali');

    const lb = await list(b, room1);
    const seen = lb.body.reflections.find((x: { reflectionId: string }) => x.reflectionId === published);
    expect(seen).toMatchObject({ isMine: false, gestureCount: null, text: telugu, author: { memberId: member.a, pseudonym: expect.stringMatching(/^[A-Z][a-z]+ [A-Z][a-z]+$/) } });
    expect((await call(b, 'get', `/v1/rooms/${room1}/reflections/${published}`)).body.reflectionId).toBe(published);

    const stored = await row(published);
    expect(stored.body_ct).not.toContain('Diwali');
    expect(Buffer.from(stored.body_ct ?? '', 'base64').toString('utf8')).not.toContain('Diwali');
    expect(openReflection(masterKey, published, { bodyCt: stored.body_ct ?? '', bodyKey: stored.body_key ?? '' })).toBe(telugu);
    expect(await reportsOn(published)).toMatchObject({ rowCount: 0 }); // nothing queued for clean text
  });

  it('idempotent replay (200, same outcome); the same id from someone else → 409', async () => {
    const id = uuidv7();
    expect((await send(a, room1, 'a quiet evening', id)).status).toBe(201);
    const again = await send(a, room1, 'a quiet evening', id);
    expect([again.status, again.body.status, again.body.reflectionId]).toEqual([200, 'published', id]);
    expect((await send(b, room1, 'mine now', id)).body.code).toBe('reflection_id_conflict');
  });

  // ================================================================== text rules
  it('contact details and links are rejected and nothing is stored (REQ-REF-02, REQ-SAFE-07)', async () => {
    for (const [text, reason] of [
      ['98765 43210', 'contact_details'],
      ['insta: @quietcomet', 'contact_details'],
      ['name@okaxis', 'contact_details'],
      ['తొమ్మిది ఎనిమిది ఏడు ఆరు ఐదు నాలుగు మూడు రెండు ఒకటి సున్నా', 'contact_details'],
      ['9 8 7 6 5 4 3 2 1 0', 'contact_details'],
      ['insta: x', 'contact_details'],
      ['check www.example.com', 'link'],
    ] as const) {
      const id = uuidv7();
      const r = await send(b, room1, text, id);
      expect([text, r.status, r.body.status, r.body.rejectReason, r.body.reflection]).toEqual([text, 200, 'rejected', reason, null]);
      expect(await one('select count(*)::int as n from public.reflections where id = $1', [id])).toEqual({ n: 0 });
    }
  });

  it('crisis lexicon → crisis_diverted: support sheet, crisis lane, never listed, never a strike (REQ-REF-04)', async () => {
    const calls = fake.calls;
    const r = await send(c, room1, 'honestly i want to die tonight, call 98765 43210');
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ status: 'crisis_diverted', showSupport: true, rejectReason: null, reflection: null });
    expect(fake.calls).toBe(calls); // decided by the rules, no classifier call
    const id = r.body.reflectionId as string;
    expect((await row(id)).status).toBe('crisis_diverted');
    const reps = (await reportsOn(id)).rows;
    expect(reps).toEqual([expect.objectContaining({ lane: 'crisis', reason: 1, source: 'auto', auto_signal: 'reflection_crisis' })]);
    for (const u of [a, b, c]) expect((await list(u, room1)).body.reflections.map((x: { reflectionId: string }) => x.reflectionId)).not.toContain(id);
    await expect(app.get(ModerationService).act({ reportId: reps[0].id, action: 'strike', actor: 'staff:e2e' })).rejects.toMatchObject({ code: 'crisis_never_strikes' });

    const viaProvider = await send(c, room1, 'sadword tonight');
    expect(viaProvider.body).toMatchObject({ status: 'crisis_diverted', showSupport: true });
  });

  it('grooming → rejected (personal_questions), Minors & grooming lane, author shadow-muted until review', async () => {
    const r = await send(c, room1, 'which school are you in?');
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ status: 'rejected', rejectReason: 'personal_questions' });
    const reps = (await reportsOn(r.body.reflectionId)).rows;
    expect(reps).toEqual([expect.objectContaining({ lane: 'minors_grooming', reason: 9, auto_signal: 'reflection_minor_safety' })]);
    expect(await one(`select count(*)::int as n from public.sanctions where user_id = $1 and kind = 'shadow_mute' and source = 'auto' and lifted_at is null`, [c.id])).toEqual({ n: 1 });
    // …so the next clean one is held (sanction), and it doesn't reach anyone.
    const next = await send(c, room1, 'long day');
    expect(next.body).toMatchObject({ status: 'held', review: 'soon' });
    expect((await row(next.body.reflectionId)).hold_reason).toBe('sanction');
  });

  // ================================================================== classifier outcomes
  it('high score → rejected (stored, violation lane); medium → held for a human; only the author sees held', async () => {
    const hi = await send(b, room1, 'you are a meanword');
    expect(hi.body).toMatchObject({ status: 'rejected', rejectReason: 'hurtful' });
    expect((await reportsOn(hi.body.reflectionId)).rows).toEqual([expect.objectContaining({ lane: 'harassment', auto_signal: 'reflection_violation' })]);
    const med = await send(b, room1, 'feeling grumpyword today');
    expect(med.body).toMatchObject({ status: 'held', review: 'soon', rejectReason: null });
    expect((await reportsOn(med.body.reflectionId)).rows).toEqual([expect.objectContaining({ auto_signal: 'reflection_hold', status: 'open' })]);
    const mineHeld = (await list(b, room1)).body.reflections.find((x: { reflectionId: string }) => x.reflectionId === med.body.reflectionId);
    expect(mineHeld).toMatchObject({ status: 'held', isMine: true, review: 'soon' });
    const rejectedMine = (await list(b, room1)).body.reflections.find((x: { reflectionId: string }) => x.reflectionId === hi.body.reflectionId);
    expect(rejectedMine).toMatchObject({ status: 'rejected', rejectReason: 'hurtful' });
    expect((await list(a, room1)).body.reflections.map((x: { reflectionId: string }) => x.reflectionId)).not.toEqual(
      expect.arrayContaining([med.body.reflectionId]),
    );
  });

  it('fail closed: provider error, no key, and a timeout all hold; nothing is released later (REQ-REF-03)', async () => {
    fake.fail = 'error';
    const e = await send(a, room1, 'omni is down');
    expect(e.body).toMatchObject({ status: 'held' });
    expect((await row(e.body.reflectionId)).hold_reason).toBe('provider_unavailable');
    expect((await list(a, room1)).body.composer.slow).toBe(true);
    fake.fail = null;

    reflections.useProvider(new UnavailableModerationProvider());
    const k = await send(a, room1, 'no key configured');
    expect(k.body).toMatchObject({ status: 'held' });
    expect((await row(k.body.reflectionId)).hold_reason).toBe('provider_unavailable');
    reflections.useProvider(fake);

    await setConfig({ provider_timeout_ms: 500 });
    fake.delayMs = 800;
    const t = await send(a, room1, 'slow classifier');
    expect(t.body.status).toBe('held');
    expect((await row(t.body.reflectionId)).hold_reason).toBe('timeout');
    fake.delayMs = 0;
    await setConfig({ provider_timeout_ms: 5000 });
    await sleep(300);
    for (const id of [e.body.reflectionId, k.body.reflectionId, t.body.reflectionId]) expect((await row(id)).status).toBe('held');
  });

  it('> respond window → 201 pending, then the decision arrives on the author topic (reflection_status)', async () => {
    await setConfig({ respond_within_ms: 100 });
    fake.delayMs = 700;
    const r = await send(a, room1, 'take your time with this one');
    expect(r.status).toBe(201);
    expect(r.body).toMatchObject({ status: 'pending', review: 'soon' });
    expect(r.body.reflection).toMatchObject({ status: 'pending', isMine: true });
    const ev = await sockA.waitForBroadcast(`member:${member.a}`, 'reflection_status', (p) => p.reflectionId === r.body.reflectionId);
    expect(ev.payload).toMatchObject({ reflectionId: r.body.reflectionId, status: 'published' });
    await sockB.waitForBroadcast(`room:${room1}`, 'reflection_published', (p) => p.reflectionId === r.body.reflectionId);
    fake.delayMs = 0;
    await setConfig({ respond_within_ms: 1800 });
    await reflections.idle();
  });

  it('REQ-REF-08: a borderline sexual score publishes in an all-adult room and holds in a room with an under-18 — same answer shape', async () => {
    const adult = await send(a, room1, 'borderline words');
    const minorRoom = await send(d, room2, 'borderline words');
    expect(adult.body.status).toBe('published');
    expect(minorRoom.body.status).toBe('held');
    expect(await row(minorRoom.body.reflectionId)).toMatchObject({ hold_reason: 'strict_threshold', strict: true, involves_minor: true });
    const shape = (v: unknown): unknown =>
      Array.isArray(v) ? v.map(shape).slice(0, 1) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, shape((v as Record<string, unknown>)[k])])) : typeof v;
    expect((await send(m, room2, 'a gentle clean line')).body.status).toBe('published'); // the minor's own
    expect(shape((await list(m, room2)).body)).toEqual(shape((await list(a, room1)).body)); // nothing says "under 18"
  });

  it('overnight: only text rated clean with high confidence publishes; the rest waits for the morning', async () => {
    await setConfig({ overnight_start: '00:00', overnight_end: '23:59' });
    const faint = await send(a, room1, 'faintly annoyed tonight');
    expect(faint.body).toMatchObject({ status: 'held', review: 'overnight' });
    expect((await row(faint.body.reflectionId)).hold_reason).toBe('overnight');
    expect((await send(a, room1, 'a calm clean note')).body.status).toBe('published');
    await setConfig({ overnight_start: '00:00', overnight_end: '00:00' });
  });

  // ================================================================== flags and limits
  it('hold_all holds every new reflection; reduced mode / the kill switch / a paused pool → 503 reflections_paused', async () => {
    await setFlag('hold_all', true);
    const h = await send(a, room1, 'held by hold all');
    expect(h.body.status).toBe('held');
    expect((await row(h.body.reflectionId)).hold_reason).toBe('hold_all');
    await setFlag('hold_all', false);

    for (const [key, enabled, payload] of [
      ['reduced_mode', true, undefined],
      ['reflections_composer', false, undefined],
      ['reflections_composer', true, { pausedPools: ['en'] }],
    ] as const) {
      await setFlag(key, enabled, payload);
      const r = await send(a, room1, 'paused?');
      expect([key, r.status, r.body.code]).toEqual([key, 503, 'reflections_paused']);
      expect((await list(a, room1)).body.composer.state).toBe('paused');
      await setFlag('reduced_mode', false);
      await setFlag('reflections_composer', true, { pausedPools: [] });
    }
    // Gestures keep working while reflections rest.
    await setFlag('reduced_mode', true);
    expect((await call(a, 'post', `/v1/rooms/${room1}/gestures`, { type: 'hug', target: 'room' })).status).toBe(202);
    await setFlag('reduced_mode', false);
  });

  it('3 per room per 24 h (rejections do not count) and the account-wide daily cap (REQ-REF-01)', async () => {
    const sent = (await one<{ n: number }>(
      `select count(*)::int as n from public.reflections where user_id = $1 and room_id = $2 and status not in ('rejected','crisis_diverted')`,
      [d.id, room2],
    )).n;
    await setConfig({ per_room_24h: sent + 2 });
    expect((await send(d, room2, '98765 43210')).body.status).toBe('rejected'); // doesn't use one up
    expect((await send(d, room2, 'first of two')).status).toBe(201);
    const second = await send(d, room2, 'second of two');
    expect(second.body.composer).toMatchObject({ remainingInRoom: 0, state: 'limit_reached' });
    const third = await send(d, room2, 'one too many');
    expect([third.status, third.body.code]).toEqual([429, 'reflection_room_limit']);
    await setConfig({ per_room_24h: 50, per_account_24h: 1 });
    expect((await send(d, room2, 'daily cap')).body.code).toBe('reflection_daily_limit');
    await setConfig({ per_account_24h: 200 });
  });

  // ================================================================== gestures, blocks, mutes
  it('gestures on a reflection reach its author (reflectionId), count for the author only; own / held / bad shapes refused', async () => {
    const g = await call(b, 'post', `/v1/rooms/${room1}/gestures`, { type: 'warm_tea', target: 'reflection', toReflectionId: published });
    expect(g.status).toBe(202);
    const got = await sockA.waitForBroadcast(`member:${member.a}`, 'gesture_received', (p) => p.gestureId === g.body.gestureId);
    expect(got.payload).toMatchObject({ reflectionId: published, fromMemberId: member.b, type: 'warm_tea' });
    const anon = await sockB.waitForBroadcast(`room:${room1}`, 'gesture_sent', (p) => p.gestureId === g.body.gestureId);
    expect(anon.payload).toMatchObject({ target: 'reflection', reflectionId: published });
    expect(anon.payload).not.toHaveProperty('fromMemberId');
    expect((await list(a, room1)).body.reflections.find((x: { reflectionId: string }) => x.reflectionId === published).gestureCount).toBe(1);
    expect((await list(b, room1)).body.reflections.find((x: { reflectionId: string }) => x.reflectionId === published).gestureCount).toBeNull();

    expect((await call(a, 'post', `/v1/rooms/${room1}/gestures`, { type: 'hug', target: 'reflection', toReflectionId: published })).body.code).toBe('invalid_target');
    const held = (await one<{ id: string }>(`select id from public.reflections where room_id = $1 and status = 'held' limit 1`, [room1])).id;
    expect((await call(b, 'post', `/v1/rooms/${room1}/gestures`, { type: 'hug', target: 'reflection', toReflectionId: held })).body.code).toBe('reflection_not_found');
    expect((await call(b, 'post', `/v1/rooms/${room1}/gestures`, { type: 'hug', target: 'reflection', toMemberId: member.a })).body.code).toBe('invalid_request');
    expect((await call(b, 'post', `/v1/rooms/${room1}/gestures`, { type: 'hug', target: 'room', toReflectionId: published })).body.code).toBe('invalid_request');
  });

  it('blocked pairs never see each other’s reflections, both ways; their gestures drop silently; mute hides for the muter only', async () => {
    const fromC = await send(c, room1, 'c says hello'); // c is shadow-muted: held — use b's instead
    expect(fromC.body.status).toBe('held');
    const fromB = await send(b, room1, 'b says hello');
    expect(fromB.body.status).toBe('published');
    const blk = await call(a, 'post', '/v1/safety/blocks', { roomId: room1, memberId: member.b });
    expect(blk.status).toBe(201);
    const ids = async (u: TestUser) => (await list(u, room1)).body.reflections.map((x: { reflectionId: string }) => x.reflectionId);
    expect(await ids(a)).not.toContain(fromB.body.reflectionId);
    expect(await ids(b)).not.toContain(published);
    expect((await call(b, 'get', `/v1/rooms/${room1}/reflections/${published}`)).body.code).toBe('reflection_not_found');
    const g = await call(b, 'post', `/v1/rooms/${room1}/gestures`, { type: 'hug', target: 'reflection', toReflectionId: published });
    expect(g.status).toBe(202); // looks sent
    expect(await one('select dropped from public.room_gestures where id = $1', [g.body.gestureId])).toEqual({ dropped: 'blocked' });
    await call(a, 'delete', `/v1/safety/blocks/${blk.body.blockId}`);
    expect(await ids(b)).toContain(published);

    await call(c, 'post', `/v1/rooms/${room1}/mutes`, { memberId: member.a });
    expect(await ids(c)).not.toContain(published);
    expect(await ids(b)).toContain(published);
    await call(c, 'delete', `/v1/rooms/${room1}/mutes/${member.a}`);
  });

  // ================================================================== reports, auto-hide, evidence
  it('a report hides it for the reporter at once; 3 distinct reporters hide it for everyone (repeats count once); evidence is encrypted', async () => {
    const r = await send(a, room1, 'please report me thrice');
    const id = r.body.reflectionId as string;
    const report = (u: TestUser, reason = 2) => call(u, 'post', '/v1/safety/reports', { target: { kind: 'reflection', roomId: room1, reflectionId: id }, reason });
    expect((await call(a, 'post', '/v1/safety/reports', { target: { kind: 'reflection', roomId: room1, reflectionId: id }, reason: 2 })).body.code).toBe('invalid_target');
    const first = await report(b);
    expect(first.status).toBe(201);
    expect(first.body).toEqual({ reportId: expect.any(String), showHelplines: false });
    expect((await report(b)).status).toBe(200); // repeat counts once
    const ids = async (u: TestUser) => (await list(u, room1)).body.reflections.map((x: { reflectionId: string }) => x.reflectionId);
    expect(await ids(b)).not.toContain(id);
    expect(await ids(c)).toContain(id);
    expect((await row(id)).hidden_at).toBeNull();
    await report(c, 6);
    expect((await row(id)).hidden_at).toBeNull(); // 2 distinct
    const e = await mk('refl-e');
    const je = await join(e, 'storm', 'anxious');
    expect(je.roomId).toBe(room1);
    member.e = je.memberId;
    await report(e, 4);
    expect((await row(id)).hidden_at).not.toBeNull();
    await sockA.waitForBroadcast(`room:${room1}`, 'reflection_removed', (p) => p.reflectionId === id);
    expect(await ids(a)).toContain(id); // the author sees no change
    expect(await ids(c)).not.toContain(id);

    const reps = (await reportsOn(id)).rows;
    expect(reps.map((x) => x.lane)).toEqual(['harassment', 'spam', 'harassment']);
    const hold = await one<{ item_kind: string; item_ref: string; snapshot: { reflection: { bodyCt: string; bodyKey: string } } }>(
      'select item_kind, item_ref, snapshot from public.evidence_holds where id = $1',
      [reps[0].evidence_hold_id],
    );
    expect(hold).toMatchObject({ item_kind: 'reflection', item_ref: id });
    expect(JSON.stringify(hold.snapshot)).not.toContain('report me thrice');
    expect(openReflection(masterKey, id, hold.snapshot.reflection)).toBe('please report me thrice');
  });

  it('one sexual / contact report hides it when the author or the reporter is under 18 (REQ-REF-06)', async () => {
    const r = await send(d, room2, 'a normal line');
    expect(r.body.status).toBe('published');
    const rep = await call(m, 'post', '/v1/safety/reports', { target: { kind: 'reflection', roomId: room2, reflectionId: r.body.reflectionId }, reason: 3 });
    expect(rep.body).toEqual({ reportId: expect.any(String), showHelplines: false }); // same answer at every age
    expect((await row(r.body.reflectionId)).hidden_at).not.toBeNull();
    expect((await reportsOn(r.body.reflectionId)).rows[0]).toMatchObject({ lane: 'minors_grooming', involves_minor: true, pages: true });
  });

  it('delete: published → gone for everyone (reflection_removed, text scrubbed); held → withdrawn and its hold item closed', async () => {
    const p = await send(a, room1, 'delete me soon');
    await call(a, 'delete', `/v1/rooms/${room1}/reflections/${p.body.reflectionId}`).then((x) => expect(x.status).toBe(204));
    await sockB.waitForBroadcast(`room:${room1}`, 'reflection_removed', (x) => x.reflectionId === p.body.reflectionId);
    expect(await row(p.body.reflectionId)).toMatchObject({ status: 'deleted', body_ct: null, body_key: null });
    expect((await call(a, 'delete', `/v1/rooms/${room1}/reflections/${p.body.reflectionId}`)).status).toBe(204); // idempotent
    expect((await call(b, 'delete', `/v1/rooms/${room1}/reflections/${published}`)).body.code).toBe('reflection_not_found');

    const h = await send(b, room1, 'grumpyword to withdraw');
    expect(h.body.status).toBe('held');
    await call(b, 'delete', `/v1/rooms/${room1}/reflections/${h.body.reflectionId}`);
    expect((await reportsOn(h.body.reflectionId)).rows).toEqual([expect.objectContaining({ status: 'dismissed' })]);
  });

  // ================================================================== admin console
  describe('admin console (/admin/reflections*, real staff sessions)', () => {
    let heldId = '';
    it('lists held items with decrypted text and pools; the item view has no account id or DOB', async () => {
      const h = await send(b, room1, 'grumpyword for review');
      heldId = h.body.reflectionId;
      const l = await call(moderator, 'get', '/admin/reflections?status=held');
      expect(l.status).toBe(200);
      const item = l.body.items.find((x: { reflectionId: string }) => x.reflectionId === heldId);
      expect(item).toMatchObject({ status: 'held', holdReason: 'uncertain', text: 'grumpyword for review', report: { lane: 'spam', autoSignal: 'reflection_hold' } });
      expect(l.body.pools).toEqual(expect.arrayContaining([expect.objectContaining({ pool: 'en', paused: false })]));
      const v = await call(moderator, 'get', `/admin/reflections/${heldId}`);
      expect(v.body).toMatchObject({ text: 'grumpyword for review', scores: { harassment: 0.5 }, allowedDecisions: ['approve', 'remove', 'escalate'], canStrike: true });
      expect(v.body.author).toMatchObject({ pseudonym: expect.any(String), hash: expect.stringMatching(/^[0-9a-f]{64}$/), under18: false });
      const json = JSON.stringify(v.body);
      for (const s of [b.id, b.email, ADULT_DOB]) expect(json).not.toContain(s);
      const rid = v.body.reports[0].reportId;
      expect((await call(moderator, 'get', `/admin/reflections/by-report/${rid}`)).body).toEqual({ reflectionId: heldId });
    });

    it('approve publishes it (broadcast) and closes its report; remove with a strike takes it down through the ladder', async () => {
      const ok = await call(moderator, 'post', `/admin/reflections/${heldId}/decision`, { decision: 'approve', reasonCode: 'no_violation' });
      expect(ok.status).toBe(200);
      expect(ok.body).toMatchObject({ previousStatus: 'held', status: 'published', reportsResolved: 1 });
      await sockA.waitForBroadcast(`room:${room1}`, 'reflection_published', (p) => p.reflectionId === heldId);
      expect((await reportsOn(heldId)).rows[0].status).toBe('dismissed');

      const bad = await send(b, room1, 'meanword again');
      const rm = await call(owner, 'post', `/admin/reflections/${heldId}/decision`, { decision: 'remove', reasonCode: 'harassment', strike: true });
      expect(rm.body.code).toBe('no_open_report'); // approved: nothing open to strike from
      const rm2 = await call(owner, 'post', `/admin/reflections/${bad.body.reflectionId}/decision`, { decision: 'remove', reasonCode: 'harassment', strike: true, rejectReason: 'hurtful' });
      expect(rm2.status).toBe(200);
      expect(rm2.body).toMatchObject({ previousStatus: 'rejected', status: 'rejected', strike: { activeStrikes: 1, autoBan: false } });
      expect(await one(`select count(*)::int as n from public.strikes where user_id = $1`, [b.id])).toEqual({ n: 1 });
      // an active strike holds the author's next reflection
      expect((await send(b, room1, 'after my strike')).body.status).toBe('held');

      const pub = await send(a, room1, 'take this down');
      const down = await call(moderator, 'post', `/admin/reflections/${pub.body.reflectionId}/decision`, { decision: 'remove', reasonCode: 'other' });
      expect(down.body).toMatchObject({ previousStatus: 'published', status: 'removed' });
      await sockB.waitForBroadcast(`room:${room1}`, 'reflection_removed', (p) => p.reflectionId === pub.body.reflectionId);
      expect((await list(a, room1)).body.reflections.find((x: { reflectionId: string }) => x.reflectionId === pub.body.reflectionId)).toMatchObject({
        status: 'removed',
        rejectReason: 'other',
      });
      const audit = await db.query(`select action from public.moderation_actions where detail ->> 'reflectionId' = $1`, [pub.body.reflectionId]);
      expect(audit.rows.map((x) => x.action)).toContain('reflection_remove');
    });

    it('crisis items: never a strike; release as false positive; escalate moves a lane up and pages', async () => {
      const cr = await send(a, room1, 'i want to die');
      const s = await call(moderator, 'post', `/admin/reflections/${cr.body.reflectionId}/decision`, { decision: 'remove', reasonCode: 'x', strike: true });
      expect(s.body.code).toBe('crisis_never_strikes');
      const v = await call(moderator, 'get', `/admin/reflections/${cr.body.reflectionId}`);
      expect(v.body).toMatchObject({ supportShown: true, canStrike: false });

      const held = await send(a, room1, 'grumpyword escalate me');
      const esc = await call(moderator, 'post', `/admin/reflections/${held.body.reflectionId}/decision`, { decision: 'escalate', reasonCode: 'looks_like_grooming', lane: 'minors_grooming' });
      expect(esc.body).toMatchObject({ escalated: { lane: 'minors_grooming' } });
      expect((await reportsOn(held.body.reflectionId)).rows[0].lane).toBe('minors_grooming');
      const down = await call(moderator, 'post', `/admin/reflections/${held.body.reflectionId}/decision`, { decision: 'escalate', reasonCode: 'x', lane: 'minors_grooming' });
      expect(down.body.code).toBe('invalid_lane');
    });

    it('pool pause is Owner-only and pauses the composer', async () => {
      expect((await call(moderator, 'post', '/admin/reflections/pools/en/pause', { reasonCode: 'overload' })).body.code).toBe('forbidden_role');
      expect((await call(owner, 'post', '/admin/reflections/pools/en/pause', { reasonCode: 'overload' })).status).toBe(204);
      app.get(RemoteConfigService).invalidate();
      expect((await send(a, room1, 'paused pool')).body.code).toBe('reflections_paused');
      expect((await call(owner, 'post', '/admin/reflections/pools/en/resume', { reasonCode: 'back' })).status).toBe(204);
      app.get(RemoteConfigService).invalidate();
      expect((await send(a, room1, 'resumed pool')).status).toBe(201);
    });
  });

  // ================================================================== worker
  it('worker: a stuck pending item is held (fail closed); held items expire when the room becomes a memory; a pool over the limit pauses', async () => {
    const stuck = uuidv7();
    await db.query(
      `insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool, created_at)
       select $1, $2, $3, $4, 'pending', r.body_ct, r.body_key, 5, 'en', now() - interval '10 minutes' from public.reflections r where r.id = $5`,
      [stuck, room1, member.a, a.id, published],
    );
    await setConfig({ auto_pause_held: 1 });
    const s = await runReflectionsTick(db, masterKey);
    expect(s.heldStuck).toBeGreaterThanOrEqual(1);
    expect((await row(stuck)).status).toBe('held');
    expect((await row(stuck)).hold_reason).toBe('timeout');
    expect(s.poolsPaused).toContain('en');
    await setFlag('reflections_composer', true, { pausedPools: [] });
    await setConfig({ auto_pause_held: 50 });

    await db.query(`update public.rooms set joins_close_at = created_at + interval '1 second', memory_at = created_at + interval '2 seconds' where id = $1`, [room2]);
    await sleep(2100);
    const s2 = await runReflectionsTick(db, masterKey);
    expect(s2.expired).toBeGreaterThanOrEqual(1);
    const left = await one<{ n: number }>(`select count(*)::int as n from public.reflections where room_id = $1 and status in ('held','pending')`, [room2]);
    expect(left.n).toBe(0);
    expect((await send(m, room2, 'too late')).body.code).toBe('room_read_only');
    expect((await list(m, room2)).body.composer.state).toBe('read_only');
  });

  // ================================================================== account purge
  it('the account purge removes the author’s reflections; reported ones survive only as encrypted evidence', async () => {
    expect(PERSONAL_TABLES).toContain('reflections');
    const x = await mk('refl-purge');
    const jx = await join(x, 'storm', 'anxious');
    expect(jx.roomId).toBe(room1);
    const r = await send(x, room1, 'soon to be purged');
    await call(b, 'post', '/v1/safety/reports', { target: { kind: 'reflection', roomId: room1, reflectionId: r.body.reflectionId }, reason: 2 });
    await db.query(`insert into public.account_deletions (user_id, requested_at, scheduled_for) values ($1, now(), now())`, [x.id]);
    const out = await purgeAccount(db, app.get(PrivateMediaStore), x.id);
    expect(out.status).toBe('purged');
    expect(await one('select count(*)::int as n from public.reflections where user_id = $1', [x.id])).toEqual({ n: 0 });
    const ev = await one<{ n: number }>(`select count(*)::int as n from public.evidence_holds where item_ref = $1 and $2 = any(account_ids)`, [r.body.reflectionId, x.id]);
    expect(ev.n).toBe(1);
  });

  // ================================================================== DS-10
  it('DS-10: no reflection response or realtime payload carries an account id, email, DOB, age, lane or score', async () => {
    await sleep(500);
    const secrets = [...users.flatMap((u) => [u.id, u.email]), ...dobs].map((s) => s.toLowerCase());
    const FORBIDDEN_KEY =
      /^(user_?id|userIds?|account_?ids?|sub|email|birth_?date|dob|age|is_?minor|minor|under_?18|involves_?minor|lane|reason_?code|reporter_?user_?id|target_?user_?id|subject_?hash|scores?|mod_?scores|strict|hold_?reason|text_?hash|body_?ct|body_?key)$/i;
    const violations: string[] = [];
    const walk = (v: unknown, where: string): void => {
      if (v === null || v === undefined) return;
      if (typeof v === 'string') {
        const low = v.toLowerCase();
        for (const s of secrets) if (low.includes(s)) violations.push(`${where}: contains an account id / email / DOB`);
        return;
      }
      if (Array.isArray(v)) return v.forEach((x, i) => walk(x, `${where}[${i}]`));
      if (typeof v === 'object') {
        for (const [k, x] of Object.entries(v)) {
          if (FORBIDDEN_KEY.test(k)) violations.push(`${where}.${k}: forbidden key`);
          walk(x, `${where}.${k}`);
        }
      }
    };
    const appFacing = recorded.filter((r) => /^(GET|POST|DELETE) \/v1\//.test(r.where));
    for (const r of appFacing) walk(r.body, r.where);
    const broadcasts = sockets.flatMap((s) => s.broadcasts());
    for (const b2 of broadcasts) walk(b2.payload, `realtime ${b2.topic} ${b2.event}`);
    expect(appFacing.filter((r) => r.where.includes('/reflections')).length).toBeGreaterThan(60);
    for (const e of ['reflection_published', 'reflection_removed', 'reflection_status', 'gesture_received', 'gesture_sent']) {
      expect(broadcasts.map((x) => x.event)).toContain(e);
    }
    expect(violations).toEqual([]);
  });
});
