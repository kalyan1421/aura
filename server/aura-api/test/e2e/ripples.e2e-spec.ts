/**
 * F7 Breath Ripples, end to end against the live local stack: NestJS app, Postgres (migration 20261005000021), Supabase
 * Auth (real ES256 tokens) and Supabase Realtime (private `game:` / `ripples:` channels authorised by RLS on
 * realtime.messages; players broadcast client to client, the server with realtime.send()).
 *
 * Global rows (flags, ripple_config, matching_config) are never changed: start rules are exercised by backdating this
 * suite's own tickets / invites / sessions. The last test scans every recorded response and realtime payload for
 * account ids, emails, DOBs and age/lane keys (the DS-10 contract test).
 */
import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { uuidv7 } from '../../src/common/uuid';
import { runRippleLifecycle } from '../../src/ripples/ripple-lifecycle';
import { RealtimeClient } from './realtime';
import { bootApp, createUser, dbPool, deleteUser, type TestUser } from './support';

jest.setTimeout(90_000);

const ADULT_DOB = '1998-07-21';
const MINOR_DOB = `${new Date().getUTCFullYear() - 15}-03-03`;
const PSEUDONYM = /^[A-Z][a-z]{1,14} [A-Z][a-z]{1,14}$/;
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

type Method = 'get' | 'post' | 'put' | 'delete';

describe('Breath Ripples (e2e, live local Supabase + Realtime)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  const sockets: RealtimeClient[] = [];
  const recorded: Array<{ where: string; body: unknown }> = [];
  const rooms: string[] = [];
  const dobs = new Set<string>([ADULT_DOB, MINOR_DOB]);

  const http = () => request(app.getHttpServer());
  async function call(u: TestUser, method: Method, path: string, body?: unknown): Promise<request.Response> {
    let r = http()[method](path).set('Authorization', `Bearer ${u.token}`);
    if (body !== undefined) r = r.send(body as object);
    const res = await r;
    recorded.push({ where: `${method.toUpperCase()} ${path} → ${res.status}`, body: res.body });
    return res;
  }
  const one = async <T = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T> => (await db.query(sql, params)).rows[0] as T;

  async function mk(label: string, dob = ADULT_DOB): Promise<TestUser> {
    const u = await createUser(`ripples-${label}`);
    users.push(u);
    dobs.add(dob);
    await http().post('/v1/profile').set('Authorization', `Bearer ${u.token}`).send({ birthDate: dob, uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' }).expect(200);
    const { v } = await one<{ v: number }>('select guidelines_version::int as v from public.safety_config where id');
    expect((await call(u, 'post', '/v1/safety/guidelines/accept', { version: v })).status).toBe(200);
    return u;
  }

  const quick = (u: TestUser, ticketId: string) => call(u, 'post', '/v1/ripples/match', { ticketId, entry: 'quick' });
  const fromRoom = (u: TestUser, ticketId: string, roomId: string) => call(u, 'post', '/v1/ripples/match', { ticketId, entry: 'room', roomId });
  /** Time travel for this suite's own tickets only (the queue is global; nothing else is touched). */
  const backdate = (ticketIds: string[], seconds: number) =>
    db.query(
      `update public.ripple_tickets set enqueued_at = enqueued_at - make_interval(secs => $2) where id = any($1::uuid[])`,
      [ticketIds, seconds],
    );
  /** Move a session into the past so the server clock allows `seconds` of it. */
  const age = (sessionId: string, seconds: number) =>
    db.query(
      `update public.ripple_sessions set t0 = t0 - make_interval(secs => $2), ends_at = ends_at - make_interval(secs => $2) where id = $1`,
      [sessionId, seconds],
    );

  async function listen(u: TestUser, topic: string, ack = false): Promise<RealtimeClient> {
    const s = await RealtimeClient.connect();
    sockets.push(s);
    expect(await s.join(topic, u.token, { ack })).toEqual({ ok: true });
    return s;
  }

  /** Two people matched together through the early rule (8 s with 2 humans). */
  async function pair(a: TestUser, b: TestUser): Promise<{ sessionId: string; seatA: number; seatB: number; body: Record<string, unknown> }> {
    const [ta, tb] = [uuidv7(), uuidv7()];
    expect((await quick(a, ta)).body.status).toBe('waiting');
    expect((await quick(b, tb)).body.status).toBe('waiting');
    await backdate([ta, tb], 9);
    const ra = await quick(a, ta);
    expect(ra.body.status).toBe('matched');
    const rb = await quick(b, tb);
    expect(rb.body.status).toBe('matched');
    expect(rb.body.session.sessionId).toBe(ra.body.session.sessionId);
    return { sessionId: ra.body.session.sessionId, seatA: ra.body.session.mySeat, seatB: rb.body.session.mySeat, body: ra.body };
  }

  async function roomWith(members: TestUser[]): Promise<{ roomId: string; memberIds: string[] }> {
    const room = await one<{ id: string }>(
      `insert into public.rooms (language_pool, quadrant, tz_region, seed_mood_id, theme, opened_at, joins_close_at, memory_at, purge_at)
       values ('en', 'rain', 'south_asia', 'lonely', 'rain_sanctuary', now(), now() + interval '19 hours', now() + interval '23 hours',
               now() + interval '8 days') returning id`,
    );
    rooms.push(room.id);
    const names = ['Quiet Comet', 'Gentle Moon', 'Soft Star', 'Calm Tide'];
    const memberIds: string[] = [];
    for (const [i, u] of members.entries()) {
      const m = await one<{ member_id: string }>(
        `insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
         values ($1, $2, $3, 'lonely', 'rain', 'en', 'south_asia', 4, 'spark') returning member_id`,
        [room.id, u.id, names[i]],
      );
      memberIds.push(m.member_id);
    }
    return { roomId: room.id, memberIds };
  }

  const echoCount = async (): Promise<number> => (await one<{ n: number }>('select count(*)::int as n from echo_library.recordings')).n;

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
  });

  afterAll(async () => {
    for (const s of sockets) s.close();
    if (db) {
      const ids = users.map((u) => u.id);
      const mine = `select id from public.reports where reporter_user_id = any($1::uuid[]) or target_user_id = any($1::uuid[])`;
      await db.query(`delete from public.evidence_holds where report_id in (${mine}) or account_ids && $1::uuid[]`, [ids]);
      await db.query(`delete from public.reports where id in (${mine})`, [ids]);
      await db.query(`delete from public.ripple_sessions where id in (select session_id from public.ripple_seats where user_id = any($1::uuid[]))`, [ids]);
      if (rooms.length) await db.query('delete from public.rooms where id = any($1::uuid[])', [rooms]);
      // This suite's echoes carry its marker pattern (offsets of 7 steps): unlinked rows can only be found by content.
      await db.query(`delete from echo_library.recordings where offsets[1] = 7 and offsets[2] = -7`);
    }
    await Promise.all(users.map((u) => deleteUser(u.id)));
    await db?.end();
    await app?.close();
  });

  // ================================================================== validation
  it('401 without a token; 400 on bad bodies; 404 on strangers’ sessions', async () => {
    await http().post('/v1/ripples/match').send({}).expect(401);
    const u = await mk('validate');
    expect((await call(u, 'post', '/v1/ripples/match', { ticketId: 'nope', entry: 'quick' })).status).toBe(400);
    expect((await call(u, 'post', '/v1/ripples/match', { ticketId: uuidv7(), entry: 'room' })).status).toBe(400);
    expect((await call(u, 'post', '/v1/ripples/match', { ticketId: uuidv7(), entry: 'quick', roomId: randomUUID() })).status).toBe(400);
    expect((await call(u, 'get', `/v1/ripples/sessions/${randomUUID()}`)).status).toBe(404);
    expect((await call(u, 'post', '/v1/ripples/match', { ticketId: uuidv7(), entry: 'room', roomId: randomUUID() })).body.code).toBe('not_found');
  });

  // ================================================================== matching
  it('quick-match: waiting → matched at 8 s with 2 humans; guide / echo fill; pseudonyms; poll hint', async () => {
    const [a, b] = [await mk('early-a'), await mk('early-b')];
    const ta = uuidv7();
    const w = await quick(a, ta);
    expect(w.status).toBe(200);
    expect(w.body).toEqual({ status: 'waiting', ticketId: ta, pollAfterMs: expect.any(Number), serverTime: expect.any(String), serverTimeMs: expect.any(Number) });
    expect(w.body.pollAfterMs).toBeLessThanOrEqual(2000);
    // Same ticket again = a poll, not a second place in the queue.
    expect((await quick(a, ta)).body.status).toBe('waiting');
    expect((await one<{ n: number }>('select count(*)::int as n from public.ripple_tickets where user_id = $1', [a.id])).n).toBe(1);
    await call(a, 'delete', `/v1/ripples/match/${ta}`);

    const { body } = await pair(a, b);
    const s = body.session as Record<string, unknown> & { seats: Array<{ seat: number; kind: string; label: string | null }> };
    expect(s).toMatchObject({ entry: 'quick', startRule: 'early', settleMs: 10000, inhaleMs: 4000, exhaleMs: 6000, cycles: 16, fadeMs: 10000, humans: 2 });
    expect((s.endsAtMs as number) - (s.t0Ms as number)).toBe(180_000);
    expect(s.seats).toHaveLength(4);
    expect(s.seats.filter((x) => x.kind === 'human').map((x) => x.label)).toEqual([expect.stringMatching(PSEUDONYM), expect.stringMatching(PSEUDONYM)]);
    expect(s.seats.filter((x) => x.kind !== 'human').every((x) => x.label === null)).toBe(true);
    expect((s.echoes as number) + (s.guides as number)).toBe(2);
    expect(s.realtime).toEqual({ topic: `game:${s.sessionId}` });
  });

  it('REQ-GAME-01: one person alone starts at 20 s (no "no one found"); a blocked pair is never seated together', async () => {
    const [a, b] = [await mk('solo-a'), await mk('solo-b')];
    await db.query('insert into public.blocks (blocker_user_id, blocked_user_id) values ($1, $2)', [b.id, a.id]);
    const [ta, tb] = [uuidv7(), uuidv7()];
    await quick(a, ta);
    await quick(b, tb);
    await backdate([ta, tb], 10); // past 8 s: two humans, but blocked → nobody starts early
    expect((await quick(a, ta)).body.status).toBe('waiting');
    expect((await quick(b, tb)).body.status).toBe('waiting');
    await backdate([ta, tb], 11); // past 20 s: both start, apart
    const ra = await quick(a, ta);
    const rb = await quick(b, tb);
    expect(ra.body.status).toBe('matched');
    expect(rb.body.status).toBe('matched');
    expect(ra.body.session.sessionId).not.toBe(rb.body.session.sessionId);
    expect(ra.body.session).toMatchObject({ startRule: 'timeout', humans: 1 });
    const waited = await one<{ w: number }>('select waited_ms as w from public.ripple_seats where user_id = $1', [a.id]);
    expect(waited.w).toBeGreaterThanOrEqual(20_000);
  });

  // ================================================================== realtime
  it('game topic: seat holders only; breath events go client to client; leave dims into an echo; last leave ends it', async () => {
    const [a, b, c] = [await mk('rt-a'), await mk('rt-b'), await mk('rt-c')];
    const { sessionId, seatA, seatB } = await pair(a, b);
    const topic = `game:${sessionId}`;
    const sa = await listen(a, topic, true);
    const sb = await listen(b, topic);
    const outsider = await RealtimeClient.connect();
    sockets.push(outsider);
    expect((await outsider.join(topic, c.token)).ok).toBe(false);

    expect(await sa.clientBroadcast(topic, 'breath_state', { seat: seatA, phase: 'in', t: Date.now() })).toBe('ok'); // INSERT policy
    const got = await sb.waitForBroadcast(topic, 'breath_state');
    expect(got.payload).toMatchObject({ seat: seatA, phase: 'in', t: expect.any(Number) });

    // A leaves silently: B hears an echo, never "left".
    expect((await call(a, 'post', `/v1/ripples/sessions/${sessionId}/leave`)).status).toBe(204);
    const upd = await sb.waitForBroadcast(topic, 'seat_update');
    expect(upd.payload).toMatchObject({ seat: seatA, kind: 'echo', at: expect.any(String) });
    expect(Object.keys(upd.payload).sort()).toEqual(['at', 'id', 'kind', 'seat']); // `id` = Realtime's message id
    expect((await call(a, 'get', `/v1/ripples/sessions/${sessionId}`)).status).toBe(404);
    const view = await call(b, 'get', `/v1/ripples/sessions/${sessionId}`);
    expect(view.body.seats.find((x: { seat: number }) => x.seat === seatA)).toEqual({ seat: seatA, kind: 'echo', label: null });
    expect(view.body.mySeat).toBe(seatB);
    const late = await RealtimeClient.connect();
    sockets.push(late);
    expect((await late.join(topic, a.token)).ok).toBe(false); // left: no way back into the channel

    expect((await call(b, 'post', `/v1/ripples/sessions/${sessionId}/leave`)).status).toBe(204);
    const ended = await one<{ ended_at: Date | null }>('select ended_at from public.ripple_sessions where id = $1', [sessionId]);
    expect(ended.ended_at).not.toBeNull();
  });

  // ================================================================== room invites
  it('room invite: banner (block-filtered), room pseudonyms, starts at 20 s; parallel sessions for a blocked pair', async () => {
    const [a, b, c] = [await mk('inv-a'), await mk('inv-b'), await mk('inv-c')];
    const { roomId } = await roomWith([a, b, c]);
    const banner = await listen(b, `ripples:${roomId}`);
    await db.query('insert into public.blocks (blocker_user_id, blocked_user_id) values ($1, $2)', [c.id, a.id]); // C blocked A

    const ta = uuidv7();
    const ra = await fromRoom(a, ta, roomId);
    expect(ra.body).toMatchObject({ status: 'waiting', invite: { fromPseudonym: 'Quiet Comet', humans: 1, capacity: 4, mine: true } });
    const inviteId = ra.body.invite.inviteId as string;
    await banner.waitForBroadcast(`ripples:${roomId}`, 'ripple_invite', (p) => p.inviteId === inviteId);

    expect((await call(b, 'get', `/v1/ripples/rooms/${roomId}/invite`)).body.invite).toMatchObject({ inviteId, fromPseudonym: 'Quiet Comet', mine: false });
    expect((await call(c, 'get', `/v1/ripples/rooms/${roomId}/invite`)).body).toEqual({ invite: null }); // the blocker never sees it

    const [tb, tc] = [uuidv7(), uuidv7()];
    expect((await fromRoom(b, tb, roomId)).body.invite).toMatchObject({ inviteId, humans: 2 });
    expect((await fromRoom(c, tc, roomId)).body.invite.inviteId).toBe(inviteId); // no change for anyone
    // A second invite within 10 min by the same person just joins the open one / the queue (no error).
    await db.query(`update public.ripple_invites set starts_at = now() - interval '1 second', created_at = now() - interval '21 seconds' where id = $1`, [inviteId]);
    const [ma, mb, mc] = [await fromRoom(a, ta, roomId), await fromRoom(b, tb, roomId), await fromRoom(c, tc, roomId)];
    for (const m of [ma, mb, mc]) expect(m.body.status).toBe('matched');
    expect(ma.body.session.sessionId).toBe(mb.body.session.sessionId);
    expect(mc.body.session.sessionId).not.toBe(ma.body.session.sessionId); // C and A never share a session
    expect(ma.body.session).toMatchObject({ entry: 'room', roomId, startRule: 'invite' });
    expect(ma.body.session.seats.filter((x: { kind: string }) => x.kind === 'human').map((x: { label: string }) => x.label).sort()).toEqual([
      'Gentle Moon',
      'Quiet Comet',
    ]);
    await banner.waitForBroadcast(`ripples:${roomId}`, 'ripple_invite_closed', (p) => p.inviteId === inviteId);

    // Rate limit: A opened one in the last 10 min → a new tap goes to the global queue silently.
    const again = await fromRoom(a, uuidv7(), roomId);
    expect(again.status).toBe(200);
    expect(again.body.status).toBe('waiting');
    expect(again.body.invite).toBeUndefined();
    await call(a, 'delete', `/v1/ripples/match/${again.body.ticketId}`);
  });

  // ================================================================== completion, echoes, consent
  it('REQ-GAME-09: 12+ cycles write one unlinked echo; after opt-out, none; claims are capped by the server clock', async () => {
    const [a, b] = [await mk('echo-a'), await mk('echo-b')];
    const trace = { offsets: [7, -7, ...Array.from({ length: 30 }, (_, i) => (i % 3) - 1)] };

    expect((await call(a, 'get', '/v1/ripples/echo-consent')).body).toEqual({ enabled: true }); // on by default
    const first = await pair(a, b);
    await age(first.sessionId, 185);
    const before = await echoCount();
    expect((await call(a, 'post', `/v1/ripples/sessions/${first.sessionId}/complete`, { cycles: 16, trace })).status).toBe(204);
    expect(await echoCount()).toBe(before + 1);
    // Once per seat.
    await call(a, 'post', `/v1/ripples/sessions/${first.sessionId}/complete`, { cycles: 16, trace });
    expect(await echoCount()).toBe(before + 1);
    const seat = await one<{ cycles_done: number; completed: boolean }>('select cycles_done, completed from public.ripple_seats where user_id = $1', [a.id]);
    expect(seat).toEqual({ cycles_done: 16, completed: true });

    // REQ-GAME-07: the library has no column that can join back to anyone.
    const cols = (await db.query(`select column_name from information_schema.columns where table_schema = 'echo_library' and table_name = 'recordings' order by 1`)).rows.map((r) => r.column_name);
    expect(cols).toEqual(['completion', 'id', 'iso_week', 'median_offset_ms', 'offsets', 'pacer_version']);
    const fks = await one<{ n: number }>(`select count(*)::int as n from information_schema.table_constraints where table_schema = 'echo_library' and constraint_type = 'FOREIGN KEY'`);
    expect(fks.n).toBe(0);

    // Opt out → B's later session writes nothing (and A's claim of 16 cycles 30 s in is capped).
    expect((await call(b, 'put', '/v1/ripples/echo-consent', { enabled: false })).body).toEqual({ enabled: false });
    expect((await call(b, 'get', '/v1/ripples/echo-consent')).body).toEqual({ enabled: false });
    const c = await mk('echo-c');
    const second = await pair(b, c);
    await age(second.sessionId, 185);
    const mid = await echoCount();
    await call(b, 'post', `/v1/ripples/sessions/${second.sessionId}/complete`, { cycles: 16, trace });
    expect(await echoCount()).toBe(mid);
    expect((await call(b, 'put', '/v1/ripples/echo-consent', { enabled: true })).body).toEqual({ enabled: true });

    const d = await mk('echo-d');
    const third = await pair(c, d);
    await age(third.sessionId, 30); // 30 s in: only 2 cycles have happened
    await call(c, 'post', `/v1/ripples/sessions/${third.sessionId}/complete`, { cycles: 16, trace });
    expect(await one('select cycles_done, completed from public.ripple_seats where user_id = $1 and session_id = $2', [c.id, third.sessionId])).toEqual({
      cycles_done: 2,
      completed: false,
    });
    expect(await echoCount()).toBe(mid); // < 12 cycles: no echo
  });

  // ================================================================== safety on a light
  it('REQ-GAME-08: report / block by tapping a light; echoes can’t be reported; flood is flagged once', async () => {
    const [a, b] = [await mk('safe-a'), await mk('safe-b', MINOR_DOB)];
    const { sessionId, seatA, seatB, body } = await pair(a, b);
    const other = (body.session as { seats: Array<{ seat: number; kind: string }> }).seats.find((x) => x.kind !== 'human');

    const rep = await call(a, 'post', `/v1/ripples/sessions/${sessionId}/reports`, { seat: seatB, reason: 2, note: 'kept pulsing at me' });
    expect(rep.status).toBe(201);
    expect(rep.body).toEqual({ reportId: expect.any(String), showHelplines: false });
    const row = await one<{ lane: string; involves_minor: boolean; target_kind: string; target_user_id: string; evidence_hold_id: string }>(
      'select lane, involves_minor, target_kind, target_user_id, evidence_hold_id from public.reports where id = $1',
      [rep.body.reportId],
    );
    expect(row).toMatchObject({ lane: 'minors_grooming', involves_minor: true, target_kind: 'ripple_seat', target_user_id: b.id });
    const hold = await one<{ account_ids: string[]; snapshot: { seats: Array<{ accountId: string | null }> } }>(
      'select account_ids, snapshot from public.evidence_holds where id = $1',
      [row.evidence_hold_id],
    );
    expect(hold.account_ids).toEqual([b.id]); // the subject only, never the reporter
    expect(hold.snapshot.seats.map((s) => s.accountId).filter(Boolean)).toEqual([b.id]);
    expect((await call(a, 'post', `/v1/ripples/sessions/${sessionId}/reports`, { seat: seatB, reason: 2 })).status).toBe(200);
    expect((await call(a, 'post', `/v1/ripples/sessions/${sessionId}/reports`, { seat: seatB, reason: 1 })).body.showHelplines).toBe(true);
    if (other) expect((await call(a, 'post', `/v1/ripples/sessions/${sessionId}/reports`, { seat: other.seat, reason: 2 })).body.code).toBe('seat_not_found');
    expect((await call(a, 'post', `/v1/ripples/sessions/${sessionId}/reports`, { seat: seatA, reason: 2 })).body.code).toBe('invalid_target');

    const blk = await call(a, 'post', `/v1/ripples/sessions/${sessionId}/blocks`, { seat: seatB });
    expect(blk.status).toBe(201);
    expect((await call(a, 'post', `/v1/ripples/sessions/${sessionId}/blocks`, { seat: seatB })).status).toBe(200);
    expect(await one('select 1 as ok from public.blocks where blocker_user_id = $1 and blocked_user_id = $2', [a.id, b.id])).toEqual({ ok: 1 });

    for (let i = 0; i < 3; i++) expect((await call(a, 'post', `/v1/ripples/sessions/${sessionId}/flood`, { seat: seatB })).status).toBe(204);
    expect(await one(`select count(*)::int as n from public.reports where auto_signal = 'ripple_flood' and target_user_id = $1`, [b.id])).toEqual({ n: 1 });

    // Blocked now → never matched again, even at 8 s.
    const [ta, tb] = [uuidv7(), uuidv7()];
    await quick(a, ta);
    await quick(b, tb);
    await backdate([ta, tb], 9);
    expect((await quick(a, ta)).body.status).toBe('waiting');
    await call(a, 'delete', `/v1/ripples/match/${ta}`);
    await call(b, 'delete', `/v1/ripples/match/${tb}`);
  });

  it('worker tick: ends sessions past t0 + 180 s (session_end, once) and expires quiet tickets', async () => {
    const [a, b] = [await mk('tick-a'), await mk('tick-b')];
    const { sessionId } = await pair(a, b);
    const s = await listen(a, `game:${sessionId}`);
    await age(sessionId, 181);
    const tq = uuidv7();
    const c = await mk('tick-c');
    await quick(c, tq);
    await db.query(`update public.ripple_tickets set last_poll_at = now() - interval '10 seconds' where id = $1`, [tq]);
    await runRippleLifecycle(db);
    await s.waitForBroadcast(`game:${sessionId}`, 'session_end');
    expect((await one<{ status: string }>('select status from public.ripple_tickets where id = $1', [tq])).status).toBe('expired');
    expect((await call(a, 'get', `/v1/ripples/sessions/${sessionId}`)).body.ended).toBe(true);
    await call(c, 'delete', `/v1/ripples/match/${tq}`);
  });

  // ================================================================== DS-10
  it('DS-10: no ripples response or realtime payload carries an account id, email, DOB, age or lane', async () => {
    await sleep(500);
    const secrets = [...users.flatMap((u) => [u.id, u.email]), ...dobs].map((s) => s.toLowerCase());
    const FORBIDDEN_KEY =
      /^(user_?id|userIds?|account_?ids?|sub|email|birth_?date|dob|age|is_?minor|minor|under_?18|involves_?minor|lane|reason_?code|reporter_?user_?id|target_?user_?id|member_?id|seat_?id|sync|score)$/i;
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
    const ripples = recorded.filter((r) => r.where.includes('/v1/ripples'));
    for (const r of ripples) walk(r.body, r.where);
    const broadcasts = sockets.flatMap((s) => s.broadcasts());
    for (const b of broadcasts) walk(b.payload, `realtime ${b.topic} ${b.event}`);
    expect(ripples.length).toBeGreaterThan(40);
    expect(new Set(broadcasts.map((b) => b.event))).toEqual(new Set(['breath_state', 'seat_update', 'ripple_invite', 'ripple_invite_closed', 'session_end']));
    expect(violations).toEqual([]);
  });
});
