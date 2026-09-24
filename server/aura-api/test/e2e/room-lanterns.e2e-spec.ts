/**
 * F5 room lanterns and Tonight's intention (Milestone B, REQ-ROOM-13 / REQ-ROOM-14), end to end against the live local
 * stack: NestJS app, Postgres (migration 20261005000022), Supabase Auth and Realtime.
 *
 * Shared-stack etiquette: this suite changes no global row (flags, matching_config, rate-limit keys). It builds its OWN
 * room (seated by SQL, capacity = its members, so the matcher can't put anyone else in it), ticks only that room
 * (`tickRoom`) and simulates the room's Lantern Hour by calling the services with an injected clock — the room's
 * timeline is shifted around that clock. HTTP calls run on the real clock (the room is outside Lantern Hour there).
 * Only its own room and users are deleted afterwards.
 *
 * Exit criterion (20-timeline weeks 15–17): "lantern never dims (REQ-ROOM-13)".
 */
import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { addBreathCyclesToRoomLantern } from '../../src/rooms/lanterns';
import { LanternsService } from '../../src/rooms/lanterns.service';
import { GesturesService } from '../../src/rooms/gestures.service';
import { loadMatchingConfig, type MatchingConfig } from '../../src/rooms/matching-config';
import { lanternWindow, TZ_REGIONS, type TzRegion } from '../../src/rooms/regions';
import { tickRoom } from '../../src/rooms/room-lifecycle';
import { RoomsService } from '../../src/rooms/rooms.service';
import { RealtimeClient } from './realtime';
import { bootApp, createUser, dbPool, deleteUser, type TestUser } from './support';

jest.setTimeout(90_000);

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));
const GAP = 2_150; // > the 1-per-2-s gesture limit (per account)
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;
const ROOM_STATE_KEYS = ['at', 'id', 'intention', 'joinsCloseAt', 'lantern', 'memoryAt', 'purgeAt', 'readOnly', 'state'];

describe('Room lanterns + Tonight\'s intention (e2e, live local stack)', () => {
  let app: INestApplication;
  let db: Pool;
  let gestures: GesturesService;
  let lanterns: LanternsService;
  let rooms: RoomsService;
  let cfg: MatchingConfig;
  let socket: RealtimeClient;
  const users: TestUser[] = [];
  let a: TestUser;
  let b: TestUser;
  let c: TestUser;
  const roomId = randomUUID();
  const member = { a: randomUUID(), b: randomUUID(), c: randomUUID() };
  const pseudonyms = ['Quiet Comet', 'Gentle Harbor', 'Soft Lantern'];
  let region: TzRegion;
  let inside: Date; // 30 min into the room's (simulated) Lantern Hour
  let after: Date; // 30 min after it ended
  const http = () => request(app.getHttpServer());
  const call = (u: TestUser, method: 'get' | 'post', path: string, body?: object) => {
    const r = http()[method](path).set('Authorization', `Bearer ${u.token}`);
    return body ? r.send(body) : r;
  };
  const progress = async (): Promise<number> =>
    (await db.query<{ p: number }>('select lantern_progress as p from public.rooms where id = $1', [roomId])).rows[0].p;
  const level = async (): Promise<number> =>
    (await db.query<{ l: number }>('select lantern_level::int as l from public.rooms where id = $1', [roomId])).rows[0].l;
  const dropped = async (gestureId: string): Promise<string | null> =>
    (await db.query<{ d: string | null }>('select dropped as d from public.room_gestures where id = $1', [gestureId])).rows[0]?.d ?? null;
  const roomGesture = (u: TestUser, at: Date = inside) => gestures.send(u.id, roomId, { type: 'light_a_candle', target: 'room' }, at);

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
    gestures = app.get(GesturesService);
    lanterns = app.get(LanternsService);
    rooms = app.get(RoomsService);
    cfg = await loadMatchingConfig(db);

    // A region that is NOT in Lantern Hour on the real clock (windows never overlap, so 3 of 4 qualify).
    const now = new Date();
    region = TZ_REGIONS.find((r) => !lanternWindow(r, now, cfg.lanternStart, cfg.lanternEnd).active)!;
    const w = lanternWindow(region, now, cfg.lanternStart, cfg.lanternEnd);
    inside = new Date(w.startsAt.getTime() + 30 * 60_000);
    after = new Date(w.endsAt.getTime() + 30 * 60_000);

    [a, b, c] = await Promise.all([createUser('lantern-a'), createUser('lantern-b'), createUser('lantern-c')]);
    users.push(a, b, c);
    for (const u of users) {
      await http()
        .post('/v1/profile')
        .set('Authorization', `Bearer ${u.token}`)
        .send({ birthDate: '1999-03-14', uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' })
        .expect(200);
    }
    // Our own room: full (capacity 3), young relative to the simulated clock, open (2+ members).
    await db.query(
      `insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, capacity, status,
                                 created_at, opened_at, joins_close_at, memory_at, purge_at)
       values ($1, 'en', 'storm', $2, 'anxious', 'lighthouse', 3, 'open',
               $3::timestamptz - interval '1 hour', $3::timestamptz - interval '50 minutes', $3::timestamptz + interval '19 hours',
               $3::timestamptz + interval '23 hours', $3::timestamptz + interval '23 hours' + interval '7 days')`,
      [roomId, region, inside],
    );
    const seat = (m: string, u: TestUser, p: string) =>
      db.query(
        `insert into public.room_members (member_id, room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool,
                                          home_region, match_step, stage)
         values ($1, $2, $3, $4, 'anxious', 'storm', 'en', $5, 4, 'spark')`,
        [m, roomId, u.id, p, region],
      );
    await seat(member.a, a, pseudonyms[0]);
    await seat(member.b, b, pseudonyms[1]);
    await seat(member.c, c, pseudonyms[2]);

    socket = await RealtimeClient.connect();
    expect(await socket.join(`room:${roomId}`, a.token)).toEqual({ ok: true });
  });

  afterAll(async () => {
    socket?.close();
    await db?.query('delete from public.rooms where id = $1', [roomId]).catch(() => undefined);
    await Promise.all(users.map((u) => deleteUser(u.id)));
    await db?.end();
    await app?.close();
  });

  it('before its first Lantern Hour: no lantern, no intention, and holding answers 409 intention_closed', async () => {
    const d = await call(a, 'get', `/v1/rooms/${roomId}`).expect(200);
    expect(d.body.room.lantern).toBeNull();
    expect(d.body.room.intention).toBeNull();
    expect(d.body.me.holdingIntention).toBe(false);
    const h = await call(a, 'post', `/v1/rooms/${roomId}/intention/hold`).expect(409);
    expect(h.body.code).toBe('intention_closed');
    await call(a, 'post', `/v1/rooms/${randomUUID()}/intention/hold`).expect(404);
  });

  it('Lantern Hour starts: the tick pins tonight\'s intention and room_state carries the lantern (level 0) and the preset', async () => {
    const t = await tickRoom(db, roomId, inside, cfg);
    expect(t.transition).toBe(true);
    const presets = (await db.query<{ key: string }>(`select key from public.room_intention_presets where language_pool = 'en' and enabled`)).rows.map((r) => r.key);
    const st = await socket.waitForBroadcast(`room:${roomId}`, 'room_state', (p) => p.state === 'lantern_hour');
    expect(st.payload.lantern).toEqual({ level: 0, maxLevel: 5, active: true });
    const intention = st.payload.intention as { key: string; holds: number; open: boolean };
    expect(presets).toContain(intention.key);
    expect(intention).toEqual({ key: intention.key, holds: 0, open: true });
  });

  it('delivered gestures add light scaled to the room (3 live → 5 per level); room_state only when the level rises', async () => {
    await roomGesture(a);
    await roomGesture(b);
    await roomGesture(c);
    expect(await progress()).toBe(600);
    expect(await level()).toBe(0);
    await sleep(GAP);
    await roomGesture(a);
    // No broadcast per gesture: nothing announced a level the lantern hasn't reached (unit test pins the rest).
    expect(socket.broadcasts(`room:${roomId}`, 'room_state').filter((x) => (x.payload.lantern as { level: number } | null)?.level === 1)).toHaveLength(0);
    await roomGesture(b);
    expect(await progress()).toBe(1000);
    expect(await level()).toBe(1);
    const st = await socket.waitForBroadcast(`room:${roomId}`, 'room_state', (p) => (p.lantern as { level: number } | null)?.level === 1);
    expect(st.payload.state).toBe('lantern_hour');
  });

  it('dropped gestures add nothing: over-limit, blocked pairs (both ways) and muted', async () => {
    await call(b, 'post', '/v1/safety/blocks', { roomId, memberId: member.c }).expect(201);
    await call(c, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: member.a }).expect(204);
    await sleep(GAP);
    let p = await progress();

    const toB = await gestures.send(c.id, roomId, { type: 'hug', target: 'member', toMemberId: member.b }, inside);
    expect(await dropped(toB.gestureId)).toBe('blocked');
    const toC = await gestures.send(b.id, roomId, { type: 'hug', target: 'member', toMemberId: member.c }, inside);
    expect(await dropped(toC.gestureId)).toBe('blocked');
    expect(await progress()).toBe(p);

    const muted = await gestures.send(a.id, roomId, { type: 'warm_tea', target: 'member', toMemberId: member.c }, inside);
    expect(await dropped(muted.gestureId)).toBe('muted');
    expect(await progress()).toBe(p);

    await sleep(GAP);
    p = await progress();
    const ok = await roomGesture(a);
    const over = await roomGesture(a); // within 2 s: over the limit
    expect(await dropped(ok.gestureId)).toBeNull();
    expect(await dropped(over.gestureId)).toBe('over_limit');
    expect(await progress()).toBe(p + 200); // only the delivered one
  });

  it('a removed reflection (and the gestures on it) never dims the lantern', async () => {
    const reflectionId = randomUUID();
    await db.query(
      `insert into public.reflections (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, language_pool, published_at)
       values ($1, $2, $3, $4, 'published', repeat('x', 32), repeat('k', 32), 12, 'en', now())`,
      [reflectionId, roomId, member.b, b.id],
    );
    await sleep(GAP);
    const before = await progress();
    const g = await gestures.send(a.id, roomId, { type: 'me_too', target: 'reflection', toReflectionId: reflectionId }, inside);
    expect(await dropped(g.gestureId)).toBeNull();
    const lit = await progress();
    expect(lit).toBeGreaterThan(before);
    await db.query(`update public.reflections set status = 'removed', removed_at = now() where id = $1`, [reflectionId]);
    await db.query('delete from public.reflections where id = $1', [reflectionId]); // cascades its gestures
    expect((await db.query('select 1 from public.room_gestures where id = $1', [g.gestureId])).rowCount).toBe(0);
    expect(await progress()).toBe(lit);
  });

  it("Tonight's intention: one tap, idempotent, only the room total — broadcast without anyone's id", async () => {
    const first = await lanterns.hold(a.id, roomId, inside);
    expect(first.holding).toBe(true);
    expect(first.intention.holds).toBe(1);
    expect(first.intention.open).toBe(true);
    const again = await lanterns.hold(a.id, roomId, inside);
    expect(again.intention.holds).toBe(1);
    const second = await lanterns.hold(b.id, roomId, inside);
    expect(second.intention.holds).toBe(2);
    await socket.waitForBroadcast(`room:${roomId}`, 'room_state', (p) => (p.intention as { holds: number } | null)?.holds === 2);
    expect((await rooms.detail(a.id, roomId, inside)).me.holdingIntention).toBe(true);
    expect((await rooms.detail(c.id, roomId, inside)).me.holdingIntention).toBe(false);
    expect(JSON.stringify(second)).not.toMatch(UUID);
  });

  it('leaving never dims the lantern or lowers the hold count', async () => {
    const p = await progress();
    const holds = (await db.query<{ n: number }>('select intention_holds as n from public.rooms where id = $1', [roomId])).rows[0].n;
    await call(b, 'post', `/v1/rooms/${roomId}/leave`).expect(200);
    expect(await progress()).toBe(p);
    expect((await db.query<{ n: number }>('select intention_holds as n from public.rooms where id = $1', [roomId])).rows[0].n).toBe(holds);
    await expect(lanterns.hold(b.id, roomId, inside)).rejects.toMatchObject({ status: 404, code: 'not_found' });
  });

  it('Breath Ripples hook: human cycles from a session started in the room add light', async () => {
    const before = await progress();
    const r = await addBreathCyclesToRoomLantern(db, roomId, 16, inside);
    expect(r).not.toBeNull();
    expect(await progress()).toBeGreaterThan(before);
    expect(await addBreathCyclesToRoomLantern(db, roomId, 16, after)).toBeNull(); // outside the hour: nothing
  });

  it('the database refuses to dim it (REQ-ROOM-13 backstop, any role)', async () => {
    await expect(db.query('update public.rooms set lantern_progress = 0 where id = $1', [roomId])).rejects.toMatchObject({ code: 'AR030' });
    await expect(db.query('update public.rooms set intention_holds = 0 where id = $1', [roomId])).rejects.toMatchObject({ code: 'AR030' });
  });

  it('at 23:00 it keeps the level reached, takes no more light, and the intention is read-only', async () => {
    const lvl = await level();
    expect(lvl).toBeGreaterThanOrEqual(1);
    await tickRoom(db, roomId, after, cfg);
    // (A dev worker on the real clock may also tick this room; match the post-hour state with the level reached.)
    const st = await socket.waitForBroadcast(
      `room:${roomId}`,
      'room_state',
      (p) => p.state === 'open' && (p.lantern as { level: number } | null)?.level === lvl,
    );
    expect(st.payload.lantern).toEqual({ level: lvl, maxLevel: 5, active: false });
    expect((st.payload.intention as { open: boolean }).open).toBe(false);
    await sleep(GAP);
    const p = await progress();
    await roomGesture(a, after);
    expect(await progress()).toBe(p);
    await expect(lanterns.hold(c.id, roomId, after)).rejects.toMatchObject({ status: 409, code: 'intention_closed' });
  });

  it('the memory shows "Tonight\'s lantern" at the level it reached', async () => {
    const lvl = await level();
    const memoryAt = new Date(inside.getTime() + 23.5 * 3_600_000);
    const d = await rooms.detail(a.id, roomId, memoryAt);
    expect(d.room.state).toBe('memory');
    expect(d.room.lantern).toEqual({ level: lvl, maxLevel: 5, active: false });
    expect(d.room.intention?.holds).toBe(2);
    await expect(lanterns.hold(c.id, roomId, memoryAt)).rejects.toMatchObject({ status: 409, code: 'intention_closed' });
  });

  it('DS-10: every room_state carries room totals only — no member id, account id, pseudonym or per-member value', async () => {
    const states = socket.broadcasts(`room:${roomId}`, 'room_state');
    expect(states.length).toBeGreaterThanOrEqual(4);
    const forbidden = [...Object.values(member), ...users.map((u) => u.id), ...users.map((u) => u.email), ...pseudonyms];
    for (const s of states) {
      for (const k of Object.keys(s.payload)) expect(ROOM_STATE_KEYS).toContain(k);
      if (s.payload.lantern) expect(Object.keys(s.payload.lantern as object).sort()).toEqual(['active', 'level', 'maxLevel']);
      if (s.payload.intention) expect(Object.keys(s.payload.intention as object).sort()).toEqual(['holds', 'key', 'open']);
      const { id: _messageId, ...rest } = s.payload; // Realtime's own message id
      const json = JSON.stringify(rest);
      for (const f of forbidden) expect(json).not.toContain(f);
      expect(json.match(UUID)).toBeNull();
    }
    // The HTTP detail never names who holds or lit anything either (only your own `me.holdingIntention`).
    const d = await call(a, 'get', `/v1/rooms/${roomId}`).expect(200);
    const body = JSON.stringify(d.body);
    expect(body).not.toContain(a.id);
    expect(body).not.toMatch(/holders|contribution|lanternShare|litBy/i);
  });
});
