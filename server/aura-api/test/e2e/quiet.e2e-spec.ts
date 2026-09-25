/**
 * F16 Quiet Together + the Lantern Hour wind-down, end to end against the live local stack: NestJS app, Postgres
 * (migration 20261005000027), Supabase Auth (real ES256 tokens) and Supabase Realtime (the private `quiet:<id>` topic
 * authorised by RLS on realtime.messages, read-only for members; `room:<id>` for the wind-down's room total).
 *
 * Shared-stack etiquette: no global row is changed (flags, quiet_config, matching_config). Kill switches are exercised
 * by stubbing the flag readers; block ends by moving this suite's OWN sessions in time; the wind-down on this suite's
 * OWN room (seated by SQL, capacity = its members) through the services with an injected clock inside a simulated
 * Lantern Hour. Only this suite's rows are deleted afterwards.
 *
 * The last test is REQ-QUIET-01's exit criterion (20-timeline weeks 37–42): "no member list in any Quiet Together
 * payload" — every recorded response and realtime payload is scanned.
 */
import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import * as quietFlags from '../../src/quiet/quiet-flags';
import { runQuietLifecycle } from '../../src/quiet/quiet-lifecycle';
import { loadMatchingConfig, type MatchingConfig } from '../../src/rooms/matching-config';
import { lanternWindow, TZ_REGIONS, type TzRegion } from '../../src/rooms/regions';
import { tickRoom } from '../../src/rooms/room-lifecycle';
import * as windDown from '../../src/rooms/wind-down';
import { WindDownService } from '../../src/rooms/wind-down.service';
import { RealtimeClient } from './realtime';
import { bootApp, createUser, dbPool, deleteUser, type TestUser } from './support';

jest.setTimeout(120_000);

const ADULT_DOB = '1998-07-21';
const MINOR_DOB = `${new Date().getUTCFullYear() - 15}-03-03`;
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;

type Method = 'get' | 'post' | 'delete';

describe('Quiet Together + Lantern Hour wind-down (e2e, live local Supabase + Realtime)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  const sockets: RealtimeClient[] = [];
  const recorded: Array<{ where: string; body: unknown }> = [];
  const sessions = new Set<string>();
  const rooms: string[] = [];
  const dobs = new Set<string>([ADULT_DOB, MINOR_DOB]);

  const http = () => request(app.getHttpServer());
  async function call(u: TestUser, method: Method, path: string, body?: unknown): Promise<request.Response> {
    let r = http()[method](path).set('Authorization', `Bearer ${u.token}`);
    if (body !== undefined) r = r.send(body as object);
    const res = await r;
    recorded.push({ where: `${method.toUpperCase()} ${path} → ${res.status}`, body: res.body });
    const sid = (res.body as { session?: { sessionId?: string } })?.session?.sessionId;
    if (sid) sessions.add(sid);
    return res;
  }
  const one = async <T = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T> => (await db.query(sql, params)).rows[0] as T;

  async function mk(label: string, opts: { dob?: string; timezone?: string; guidelines?: boolean } = {}): Promise<TestUser> {
    const u = await createUser(`quiet-${label}`);
    users.push(u);
    dobs.add(opts.dob ?? ADULT_DOB);
    await http()
      .post('/v1/profile')
      .set('Authorization', `Bearer ${u.token}`)
      .send({ birthDate: opts.dob ?? ADULT_DOB, uiLocale: 'en', timezone: opts.timezone ?? 'Asia/Kolkata', country: 'IN' })
      .expect(200);
    if (opts.guidelines !== false) {
      const { v } = await one<{ v: number }>('select guidelines_version::int as v from public.safety_config where id');
      expect((await call(u, 'post', '/v1/safety/guidelines/accept', { version: v })).status).toBe(200);
    }
    return u;
  }

  const join = (u: TestUser, mode: string, extra: Record<string, unknown> = {}) => call(u, 'post', '/v1/quiet/join', { mode, ...extra });
  const beat = (u: TestUser, sessionId: string) => call(u, 'post', `/v1/quiet/sessions/${sessionId}/heartbeat`);
  const gesture = (u: TestUser, sessionId: string, body: unknown) => call(u, 'post', `/v1/quiet/sessions/${sessionId}/gestures`, body);

  async function listen(u: TestUser, topic: string): Promise<RealtimeClient> {
    const s = await RealtimeClient.connect();
    sockets.push(s);
    expect(await s.join(topic, u.token)).toEqual({ ok: true });
    return s;
  }

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    for (const s of sockets) s.close();
    if (db) {
      const ids = users.map((u) => u.id);
      const mine = `select id from public.reports where reporter_user_id = any($1::uuid[]) or target_user_id = any($1::uuid[])
                     or (target_kind = 'quiet_session' and target_ref = any($2::uuid[]))`;
      const sids = [...sessions];
      await db.query(`delete from public.evidence_holds where report_id in (${mine}) or account_ids && $1::uuid[]`, [ids, sids]);
      await db.query(`delete from public.reports where id in (${mine})`, [ids, sids]);
      await db.query('delete from public.sanctions where user_id = any($1::uuid[])', [ids]);
      await db.query('delete from public.quiet_sessions where id = any($1::uuid[])', [sids]);
      if (rooms.length) await db.query('delete from public.rooms where id = any($1::uuid[])', [rooms]);
    }
    await Promise.all(users.map((u) => deleteUser(u.id)));
    await db?.end();
    await app?.close();
  });

  let a: TestUser;
  let b: TestUser;
  let study: string;
  let socketB: RealtimeClient;

  // ================================================================== validation
  it('401 without a token; 400 on bad or extra fields; 409 guidelines first; 404 on strangers’ sessions', async () => {
    await http().post('/v1/quiet/join').send({ mode: 'study' }).expect(401);
    const g = await mk('guidelines', { guidelines: false });
    const r = await join(g, 'study');
    expect(r.status).toBe(409);
    expect(r.body.code).toBe('guidelines_required');
    a = await mk('a');
    expect((await join(a, 'party')).status).toBe(400);
    expect((await join(a, 'study', { note: 'hello' })).status).toBe(400); // strict: no text anywhere
    expect((await join(a, 'study', { timezone: 'Not/AZone' })).status).toBe(400);
    expect((await beat(a, randomUUID())).status).toBe(404);
    expect((await beat(a, 'nope')).status).toBe(404);
    expect((await call(a, 'post', `/v1/quiet/sessions/${randomUUID()}/leave`)).status).toBe(204); // idempotent no-op
  });

  // ================================================================== REQ-QUIET-01 join, count
  it('REQ-QUIET-01: drop in at any minute; the count shows in the join response; blocks are on the region clock', async () => {
    const t = Date.now();
    const ra = await join(a, 'study');
    expect(ra.status).toBe(200);
    expect(Date.now() - t).toBeLessThan(1000); // "shows the count within 1 s"
    const s = ra.body.session;
    study = s.sessionId;
    expect(s.count).toBeGreaterThanOrEqual(1);
    expect(s.mode).toBe('study');
    // south_asia (+5:30): blocks start at hh:30 UTC and last 60 minutes; `now` is inside.
    expect(new Date(s.t0Ms).getUTCMinutes()).toBe(30);
    expect(s.endsAtMs - s.t0Ms).toBe(3_600_000);
    expect(s.serverTimeMs).toBeGreaterThanOrEqual(s.t0Ms);
    expect(s.serverTimeMs).toBeLessThan(s.endsAtMs);
    expect(s.rhythm).toEqual({ focusMin: 25, breakMin: 5 });
    expect(s.realtime).toEqual({ topic: `quiet:${study}` });
    expect(s.soundscape.stems.length).toBeGreaterThan(0);
    expect(ra.headers['cache-control']).toBe('no-store');

    b = await mk('b');
    socketB = undefined as unknown as RealtimeClient;
    const rb = await join(b, 'study');
    expect(rb.body.session.sessionId).toBe(study);
    expect(rb.body.session.count).toBe(s.count + 1);
    expect(rb.body.session.soundscape).toEqual(s.soundscape); // the same mix and t0 on every phone
    expect(rb.body.session.t0Ms).toBe(s.t0Ms);
    // Idempotent: the same mode again → the same session.
    expect((await join(a, 'study')).body.session.sessionId).toBe(study);
  });

  it('realtime: members read quiet:<id>; strangers are refused; nobody can broadcast on it', async () => {
    socketB = await listen(b, `quiet:${study}`);
    const stranger = await mk('stranger');
    const s = await RealtimeClient.connect();
    sockets.push(s);
    const refused = await s.join(`quiet:${study}`, stranger.token);
    expect(refused.ok).toBe(false);
    const writer = await RealtimeClient.connect();
    sockets.push(writer);
    expect(await writer.join(`quiet:${study}`, a.token, { ack: true })).toEqual({ ok: true });
    expect(await writer.clientBroadcast(`quiet:${study}`, 'gesture', { type: 'hug' })).not.toBe('ok');
  });

  // ================================================================== REQ-QUIET-02 gestures
  it('REQ-QUIET-02: a preset to the whole session, unnamed; text or a target is refused; limits drop silently', async () => {
    expect((await gesture(a, study, { type: 'light_a_candle', text: 'hi' })).status).toBe(400);
    expect((await gesture(a, study, { type: 'hug', toMemberId: randomUUID() })).status).toBe(400);
    expect((await gesture(a, study, { type: 'hug', target: 'member' })).status).toBe(400);
    expect((await gesture(a, study, { type: 'hello' })).status).toBe(400);

    const sent = await gesture(a, study, { type: 'light_a_candle' });
    expect(sent.status).toBe(202);
    const got = await socketB.waitForBroadcast(`quiet:${study}`, 'gesture', (p) => p.gestureId === sent.body.gestureId);
    expect(Object.keys(got.payload).sort()).toEqual(['at', 'gestureId', 'id', 'type']); // `id`: Realtime's own message id
    expect(got.payload.type).toBe('light_a_candle');

    // Within 10 s: the same 202, but dropped (never broadcast).
    const again = await gesture(a, study, { type: 'warm_tea' });
    expect(again.status).toBe(202);
    expect((await one<{ d: string | null }>('select dropped as d from public.quiet_gestures where id = $1', [again.body.gestureId])).d).toBe('over_limit');
    await sleep(800);
    expect(socketB.broadcasts(`quiet:${study}`, 'gesture').some((x) => x.payload.gestureId === again.body.gestureId)).toBe(false);
    // Not a member → 404.
    const c = await mk('c');
    expect((await gesture(c, study, { type: 'hug' })).status).toBe(404);
  });

  it('3 limit hits in 24 h: shadow-muted for 24 h and one spam-lane item (the sender still sees 202)', async () => {
    const f = await mk('flood');
    const s = (await join(f, 'rest')).body.session.sessionId as string;
    const first = await gesture(f, s, { type: 'hug' });
    expect(first.status).toBe(202);
    for (let i = 0; i < 3; i++) expect((await gesture(f, s, { type: 'hug' })).status).toBe(202);
    const muted = await one<{ n: number }>(
      `select count(*)::int as n from public.sanctions where user_id = $1 and kind = 'gesture_shadow_mute' and lifted_at is null and ends_at > now()`,
      [f.id],
    );
    expect(muted.n).toBe(1);
    const rep = await one<{ n: number; kind: string; signal: string; lane: string }>(
      `select count(*)::int as n, max(target_kind) as kind, max(auto_signal) as signal, max(lane) as lane
         from public.reports where target_user_id = $1 and source = 'auto'`,
      [f.id],
    );
    expect(rep).toEqual({ n: 1, kind: 'quiet_session', signal: 'gesture_flood', lane: 'spam' });
    // Shadow-muted: after the interval, a gesture answers like a delivery but is stored as dropped.
    await db.query(`update public.quiet_gestures set created_at = created_at - interval '1 minute' where session_id = $1`, [s]);
    const later = await gesture(f, s, { type: 'stargaze' });
    expect(later.status).toBe(202);
    expect((await one<{ d: string | null }>('select dropped as d from public.quiet_gestures where id = $1', [later.body.gestureId])).d).toBe('shadow_muted');
  });

  // ================================================================== placement: blocks, merge
  it('REQ-QUIET-06: a blocked pair (either direction) is never placed together', async () => {
    const people = await Promise.all(['p1', 'p2', 'p3', 'p4', 'p5', 'p6'].map((l) => mk(l)));
    const [p1, p2, p3, p4, p5, p6] = people;
    await db.query(
      `insert into public.blocks (blocker_user_id, blocked_user_id) values ($1, $2), ($3, $4), ($5, $6), ($2, $5)`,
      [p1.id, p2.id, p4.id, p3.id, p5.id, p6.id],
    );
    const placed = new Map<string, string>();
    for (const p of people) placed.set(p.id, (await join(p, 'read')).body.session.sessionId);
    const pairs: Array<[TestUser, TestUser]> = [
      [p1, p2],
      [p3, p4],
      [p5, p6],
      [p2, p5],
    ];
    for (const [x, y] of pairs) expect(placed.get(x.id)).not.toBe(placed.get(y.id));
    // Unblocked people still share a session (the fullest one with room).
    expect(new Set(placed.values()).size).toBeLessThan(people.length);
  });

  it('a thin region merges into the busiest one (Chicago → the live south_asia study session)', async () => {
    const far = await mk('chicago', { timezone: 'America/Chicago' });
    await beat(a, study);
    await beat(b, study);
    const r = await join(far, 'study');
    // Americas has nobody studying live; south_asia has a and b → the same session (not split by language or region).
    const americas = await one<{ n: number }>(
      `select count(*)::int as n from public.quiet_members m join public.quiet_sessions s on s.id = m.session_id
        where s.mode = 'study' and s.tz_region = 'americas' and m.left_at is null and s.ends_at > now() and m.user_id <> $1`,
      [far.id],
    );
    if (americas.n < 3) expect(r.body.session.sessionId).toBe(study);
    await call(far, 'post', `/v1/quiet/sessions/${r.body.session.sessionId}/leave`);
  });

  // ================================================================== heartbeat, next block, leave
  it('the heartbeat keeps you counted; at the block’s end it moves you into the next block (a new session)', async () => {
    const hb = await beat(b, study);
    expect(hb.status).toBe(200);
    expect(hb.body.session.sessionId).toBe(study);
    // Move this suite's own session so its block ended a minute ago (not yet stale).
    await db.query(
      `update public.quiet_sessions set t0 = now() - interval '61 minutes', ends_at = now() - interval '1 minute' where id = $1`,
      [study],
    );
    expect((await gesture(b, study, { type: 'hug' })).body.code).toBe('block_over');
    const moved = await beat(b, study);
    expect(moved.status).toBe(200);
    expect(moved.body.session.sessionId).not.toBe(study);
    expect(moved.body.session.mode).toBe('study');
    expect(moved.body.session.t0Ms).toBeLessThanOrEqual(moved.body.session.serverTimeMs);
    expect(moved.body.session.endsAtMs).toBeGreaterThan(moved.body.session.serverTimeMs);
    // The old membership is closed; heartbeating the old session again is a quiet 404 (the phone rejoins).
    expect((await beat(b, study)).status).toBe(404);
    // a follows too.
    const movedA = await beat(a, study);
    expect(movedA.body.session.sessionId).toBe(moved.body.session.sessionId);
    study = moved.body.session.sessionId;
  });

  it('REQ-QUIET-04: leaving costs nothing — 204, the count drops, and nothing is earned or recorded for time spent', async () => {
    const personal = async (u: TestUser) =>
      one<{ n: number }>(
        `select (select count(*) from public.starlight_ledger where user_id = $1)
              + (select count(*) from public.active_days where user_id = $1)
              + (select count(*) from public.streak_state where user_id = $1)
              + (select count(*) from public.sanctuary_sessions where user_id = $1)
              + (select count(*) from public.notification_activity where user_id = $1) as n`,
        [u.id],
      );
    const before = await personal(b);
    const countBefore = (await beat(a, study)).body.session.count as number;
    expect((await call(b, 'post', `/v1/quiet/sessions/${study}/leave`)).status).toBe(204);
    expect((await call(b, 'post', `/v1/quiet/sessions/${study}/leave`)).status).toBe(204);
    expect((await beat(a, study)).body.session.count).toBe(countBefore - 1);
    expect((await personal(b)).n).toBe(before.n);
    expect((await beat(b, study)).status).toBe(404);
    // Dropping in again works at any minute.
    expect((await join(b, 'study')).body.session.sessionId).toBe(study);
  });

  // ================================================================== kill switch (stubbed: global flags stay untouched)
  it('kill switch per region: quiet_paused on join (and at a block’s end); the switch reads the region', async () => {
    const spy = jest.spyOn(quietFlags, 'regionPaused').mockImplementation(async (_q, flag, region) => flag === 'quiet_enabled' && region === 'south_asia');
    const u = await mk('paused');
    const r = await join(u, 'rest');
    expect(r.status).toBe(503);
    expect(r.body.code).toBe('quiet_paused');
    const elsewhere = await join(u, 'rest', { timezone: 'Europe/Berlin' });
    expect(elsewhere.status).toBe(200);
    spy.mockRestore();
    await call(u, 'post', `/v1/quiet/sessions/${elsewhere.body.session.sessionId}/leave`);
  });

  it('suspended accounts: 403 rooms_suspended (every stranger surface), but reporting still works', async () => {
    const s = await mk('suspended');
    const sid = (await join(s, 'read')).body.session.sessionId as string;
    await db.query(`insert into public.sanctions (user_id, kind, reason_code, source, ends_at) values ($1, 'room_suspension', 'e2e', 'moderator', now() + interval '1 day')`, [s.id]);
    expect((await join(s, 'read')).body.code).toBe('rooms_suspended');
    expect((await beat(s, sid)).body.code).toBe('rooms_suspended');
    expect((await call(s, 'post', `/v1/quiet/sessions/${sid}/reports`, { reason: 8 })).status).toBe(201);
  });

  // ================================================================== report a problem here
  it('"Report a problem here": F9 lanes, 201 then 200, subjects = gesture senders (never the reporter), evidence held', async () => {
    await sleep(10_500); // a's gesture interval
    const g = await gesture(a, study, { type: 'soft_rain' });
    expect(g.status).toBe(202);
    const r1 = await call(b, 'post', `/v1/quiet/sessions/${study}/reports`, { reason: 2, note: 'someone keeps flooding' });
    expect(r1.status).toBe(201);
    expect(r1.body).toEqual({ reportId: expect.any(String), showHelplines: false });
    const r2 = await call(b, 'post', `/v1/quiet/sessions/${study}/reports`, { reason: 2 });
    expect(r2.status).toBe(200);
    expect(r2.body.reportId).toBe(r1.body.reportId);
    const rep = await one<{ target_kind: string; lane: string; target_ref: string; hold: string }>(
      'select target_kind, lane, target_ref, evidence_hold_id as hold from public.reports where id = $1',
      [r1.body.reportId],
    );
    expect(rep).toMatchObject({ target_kind: 'quiet_session', lane: 'harassment', target_ref: study });
    const hold = await one<{ item_kind: string; account_ids: string[]; snapshot: { gestures: unknown[]; members: Array<{ accountId: string | null; isReporter: boolean }> } }>(
      'select item_kind, account_ids, snapshot from public.evidence_holds where id = $1',
      [rep.hold],
    );
    expect(hold.item_kind).toBe('quiet_session');
    expect(hold.account_ids).toContain(a.id);
    expect(hold.account_ids).not.toContain(b.id);
    expect(hold.snapshot.gestures.length).toBeGreaterThan(0);
    expect(hold.snapshot.members.find((m) => m.isReporter)?.accountId ?? null).toBeNull();
    const crisis = await call(b, 'post', `/v1/quiet/sessions/${study}/reports`, { reason: 1 });
    expect(crisis.body.showHelplines).toBe(true);
    expect((await call(b, 'post', `/v1/quiet/sessions/${study}/reports`, { reason: 12 })).status).toBe(400);
    expect((await call(b, 'post', `/v1/quiet/sessions/${randomUUID()}/reports`, { reason: 2 })).status).toBe(404);
  });

  it('a minor involved → Minors & grooming, invisibly (nothing in the response says so)', async () => {
    const minor = await mk('minor', { dob: MINOR_DOB });
    const sid = (await join(minor, 'study')).body.session.sessionId as string;
    const r = await call(minor, 'post', `/v1/quiet/sessions/${sid}/reports`, { reason: 6 });
    expect(r.status).toBe(201);
    expect(Object.keys(r.body).sort()).toEqual(['reportId', 'showHelplines']);
    expect((await one<{ lane: string }>('select lane from public.reports where id = $1', [r.body.reportId])).lane).toBe('minors_grooming');
  });

  // ================================================================== worker tick
  it('the tick: a live count on quiet:<id> every 30 s; quiet memberships closed; sessions purged 7 days on', async () => {
    const sock = await listen(a, `quiet:${study}`);
    const s = await runQuietLifecycle(db, new Date(), [study]);
    expect(s.errors).toEqual([]);
    const c = await sock.waitForBroadcast(`quiet:${study}`, 'count');
    expect(Object.keys(c.payload).sort()).toEqual(['at', 'count', 'id']);
    expect(c.payload.count).toBeGreaterThanOrEqual(1);

    const q = await mk('stale');
    const sid = (await join(q, 'rest', { timezone: 'Asia/Tokyo' })).body.session.sessionId as string;
    await db.query(`update public.quiet_members set last_seen_at = now() - interval '11 minutes', joined_at = now() - interval '12 minutes' where user_id = $1`, [q.id]);
    await runQuietLifecycle(db, new Date(), [sid]);
    expect((await one<{ n: number }>('select count(*)::int as n from public.quiet_members where user_id = $1 and left_at is null', [q.id])).n).toBe(0);
    expect((await beat(q, sid)).status).toBe(404);

    await db.query(`update public.quiet_sessions set t0 = now() - interval '9 days', ends_at = now() - interval '8 days', purge_at = now() - interval '1 day' where id = $1`, [sid]);
    const p = await runQuietLifecycle(db, new Date(), [sid]);
    expect(p.purged).toBe(1);
    expect((await one<{ n: number }>('select count(*)::int as n from public.quiet_members where session_id = $1', [sid])).n).toBe(0);
  });

  // ================================================================== Lantern Hour wind-down (REQ-QUIET-07)
  describe('Lantern Hour wind-down', () => {
    let wd: WindDownService;
    let cfg: MatchingConfig;
    let region: TzRegion;
    let before: Date; // Lantern Hour, before 22:30 on the region clock
    let during: Date; // 22:35
    let after: Date; // 22:55 (still Lantern Hour; the wind-down has ended)
    const roomId = randomUUID();
    let w1: TestUser;
    let w2: TestUser;
    let w3: TestUser;
    let roomSocket: RealtimeClient;

    beforeAll(async () => {
      wd = app.get(WindDownService);
      cfg = await loadMatchingConfig(db);
      const now = new Date();
      region = TZ_REGIONS.find((r) => !lanternWindow(r, now, cfg.lanternStart, cfg.lanternEnd).active)!;
      const w = lanternWindow(region, now, cfg.lanternStart, cfg.lanternEnd);
      before = new Date(w.startsAt.getTime() + 20 * 60_000);
      during = new Date(w.startsAt.getTime() + 95 * 60_000);
      after = new Date(w.startsAt.getTime() + 115 * 60_000);
      [w1, w2, w3] = await Promise.all([mk('wd-1'), mk('wd-2'), mk('wd-3')]);
      await db.query(
        `insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, capacity, status,
                                   created_at, opened_at, joins_close_at, memory_at, purge_at)
         values ($1, 'en', 'moonlight', $2, 'calm', 'midnight_observatory', 3, 'open',
                 $3::timestamptz - interval '1 hour', $3::timestamptz - interval '50 minutes', $3::timestamptz + interval '19 hours',
                 $3::timestamptz + interval '23 hours', $3::timestamptz + interval '23 hours' + interval '7 days')`,
        [roomId, region, before],
      );
      rooms.push(roomId);
      const names = ['Quiet Comet', 'Gentle Harbor', 'Soft Lantern'];
      for (const [i, u] of [w1, w2, w3].entries()) {
        await db.query(
          `insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
           values ($1, $2, $3, 'calm', 'moonlight', 'en', $4, 4, 'spark')`,
          [roomId, u.id, names[i], region],
        );
      }
      roomSocket = await listen(w3, `room:${roomId}`);
    });

    it('before 22:30: "soon" with the times; joining answers 409 wind_down_closed', async () => {
      const r = await wd.get(w1.id, roomId, before);
      expect(r.windDown?.state).toBe('soon');
      expect(r.windDown?.count).toBe(0);
      expect(r.windDown?.joined).toBe(false);
      expect(r.windDown!.endsAtMs - r.windDown!.startsAtMs).toBe(20 * 60_000);
      await expect(wd.join(w1.id, roomId, before)).rejects.toMatchObject({ code: 'wind_down_closed' });
    });

    it('opted-in members start the same track from the server t0, with the Calm pacer and preset cues; the room sees "N winding down"', async () => {
      const r1 = await wd.join(w1.id, roomId, during);
      const r2 = await wd.join(w2.id, roomId, new Date(during.getTime() + 60_000));
      expect(r1.windDown).toMatchObject({ state: 'open', joined: true, count: 1, pacer: { pattern: 'calm', inhaleMs: 4000, exhaleMs: 6000 } });
      expect(r2.windDown?.count).toBe(2);
      expect(r2.windDown?.startsAtMs).toBe(r1.windDown?.startsAtMs); // one common t0
      expect(r2.windDown?.soundscape).toEqual(r1.windDown?.soundscape); // one ambient track
      expect(r1.windDown?.cues.map((c) => c.key)).toContain('day_quieter');
      const signal = await roomSocket.waitForBroadcast(`room:${roomId}`, 'wind_down', (p) => p.count === 2);
      expect(Object.keys(signal.payload).sort()).toEqual(['at', 'count', 'id', 'state']);
      // Idempotent; a third member sees the total, not who.
      expect((await wd.join(w1.id, roomId, during)).windDown?.count).toBe(2);
      const w3view = await wd.get(w3.id, roomId, during);
      expect(w3view.windDown).toMatchObject({ state: 'open', count: 2, joined: false });
      expect(JSON.stringify(w3view)).not.toMatch(/Quiet Comet|Gentle Harbor|member|user/i);
    });

    it('leaving costs nothing: the count drops; the tick ends it after 20 minutes', async () => {
      await wd.leave(w1.id, roomId, during);
      await roomSocket.waitForBroadcast(`room:${roomId}`, 'wind_down', (p) => p.count === 1);
      expect((await wd.get(w1.id, roomId, during)).windDown).toMatchObject({ joined: false, count: 1 });
      await tickRoom(db, roomId, after, cfg);
      await roomSocket.waitForBroadcast(`room:${roomId}`, 'wind_down', (p) => p.state === 'ended');
      expect((await wd.get(w1.id, roomId, after)).windDown).toBeNull();
    });

    it('kill switch per region → 503 wind_down_paused and no offer; HTTP: members only', async () => {
      const spy = jest.spyOn(windDown, 'windDownPausedFor').mockResolvedValue(true);
      await expect(wd.join(w1.id, roomId, during)).rejects.toMatchObject({ code: 'wind_down_paused' });
      spy.mockRestore();
      const res = await call(w1, 'get', `/v1/rooms/${roomId}/wind-down`);
      expect(res.status).toBe(200);
      expect(res.body.windDown === null || typeof res.body.windDown === 'object').toBe(true);
      expect(res.body.serverTimeMs).toEqual(expect.any(Number));
      expect((await call(a, 'get', `/v1/rooms/${roomId}/wind-down`)).status).toBe(404);
      expect((await call(a, 'post', `/v1/rooms/${roomId}/wind-down`)).status).toBe(404);
      expect((await call(w1, 'delete', `/v1/rooms/${roomId}/wind-down`)).status).toBe(204);
    });
  });

  // ================================================================== REQ-QUIET-01 exit criterion
  it('REQ-QUIET-01: no member list, member id, pseudonym, account id, age or mood in any Quiet Together payload', async () => {
    await sleep(500);
    const memberIds = (await db.query<{ member_id: string }>('select member_id from public.quiet_members where session_id = any($1::uuid[])', [[...sessions]])).rows.map(
      (r) => r.member_id,
    );
    const secrets = [...users.flatMap((u) => [u.id, u.email]), ...dobs, ...memberIds].map((s) => s.toLowerCase());
    const FORBIDDEN_KEY =
      /^(members?|member_?ids?|memberList|pseudonyms?|user_?ids?|userIds?|account_?ids?|sub|email|birth_?date|dob|age|is_?minor|minor|under_?18|involves_?minor|lane|mood|mood_?chip|silhouettes?|stage|hue|from_?member_?id|from_?pseudonym|sender)$/i;
    const violations: string[] = [];
    const walk = (v: unknown, where: string): void => {
      if (v === null || v === undefined) return;
      if (typeof v === 'string') {
        const low = v.toLowerCase();
        for (const s of secrets) if (low.includes(s)) violations.push(`${where}: contains an account / member id, email or DOB`);
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
    const quiet = recorded.filter((r) => r.where.includes('/v1/quiet') || r.where.includes('/wind-down'));
    for (const r of quiet) walk(r.body, r.where);
    const broadcasts = sockets.flatMap((s) => s.broadcasts()).filter((b) => b.topic.startsWith('quiet:') || b.event === 'wind_down');
    for (const b of broadcasts) walk(b.payload, `realtime ${b.topic} ${b.event}`);
    expect(quiet.length).toBeGreaterThan(40);
    expect(new Set(broadcasts.map((b) => b.event))).toEqual(new Set(['gesture', 'count', 'wind_down']));
    // Session payloads: the only UUID in a session view is its own session id.
    for (const r of quiet) {
      const s = (r.body as { session?: { sessionId: string } }).session;
      if (s) expect(new Set(JSON.stringify(s).match(UUID))).toEqual(new Set([s.sessionId]));
    }
    expect(violations).toEqual([]);
  });
});
