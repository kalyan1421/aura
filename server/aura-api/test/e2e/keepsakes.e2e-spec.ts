/**
 * F13 keepsakes, end to end against the live local stack (NestJS app, Postgres with migration 20261005000026, Supabase
 * Auth + PostgREST): awarding from the records NestJS already holds (capsule metadata, active days, Breath Ripples
 * seats, Lantern Hour room memberships, Sanctuary session records), idempotency, "never lost" (REQ-SHR-05), and the
 * DS-10 / CI-8 contract: no endpoint or select returns another person's keepsakes, and no room, reflection or game
 * response carries a keepsake field (REQ-SHR-06).
 *
 * Global rows are never changed. The Lantern Hour room and the Breath Ripples session are this suite's own rows (a
 * full, closed-pool room nobody else can match into), deleted afterwards. The worker's sweep is exercised read-only
 * (`recentCandidates`) plus a direct award for this suite's own user, so other suites' users are never touched.
 */
import { randomBytes } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { uuidv7 } from '../../src/common/uuid';
import { withTx } from '../../src/db/db';
import { awardKeepsakes } from '../../src/keepsakes/award';
import { KEEPSAKE_KEYS } from '../../src/keepsakes/keepsake-rules';
import { recentCandidates } from '../../src/keepsakes/sweep';
import { addDays, auraDay } from '../../src/rules';
import { bootApp, createUser, dbPool, deleteUser, localAnonKey, SUPABASE_URL, type TestUser } from './support';

jest.setTimeout(90_000);

const TZ = 'Asia/Kolkata';
const DEVICE = uuidv7();
const H = 3600_000;
const ct = (): string => randomBytes(48).toString('base64');

describe('F13 keepsakes (e2e, live local Supabase)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  const rooms: string[] = [];
  const sessions: string[] = [];
  const recorded: Array<{ where: string; body: unknown }> = [];

  const http = () => request(app.getHttpServer());
  const as = (u: TestUser, r: request.Test) => r.set('Authorization', `Bearer ${u.token}`);
  const mk = async (label: string, onboard = true): Promise<TestUser> => {
    const u = await createUser(`keep-${label}`);
    users.push(u);
    if (onboard) {
      await as(u, http().post('/v1/profile')).send({ birthDate: '2001-04-04', uiLocale: 'en', timezone: TZ, country: 'IN' }).expect(200);
    }
    return u;
  };
  const push = async (u: TestUser, mutations: unknown[]): Promise<string[]> =>
    (await as(u, http().post('/v1/sync/push')).send({ deviceId: DEVICE, mutations }).expect(200)).body.results.map(
      (r: { status: string; reason?: string }) => r.reason ?? r.status,
    );
  const mine = async (u: TestUser): Promise<Array<{ key: string; earnedOn: string }>> => {
    const res = await as(u, http().get('/v1/keepsakes')).expect(200);
    expect(res.headers['cache-control']).toBe('no-store');
    recorded.push({ where: 'GET /v1/keepsakes', body: res.body });
    return res.body.keepsakes;
  };
  const keys = async (u: TestUser): Promise<string[]> => (await mine(u)).map((k) => k.key);
  const today = (): string => auraDay(new Date(), TZ);
  const moodSeal = (capsuleId: string) => ({
    id: uuidv7(),
    entity: 'capsule',
    op: 'seal',
    deviceTs: new Date().toISOString(),
    tz: TZ,
    payload: { id: capsuleId, payloadCt: ct(), unlockType: 'mood', triggerQuadrant: 'rain' },
  });
  const sanctuary = (seconds: number) => ({
    id: uuidv7(),
    entity: 'sanctuary_session',
    op: 'upsert',
    deviceTs: new Date().toISOString(),
    localDay: today(),
    tz: TZ,
    payload: { id: uuidv7(), activity: 'sounds', variant: 'timer_30', durationS: seconds },
  });
  /** What the app does for a select-own read: PostgREST with the user's JWT. */
  const rest = async (u: TestUser | null, query: string) => {
    const headers: Record<string, string> = { apikey: localAnonKey() };
    if (u) headers.Authorization = `Bearer ${u.token}`;
    const res = await fetch(`${SUPABASE_URL}/rest/v1/keepsakes?${query}`, { headers });
    return { status: res.status, body: (await res.json()) as unknown };
  };

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
  });

  afterAll(async () => {
    if (rooms.length) await db.query('delete from public.rooms where id = any($1::uuid[])', [rooms]);
    if (sessions.length) await db.query('delete from public.ripple_sessions where id = any($1::uuid[])', [sessions]);
    for (const u of users) await deleteUser(u.id);
    await db?.end();
    await app?.close();
  });

  it('nothing earned yet → an empty box (and no profile → empty, nothing written)', async () => {
    const fresh = await mk('fresh');
    expect(await mine(fresh)).toEqual([]);
    const noProfile = await mk('noprofile', false);
    expect(await mine(noProfile)).toEqual([]);
    expect((await db.query('select count(*)::int as n from public.keepsake_tallies where user_id = $1', [noProfile.id])).rows[0].n).toBe(0);
  });

  it('sealing a first capsule adds that seal once, dated today; deleting the capsule leaves it (REQ-SHR-05)', async () => {
    const u = await mk('capsule');
    const capsuleId = uuidv7();
    expect(await push(u, [moodSeal(capsuleId)])).toEqual(['applied']);
    expect(await mine(u)).toEqual([{ key: 'capsule_sealed_first', earnedOn: today() }]);
    // Idempotent: a second call and a second capsule change nothing.
    expect(await push(u, [moodSeal(uuidv7())])).toEqual(['applied']);
    expect(await mine(u)).toEqual([{ key: 'capsule_sealed_first', earnedOn: today() }]);
    expect((await db.query('select count(*)::int as n from public.keepsakes where user_id = $1', [u.id])).rows[0].n).toBe(1);

    const del = { id: uuidv7(), entity: 'capsule', op: 'delete', deviceTs: new Date().toISOString(), payload: { id: capsuleId } };
    expect(await push(u, [del])).toEqual(['applied']);
    expect(await keys(u)).toEqual(['capsule_sealed_first']);

    // The first capsule opened (as the sync push records a fire + open), on its own day.
    await db.query(
      `update public.capsules set fired_at = now() - interval '2 hours', cooldown_until = now() + interval '166 hours',
              opened_at = now() - interval '1 hour', opened_device_ts = now() - interval '1 hour'
        where user_id = $1 and deleted_at is null`,
      [u.id],
    );
    expect(await mine(u)).toEqual([
      { key: 'capsule_sealed_first', earnedOn: today() },
      { key: 'capsule_opened_first', earnedOn: auraDay(new Date(Date.now() - H), TZ) },
    ]);

    // Never lost at the database either: a direct delete or update is refused while the account lives.
    await expect(db.query('delete from public.keepsakes where user_id = $1', [u.id])).rejects.toMatchObject({ code: 'AR060' });
    await expect(db.query(`update public.keepsakes set earned_on = '2020-01-01' where user_id = $1`, [u.id])).rejects.toMatchObject({ code: 'AR060' });
  });

  it('the 7th lifetime glow day earns glow_days_7 on that day; 60 Sanctuary minutes earn their seal', async () => {
    const u = await mk('glow');
    const first = addDays(today(), -20);
    const glowDays = [0, 1, 3, 4, 8, 9, 12, 15].map((d) => addDays(first, d));
    for (const d of glowDays) await db.query('insert into public.active_days (user_id, local_day) values ($1, $2)', [u.id, d]);
    expect(await push(u, [sanctuary(1800), sanctuary(1799)])).toEqual(['applied', 'applied']);
    expect(await mine(u)).toEqual([{ key: 'glow_days_7', earnedOn: glowDays[6] }]);
    expect(await push(u, [sanctuary(1)])).toEqual(['applied']);
    expect(await mine(u)).toEqual([
      { key: 'glow_days_7', earnedOn: glowDays[6] },
      { key: 'sanctuary_minutes_60', earnedOn: today() },
    ]);
  });

  describe('Lantern Hour and Breath Ripples, then the DS-10 contract', () => {
    let a: TestUser;
    let b: TestUser;
    let roomId: string;
    const lanternAt = new Date(Date.now() - 3 * H); // the window (2 h) ended an hour ago

    beforeAll(async () => {
      a = await mk('lantern-a');
      b = await mk('lantern-b');
      // A full (capacity 2), closed-pool room of this suite's own: nobody else can be matched into it.
      const room = await db.query<{ id: string }>(
        `insert into public.rooms (language_pool, quadrant, tz_region, seed_mood_id, theme, capacity, status,
                                   created_at, opened_at, joins_close_at, memory_at, purge_at, lantern_hour_at)
         values ('hi', 'sunrise', 'east_asia_pacific', 'joyful', 'sunrise_deck', 2, 'open',
                 now() - interval '5 hours', now() - interval '4 hours', now() + interval '15 hours',
                 now() + interval '19 hours', now() + interval '7 days 19 hours', $1)
         returning id`,
        [lanternAt],
      );
      roomId = room.rows[0].id;
      rooms.push(roomId);
      const member = (u: TestUser, pseudonym: string, lastSeen: string) =>
        db.query(
          `insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool,
                                            home_region, match_step, stage, joined_at, last_seen_at)
           values ($1, $2, $3, 'joyful', 'sunrise', 'hi', 'east_asia_pacific', 1, 'spark', now() - interval '4 hours', ${lastSeen})`,
          [roomId, u.id, pseudonym],
        );
      await member(a, 'Quiet Comet', "now() - interval '150 minutes'");
      await member(b, 'Soft Harbor', "now() - interval '170 minutes'");
      // A's Breath Ripples session that has ended (a human seat).
      const s = await db.query<{ id: string }>(
        `insert into public.ripple_sessions (entry, start_rule, t0, settle_ms, inhale_ms, exhale_ms, cycles, fade_ms, pacer_version, ends_at, ended_at, purge_at)
         values ('quick', 'timeout', now() - interval '63 minutes', 10000, 4000, 6000, 16, 10000, 1, now() - interval '60 minutes',
                 now() - interval '60 minutes', now() + interval '6 days') returning id`,
      );
      sessions.push(s.rows[0].id);
      await db.query(`insert into public.ripple_seats (session_id, seat, kind, user_id, pseudonym) values ($1, 1, 'human', $2, 'Quiet Comet')`, [
        s.rows[0].id,
        a.id,
      ]);
    });

    it('a Lantern Hour spent in a room and a first Breath Ripples session become seals, counted once', async () => {
      const night = auraDay(lanternAt, TZ);
      const ripple = auraDay(new Date(Date.now() - H), TZ);
      expect(await mine(a)).toEqual([
        { key: 'ripples_first', earnedOn: ripple },
        { key: 'lantern_hours_1', earnedOn: night },
      ]);
      expect(await mine(b)).toEqual([{ key: 'lantern_hours_1', earnedOn: night }]);
      const tally = async (u: TestUser) =>
        (await db.query('select lantern_nights, lantern_through from public.keepsake_tallies where user_id = $1', [u.id])).rows[0];
      expect(await tally(a)).toEqual({ lantern_nights: 1, lantern_through: lanternAt });
      await mine(a);
      expect((await tally(a)).lantern_nights).toBe(1); // the watermark: the same night never counts twice
    });

    it('the worker finds recent people by their records (read-only) and awards idempotently', async () => {
      const since = new Date(Date.now() - 6 * H);
      const found = await recentCandidates(db, since, new Date());
      expect(found).toEqual(expect.arrayContaining([a.id, b.id]));
      const again = await withTx(db, (tx) => awardKeepsakes(tx, a.id));
      expect(again).toEqual({ added: [], newNights: 0 });
    });

    it('DS-10 / CI-8: no endpoint or select returns another person\'s keepsakes', async () => {
      const aKeys = await keys(a);
      const bKeys = await keys(b);
      expect(aKeys).toContain('ripples_first');
      expect(bKeys).not.toContain('ripples_first');
      // No route takes a person: a path id is not a route, a query parameter is ignored.
      await as(b, http().get(`/v1/keepsakes/${a.id}`)).expect(404);
      const viaQuery = await as(b, http().get('/v1/keepsakes').query({ userId: a.id, user_id: a.id })).expect(200);
      expect(viaQuery.body.keepsakes.map((k: { key: string }) => k.key)).toEqual(bKeys);
      await http().get('/v1/keepsakes').expect(401);
      // Select-own through PostgREST: B asking for A's rows gets none; A gets exactly their own.
      expect(await rest(b, `select=*&user_id=eq.${a.id}`)).toEqual({ status: 200, body: [] });
      const own = await rest(a, 'select=keepsake_key,earned_on&order=keepsake_key');
      expect(own.status).toBe(200);
      expect((own.body as Array<{ keepsake_key: string }>).map((r) => r.keepsake_key).sort()).toEqual([...aKeys].sort());
      const anon = await rest(null, 'select=*');
      expect(anon.status === 401 || (anon.status === 200 && Array.isArray(anon.body) && anon.body.length === 0)).toBe(true);
      // The server-only tally is never readable by the app.
      const tally = await fetch(`${SUPABASE_URL}/rest/v1/keepsake_tallies?select=*`, {
        headers: { apikey: localAnonKey(), Authorization: `Bearer ${a.token}` },
      });
      expect(tally.status).not.toBe(200);
      await tally.arrayBuffer();
    });

    it('REQ-SHR-06: room, reflection and game responses carry no keepsake field', async () => {
      const bodies: unknown[] = [];
      for (const u of [a, b]) {
        for (const path of ['/v1/rooms', `/v1/rooms/${roomId}`, `/v1/rooms/${roomId}/reflections`, '/v1/ripples/echo-consent', `/v1/ripples/sessions/${sessions[0]}`]) {
          const res = await as(u, http().get(path));
          bodies.push(res.body);
          recorded.push({ where: `GET ${path}`, body: res.body });
        }
      }
      const text = JSON.stringify(bodies);
      expect(text).not.toMatch(/keepsake/i);
      for (const key of KEEPSAKE_KEYS) expect(text).not.toContain(key);
    });

    it('purging the room (7 days after it closes) takes neither the seal nor the count', async () => {
      await db.query('delete from public.rooms where id = $1', [roomId]);
      expect(await keys(a)).toEqual(['ripples_first', 'lantern_hours_1']);
      expect((await db.query('select lantern_nights from public.keepsake_tallies where user_id = $1', [a.id])).rows[0].lantern_nights).toBe(1);
    });
  });

  describe('what the keepsake route returns (after everything above)', () => {
    it('every keepsake response holds keys and days only (no ids, pseudonyms or content)', () => {
      expect(recorded.filter((x) => x.where === 'GET /v1/keepsakes').length).toBeGreaterThanOrEqual(12); // runs last
      for (const r of recorded.filter((x) => x.where === 'GET /v1/keepsakes')) {
        const body = r.body as { keepsakes: Array<Record<string, unknown>> };
        expect(Object.keys(body)).toEqual(['keepsakes']);
        for (const k of body.keepsakes) {
          expect(Object.keys(k).sort()).toEqual(['earnedOn', 'key']);
          expect(KEEPSAKE_KEYS).toContain(k.key);
          expect(k.earnedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
        }
      }
      const all = JSON.stringify(recorded.filter((x) => x.where === 'GET /v1/keepsakes'));
      for (const u of users) expect(all).not.toContain(u.id);
      expect(all).not.toMatch(/Quiet Comet|Soft Harbor/);
    });
  });
});
