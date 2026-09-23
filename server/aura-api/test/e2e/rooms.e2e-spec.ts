/**
 * F5 Mood Rooms + F9 core safety, end to end against the live local stack: NestJS app, Postgres (migrations incl.
 * 20261005000010), Supabase Auth (real ES256 tokens) and Supabase Realtime (private channels authorised by the RLS
 * policy on realtime.messages; server broadcasts via realtime.send()).
 *
 * Every stranger-facing response (/v1/rooms*, /v1/safety*) and every realtime payload received by a test socket is
 * recorded; the last test scans them all for account ids, emails, DOBs and age/lane keys (the DS-10 contract test).
 */
import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { LEGAL_HOLD_TABLES, purgeAccount } from '../../src/account/account-purge';
import { PrivateMediaStore } from '../../src/account/private-media';
import { lanternWindow } from '../../src/rooms/regions';
import { runRoomLifecycle } from '../../src/rooms/room-lifecycle';
import { ModerationError, ModerationService } from '../../src/safety/moderation.service';
import { RealtimeClient } from './realtime';
import { bootApp, createUser, dbPool, deleteUser, type TestUser } from './support';

jest.setTimeout(60_000);

const TZ = {
  americas: 'America/Chicago',
  europe_africa: 'Europe/Berlin',
  south_asia: 'Asia/Kolkata',
  east_asia_pacific: 'Asia/Tokyo',
} as const;
const ADULT_DOB = '1999-03-14';
const MINOR_DOB = `${new Date().getUTCFullYear() - 16}-02-10`; // 16 today (Meera)
const PSEUDONYM = /^[A-Z][a-z]{1,14} [A-Z][a-z]{1,14}$/;
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

type Method = 'get' | 'post' | 'delete';
interface Recorded {
  where: string;
  body: unknown;
}

describe('Rooms + safety (e2e, live local Supabase + Realtime + Redis)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  const sockets: RealtimeClient[] = [];
  const recorded: Recorded[] = [];
  const fakeAccounts: string[] = [];
  const dobs = new Set<string>([ADULT_DOB, MINOR_DOB]);
  let savedMatching: Record<string, unknown>;
  let savedSafety: Record<string, unknown>;

  // ------------------------------------------------------------------ helpers
  const http = () => request(app.getHttpServer());

  async function call(u: TestUser, method: Method, path: string, body?: unknown): Promise<request.Response> {
    let r = http()[method](path).set('Authorization', `Bearer ${u.token}`);
    if (body !== undefined) r = r.send(body as object);
    const res = await r;
    if (/^\/v1\/(rooms|safety)/.test(path)) recorded.push({ where: `${method.toUpperCase()} ${path} → ${res.status}`, body: res.body });
    return res;
  }

  async function mk(label: string, opts: { locale?: string; dob?: string; tz?: string } = {}): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    const dob = opts.dob ?? ADULT_DOB;
    dobs.add(dob);
    await http()
      .post('/v1/profile')
      .set('Authorization', `Bearer ${u.token}`)
      .send({ birthDate: dob, uiLocale: opts.locale ?? 'en', timezone: opts.tz ?? TZ.south_asia, country: 'IN' })
      .expect(200);
    return u;
  }

  const match = (u: TestUser, quadrant: string, moodId: string, timezone?: string, extra: Record<string, unknown> = {}) =>
    call(u, 'post', '/v1/rooms/match', { quadrant, moodId, ...(timezone ? { timezone } : {}), ...extra });
  const detail = (u: TestUser, roomId: string) => call(u, 'get', `/v1/rooms/${roomId}`);
  const gesture = (u: TestUser, roomId: string, body: Record<string, unknown>) => call(u, 'post', `/v1/rooms/${roomId}/gestures`, body);

  async function socket(): Promise<RealtimeClient> {
    const s = await RealtimeClient.connect();
    sockets.push(s);
    return s;
  }

  async function listen(u: TestUser, topics: string[]): Promise<RealtimeClient> {
    const s = await socket();
    for (const t of topics) expect(await s.join(t, u.token)).toEqual({ ok: true });
    return s;
  }

  /** Clean slate for a group: drop rooms that hold no non-e2e account (earlier groups, earlier runs). */
  const freshRooms = () =>
    db.query(
      `delete from public.rooms r where not exists (
         select 1 from public.room_members m join auth.users u on u.id = m.user_id
          where m.room_id = r.id and coalesce(u.email, '') not like 'e2e-%@aura.test')`,
    );

  const setMatching = (patch: Record<string, unknown>) => {
    const keys = Object.keys(patch);
    return db.query(`update public.matching_config set ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')} where id`, Object.values(patch));
  };
  const setSafety = (patch: Record<string, unknown>) => {
    const keys = Object.keys(patch);
    return db.query(`update public.safety_config set ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')} where id`, Object.values(patch));
  };

  const one = async <T = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T> => (await db.query(sql, params)).rows[0] as T;
  const gestureRow = (id: string) => one<{ dropped: string | null }>('select dropped from public.room_gestures where id = $1', [id]);
  const reportRow = (id: string) =>
    one<{ lane: string; involves_minor: boolean; status: string; reporter_user_id: string | null; target_user_id: string | null; evidence_hold_id: string | null; room_id: string | null }>(
      'select lane, involves_minor, status, reporter_user_id, target_user_id, evidence_hold_id, room_id from public.reports where id = $1',
      [id],
    );

  /** Fake members for capacity/demand tests (auth rows written directly; removed in afterAll). */
  async function fakeAccount(): Promise<string> {
    const id = randomUUID();
    await db.query(`insert into auth.users (id, email, aud, role) values ($1, $2, 'authenticated', 'authenticated')`, [id, `e2e-fake-${id}@aura.test`]);
    fakeAccounts.push(id);
    return id;
  }
  const FAKE_NAMES = 'Aa Ab Ac Ad Ae Af Ag Ah Ai Aj Ak Al Am An Ao Ap Aq Ar As At Au Av Aw Ax'.split(' ');
  async function roomWithFakes(p: {
    pool: string;
    quadrant: string;
    region: keyof typeof TZ;
    members: number;
    live: boolean;
    homePool?: string;
  }): Promise<string> {
    const theme = { storm: 'lighthouse', rain: 'rain_sanctuary', moonlight: 'midnight_observatory', sunrise: 'sunrise_deck' }[p.quadrant];
    const seed = { storm: 'anxious', rain: 'lonely', moonlight: 'calm', sunrise: 'joyful' }[p.quadrant];
    const room = await one<{ id: string }>(
      `insert into public.rooms (language_pool, quadrant, tz_region, seed_mood_id, theme, opened_at, joins_close_at, memory_at, purge_at)
       values ($1, $2, $3, $4, $5, now(), now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days') returning id`,
      [p.pool, p.quadrant, p.region, seed, theme],
    );
    for (let i = 0; i < p.members; i++) {
      await db.query(
        `insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region,
                                          match_step, stage, last_seen_at)
         values ($1, $2, $3, $4, $5, $6, $7, 4, 'spark', case when $8 then now() else now() - interval '1 hour' end)`,
        [room.id, await fakeAccount(), `Seeded ${FAKE_NAMES[i]}`, seed, p.quadrant, p.homePool ?? p.pool, p.region, p.live],
      );
    }
    return room.id;
  }

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
    savedMatching = (await db.query('select * from public.matching_config where id')).rows[0];
    savedSafety = (await db.query('select * from public.safety_config where id')).rows[0];
    // Deterministic partitions for the suite: no thin merge, no adjacent merge, no 2-second spacing between gestures.
    // Groups that test those rules switch them on temporarily.
    await setMatching({ thin_join_threshold: 0, partition_live_min: 1, adjacent_live_min: 48, gesture_min_interval_ms: 0 });
  });

  afterAll(async () => {
    for (const s of sockets) s.close();
    if (db) {
      const restore = (table: string, row: Record<string, unknown>) => {
        const keys = Object.keys(row).filter((k) => k !== 'id');
        return db.query(`update public.${table} set ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')} where id`, keys.map((k) => row[k]));
      };
      if (savedMatching) await restore('matching_config', savedMatching);
      if (savedSafety) await restore('safety_config', savedSafety);
      // Reports and evidence outlive accounts by design; remove this suite's own so they don't pile up locally.
      const ids = [...users.map((u) => u.id), ...fakeAccounts];
      const mine = `select id from public.reports where reporter_user_id = any($1::uuid[]) or target_user_id = any($1::uuid[])`;
      await db.query(`delete from public.evidence_holds where report_id in (${mine}) or account_ids && $1::uuid[]`, [ids]);
      await db.query(`delete from public.reports where id in (${mine})`, [ids]);
    }
    await Promise.all(users.map((u) => deleteUser(u.id)));
    if (db) {
      if (fakeAccounts.length) await db.query('delete from auth.users where id = any($1::uuid[])', [fakeAccounts]);
      await freshRooms();
      await db.end();
    }
    await app?.close();
  });

  // ================================================================== auth & validation
  it('401 without a token on every rooms/safety route', async () => {
    const id = randomUUID();
    for (const [method, path] of [
      ['post', '/v1/rooms/match'],
      ['get', '/v1/rooms'],
      ['get', `/v1/rooms/${id}`],
      ['post', `/v1/rooms/${id}/heartbeat`],
      ['post', `/v1/rooms/${id}/gestures`],
      ['post', `/v1/rooms/${id}/leave`],
      ['post', `/v1/rooms/${id}/survey`],
      ['post', `/v1/rooms/${id}/mutes`],
      ['delete', `/v1/rooms/${id}/mutes/${id}`],
      ['post', '/v1/safety/reports'],
      ['get', '/v1/safety/reports'],
      ['post', '/v1/safety/blocks'],
      ['get', '/v1/safety/blocks'],
      ['delete', `/v1/safety/blocks/${id}`],
      ['get', '/v1/safety/me'],
    ] as const) {
      const r = await http()[method](path).expect(401);
      expect(r.body).toEqual({ code: 'unauthorized', message: expect.any(String) });
    }
  });

  it('match: 409 profile_required before onboarding; 400 on bad bodies and a mood outside the quadrant', async () => {
    const u = await createUser('rooms-noprofile');
    users.push(u);
    expect((await match(u, 'storm', 'anxious')).status).toBe(409);
    const v = await mk('rooms-validate');
    for (const body of [
      {},
      { quadrant: 'storm' },
      { quadrant: 'fog', moodId: 'anxious' },
      { quadrant: 'storm', moodId: 'calm' }, // calm is moonlight
      { quadrant: 'storm', moodId: 'nope' },
      { quadrant: 'storm', moodId: 'anxious', timezone: 'Mars/Olympus' },
      { quadrant: 'storm', moodId: 'anxious', allowPoolFallback: 'yes' },
    ]) {
      const r = await call(v, 'post', '/v1/rooms/match', body);
      expect(r.status).toBe(400);
      expect(r.body.code).toBe('invalid_request');
    }
    expect((await call(v, 'get', '/v1/rooms/not-a-uuid')).status).toBe(404);
    expect((await call(v, 'get', `/v1/rooms/${randomUUID()}`)).body.code).toBe('not_found');
    expect((await call(v, 'get', '/v1/rooms')).body).toEqual({ rooms: [] });
  });

  // ================================================================== matching, re-entry, pseudonyms, realtime
  describe('matching and realtime', () => {
    let a: TestUser;
    let b: TestUser;
    let c: TestUser;
    let storm: { roomId: string; aMember: string; aName: string; bMember: string; bName: string };
    let sa: RealtimeClient;
    let sb: RealtimeClient;

    beforeAll(async () => {
      await freshRooms();
      [a, b, c] = await Promise.all([mk('rt-a'), mk('rt-b'), mk('rt-c')]);
    });

    it('the first person spawns a forming room (step 4); a second joins it (step 2) and it opens', async () => {
      const r1 = await match(a, 'storm', 'anxious', TZ.europe_africa);
      expect(r1.status).toBe(200);
      expect(r1.headers['cache-control']).toBe('no-store');
      expect(r1.body.match).toEqual({ step: 4, reentry: false, created: true, merged: false });
      expect(r1.body.room).toMatchObject({ quadrant: 'storm', theme: 'lighthouse', state: 'forming', readOnly: false });
      expect(r1.body.room.lanternHour).toMatchObject({ timezone: 'Europe/Berlin', active: expect.any(Boolean) });
      expect(r1.body.me.pseudonym).toMatch(PSEUDONYM);
      expect(r1.body.me.moodChip).toBe('anxious');
      expect(r1.body.counts).toEqual({ hereNow: 1, today: 1 });
      expect(r1.body.members).toHaveLength(1);
      expect(r1.body.members[0]).toMatchObject({ isMe: true, live: true, muted: false, memberId: r1.body.me.memberId });
      expect(r1.body.realtime).toEqual({ roomTopic: `room:${r1.body.room.roomId}`, memberTopic: `member:${r1.body.me.memberId}` });
      const roomId = r1.body.room.roomId as string;

      sa = await listen(a, [`room:${roomId}`, `member:${r1.body.me.memberId}`]);

      const r2 = await match(b, 'storm', 'restless', TZ.europe_africa);
      expect(r2.status).toBe(200);
      expect(r2.body.match).toEqual({ step: 2, reentry: false, created: false, merged: false });
      expect(r2.body.room.roomId).toBe(roomId);
      expect(['open', 'lantern_hour']).toContain(r2.body.room.state);
      expect(r2.body.room.state === 'lantern_hour').toBe(r2.body.room.lanternHour.active);
      expect(r2.body.me.memberId).not.toBe(r1.body.me.memberId);
      expect(r2.body.me.pseudonym).not.toBe(r1.body.me.pseudonym);
      expect(r2.body.counts).toEqual({ hereNow: 2, today: 2 });
      expect(r2.body.members.map((m: { isMe: boolean }) => m.isMe)).toEqual([false, true]);
      storm = { roomId, aMember: r1.body.me.memberId, aName: r1.body.me.pseudonym, bMember: r2.body.me.memberId, bName: r2.body.me.pseudonym };

      const joined = await sa.waitForBroadcast(`room:${roomId}`, 'member_joined');
      expect(joined.payload).toEqual({
        id: expect.any(String),
        member: { memberId: storm.bMember, pseudonym: storm.bName, silhouette: { stage: 'spark', hue: null, cosmetic: null }, moodChip: 'restless' },
        counts: { hereNow: 2, today: 2 },
        at: expect.any(String),
      });
      const state = await sa.waitForBroadcast(`room:${roomId}`, 'room_state');
      expect(state.payload).toMatchObject({ state: r2.body.room.state, readOnly: false, joinsCloseAt: r2.body.room.joinsCloseAt });
    });

    it('REQ-ROOM-04: a same-quadrant check-in returns to the same room, seat and pseudonym (step 0)', async () => {
      const r = await match(a, 'storm', 'frustrated', TZ.europe_africa);
      expect(r.body.match).toEqual({ step: 0, reentry: true, created: false, merged: false });
      expect(r.body.room.roomId).toBe(storm.roomId);
      expect(r.body.me).toMatchObject({ memberId: storm.aMember, pseudonym: storm.aName, moodChip: 'anxious' });
      const n = await one<{ n: number }>('select count(*)::int as n from public.room_members where user_id = $1', [a.id]);
      expect(n.n).toBe(1); // never two storm rooms
    });

    it('REQ-ROOM-05: one account in two rooms has different pseudonyms and member ids', async () => {
      const r = await match(a, 'moonlight', 'calm', TZ.europe_africa);
      expect(r.status).toBe(200);
      expect(r.body.room.roomId).not.toBe(storm.roomId);
      expect(r.body.room.theme).toBe('midnight_observatory');
      expect(r.body.me.memberId).not.toBe(storm.aMember);
      expect(r.body.me.pseudonym).not.toBe(storm.aName);
      const list = await call(a, 'get', '/v1/rooms');
      expect(list.body.rooms.map((x: { room: { quadrant: string } }) => x.room.quadrant).sort()).toEqual(['moonlight', 'storm']);
      for (const x of list.body.rooms) expect(Object.keys(x).sort()).toEqual(['counts', 'me', 'room']);
    });

    it('realtime: members only, your own member topic only, and clients can never broadcast', async () => {
      const outsider = await socket();
      const refused = await outsider.join(`room:${storm.roomId}`, c.token);
      expect(refused.ok).toBe(false);
      expect(refused.reason).toMatch(/Unauthorized/);
      expect((await outsider.join(`member:${storm.aMember}`, c.token)).ok).toBe(false);
      expect((await outsider.join(`member:${storm.bMember}`, a.token)).ok).toBe(false); // A can't listen to B's topic

      // A member may listen, but a client broadcast is never accepted (no INSERT policy: Realtime refuses or silently
      // drops it — with `ack` an accepted one would answer "ok") and never reaches anyone.
      const forger = await socket();
      expect(await forger.join(`room:${storm.roomId}`, b.token, { ack: true })).toEqual({ ok: true });
      expect(await forger.clientBroadcast(`room:${storm.roomId}`, 'forged_event', { note: 'hello' })).not.toBe('ok');
      await sleep(800);
      expect(sa.broadcasts(`room:${storm.roomId}`, 'forged_event')).toEqual([]);
      forger.leave(`room:${storm.roomId}`);
    });

    it('REQ-ROOM-06: a gesture reaches the recipient with the sender’s pseudonym; others see an unnamed animation', async () => {
      sb = await listen(b, [`room:${storm.roomId}`, `member:${storm.bMember}`]);
      const t0 = Date.now();
      const r = await gesture(a, storm.roomId, { type: 'warm_tea', target: 'member', toMemberId: storm.bMember });
      expect(r.status).toBe(202);
      expect(r.body).toEqual({ gestureId: expect.any(String), at: expect.any(String) });
      const gid = r.body.gestureId as string;

      const received = await sb.waitForBroadcast(`member:${storm.bMember}`, 'gesture_received', (p) => p.gestureId === gid);
      expect(Date.now() - t0).toBeLessThan(5000);
      expect(received.payload).toEqual({ id: expect.any(String), gestureId: gid, type: 'warm_tea', fromMemberId: storm.aMember, fromPseudonym: storm.aName, at: r.body.at });
      for (const s of [sa, sb]) {
        const anon = await s.waitForBroadcast(`room:${storm.roomId}`, 'gesture_sent', (p) => p.gestureId === gid);
        expect(anon.payload).toEqual({ id: expect.any(String), gestureId: gid, type: 'warm_tea', target: 'member', at: r.body.at });
      }
      expect(sa.broadcasts(`member:${storm.aMember}`, 'gesture_received')).toEqual([]); // the sender's own topic stays quiet

      const bView = await detail(b, storm.roomId);
      expect(bView.body.gestures.received[0]).toEqual({ gestureId: gid, type: 'warm_tea', fromMemberId: storm.aMember, fromPseudonym: storm.aName, at: r.body.at });
      expect(bView.body.gestures.recent[0]).toEqual({ gestureId: gid, type: 'warm_tea', target: 'member', at: r.body.at });
      const aView = await detail(a, storm.roomId);
      expect(aView.body.gestures.sent[0]).toEqual({ gestureId: gid, type: 'warm_tea', target: 'member', toMemberId: storm.bMember, at: r.body.at });
      expect(aView.body.gestures.received).toEqual([]);

      const room = await gesture(b, storm.roomId, { type: 'me_too', target: 'room' });
      expect(room.status).toBe(202);
      const anon = await sa.waitForBroadcast(`room:${storm.roomId}`, 'gesture_sent', (p) => p.gestureId === room.body.gestureId);
      expect(anon.payload.target).toBe('room');
    });

    it('gesture validation: unknown preset, reflection target, shape, self, strangers → 400/404', async () => {
      const bad = [
        { type: 'kiss', target: 'room' },
        { type: 'hug', target: 'reflection', toMemberId: storm.bMember },
        { type: 'hug', target: 'member' },
        { type: 'hug', target: 'room', toMemberId: storm.bMember },
      ];
      for (const body of bad) {
        const r = await gesture(a, storm.roomId, body);
        expect(r.status).toBe(400);
        expect(r.body.code).toBe('invalid_request');
      }
      expect((await gesture(a, storm.roomId, { type: 'hug', target: 'member', toMemberId: storm.aMember })).body.code).toBe('invalid_target');
      expect((await gesture(a, storm.roomId, { type: 'hug', target: 'member', toMemberId: randomUUID() })).body.code).toBe('member_not_found');
      expect((await gesture(c, storm.roomId, { type: 'hug', target: 'room' })).body.code).toBe('not_found');
      expect((await detail(c, storm.roomId)).status).toBe(404);
    });

    it('heartbeat keeps you "here now" and a quiet → live change is broadcast', async () => {
      await db.query(`update public.room_members set last_seen_at = now() - interval '10 minutes' where member_id = $1`, [storm.bMember]);
      const before = await detail(a, storm.roomId);
      expect(before.body.counts.hereNow).toBe(1);
      expect(before.body.members.find((m: { memberId: string }) => m.memberId === storm.bMember).live).toBe(false);
      const hb = await call(b, 'post', `/v1/rooms/${storm.roomId}/heartbeat`);
      expect(hb.status).toBe(200);
      expect(Object.keys(hb.body).sort()).toEqual(['counts', 'room']);
      expect(hb.body.counts).toEqual({ hereNow: 2, today: 2 });
      await sa.waitForBroadcast(`room:${storm.roomId}`, 'presence', (p) => (p.counts as { hereNow: number }).hereNow === 2);
    });
  });

  // ================================================================== limits and shadow-mute
  describe('gesture limits', () => {
    let d: TestUser;
    let e: TestUser;
    let roomId: string;
    let dMember: string;
    let eMember: string;
    let se: RealtimeClient;

    beforeAll(async () => {
      await freshRooms();
      [d, e] = await Promise.all([mk('lim-d'), mk('lim-e')]);
      const rd = await match(d, 'storm', 'overwhelmed', TZ.east_asia_pacific);
      const re = await match(e, 'storm', 'anxious', TZ.east_asia_pacific);
      roomId = rd.body.room.roomId;
      expect(re.body.room.roomId).toBe(roomId);
      dMember = rd.body.me.memberId;
      eMember = re.body.me.memberId;
      se = await listen(e, [`member:${eMember}`]);
    });

    afterAll(() => setMatching({ gesture_min_interval_ms: 0, gesture_room_hour_max: 40 }));

    const toE = (type: string) => gesture(d, roomId, { type, target: 'member', toMemberId: eMember });

    it('1 per 2 s: the second gesture inside 2 s looks sent but is dropped', async () => {
      await setMatching({ gesture_min_interval_ms: 2000 });
      const first = await toE('warm_tea');
      const second = await toE('hug');
      expect([first.status, second.status]).toEqual([202, 202]);
      expect(Object.keys(second.body).sort()).toEqual(['at', 'gestureId']);
      expect((await gestureRow(first.body.gestureId)).dropped).toBeNull();
      expect((await gestureRow(second.body.gestureId)).dropped).toBe('over_limit');
      await se.waitForBroadcast(`member:${eMember}`, 'gesture_received', (p) => p.gestureId === first.body.gestureId);
      await sleep(1500);
      expect(se.broadcasts(`member:${eMember}`, 'gesture_received').map((b) => b.payload.gestureId)).not.toContain(second.body.gestureId);
      await setMatching({ gesture_min_interval_ms: 0 });
    });

    it('same gesture to the same member ≤ 3 per 10 min; 40 per room per hour; 3 hits in 24 h → 24 h shadow-mute + spam item', async () => {
      const soft = [await toE('soft_rain'), await toE('soft_rain'), await toE('soft_rain'), await toE('soft_rain')];
      expect(soft.map((r) => r.status)).toEqual([202, 202, 202, 202]);
      expect((await gestureRow(soft[2].body.gestureId)).dropped).toBeNull();
      expect((await gestureRow(soft[3].body.gestureId)).dropped).toBe('over_limit'); // hit #2

      // counted so far in this room: warm_tea + 3 soft_rain = 4 → cap the room-hour limit there for hit #3
      await setMatching({ gesture_room_hour_max: 4 });
      const third = await toE('stargaze');
      expect(third.status).toBe(202);
      expect((await gestureRow(third.body.gestureId)).dropped).toBe('over_limit');

      const mute = await one<{ kind: string; source: string; hours: number; report_id: string | null }>(
        `select kind, source, round(extract(epoch from (ends_at - starts_at)) / 3600)::int as hours, report_id
           from public.sanctions where user_id = $1 and kind = 'gesture_shadow_mute'`,
        [d.id],
      );
      expect(mute).toMatchObject({ kind: 'gesture_shadow_mute', source: 'auto', hours: 24 });
      const auto = await one<{ lane: string; source: string; auto_signal: string; target_user_id: string; evidence_hold_id: string | null }>(
        'select lane, source, auto_signal, target_user_id, evidence_hold_id from public.reports where id = $1',
        [mute.report_id],
      );
      expect(auto).toMatchObject({ lane: 'spam', source: 'auto', auto_signal: 'gesture_flood', target_user_id: d.id });
      expect(auto.evidence_hold_id).not.toBeNull();
      const audit = await one<{ actor: string; subject_hash: string; detail: unknown }>(
        `select actor, subject_hash, detail from public.moderation_actions where report_id = $1 and action = 'auto_gesture_shadow_mute'`,
        [mute.report_id],
      );
      expect(audit.actor).toBe('system');
      expect(audit.subject_hash).toMatch(/^[0-9a-f]{64}$/);
      expect(JSON.stringify(audit)).not.toContain(d.id);

      await setMatching({ gesture_room_hour_max: 40 });
      const muted = await toE('deep_breath');
      expect(muted.status).toBe(202);
      expect((await gestureRow(muted.body.gestureId)).dropped).toBe('shadow_muted');
      const dView = await detail(d, roomId);
      expect(dView.body.gestures.sent.map((g: { gestureId: string }) => g.gestureId)).toContain(muted.body.gestureId); // looks sent
      const eView = await detail(e, roomId);
      expect(eView.body.gestures.received.map((g: { gestureId: string }) => g.gestureId)).not.toContain(muted.body.gestureId);
      const standing = await call(d, 'get', '/v1/safety/me');
      expect(standing.body).toEqual({ rooms: 'available', until: null, notices: [] }); // shadow-mutes are invisible
    });
  });

  // ================================================================== blocks
  describe('blocks', () => {
    let f: TestUser;
    let g: TestUser;
    let h: TestUser;
    let roomId: string;
    let fMember: string;
    let gMember: string;
    let blockId: string;
    let sf: RealtimeClient;

    beforeAll(async () => {
      await freshRooms();
      [f, g, h] = await Promise.all([mk('blk-f', { locale: 'te-Latn' }), mk('blk-g', { locale: 'te-Latn' }), mk('blk-h', { locale: 'te-Latn' })]);
      const rf = await match(f, 'storm', 'anxious', TZ.south_asia);
      const rg = await match(g, 'storm', 'anxious', TZ.south_asia);
      roomId = rf.body.room.roomId;
      expect(rg.body.room.roomId).toBe(roomId);
      fMember = rf.body.me.memberId;
      gMember = rg.body.me.memberId;
      sf = await listen(f, [`member:${fMember}`]);
    });

    it('block → 201 (repeat 200, same id); the list keeps no pseudonym or identity', async () => {
      const r = await call(f, 'post', '/v1/safety/blocks', { roomId, memberId: gMember });
      expect(r.status).toBe(201);
      expect(r.body).toEqual({ blockId: expect.any(String) });
      blockId = r.body.blockId;
      const again = await call(f, 'post', '/v1/safety/blocks', { roomId, memberId: gMember });
      expect(again.status).toBe(200);
      expect(again.body).toEqual({ blockId });
      const list = await call(f, 'get', '/v1/safety/blocks');
      expect(list.body).toEqual({ blocks: [{ blockId, quadrant: 'storm', createdAt: expect.any(String) }] });
    });

    it('the blocker stops seeing them; the blocked person sees no change; gestures drop both ways but look sent', async () => {
      const fView = await detail(f, roomId);
      expect(fView.body.members.map((m: { memberId: string }) => m.memberId)).toEqual([fMember]);
      const gView = await detail(g, roomId);
      expect(gView.body.members.map((m: { memberId: string }) => m.memberId)).toEqual([fMember, gMember]);
      expect(gView.body.counts).toEqual(fView.body.counts); // counts are room facts, identical for both

      const gToF = await gesture(g, roomId, { type: 'warm_tea', target: 'member', toMemberId: fMember });
      expect(gToF.status).toBe(202);
      expect((await gestureRow(gToF.body.gestureId)).dropped).toBe('blocked');
      const fToG = await gesture(f, roomId, { type: 'hug', target: 'member', toMemberId: gMember });
      expect(fToG.status).toBe(202);
      expect((await gestureRow(fToG.body.gestureId)).dropped).toBe('blocked');
      await sleep(1200);
      expect(sf.broadcasts(`member:${fMember}`, 'gesture_received')).toEqual([]);
      expect((await detail(f, roomId)).body.gestures.received).toEqual([]);
      expect((await detail(g, roomId)).body.gestures.sent.map((x: { gestureId: string }) => x.gestureId)).toContain(gToF.body.gestureId);
    });

    it('REQ-SAFE-06: the pair is never matched into the same room again (every quadrant), while others still are', async () => {
      for (const [q, mood] of [
        ['rain', 'lonely'],
        ['sunrise', 'joyful'],
        ['moonlight', 'calm'],
      ] as const) {
        const gRoom = (await match(g, q, mood, TZ.south_asia)).body.room.roomId;
        const fRoom = await match(f, q, mood, TZ.south_asia);
        expect(fRoom.status).toBe(200);
        expect(fRoom.body.room.roomId).not.toBe(gRoom);
        expect(fRoom.body.match.created).toBe(true);
        const hRoom = await match(h, q, mood, TZ.south_asia); // control: G's room was joinable for anyone else
        expect([gRoom, fRoom.body.room.roomId]).toContain(hRoom.body.room.roomId);
      }
    });

    it('validation, then unblock → 204 (idempotent)', async () => {
      expect((await call(f, 'post', '/v1/safety/blocks', { roomId, memberId: fMember })).body.code).toBe('invalid_target');
      expect((await call(f, 'post', '/v1/safety/blocks', { roomId, memberId: randomUUID() })).body.code).toBe('member_not_found');
      expect((await call(h, 'post', '/v1/safety/blocks', { roomId, memberId: gMember })).body.code).toBe('not_found');
      expect((await call(f, 'post', '/v1/safety/blocks', { roomId })).status).toBe(400);
      expect((await call(f, 'delete', `/v1/safety/blocks/${blockId}`)).status).toBe(204);
      expect((await call(f, 'delete', `/v1/safety/blocks/${blockId}`)).status).toBe(204);
      expect((await call(f, 'get', '/v1/safety/blocks')).body).toEqual({ blocks: [] });
      expect((await detail(f, roomId)).body.members.map((m: { memberId: string }) => m.memberId)).toEqual([fMember, gMember]);
    });
  });

  // ================================================================== mutes and reports → lanes
  describe('mutes and reports', () => {
    let i: TestUser;
    let j: TestUser;
    let k: TestUser;
    let meera: TestUser;
    let roomId: string;
    const mem: Record<string, string> = {};

    beforeAll(async () => {
      await freshRooms();
      [i, j, k, meera] = await Promise.all([mk('rep-i'), mk('rep-j'), mk('rep-k'), mk('rep-meera', { dob: MINOR_DOB })]);
      for (const [name, u] of [
        ['i', i],
        ['j', j],
        ['k', k],
        ['meera', meera],
      ] as const) {
        const r = await match(u, 'rain', 'lonely', TZ.americas);
        roomId ??= r.body.room.roomId;
        expect(r.body.room.roomId).toBe(roomId);
        mem[name] = r.body.me.memberId;
      }
    });

    afterAll(() => setSafety({ report_daily_limit: 20 }));

    const report = (u: TestUser, target: Record<string, unknown>, reason: number, note?: string) =>
      call(u, 'post', '/v1/safety/reports', { target: { roomId, ...target }, reason, ...(note ? { note } : {}) });

    it('mute is per membership and for you only: their gestures to you drop; unmute restores', async () => {
      expect((await call(i, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: mem.j })).status).toBe(204);
      expect((await call(i, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: mem.j })).status).toBe(204); // idempotent
      const iView = await detail(i, roomId);
      expect(iView.body.members.find((m: { memberId: string }) => m.memberId === mem.j).muted).toBe(true);
      expect((await detail(k, roomId)).body.members.find((m: { memberId: string }) => m.memberId === mem.j).muted).toBe(false);
      const muted = await gesture(j, roomId, { type: 'hug', target: 'member', toMemberId: mem.i });
      expect(muted.status).toBe(202);
      expect((await gestureRow(muted.body.gestureId)).dropped).toBe('muted');
      expect((await call(i, 'delete', `/v1/rooms/${roomId}/mutes/${mem.j}`)).status).toBe(204);
      expect((await call(i, 'delete', `/v1/rooms/${roomId}/mutes/${mem.j}`)).status).toBe(204);
      const back = await gesture(j, roomId, { type: 'hug', target: 'member', toMemberId: mem.i });
      expect((await gestureRow(back.body.gestureId)).dropped).toBeNull();
      expect((await call(i, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: mem.i })).body.code).toBe('invalid_target');
      expect((await call(i, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: randomUUID() })).body.code).toBe('member_not_found');
      expect((await call(i, 'post', `/v1/rooms/${roomId}/mutes`, {})).status).toBe(400);
    });

    it('adult ↔ adult harassment → harassment lane; the member hides for the reporter; repeats count once', async () => {
      const r = await report(k, { kind: 'member', memberId: mem.j }, 2, 'kept sending the same thing');
      expect(r.status).toBe(201);
      expect(r.body).toEqual({ reportId: expect.any(String), showHelplines: false });
      const again = await report(k, { kind: 'member', memberId: mem.j }, 2);
      expect(again.status).toBe(200);
      expect(again.body.reportId).toBe(r.body.reportId);
      const row = await reportRow(r.body.reportId);
      expect(row).toMatchObject({ lane: 'harassment', involves_minor: false, status: 'open', reporter_user_id: k.id, target_user_id: j.id });
      const hold = await one<{ account_ids: string[]; hold_days: number; snapshot: string }>(
        `select account_ids, round(extract(epoch from (hold_until - created_at)) / 86400)::int as hold_days, snapshot::text as snapshot
           from public.evidence_holds where id = $1`,
        [row.evidence_hold_id],
      );
      expect(hold.account_ids).toEqual([j.id]); // the subject only — never the reporter
      expect(hold.hold_days).toBe(180);
      expect(hold.snapshot).not.toContain(k.id);
      expect((await detail(k, roomId)).body.members.find((m: { memberId: string }) => m.memberId === mem.j).muted).toBe(true);
    });

    it('reason 1 → crisis lane, helplines for the reporter, nothing hidden', async () => {
      const r = await report(i, { kind: 'member', memberId: mem.k }, 1);
      expect(r.body).toEqual({ reportId: expect.any(String), showHelplines: true });
      expect((await reportRow(r.body.reportId)).lane).toBe('crisis');
      expect((await detail(i, roomId)).body.members.find((m: { memberId: string }) => m.memberId === mem.k).muted).toBe(false);
    });

    it('anyone under 18 on either side → Minors & grooming lane, invisibly (same response as adults)', async () => {
      const byMinor = await report(meera, { kind: 'member', memberId: mem.j }, 6);
      const aboutMinor = await report(i, { kind: 'member', memberId: mem.meera }, 2);
      for (const r of [byMinor, aboutMinor]) {
        expect(r.status).toBe(201);
        expect(r.body).toEqual({ reportId: expect.any(String), showHelplines: false });
        expect(await reportRow(r.body.reportId)).toMatchObject({ lane: 'minors_grooming', involves_minor: true });
      }
      const roomReport = await report(k, { kind: 'room' }, 8);
      expect(await reportRow(roomReport.body.reportId)).toMatchObject({ lane: 'minors_grooming', involves_minor: true });
    });

    it('a reported gesture drops out of the reporter’s lists', async () => {
      const g = await gesture(j, roomId, { type: 'stargaze', target: 'member', toMemberId: mem.i });
      expect((await detail(i, roomId)).body.gestures.received.map((x: { gestureId: string }) => x.gestureId)).toContain(g.body.gestureId);
      const r = await report(i, { kind: 'gesture', gestureId: g.body.gestureId }, 3);
      expect(r.status).toBe(201);
      expect(await reportRow(r.body.reportId)).toMatchObject({ lane: 'harassment', target_user_id: j.id });
      const after = await detail(i, roomId);
      expect(after.body.gestures.received.map((x: { gestureId: string }) => x.gestureId)).not.toContain(g.body.gestureId);
      expect(after.body.gestures.recent.map((x: { gestureId: string }) => x.gestureId)).not.toContain(g.body.gestureId);
      expect((await report(j, { kind: 'gesture', gestureId: g.body.gestureId }, 3)).body.code).toBe('invalid_target');
    });

    it('two different people saying "may be under 13" pause that account’s rooms pending review', async () => {
      const first = await report(i, { kind: 'member', memberId: mem.meera }, 7);
      expect(await reportRow(first.body.reportId)).toMatchObject({ lane: 'minors_grooming' });
      expect((await report(i, { kind: 'member', memberId: mem.meera }, 7)).status).toBe(200); // same person: counts once
      expect((await call(meera, 'get', '/v1/rooms')).status).toBe(200);
      await report(k, { kind: 'member', memberId: mem.meera }, 7);

      const blocked = await call(meera, 'get', '/v1/rooms');
      expect(blocked.status).toBe(403);
      expect(blocked.body.code).toBe('rooms_suspended');
      expect((await match(meera, 'storm', 'anxious', TZ.americas)).body.code).toBe('rooms_suspended');
      const standing = await call(meera, 'get', '/v1/safety/me');
      expect(standing.body).toEqual({
        rooms: 'suspended',
        until: null,
        notices: [{ noticeId: expect.any(String), kind: 'suspension', reasonCode: 'under_13_reports', createdAt: expect.any(String), until: null }],
      });
      expect((await detail(i, roomId)).body.members.map((m: { memberId: string }) => m.memberId)).not.toContain(mem.meera);
      const s = await socket();
      expect((await s.join(`room:${roomId}`, meera.token)).ok).toBe(false);
      // help is never locked: a paused account can still report
      expect((await report(meera, { kind: 'member', memberId: mem.k }, 1)).status).toBe(201);
    });

    it('reports: 20/day for reasons 2–8 (429), reason 1 unlimited; validation', async () => {
      const used = await one<{ n: number }>(
        `select count(*)::int as n from public.reports where reporter_user_id = $1 and source = 'user' and reason <> 1`,
        [k.id],
      );
      await setSafety({ report_daily_limit: used.n });
      const over = await report(k, { kind: 'member', memberId: mem.i }, 4);
      expect(over.status).toBe(429);
      expect(over.body.code).toBe('report_limit');
      expect((await report(k, { kind: 'member', memberId: mem.i }, 1)).status).toBe(201);
      await setSafety({ report_daily_limit: 20 });

      expect((await report(k, { kind: 'member', memberId: mem.i }, 9)).body.code).toBe('invalid_request');
      expect((await report(k, { kind: 'member', memberId: mem.k }, 2)).body.code).toBe('invalid_target');
      expect((await report(k, { kind: 'member', memberId: randomUUID() }, 2)).body.code).toBe('not_found');
      expect((await report(k, { kind: 'member', memberId: mem.i }, 2, 'x'.repeat(501))).body.code).toBe('invalid_request');
      const outsider = await mk('rep-outsider');
      expect((await report(outsider, { kind: 'room' }, 2)).body.code).toBe('not_found');
    });

    it('GET /v1/safety/reports: the reporter’s inbox, never the lane', async () => {
      const r = await call(k, 'get', '/v1/safety/reports');
      expect(r.status).toBe(200);
      expect(r.body.reports.length).toBeGreaterThanOrEqual(3);
      for (const x of r.body.reports) {
        expect(Object.keys(x).sort()).toEqual(['createdAt', 'outcome', 'reason', 'reportId', 'reviewedAt', 'status', 'targetKind']);
        expect(x).toMatchObject({ status: 'received', outcome: null, reviewedAt: null });
      }
    });
  });

  // ================================================================== lifecycle: Lantern Hour, memory, purge
  describe('lifecycle', () => {
    let n: TestUser;
    let o: TestUser;
    let p: TestUser;
    let roomId: string;
    let nMember: string;
    let oMember: string;
    let sn: RealtimeClient;
    let reportId: string;

    beforeAll(async () => {
      await freshRooms();
      [n, o, p] = await Promise.all([mk('life-n'), mk('life-o'), mk('life-p')]);
      const rn = await match(n, 'sunrise', 'joyful', TZ.south_asia);
      const ro = await match(o, 'sunrise', 'proud', TZ.south_asia);
      roomId = rn.body.room.roomId;
      expect(ro.body.room.roomId).toBe(roomId);
      nMember = rn.body.me.memberId;
      oMember = ro.body.me.memberId;
      sn = await listen(n, [`room:${roomId}`]);
    });

    it('REQ-ROOM-11: Lantern Hour starts at 21:00 and ends at 23:00 on the room’s region clock (IST here)', async () => {
      const w = lanternWindow('south_asia', new Date());
      const inside = new Date(w.startsAt.getTime() + 30 * 60_000);
      const after = new Date(w.endsAt.getTime() + 30 * 60_000);
      // Keep the room young relative to the simulated clock.
      await db.query(
        `update public.rooms set created_at = $2::timestamptz - interval '1 hour', opened_at = $2::timestamptz - interval '50 minutes',
                joins_close_at = $2::timestamptz + interval '19 hours', memory_at = $2::timestamptz + interval '23 hours',
                purge_at = $2::timestamptz + interval '23 hours' + interval '7 days', status = 'open'
          where id = $1`,
        [roomId, inside],
      );
      await runRoomLifecycle(db, inside);
      expect((await one<{ status: string }>('select status from public.rooms where id = $1', [roomId])).status).toBe('lantern_hour');
      const started = await sn.waitForBroadcast(`room:${roomId}`, 'lantern_hour', (x) => (x.lanternHour as { active: boolean }).active);
      expect(started.payload.lanternHour).toEqual({
        timezone: 'Asia/Kolkata',
        active: true,
        startsAt: w.startsAt.toISOString(),
        endsAt: w.endsAt.toISOString(),
      });
      await sn.waitForBroadcast(`room:${roomId}`, 'room_state', (x) => x.state === 'lantern_hour');

      await runRoomLifecycle(db, after);
      expect((await one<{ status: string }>('select status from public.rooms where id = $1', [roomId])).status).toBe('open');
      await sn.waitForBroadcast(`room:${roomId}`, 'lantern_hour', (x) => (x.lanternHour as { active: boolean }).active === false);
      await sn.waitForBroadcast(`room:${roomId}`, 'room_state', (x) => x.state === 'open');
    });

    it('REQ-ROOM-07: at 24 h the room is a read-only memory for its members only; report/block/mute still work', async () => {
      await db.query(
        `update public.rooms set created_at = now() - interval '25 hours', opened_at = now() - interval '24 hours 50 minutes',
                joins_close_at = now() - interval '5 hours', memory_at = now() - interval '1 hour',
                purge_at = now() - interval '1 hour' + interval '7 days'
          where id = $1`,
        [roomId],
      );
      await runRoomLifecycle(db);
      await sn.waitForBroadcast(`room:${roomId}`, 'room_state', (x) => x.state === 'memory' && x.readOnly === true);
      const view = await detail(n, roomId);
      expect(view.status).toBe(200);
      expect(view.body.room).toMatchObject({ state: 'memory', readOnly: true });
      const g = await gesture(n, roomId, { type: 'hug', target: 'room' });
      expect(g.status).toBe(409);
      expect(g.body.code).toBe('room_read_only');
      const seen = await one<{ last_seen_at: Date }>('select last_seen_at from public.room_members where member_id = $1', [nMember]);
      expect((await call(n, 'post', `/v1/rooms/${roomId}/heartbeat`)).body.room.state).toBe('memory');
      expect((await one<{ last_seen_at: Date }>('select last_seen_at from public.room_members where member_id = $1', [nMember])).last_seen_at).toEqual(
        seen.last_seen_at,
      );
      expect((await call(n, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: oMember })).status).toBe(204);
      const rep = await call(n, 'post', '/v1/safety/reports', { target: { kind: 'member', roomId, memberId: oMember }, reason: 4 });
      expect(rep.status).toBe(201);
      reportId = rep.body.reportId;
      expect((await detail(p, roomId)).status).toBe(404); // non-members can't read a memory
      const list = await call(n, 'get', '/v1/rooms');
      expect(list.body.rooms.find((x: { room: { roomId: string } }) => x.room.roomId === roomId).room.state).toBe('memory');
      const fresh = await match(n, 'sunrise', 'excited', TZ.south_asia); // a memory is not an active room
      expect(fresh.body.room.roomId).not.toBe(roomId);
      expect(fresh.body.match.reentry).toBe(false);
    });

    it('purge at 24 h + 7 d: no content rows remain outside the evidence store', async () => {
      await db.query(
        `update public.rooms set created_at = now() - interval '8 days 2 hours', opened_at = now() - interval '8 days 1 hour',
                joins_close_at = now() - interval '7 days 6 hours', memory_at = now() - interval '7 days 2 hours',
                purge_at = now() - interval '1 minute'
          where id = $1`,
        [roomId],
      );
      const holdBefore = (await reportRow(reportId)).evidence_hold_id;
      expect(holdBefore).not.toBeNull();
      const s = await runRoomLifecycle(db);
      expect(s.purged).toBeGreaterThanOrEqual(1);
      expect(s.errors).toEqual([]);
      for (const [table, col] of [
        ['rooms', 'id'],
        ['room_members', 'room_id'],
        ['room_gestures', 'room_id'],
        ['room_mutes', 'room_id'],
      ]) {
        expect((await one<{ n: number }>(`select count(*)::int as n from public.${table} where ${col} = $1`, [roomId])).n).toBe(0);
      }
      const after = await reportRow(reportId);
      expect(after.room_id).toBeNull();
      expect(after.evidence_hold_id).toBe(holdBefore);
      const hold = await one<{ room_id: string; pseudonyms: string[] }>(
        `select snapshot->'room'->>'id' as room_id, array(select jsonb_array_elements(snapshot->'members')->>'pseudonym') as pseudonyms
           from public.evidence_holds where id = $1`,
        [holdBefore],
      );
      expect(hold.room_id).toBe(roomId);
      expect(hold.pseudonyms.length).toBe(1);
      expect((await detail(n, roomId)).status).toBe(404);

      await db.query(`update public.evidence_holds set created_at = now() - interval '181 days', hold_until = now() - interval '1 day' where id = $1`, [holdBefore]);
      const s2 = await runRoomLifecycle(db);
      expect(s2.evidenceExpired).toBeGreaterThanOrEqual(1);
      expect((await reportRow(reportId)).evidence_hold_id).toBeNull();
    });
  });

  // ================================================================== capacity under concurrency (real DB)
  it('REQ-ROOM-03: concurrent joins never create a 25th member', async () => {
    await freshRooms();
    const full = await roomWithFakes({ pool: 'en', quadrant: 'moonlight', region: 'europe_africa', members: 22, live: false });
    const joiners = await Promise.all([1, 2, 3, 4, 5, 6].map((x) => mk(`cap-${x}`)));
    const results = await Promise.all(joiners.map((u) => match(u, 'moonlight', 'grateful', TZ.europe_africa)));
    expect(results.map((r) => r.status)).toEqual([200, 200, 200, 200, 200, 200]);
    const active = await one<{ n: number }>('select count(*)::int as n from public.room_members where room_id = $1 and left_at is null', [full]);
    expect(active.n).toBe(24);
    expect(results.filter((r) => r.body.room.roomId === full)).toHaveLength(2);
    const over = await db.query(
      `select r.id from public.rooms r join public.room_members m on m.room_id = r.id and m.left_at is null
        group by r.id, r.capacity having count(*) > r.capacity`,
    );
    expect(over.rows).toEqual([]);
  });

  // ================================================================== leave, survey, join limit
  describe('leave, survey and the join limit', () => {
    let q: TestUser;
    let r2: TestUser;

    beforeAll(async () => {
      await freshRooms();
      [q, r2] = await Promise.all([mk('leave-q', { locale: 'te-Latn' }), mk('leave-r', { locale: 'te-Latn' })]);
    });

    it('leaving frees the quadrant slot, is broadcast, and you never rejoin that room', async () => {
      const first = await match(q, 'moonlight', 'content', TZ.americas);
      const roomId = first.body.room.roomId as string;
      const other = await match(r2, 'moonlight', 'calm', TZ.americas);
      expect(other.body.room.roomId).toBe(roomId);
      const s = await listen(r2, [`room:${roomId}`]);
      const left = await call(q, 'post', `/v1/rooms/${roomId}/leave`);
      expect(left.status).toBe(200);
      expect(left.body).toEqual({ surveyEligible: false }); // < 30 s in the room
      expect((await call(q, 'post', `/v1/rooms/${roomId}/leave`)).status).toBe(200); // idempotent
      const ev = await s.waitForBroadcast(`room:${roomId}`, 'member_left', (x) => x.memberId === first.body.me.memberId);
      expect(ev.payload).toEqual({ id: expect.any(String), memberId: first.body.me.memberId, counts: { hereNow: 1, today: 2 }, at: expect.any(String) });
      expect((await detail(q, roomId)).status).toBe(404);
      expect((await call(q, 'get', '/v1/rooms')).body.rooms).toEqual([]);
      const again = await match(q, 'moonlight', 'content', TZ.americas);
      expect(again.body.room.roomId).not.toBe(roomId); // no rejoining, although it's live and joinable
      expect(again.body.match.created).toBe(true);
    });

    it('survey: aggregate only, after ≥ 30 s, at most once a day', async () => {
      const mine = (await call(q, 'get', '/v1/rooms')).body.rooms[0];
      const roomId = mine.room.roomId as string;
      await db.query(`update public.room_members set joined_at = now() - interval '2 minutes' where member_id = $1`, [mine.me.memberId]);
      expect((await detail(q, roomId)).body.me.surveyEligible).toBe(true);
      const count = () =>
        one<{ n: number }>(
          `select coalesce(sum(n), 0)::int as n from public.room_survey_counts
            where day = (now() at time zone 'utc')::date and language_pool = 'te' and quadrant = 'moonlight' and tz_region = 'americas' and answer = 'yes'`,
        );
      const before = (await count()).n;
      const left = await call(q, 'post', `/v1/rooms/${roomId}/leave`);
      expect(left.body).toEqual({ surveyEligible: true });
      expect((await call(q, 'post', `/v1/rooms/${roomId}/survey`, { answer: 'yes' })).status).toBe(204);
      expect((await count()).n).toBe(before + 1);
      expect((await call(q, 'post', `/v1/rooms/${roomId}/survey`, { answer: 'yes' })).status).toBe(204); // ignored
      expect((await count()).n).toBe(before + 1);
      expect((await call(q, 'post', `/v1/rooms/${roomId}/survey`, { answer: 'maybe' })).status).toBe(400);
      const cols = await db.query(`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'room_survey_counts'`);
      expect(cols.rows.map((x) => x.column_name).sort()).toEqual(['answer', 'day', 'language_pool', 'n', 'quadrant', 'tz_region']);
    });

    it('3 new rooms per quadrant per 24 h → 429 room_join_limit; returning to your room is always free', async () => {
      const third = await match(q, 'moonlight', 'grateful', TZ.americas); // q's 3rd moonlight join today
      expect(third.status).toBe(200);
      await call(q, 'post', `/v1/rooms/${third.body.room.roomId}/leave`);
      const fourth = await match(q, 'moonlight', 'grateful', TZ.americas);
      expect(fourth.status).toBe(429);
      expect(fourth.body.code).toBe('room_join_limit');
      for (let x = 0; x < 5; x++) expect((await match(r2, 'moonlight', 'calm', TZ.americas)).body.match.step).toBe(0);
    });
  });

  // ================================================================== pools, thin merge, adjacent merge
  describe('partitions', () => {
    beforeAll(freshRooms);
    afterAll(() => setMatching({ thin_join_threshold: 0, partition_live_min: 1, adjacent_live_min: 48 }));

    it('Hindi + Hinglish rooms stay off: 409 unless the person chooses an English room', async () => {
      const hi = await mk('pool-hi', { locale: 'hi-Latn' });
      const r = await match(hi, 'rain', 'drained', TZ.east_asia_pacific);
      expect(r.status).toBe(409);
      expect(r.body.code).toBe('language_pool_unavailable');
      const ok = await match(hi, 'rain', 'drained', TZ.east_asia_pacific, { allowPoolFallback: true });
      expect(ok.status).toBe(200);
      const row = await one<{ language_pool: string; home_language_pool: string }>(
        `select r.language_pool, m.home_language_pool from public.room_members m join public.rooms r on r.id = m.room_id where m.member_id = $1`,
        [ok.body.me.memberId],
      );
      expect(row).toEqual({ language_pool: 'en', home_language_pool: 'hi' });
      expect((await db.query(`select 1 from public.rooms where language_pool = 'hi'`)).rowCount).toBe(0);
    });

    it('REQ-ROOM-10: a thin Dallas Telugu partition merges (cold start → en × south_asia); a busier one stays', async () => {
      await freshRooms();
      await setMatching({ thin_join_threshold: 12 });
      const dallas = await mk('thin-dallas', { locale: 'te-Latn', tz: TZ.americas });
      const merged = await match(dallas, 'storm', 'anxious', TZ.americas);
      expect(merged.body.match).toMatchObject({ merged: true, created: true });
      const placed = await one<{ language_pool: string; tz_region: string }>('select language_pool, tz_region from public.rooms where id = $1', [
        merged.body.room.roomId,
      ]);
      expect(placed).toEqual({ language_pool: 'en', tz_region: 'south_asia' });
      expect(merged.body.room.lanternHour.timezone).toBe('Asia/Kolkata'); // merged rooms keep their home region's clock

      const busy = await roomWithFakes({ pool: 'te', quadrant: 'sunrise', region: 'americas', members: 12, live: false });
      const dallas2 = await mk('thin-dallas2', { locale: 'te-Latn', tz: TZ.americas });
      const stays = await match(dallas2, 'sunrise', 'joyful', TZ.americas);
      expect(stays.body.match.merged).toBe(false);
      expect(stays.body.room.roomId).toBe(busy);
      expect(stays.body.room.lanternHour.timezone).toBe('America/Chicago');
    });

    it('step 3 merges into the adjacent quadrant on the same side only (never pleasant with unpleasant)', async () => {
      await freshRooms();
      await setMatching({ thin_join_threshold: 0, partition_live_min: 3, adjacent_live_min: 3 });
      const rain = await roomWithFakes({ pool: 'te', quadrant: 'rain', region: 'east_asia_pacific', members: 3, live: true });
      const pleasant = await roomWithFakes({ pool: 'te', quadrant: 'moonlight', region: 'east_asia_pacific', members: 6, live: true });
      const u = await mk('adj-storm', { locale: 'te-Latn' });
      const r = await match(u, 'storm', 'restless', TZ.east_asia_pacific);
      expect(r.body.match).toEqual({ step: 3, reentry: false, created: false, merged: true });
      expect(r.body.room).toMatchObject({ roomId: rain, quadrant: 'rain' });
      const back = await match(u, 'storm', 'anxious', TZ.east_asia_pacific); // the storm check-in returns to it
      expect(back.body.match.step).toBe(0);
      expect(back.body.room.roomId).toBe(rain);
      const v = await mk('adj-sunrise', { locale: 'te-Latn' });
      const s = await match(v, 'sunrise', 'excited', TZ.east_asia_pacific);
      expect(s.body.room.roomId).toBe(pleasant); // sunrise → moonlight, never → rain
      expect(s.body.match.step).toBe(3);
    });
  });

  // ================================================================== moderation service (internal API) and sanctions
  describe('moderation (internal API) and sanctions', () => {
    let s1: TestUser;
    let t1: TestUser;
    let u1: TestUser;
    let roomId: string;
    const mem: Record<string, string> = {};
    let mod: ModerationService;

    beforeAll(async () => {
      await freshRooms();
      mod = app.get(ModerationService);
      [s1, t1, u1] = await Promise.all([mk('mod-s'), mk('mod-t'), mk('mod-u')]);
      for (const [name, u] of [
        ['s', s1],
        ['t', t1],
        ['u', u1],
      ] as const) {
        const r = await match(u, 'rain', 'numb', TZ.europe_africa);
        roomId ??= r.body.room.roomId;
        mem[name] = r.body.me.memberId;
      }
    });

    const report = async (by: TestUser, memberId: string, reason: number): Promise<string> => {
      const r = await call(by, 'post', '/v1/safety/reports', { target: { kind: 'member', roomId, memberId }, reason });
      expect([200, 201]).toContain(r.status);
      return r.body.reportId;
    };

    it('queue: lane order, SLA, console-only flags — and no raw account ids', async () => {
      const harassment = await report(t1, mem.s, 2);
      const crisis = await report(u1, mem.s, 1);
      const queue = await mod.listQueue({ limit: 500 });
      const ids = queue.map((x) => x.reportId);
      expect(ids).toEqual(expect.arrayContaining([crisis, harassment]));
      expect(ids.indexOf(crisis)).toBeLessThan(ids.indexOf(harassment));
      const item = queue.find((x) => x.reportId === harassment);
      expect(item).toMatchObject({
        lane: 'harassment',
        reason: 2,
        reasonKey: 'harassment',
        involvesMinor: false,
        overdue: false,
        room: { roomId, quadrant: 'rain', languagePool: 'en', tzRegion: 'europe_africa' },
        subject: { hash: expect.stringMatching(/^[0-9a-f]{64}$/), activeStrikes: 0, activeSanctions: [] },
      });
      expect(JSON.stringify(queue)).not.toContain(s1.id);
      await expect(mod.act({ reportId: crisis, action: 'strike', actor: 'staff:e2e' })).rejects.toMatchObject({ code: 'crisis_never_strikes' });
      await expect(mod.act({ reportId: randomUUID(), action: 'dismiss', actor: 'staff:e2e' })).rejects.toBeInstanceOf(ModerationError);
      const dismissed = await mod.act({ reportId: crisis, action: 'dismiss', actor: 'staff:e2e' });
      expect(dismissed.status).toBe('dismissed');
      const inbox = await call(u1, 'get', '/v1/safety/reports');
      expect(inbox.body.reports.find((x: { reportId: string }) => x.reportId === crisis)).toMatchObject({ status: 'reviewed', outcome: 'no_action' });

      // strike 1 → a visible warning notice
      const s1Strike = await mod.act({ reportId: harassment, action: 'strike', actor: 'staff:e2e' });
      expect(s1Strike).toMatchObject({ status: 'actioned', activeStrikes: 1, strikeId: expect.any(String) });
      expect((await call(s1, 'get', '/v1/safety/me')).body.notices).toEqual([
        { noticeId: expect.any(String), kind: 'warning', reasonCode: 'harassment', createdAt: expect.any(String), until: null },
      ]);
      expect((await call(t1, 'get', '/v1/safety/reports')).body.reports[0]).toMatchObject({ status: 'reviewed', outcome: 'action_taken' });
    });

    it('strike 2 → 24 h shadow-mute (invisible to them): their gestures look sent but never arrive', async () => {
      const r = await report(u1, mem.s, 4);
      const out = await mod.act({ reportId: r, action: 'strike', actor: 'staff:e2e' });
      expect(out.activeStrikes).toBe(2);
      expect((await call(s1, 'get', '/v1/safety/me')).body.notices).toHaveLength(1); // no new visible notice
      const g = await gesture(s1, roomId, { type: 'hug', target: 'member', toMemberId: mem.t });
      expect(g.status).toBe(202);
      expect((await gestureRow(g.body.gestureId)).dropped).toBe('shadow_muted');
    });

    it('suspend → 403 rooms_suspended, leaves rooms for everyone else, realtime refused; lift restores', async () => {
      const st = await listen(t1, [`room:${roomId}`]);
      const r = await report(t1, mem.s, 3);
      const out = await mod.act({ reportId: r, action: 'suspend', actor: 'staff:e2e', hours: 24 });
      expect(out.sanctionId).toEqual(expect.any(String));
      const blocked = await call(s1, 'get', '/v1/rooms');
      expect(blocked.status).toBe(403);
      expect(blocked.body.code).toBe('rooms_suspended');
      const me = await call(s1, 'get', '/v1/safety/me');
      expect(me.body.rooms).toBe('suspended');
      expect(Math.abs(new Date(me.body.until).getTime() - (Date.now() + 24 * 3_600_000))).toBeLessThan(120_000);
      await st.waitForBroadcast(`room:${roomId}`, 'member_left', (x) => x.memberId === mem.s);
      expect((await detail(t1, roomId)).body.members.map((m: { memberId: string }) => m.memberId)).not.toContain(mem.s);
      const sock = await socket();
      expect((await sock.join(`room:${roomId}`, s1.token)).ok).toBe(false);
      expect((await call(s1, 'post', '/v1/safety/blocks', { roomId, memberId: mem.u })).status).toBe(201); // help never locked

      await mod.liftSanction(out.sanctionId as string, 'staff:e2e', 'appeal_upheld');
      expect((await call(s1, 'get', '/v1/rooms')).status).toBe(200);
    });

    it('minors & grooming ban: account closed, 180-day evidence hold, mandatory-report task; audit is hash-chained and append-only', async () => {
      const kid = await mk('mod-kid', { dob: MINOR_DOB });
      const kr = await match(kid, 'rain', 'lonely', TZ.europe_africa);
      expect(kr.body.room.roomId).toBe(roomId);
      const r = await report(kid, mem.u, 5); // contact / personal info towards a minor
      expect(await reportRow(r)).toMatchObject({ lane: 'minors_grooming', involves_minor: true });
      const pages = await one<{ pages: boolean; mins: number }>(
        `select pages, round(extract(epoch from (sla_due_at - created_at)) / 60)::int as mins from public.reports where id = $1`,
        [r],
      );
      expect(pages).toEqual({ pages: true, mins: 120 });
      await mod.act({ reportId: r, action: 'ban', actor: 'staff:owner', reasonCode: 'grooming' });
      for (const path of ['/v1/rooms', '/v1/safety/blocks']) {
        const res = await call(u1, 'get', path);
        expect(res.status).toBe(path === '/v1/rooms' ? 403 : 200);
      }
      expect((await call(u1, 'get', '/v1/rooms')).body.code).toBe('account_closed');
      expect((await call(u1, 'post', '/v1/safety/reports', { target: { kind: 'room', roomId }, reason: 8 })).body.code).toBe('account_closed');
      expect((await call(u1, 'get', '/v1/safety/me')).body).toMatchObject({ rooms: 'closed', notices: [expect.objectContaining({ kind: 'account_closed' })] });
      const hold = await one<{ id: string; mandatory: boolean; days: number }>(
        `select e.id, e.mandatory_report_required as mandatory, round(extract(epoch from (e.hold_until - now())) / 86400)::int as days
           from public.evidence_holds e join public.reports r on r.evidence_hold_id = e.id where r.id = $1`,
        [r],
      );
      expect(hold.mandatory).toBe(true);
      expect(hold.days).toBeGreaterThanOrEqual(179);
      expect((await mod.pendingMandatoryReports()).map((x) => x.evidenceHoldId)).toContain(hold.id);
      await mod.recordMandatoryReport(hold.id, 'staff:owner', { reportedTo: 'NCRP', reportRef: 'E2E-REF-1' });
      expect((await mod.pendingMandatoryReports()).map((x) => x.evidenceHoldId)).not.toContain(hold.id);

      const log = await mod.auditLog({ limit: 50 });
      expect(log.map((x) => x.action)).toEqual(expect.arrayContaining(['strike', 'dismiss', 'suspend', 'lift', 'ban', 'mandatory_report']));
      for (const row of log) expect(row.reasonCode === null || /^[a-z0-9_]+$/.test(row.reasonCode)).toBe(true);
      const blob = JSON.stringify(log);
      for (const u of [s1, t1, u1, kid]) expect(blob).not.toContain(u.id);
      expect(await mod.verifyAuditChain()).toBe(true);
      await expect(db.query(`update public.moderation_actions set actor = 'x' where id = $1`, [log[0].id])).rejects.toMatchObject({ code: 'AR010' });
      await expect(db.query('delete from public.moderation_actions where id = $1', [log[0].id])).rejects.toMatchObject({ code: 'AR010' });
    });
  });

  // ================================================================== pending deletion
  it('an account pending deletion is refused (403), deactivated for others and cut from realtime', async () => {
    await freshRooms();
    const w = await mk('pend-w');
    const x = await mk('pend-x');
    const rw = await match(w, 'sunrise', 'proud', TZ.americas);
    const roomId = rw.body.room.roomId as string;
    await match(x, 'sunrise', 'proud', TZ.americas);
    await http().post('/v1/account/deletion').set('Authorization', `Bearer ${w.token}`).expect(202);
    for (const res of [await call(w, 'get', '/v1/rooms'), await match(w, 'sunrise', 'proud', TZ.americas), await call(w, 'get', '/v1/safety/me')]) {
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('account_deletion_pending');
    }
    expect((await detail(x, roomId)).body.members.map((m: { memberId: string }) => m.memberId)).not.toContain(rw.body.me.memberId);
    const s = await socket();
    expect((await s.join(`room:${roomId}`, w.token)).ok).toBe(false);
    await http().delete('/v1/account/deletion').set('Authorization', `Bearer ${w.token}`).expect(200);
    expect((await detail(x, roomId)).body.members.map((m: { memberId: string }) => m.memberId)).toContain(rw.body.me.memberId);
  });

  // ================================================================== account purge: only the documented legal hold remains
  it('account purge removes every rooms/safety reference to the account except LEGAL_HOLD_TABLES rows about it', async () => {
    await freshRooms();
    const victim = await mk('purge-v');
    const y = await mk('purge-y');
    const z = await mk('purge-z');
    const mod = app.get(ModerationService);
    const room1 = await match(victim, 'moonlight', 'calm', TZ.east_asia_pacific);
    const roomId = room1.body.room.roomId as string;
    const vm = room1.body.me.memberId as string;
    const ym = (await match(y, 'moonlight', 'calm', TZ.east_asia_pacific)).body.me.memberId as string;
    const zm = (await match(z, 'moonlight', 'content', TZ.east_asia_pacific)).body.me.memberId as string;
    await match(victim, 'sunrise', 'joyful', TZ.east_asia_pacific);
    await match(y, 'sunrise', 'joyful', TZ.east_asia_pacific);

    await gesture(victim, roomId, { type: 'warm_tea', target: 'member', toMemberId: ym });
    await gesture(y, roomId, { type: 'hug', target: 'member', toMemberId: vm });
    const vGesture = await gesture(victim, roomId, { type: 'me_too', target: 'room' });
    await call(victim, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: ym });
    await call(y, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: vm });
    await call(victim, 'post', '/v1/safety/blocks', { roomId, memberId: zm });
    await call(y, 'post', '/v1/safety/blocks', { roomId, memberId: vm });
    const filedByVictim = (await call(victim, 'post', '/v1/safety/reports', { target: { kind: 'member', roomId, memberId: ym }, reason: 2 })).body.reportId;
    const aboutVictim = (await call(y, 'post', '/v1/safety/reports', { target: { kind: 'member', roomId, memberId: vm }, reason: 2 })).body.reportId;
    const aboutVictimGesture = (await call(z, 'post', '/v1/safety/reports', { target: { kind: 'gesture', roomId, gestureId: vGesture.body.gestureId }, reason: 6 })).body.reportId;
    await mod.act({ reportId: aboutVictim, action: 'strike', actor: 'staff:e2e' }); // strike + warning on the victim

    await http().post('/v1/account/deletion').set('Authorization', `Bearer ${victim.token}`).expect(202);
    await db.query(
      `update public.account_deletions set requested_at = now() - interval '8 days', scheduled_for = now() - interval '1 day' where user_id = $1`,
      [victim.id],
    );
    const out = await purgeAccount(db, app.get(PrivateMediaStore), victim.id);
    expect(out.status).toBe('purged');

    // Scan every column of every public table for the account id (uuid, uuid[], json/jsonb, text).
    const cols = await db.query<{ table_name: string; column_name: string; data_type: string; udt_name: string }>(
      `select c.table_name, c.column_name, c.data_type, c.udt_name from information_schema.columns c
         join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name and t.table_type = 'BASE TABLE'
        where c.table_schema = 'public'`,
    );
    const hits = new Map<string, number>();
    for (const c of cols.rows) {
      const col = `"${c.column_name}"`;
      const cond =
        c.udt_name === 'uuid'
          ? `${col} = $1::uuid`
          : c.udt_name === '_uuid'
            ? `$1::uuid = any(${col})`
            : ['json', 'jsonb', 'text', 'character varying'].includes(c.data_type)
              ? `${col}::text ilike '%' || $1 || '%'`
              : null;
      if (!cond) continue;
      const n = Number((await db.query(`select count(*) from public."${c.table_name}" where ${cond}`, [victim.id])).rows[0].count);
      if (n > 0) hits.set(c.table_name, (hits.get(c.table_name) ?? 0) + n);
    }
    expect([...hits.keys()].filter((t) => !(LEGAL_HOLD_TABLES as readonly string[]).includes(t))).toEqual([]);
    expect(LEGAL_HOLD_TABLES).toEqual(['evidence_holds']);

    // What the legal hold keeps is only evidence ABOUT the account (it is a subject), never where it only reported.
    const held = await db.query<{ report_id: string; subject: boolean }>(
      `select report_id, $1::uuid = any(account_ids) as subject from public.evidence_holds where snapshot::text ilike '%' || $1 || '%'`,
      [victim.id],
    );
    expect(held.rows.every((x) => x.subject)).toBe(true);
    expect(held.rows.map((x) => x.report_id).sort()).toEqual([aboutVictim, aboutVictimGesture].sort());

    // Reports stay in their lanes, de-identified; blocks, mutes, memberships, gestures, sanctions and strikes are gone.
    expect(await reportRow(filedByVictim)).toMatchObject({ reporter_user_id: null, status: 'open' });
    expect(await reportRow(aboutVictim)).toMatchObject({ target_user_id: null });
    for (const [sql, params] of [
      ['select count(*)::int as n from public.room_members where user_id = $1', [victim.id]],
      ['select count(*)::int as n from public.room_gestures where from_member_id = $1 or to_member_id = $1', [vm]],
      ['select count(*)::int as n from public.room_mutes where muter_member_id = $1 or muted_member_id = $1', [vm]],
      ['select count(*)::int as n from public.blocks where blocker_user_id = $1 or blocked_user_id = $1', [victim.id]],
      ['select count(*)::int as n from public.sanctions where user_id = $1', [victim.id]],
      ['select count(*)::int as n from public.strikes where user_id = $1', [victim.id]],
    ] as const) {
      expect((await one<{ n: number }>(sql, [...params])).n).toBe(0);
    }
    // Everyone else is untouched.
    expect((await one<{ n: number }>('select count(*)::int as n from public.room_members where user_id = $1', [y.id])).n).toBe(2);
    expect((await detail(y, roomId)).body.members.map((m: { memberId: string }) => m.memberId).sort()).toEqual([ym, zm].sort());
  });

  // ================================================================== DS-10 contract test
  it('DS-10: no stranger-facing response or realtime payload carries an account id, email, DOB, age or lane', async () => {
    await freshRooms();
    // REQ-ROOM-12: Meera (16) and Arjun (26) share a room and get identical shapes.
    const meera = await mk('ds10-meera', { locale: 'te-Latn', dob: MINOR_DOB });
    const arjun = await mk('ds10-arjun', { locale: 'te-Latn', dob: '2000-05-05' });
    const rm = await match(meera, 'sunrise', 'joyful', TZ.europe_africa);
    const roomId = rm.body.room.roomId as string;
    const mm = rm.body.me.memberId as string;
    const sm = await listen(meera, [`room:${roomId}`, `member:${mm}`]);
    const ra = await match(arjun, 'sunrise', 'excited', TZ.europe_africa);
    expect(ra.body.room.roomId).toBe(roomId);
    const am = ra.body.me.memberId as string;
    const sa = await listen(arjun, [`room:${roomId}`, `member:${am}`]);

    const g1 = await gesture(arjun, roomId, { type: 'youre_not_alone', target: 'member', toMemberId: mm });
    const g2 = await gesture(meera, roomId, { type: 'light_a_candle', target: 'member', toMemberId: am });
    await gesture(meera, roomId, { type: 'soft_rain', target: 'room' });
    await sm.waitForBroadcast(`member:${mm}`, 'gesture_received', (p) => p.gestureId === g1.body.gestureId);
    await sa.waitForBroadcast(`member:${am}`, 'gesture_received', (p) => p.gestureId === g2.body.gestureId);
    await call(arjun, 'post', `/v1/rooms/${roomId}/heartbeat`);
    await call(meera, 'post', `/v1/rooms/${roomId}/mutes`, { memberId: am });
    await call(meera, 'delete', `/v1/rooms/${roomId}/mutes/${am}`);
    const rep = await call(arjun, 'post', '/v1/safety/reports', { target: { kind: 'member', roomId, memberId: mm }, reason: 2 });
    expect(await reportRow(rep.body.reportId)).toMatchObject({ lane: 'minors_grooming', involves_minor: true }); // server knows…
    expect(rep.body).toEqual({ reportId: expect.any(String), showHelplines: false }); // …clients never do
    const blk = await call(meera, 'post', '/v1/safety/blocks', { roomId, memberId: am });
    await call(meera, 'get', '/v1/safety/blocks');
    await call(meera, 'delete', `/v1/safety/blocks/${blk.body.blockId}`);
    for (const u of [meera, arjun]) {
      await call(u, 'get', '/v1/rooms');
      await detail(u, roomId);
      await call(u, 'get', '/v1/safety/me');
      await call(u, 'get', '/v1/safety/reports');
    }
    const [dm, da] = [await detail(meera, roomId), await detail(arjun, roomId)];
    const shape = (v: unknown): unknown =>
      Array.isArray(v) ? v.map(shape).slice(0, 1) : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, shape((v as Record<string, unknown>)[k])])) : typeof v;
    expect(shape({ ...dm.body, gestures: undefined })).toEqual(shape({ ...da.body, gestures: undefined })); // identical at every age
    await sleep(800);

    // ---- the scan: every recorded response of the whole suite + every broadcast any test socket received
    const secrets = [
      ...users.flatMap((u) => [u.id, u.email]),
      ...fakeAccounts,
      ...[...dobs],
    ].map((s) => s.toLowerCase());
    const FORBIDDEN_KEY =
      /^(user_?id|userIds?|account_?ids?|sub|email|birth_?date|dob|age|is_?minor|minor|under_?18|involves_?minor|lane|reporter_?user_?id|target_?user_?id|subject_?hash)$/i;
    const violations: string[] = [];
    const walk = (v: unknown, where: string): void => {
      if (v === null || v === undefined) return;
      if (typeof v === 'string') {
        const low = v.toLowerCase();
        for (const s of secrets) if (low.includes(s)) violations.push(`${where}: contains an account id / email / DOB`);
        return;
      }
      if (Array.isArray(v)) return v.forEach((x, idx) => walk(x, `${where}[${idx}]`));
      if (typeof v === 'object') {
        for (const [k, x] of Object.entries(v)) {
          if (FORBIDDEN_KEY.test(k)) violations.push(`${where}.${k}: forbidden key`);
          walk(x, `${where}.${k}`);
        }
      }
    };
    for (const r of recorded) walk(r.body, r.where);
    const broadcasts = sockets.flatMap((s) => s.broadcasts());
    for (const b of broadcasts) walk(b.payload, `realtime ${b.topic} ${b.event}`);

    expect(recorded.length).toBeGreaterThan(100);
    expect(new Set(broadcasts.map((b) => b.event))).toEqual(
      new Set(['member_joined', 'member_left', 'presence', 'gesture_sent', 'gesture_received', 'room_state', 'lantern_hour']),
    );
    expect(violations).toEqual([]);
  });
});
