/**
 * U07 Orbit Loom constellations, end to end against the live local stack (Nest app, Postgres with migration
 * 20261005000038, Supabase Auth + PostgREST): `loom_constellation` through POST /v1/sync/push →
 * `public.loom_constellations` (cosmetic columns only), idempotent on the constellation id, the shape rule and the
 * per-day limit, letting one go (the shape erased, `updated_at` moved for pulls), and select-own through PostgREST.
 */
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { uuidv7 } from '../../src/common/uuid';
import { addDays, localDate, MAX_LOOM_CONSTELLATIONS_PER_DAY } from '../../src/rules';
import { bootApp, createUser, dbPool, deleteUser, localAnonKey, SUPABASE_URL, type TestUser } from './support';

jest.setTimeout(90_000);

const TZ = 'Asia/Kolkata';
const DEVICE = uuidv7();
const TRIANGLE = [
  [0.2, 0.2],
  [0.8, 0.25],
  [0.5, 0.8],
];

describe('Orbit Loom constellations (e2e)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  // Yesterday in IST: every instant is in the past, so the future-skew check never depends on the real clock.
  const YDAY = addDays(localDate(new Date(), TZ), -1);
  const at = (hh: number, mm = 0, day = YDAY) => zonedInstant(day, hh, mm, TZ);

  const http = () => request(app.getHttpServer());
  const as = (u: { token: string }, r: request.Test): request.Test => r.set('Authorization', `Bearer ${u.token}`);
  const push = (u: TestUser, mutations: Array<Record<string, unknown>>) =>
    as(u, http().post('/v1/sync/push')).send({ deviceId: DEVICE, mutations }).expect(200);
  const keep = (payload: Record<string, unknown>, when = at(20), day = YDAY) => ({
    id: uuidv7(),
    entity: 'loom_constellation',
    op: 'upsert',
    deviceTs: when.toISOString(),
    localDay: day,
    tz: TZ,
    payload: { id: uuidv7(), stars: TRIANGLE, links: [[0, 1], [1, 2]], meaning: null, ...payload },
  });
  const letGo = (id: string) => ({ ...keep({}), op: 'delete', payload: { id } });

  async function appUser(label: string): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    await as(u, http().post('/v1/profile')).send({ birthDate: '1996-03-14', uiLocale: 'en', timezone: TZ, country: 'IN' }).expect(200);
    return u;
  }

  let u: TestUser;
  let other: TestUser;
  const first = uuidv7();

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
    u = await appUser('loom');
    other = await appUser('loom-other');
  });

  afterAll(async () => {
    if (db) await db.end();
    for (const x of users) await deleteUser(x.id);
    await app?.close();
  });

  it('keeps one row with cosmetic columns only; the same constellation again changes nothing', async () => {
    const m = keep({ id: first, meaning: 'noticed' }, at(20, 5));
    expect((await push(u, [m])).body.results[0].status).toBe('applied');
    expect((await push(u, [{ ...m, id: uuidv7() }])).body.results[0].status).toBe('applied');
    const rows = (
      await db.query(
        `select id, stars, links, meaning, local_day::text as local_day, device_ts, deleted_at
           from public.loom_constellations where user_id = $1`,
        [u.id],
      )
    ).rows;
    expect(rows).toEqual([
      { id: first, stars: TRIANGLE, links: [[0, 1], [1, 2]], meaning: 'noticed', local_day: YDAY, device_ts: at(20, 5), deleted_at: null },
    ]);
    const cols = (
      await db.query(`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'loom_constellations' order by 1`)
    ).rows.map((r) => r.column_name);
    expect(cols).toEqual(['deleted_at', 'device_ts', 'id', 'links', 'local_day', 'meaning', 'server_ts', 'stars', 'updated_at', 'user_id']);
  });

  it('rejects: another account reusing the id, shapes the rule refuses, free-text meanings, bad days', async () => {
    const r = await push(other, [keep({ id: first })]);
    expect(r.body.results[0]).toMatchObject({ status: 'rejected', reason: 'id_conflict' });
    const bad = await push(u, [
      keep({ stars: TRIANGLE.slice(0, 2) }),
      keep({ links: [[0, 0]] }),
      keep({ meaning: 'a hard day' }),
      keep({ stars: 'three' }),
      keep({}, at(20), addDays(YDAY, -3)),
    ]);
    expect(bad.body.results.map((x: { reason?: string }) => x.reason)).toEqual([
      'invalid_constellation',
      'invalid_constellation',
      'invalid_constellation',
      'invalid_payload',
      'invalid_local_day',
    ]);
    expect((await db.query('select count(*)::int as n from public.loom_constellations where user_id = $1', [u.id])).rows[0].n).toBe(1);
  });

  it(`at most ${MAX_LOOM_CONSTELLATIONS_PER_DAY} a day; letting one go frees its place and erases its shape`, async () => {
    const more = Array.from({ length: MAX_LOOM_CONSTELLATIONS_PER_DAY - 1 }, (_, i) => keep({}, at(20, 10 + i)));
    const r = await push(u, [...more, keep({}, at(20, 30))]);
    expect(r.body.results.map((x: { status: string; reason?: string }) => x.reason ?? x.status)).toEqual([
      ...more.map(() => 'applied'),
      'too_many_constellations',
    ]);
    const before = (await db.query('select updated_at from public.loom_constellations where id = $1', [first])).rows[0].updated_at as Date;
    expect((await push(u, [letGo(first)])).body.results[0].status).toBe('applied');
    const gone = (await db.query('select stars, links, meaning, deleted_at, updated_at from public.loom_constellations where id = $1', [first])).rows[0];
    expect(gone).toMatchObject({ stars: null, links: null, meaning: null });
    expect(gone.deleted_at).not.toBeNull();
    expect((gone.updated_at as Date).getTime()).toBeGreaterThanOrEqual(before.getTime());
    expect((await push(u, [keep({}, at(20, 40))])).body.results[0].status).toBe('applied');
    // Another account cannot let it go.
    expect((await push(other, [letGo(first)])).body.results[0]).toMatchObject({ status: 'rejected', reason: 'id_conflict' });
  });

  it('select-own: the owner reads their rows (let-go ones as tombstones) through PostgREST, nobody else does', async () => {
    const read = async (x: TestUser) =>
      (await (
        await fetch(`${SUPABASE_URL}/rest/v1/loom_constellations?select=id,meaning,deleted_at&order=device_ts`, {
          headers: { apikey: localAnonKey(), Authorization: `Bearer ${x.token}` },
        })
      ).json()) as Array<{ id: string; meaning: string | null; deleted_at: string | null }>;
    const mine = await read(u);
    expect(mine).toHaveLength(MAX_LOOM_CONSTELLATIONS_PER_DAY + 1);
    expect(mine[0]).toMatchObject({ id: first, meaning: null });
    expect(mine[0].deleted_at).not.toBeNull();
    expect(await read(other)).toEqual([]);
  });
});
