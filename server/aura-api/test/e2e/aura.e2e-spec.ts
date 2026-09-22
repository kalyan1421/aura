import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { ApiError } from '../../src/common/api-error';
import { uuidv7 } from '../../src/common/uuid';
import { AppConfig } from '../../src/config/app-config';
import { unwrapDataKey } from '../../src/keys/envelope';
import { purgeOldSyncMutations } from '../../src/queues/maintenance';
import { ProfileService } from '../../src/profile/profile.service';
import { addDays, auraDay, isLocalDay, localDate } from '../../src/rules';
import { bootApp, createUser, dbPool, deleteUser, localAnonKey, localServiceKey, type TestUser } from './support';

const TZ = 'Asia/Kolkata';
const DEVICE = uuidv7();

describe('Aura API (e2e, live local Supabase + Redis)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];

  const http = () => request(app.getHttpServer());
  const newUser = async (label: string): Promise<TestUser> => {
    const u = await createUser(label);
    users.push(u);
    return u;
  };
  const onboard = (u: TestUser, over: Record<string, unknown> = {}) =>
    http()
      .post('/v1/profile')
      .set('Authorization', `Bearer ${u.token}`)
      .send({ birthDate: '2006-04-17', uiLocale: 'te-Latn', timezone: TZ, country: 'IN', ...over });
  const pushAs = (u: TestUser, mutations: unknown[]) =>
    http().post('/v1/sync/push').set('Authorization', `Bearer ${u.token}`).send({ deviceId: DEVICE, mutations });
  const count = async (table: string, userId: string): Promise<number> =>
    Number((await db.query(`select count(*) from public.${table} where user_id = $1`, [userId])).rows[0].count);

  // Live events: stamped now, on today's aura day in the profile tz → eligible.
  const now = () => new Date().toISOString();
  const today = () => auraDay(new Date(), TZ);
  const checkIn = (moodId = 'anxious', over: Record<string, unknown> = {}) => ({
    id: uuidv7(),
    entity: 'check_in',
    op: 'upsert',
    deviceTs: now(),
    localDay: today(),
    payload: { id: uuidv7(), moodId, tags: ['study'], noteCt: Buffer.from('ciphertext').toString('base64'), source: 'app' },
    ...over,
  });
  const habit = (id: string, presetKey: string | null) => ({
    id: uuidv7(),
    entity: 'habit',
    op: 'upsert',
    deviceTs: now(),
    localDay: today(),
    payload: presetKey
      ? { id, kind: 'preset', presetKey, name: null, active: true }
      : { id, kind: 'custom', name: `Custom ${id.slice(-4)}`, active: true },
  });
  const log = (habitId: string) => ({
    id: uuidv7(),
    entity: 'habit_log',
    op: 'upsert',
    deviceTs: now(),
    localDay: today(),
    payload: { id: uuidv7(), habitId },
  });
  const del = (entity: string, id: string) => ({ id: uuidv7(), entity, op: 'delete', deviceTs: now(), localDay: today(), payload: { id } });

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
  });

  afterAll(async () => {
    await Promise.all(users.map((u) => deleteUser(u.id)));
    await db?.end();
    await app?.close();
  });

  // ---------------------------------------------------------------- health & auth
  it('GET /health → ok (no auth)', async () => {
    await http().get('/health').expect(200, { status: 'ok', db: 'ok', redis: 'ok' });
  });

  it('401 without a token, with garbage, and with the anon/service_role API keys', async () => {
    for (const [method, path] of [
      ['get', '/v1/me/snapshot'],
      ['post', '/v1/sync/push'],
      ['post', '/v1/profile'],
      ['get', '/v1/keys/data-key'],
      ['put', '/v1/devices'],
      ['delete', '/v1/devices'],
    ] as const) {
      const r = await http()[method](path).expect(401);
      expect(r.body).toEqual({ code: 'unauthorized', message: expect.any(String) });
    }
    await http().get('/v1/me/snapshot').set('Authorization', 'Bearer not.a.jwt').expect(401);
    await http().get('/v1/me/snapshot').set('Authorization', `Bearer ${localAnonKey()}`).expect(401);
    await http().get('/v1/me/snapshot').set('Authorization', `Bearer ${localServiceKey()}`).expect(401);
  });

  it('malformed JSON → 400 invalid_json without echoing the body', async () => {
    const r = await http().post('/v1/profile').set('Content-Type', 'application/json').send('{"birthDate": 2006-04-17').expect(400);
    expect(r.body).toEqual({ code: 'invalid_json', message: 'Request body is not valid JSON.' });
  });

  // ---------------------------------------------------------------- profile
  describe('profile', () => {
    it('under-13 → 403 under_13 and nothing is stored', async () => {
      const u = await newUser('kid');
      const tenYearsAgo = `${new Date().getUTCFullYear() - 10}-01-15`;
      const r = await onboard(u, { birthDate: tenYearsAgo }).expect(403);
      expect(r.body).toEqual({ code: 'under_13', message: expect.any(String) });
      for (const t of ['profiles', 'avatar_state', 'streak_state', 'starlight_ledger']) expect(await count(t, u.id)).toBe(0);
      await pushAs(u, []).expect(409); // still no profile
    });

    // The age check uses the user's own local calendar date (same rule as the app). From 10:00 UTC on,
    // Kiritimati (UTC+14) is already on the next date, so these cover "13 today locally, 12 in UTC".
    const KIRITIMATI = 'Pacific/Kiritimati';
    /** The date exactly 13 years before today's date in `tz` (null on a local 29 Feb). */
    const thirteenthBirthdayToday = (tz: string): string | null => {
      const [y, m, d] = localDate(new Date(), tz).split('-').map(Number);
      const b = `${y - 13}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      return isLocalDay(b) ? b : null;
    };

    it('13th birthday today in Kiritimati (UTC+14), even while UTC is still on the day before → 200', async () => {
      const birthDate = thirteenthBirthdayToday(KIRITIMATI);
      if (!birthDate) return; // local 29 Feb: no such date 13 years ago
      const u = await newUser('kiritimati');
      const r = await onboard(u, { birthDate, timezone: KIRITIMATI }).expect(200);
      expect(r.body.profile).toMatchObject({ birthDate, timezone: KIRITIMATI });
      expect(await count('profiles', u.id)).toBe(1);
      expect(await count('avatar_state', u.id)).toBe(1);
    });

    it("one day short of 13 in the user's own zone → 403 under_13, nothing stored", async () => {
      const thirteen = thirteenthBirthdayToday(KIRITIMATI);
      if (!thirteen) return;
      const u = await newUser('kiritimati-12');
      const r = await onboard(u, { birthDate: addDays(thirteen, 1), timezone: KIRITIMATI }).expect(403);
      expect(r.body.code).toBe('under_13');
      expect(await count('profiles', u.id)).toBe(0);
      expect(await count('avatar_state', u.id)).toBe(0);
    });

    it('a profiles_min_age (23514) violation from the DB maps to 403 under_13, never 500', async () => {
      // Clock skewed 10 days ahead: the API thinks the user is 13, the DB's UTC current_date says 12.
      const u = await newUser('skew');
      const skewedNow = new Date(Date.now() + 10 * 86_400_000);
      const d = new Date();
      const birthDate = addDays(`${d.getUTCFullYear() - 13}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`, 5);
      const err = await app
        .get(ProfileService)
        .upsert(u.id, { birthDate, uiLocale: 'en', timezone: 'UTC', country: null }, skewedNow)
        .catch((e: unknown) => e);
      expect(err).toBeInstanceOf(ApiError);
      expect(err).toMatchObject({ status: 403, code: 'under_13' });
      for (const t of ['profiles', 'avatar_state', 'streak_state']) expect(await count(t, u.id)).toBe(0);
    });

    it('validates the body → 400 invalid_request', async () => {
      const u = await newUser('invalid');
      const r = await onboard(u, { uiLocale: 'fr' }).expect(400);
      expect(r.body.code).toBe('invalid_request');
      await onboard(u, { timezone: 'Mars/Olympus' }).expect(400);
      expect(await count('profiles', u.id)).toBe(0);
    });

    it('ok → 200 { profile, snapshot }, creates avatar_state + streak_state (welcome rest day)', async () => {
      const u = await newUser('onboard');
      const r = await onboard(u).expect(200);
      expect(r.body.profile).toMatchObject({
        userId: u.id,
        birthDate: '2006-04-17',
        uiLocale: 'te-Latn',
        languagePool: 'te',
        timezone: TZ,
        country: 'IN',
      });
      expect(r.body.snapshot.streak).toEqual({ glowStreak: 0, lifetimeGlowDays: 0, restBank: 1, earnCounter: 0, lastActiveDay: null });
      expect(r.body.snapshot.avatar).toMatchObject({ stage: 'spark', hue: null, isResting: false });
      const s = await db.query('select rest_bank, glow_streak from public.streak_state where user_id = $1', [u.id]);
      expect(s.rows[0]).toEqual({ rest_bank: 1, glow_streak: 0 });
      expect(await count('avatar_state', u.id)).toBe(1);
      // upsert again with another locale → same row updated, pool re-derived
      const again = await onboard(u, { uiLocale: 'hi-Latn' }).expect(200);
      expect(again.body.profile.languagePool).toBe('hi');
      expect(await count('profiles', u.id)).toBe(1);
    });

    it('date of birth is locked after onboarding → 409 birth_date_locked, stored DOB unchanged', async () => {
      const u = await newUser('doblock');
      await onboard(u).expect(200);
      const r = await onboard(u, { birthDate: '1990-01-01' }).expect(409);
      expect(r.body.code).toBe('birth_date_locked');
      const s = await db.query("select to_char(birth_date, 'YYYY-MM-DD') as d from public.profiles where user_id = $1", [u.id]);
      expect(s.rows[0].d).toBe('2006-04-17');
    });

    it('concurrent first onboardings with different DOBs: one 200, the other 409 birth_date_locked', async () => {
      const u = await newUser('race');
      const [a, b] = await Promise.all([onboard(u, { birthDate: '2001-01-01' }), onboard(u, { birthDate: '2002-02-02' })]);
      expect([a.status, b.status].sort()).toEqual([200, 409]);
      const loser = a.status === 409 ? a : b;
      expect(loser.body.code).toBe('birth_date_locked');
      expect(await count('profiles', u.id)).toBe(1);
    });
  });

  // ---------------------------------------------------------------- snapshot
  it('GET /v1/me/snapshot → Snapshot shape; 409 profile_required before onboarding', async () => {
    const u = await newUser('snapshot');
    const pre = await http().get('/v1/me/snapshot').set('Authorization', `Bearer ${u.token}`).expect(409);
    expect(pre.body.code).toBe('profile_required');
    await onboard(u).expect(200);
    const r = await http().get('/v1/me/snapshot').set('Authorization', `Bearer ${u.token}`).expect(200);
    const s = r.body;
    expect(Object.keys(s).sort()).toEqual(['auraDay', 'avatar', 'serverTime', 'starlight', 'streak']);
    expect(Object.keys(s.avatar).sort()).toEqual(
      ['constellationStars', 'equippedCosmetics', 'glowLevel', 'hue', 'isResting', 'ringCount', 'stage'].sort(),
    );
    expect(Object.keys(s.streak).sort()).toEqual(['earnCounter', 'glowStreak', 'lastActiveDay', 'lifetimeGlowDays', 'restBank']);
    expect(s.starlight).toEqual({ total: 0, today: 0 });
    expect(s.auraDay).toBe(today());
    expect(Math.abs(Date.parse(s.serverTime) - Date.now())).toBeLessThan(60_000);
    expect(Array.isArray(s.avatar.equippedCosmetics)).toBe(true);
  });

  // ---------------------------------------------------------------- sync
  describe('sync push', () => {
    it('409 profile_required without a profile; 400 on >200 mutations', async () => {
      const u = await newUser('noprofile');
      const r = await pushAs(u, [checkIn()]).expect(409);
      expect(r.body).toEqual({ code: 'profile_required', message: expect.any(String) });
      await onboard(u).expect(200);
      const big = await pushAs(u, Array.from({ length: 201 }, () => checkIn())).expect(400);
      expect(big.body.code).toBe('too_many_mutations');
      expect(await count('check_ins', u.id)).toBe(0);
    });

    let main: TestUser;
    let first: ReturnType<typeof checkIn>[];

    it('applies check-ins, credits Starlight, marks the glow day; replay → duplicate, no double credit', async () => {
      main = await newUser('sync');
      await onboard(main).expect(200);
      first = [checkIn('anxious'), checkIn('overwhelmed')];
      const r = await pushAs(main, first).expect(200);
      expect(r.body.results).toEqual(first.map((m) => ({ id: m.id, status: 'applied' })));
      expect(r.body.snapshot.starlight).toEqual({ total: 12, today: 12 });
      expect(r.body.snapshot.streak).toMatchObject({ glowStreak: 1, lifetimeGlowDays: 1, lastActiveDay: today() });
      expect(r.body.snapshot.avatar.hue).toBeCloseTo(275, 3); // both storm
      const rows = await db.query('select mood_id, quadrant, local_day, backfill, note_ct from public.check_ins where user_id = $1 order by device_ts', [main.id]);
      expect(rows.rows.map((x) => x.quadrant)).toEqual(['storm', 'storm']);
      expect(rows.rows[0]).toMatchObject({ local_day: today(), backfill: false });
      expect(await count('starlight_ledger', main.id)).toBe(2);
      expect(await count('active_days', main.id)).toBe(1);
      // persisted state matches the snapshot
      const a = await db.query('select total_starlight, stage, hue from public.avatar_state where user_id = $1', [main.id]);
      expect(a.rows[0]).toMatchObject({ total_starlight: 12, stage: 'spark' });

      const replay = await pushAs(main, first).expect(200);
      expect(replay.body.results).toEqual(first.map((m) => ({ id: m.id, status: 'duplicate' })));
      expect(replay.body.snapshot.starlight.total).toBe(12);
      expect(await count('starlight_ledger', main.id)).toBe(2);
      expect(await count('check_ins', main.id)).toBe(2);
      expect(await count('sync_mutations', main.id)).toBe(2);
    });

    it('unknown mood is rejected while the others apply (and stays rejected on replay)', async () => {
      const bad = checkIn('ecstatic');
      const ok = checkIn('calm');
      const r = await pushAs(main, [bad, ok]).expect(200);
      expect(r.body.results).toEqual([
        { id: bad.id, status: 'rejected', reason: 'unknown_mood' },
        { id: ok.id, status: 'applied' },
      ]);
      expect(r.body.snapshot.starlight.total).toBe(14); // 10 + 2 + 2
      const stored = await db.query('select 1 from public.check_ins where id = $1', [bad.payload.id]);
      expect(stored.rowCount).toBe(0);
      const sm = await db.query('select status, reason from public.sync_mutations where user_id = $1 and mutation_id = $2', [main.id, bad.id]);
      expect(sm.rows[0]).toEqual({ status: 'rejected', reason: 'unknown_mood' });
      const replay = await pushAs(main, [bad]).expect(200);
      expect(replay.body.results[0]).toEqual({ id: bad.id, status: 'rejected', reason: 'unknown_mood' });
    });

    it('deleting a check-in keeps its Starlight and glow day', async () => {
      const before = await db.query('select coalesce(sum(amount),0)::int as s, count(*)::int as n from public.starlight_ledger where user_id = $1', [main.id]);
      const d = del('check_in', first[0].payload.id);
      const r = await pushAs(main, [d]).expect(200);
      expect(r.body.results).toEqual([{ id: d.id, status: 'applied' }]);
      expect((await db.query('select 1 from public.check_ins where id = $1', [first[0].payload.id])).rowCount).toBe(0);
      const after = await db.query('select coalesce(sum(amount),0)::int as s, count(*)::int as n from public.starlight_ledger where user_id = $1', [main.id]);
      expect(after.rows[0]).toEqual(before.rows[0]);
      expect(r.body.snapshot.starlight.total).toBe(14);
      expect(r.body.snapshot.streak.lifetimeGlowDays).toBe(1);
      expect(await count('active_days', main.id)).toBe(1);
    });

    it('un-logging and re-logging a habit earns once; backfills are stored uncredited', async () => {
      const h = uuidv7();
      const l1 = log(h);
      await pushAs(main, [habit(h, 'breathe'), l1]).expect(200);
      const r = await pushAs(main, [del('habit_log', l1.payload.id), log(h)]).expect(200);
      expect(r.body.results.map((x: { status: string }) => x.status)).toEqual(['applied', 'applied']);
      const hl = await db.query("select amount, habit_key from public.starlight_ledger where user_id = $1 and reason = 'habit'", [main.id]);
      expect(hl.rows).toEqual([{ amount: 5, habit_key: 'breathe' }]);
      expect(r.body.snapshot.starlight.total).toBe(19);

      const back = checkIn('joyful', { localDay: addDays(today(), -2) });
      const b = await pushAs(main, [back]).expect(200);
      expect(b.body.results[0].status).toBe('applied');
      const row = await db.query('select backfill from public.check_ins where id = $1', [back.payload.id]);
      expect(row.rows[0].backfill).toBe(true);
      expect(b.body.snapshot.starlight.total).toBe(19);
      expect(await count('active_days', main.id)).toBe(1);
    });

    it('validation reasons: habit_not_found, unknown_entity, invalid_payload, backfill_too_old, invalid_mutation_id', async () => {
      const muts = [
        log(uuidv7()),
        { ...checkIn(), entity: 'capsule' },
        { ...checkIn(), payload: { id: 'nope', moodId: 'calm' } },
        checkIn('calm', { localDay: addDays(today(), -8) }),
        { ...checkIn(), id: 'not-a-uuid' },
      ];
      const r = await pushAs(main, muts).expect(200);
      expect(r.body.results.map((x: { reason?: string }) => x.reason)).toEqual([
        'habit_not_found',
        'unknown_entity',
        'invalid_payload',
        'backfill_too_old',
        'invalid_mutation_id',
      ]);
    });

    it("cannot overwrite another user's check-in by reusing its id", async () => {
      const intruder = await newUser('intruder');
      await onboard(intruder).expect(200);
      const stolen = { ...checkIn('joyful'), payload: { ...first[1].payload, moodId: 'joyful' } };
      const r = await pushAs(intruder, [stolen]).expect(200);
      expect(r.body.results[0]).toEqual({ id: stolen.id, status: 'rejected', reason: 'id_conflict' });
      const row = await db.query('select user_id, mood_id from public.check_ins where id = $1', [first[1].payload.id]);
      expect(row.rows[0]).toEqual({ user_id: main.id, mood_id: 'overwhelmed' });
    });

    it('concurrent pushes of the same batch serialise per user: applied once, duplicate once', async () => {
      const u = await newUser('race');
      await onboard(u).expect(200);
      const batch = [checkIn('calm'), checkIn('content')];
      const [a, b] = await Promise.all([pushAs(u, batch), pushAs(u, batch)]);
      expect([a.status, b.status]).toEqual([200, 200]);
      const statuses = [a.body.results, b.body.results].map((r: { status: string }[]) => r.map((x) => x.status).join(','));
      expect(statuses.sort()).toEqual(['applied,applied', 'duplicate,duplicate']);
      expect(await count('starlight_ledger', u.id)).toBe(2);
      expect(await count('check_ins', u.id)).toBe(2);
    });

    it('habit limits + cap: 6 presets + 3 custom + 4 check-ins = 59; delete/re-create earns at most +1 (cap 60)', async () => {
      const u = await newUser('cap');
      await onboard(u).expect(200);
      const presets = ['breathe', 'sleep_on_time', 'hydrate', 'move', 'journal', 'go_outside'];
      const habitIds = Array.from({ length: 9 }, () => uuidv7());
      const muts = [
        ...habitIds.map((h, i) => habit(h, presets[i] ?? null)),
        checkIn('calm'),
        checkIn('content'),
        checkIn('grateful'),
        checkIn('joyful'),
        ...habitIds.map((h) => log(h)),
      ];
      const r = await pushAs(u, muts).expect(200);
      expect(r.body.results.every((x: { status: string }) => x.status === 'applied')).toBe(true);
      expect(r.body.snapshot.starlight).toEqual({ total: 59, today: 59 });

      const ledger = await db.query(
        'select reason, amount, habit_key from public.starlight_ledger where user_id = $1 order by id',
        [u.id],
      );
      expect(ledger.rowCount).toBe(13);
      expect(ledger.rows.filter((x) => x.reason === 'checkin').map((x) => x.amount)).toEqual([10, 2, 2, 0]);
      expect(ledger.rows.filter((x) => x.reason === 'habit').map((x) => x.amount)).toEqual([5, 5, 5, 5, 5, 5, 5, 5, 5]);
      expect(ledger.rows.filter((x) => x.reason === 'habit').map((x) => x.habit_key)).toEqual([...presets, null, null, null]);

      // Limits: a 4th active custom habit and a second 'breathe' are rejected.
      const lim = await pushAs(u, [habit(uuidv7(), null), habit(uuidv7(), 'breathe')]).expect(200);
      expect(lim.body.results.map((x: { reason?: string }) => x.reason)).toEqual(['too_many_custom_habits', 'duplicate_preset_habit']);

      // Delete a custom habit and create a new one: its log is capped at +1, the next at 0.
      const [n1, n2] = [uuidv7(), uuidv7()];
      const d1 = await pushAs(u, [del('habit', habitIds[8]), habit(n1, null), log(n1)]).expect(200);
      expect(d1.body.snapshot.starlight.today).toBe(60);
      const d2 = await pushAs(u, [del('habit', n1), habit(n2, null), log(n2)]).expect(200);
      expect(d2.body.snapshot.starlight.today).toBe(60);
      const last = await db.query('select amount from public.starlight_ledger where user_id = $1 order by id desc limit 2', [u.id]);
      expect(last.rows.map((x) => x.amount)).toEqual([0, 1]);
      expect(await count('active_days', u.id)).toBe(1);
      expect(d2.body.snapshot.avatar).toMatchObject({ ringCount: 0, glowLevel: 0, stage: 'spark' });
    });
  });

  // ---------------------------------------------------------------- review fixes
  it("per-mutation tz: a check-in stamped in New York's evening is live even though the profile is IST", async () => {
    const u = await newUser('traveller');
    await onboard(u).expect(200); // profile tz Asia/Kolkata
    const nowIso = new Date().toISOString();
    const nyDay = auraDay(new Date(), 'America/New_York');
    const withTz = { ...checkIn('lonely'), deviceTs: nowIso, localDay: nyDay, tz: 'America/New_York' };
    const r = await pushAs(u, [withTz]).expect(200);
    expect(r.body.results[0].status).toBe('applied');
    const led = await db.query('select amount, local_day::text as d from public.starlight_ledger where user_id = $1', [u.id]);
    expect(led.rows).toEqual([{ amount: 10, d: nyDay }]);
    const bad = await pushAs(u, [{ ...checkIn(), tz: 'Mars/Olympus' }]).expect(200);
    expect(bad.body.results[0]).toMatchObject({ status: 'rejected', reason: 'invalid_tz' });
  });

  it('maintenance purges sync_mutations older than 90 days and keeps recent ones', async () => {
    const u = await newUser('purge');
    await onboard(u).expect(200);
    const [oldId, newId] = [uuidv7(), uuidv7()];
    await db.query(
      `insert into public.sync_mutations (user_id, mutation_id, entity, status, applied_at)
       values ($1, $2, 'check_in', 'applied', now() - interval '91 days'), ($1, $3, 'check_in', 'applied', now())`,
      [u.id, oldId, newId],
    );
    expect(await purgeOldSyncMutations(db)).toBeGreaterThanOrEqual(1);
    const left = await db.query('select mutation_id from public.sync_mutations where user_id = $1', [u.id]);
    expect(left.rows.map((x) => x.mutation_id)).toEqual([newId]);
  });

  // ---------------------------------------------------------------- keys
  it('GET /v1/keys/data-key is stable across calls and wrapped at rest', async () => {
    const u = await newUser('keys');
    const a = await http().get('/v1/keys/data-key').set('Authorization', `Bearer ${u.token}`).expect(200);
    const b = await http().get('/v1/keys/data-key').set('Authorization', `Bearer ${u.token}`).expect(200);
    expect(a.headers['cache-control']).toBe('no-store');
    expect(a.body).toEqual(b.body);
    expect(a.body.keyId).toMatch(/^[0-9a-f-]{36}$/);
    const key = Buffer.from(a.body.dataKey, 'base64');
    expect(key).toHaveLength(32);

    const row = await db.query('select key_id, wrapped_key from public.user_data_keys where user_id = $1', [u.id]);
    expect(row.rowCount).toBe(1);
    expect(row.rows[0].key_id).toBe(a.body.keyId);
    const wrapped: string = row.rows[0].wrapped_key;
    expect(wrapped).not.toBe(a.body.dataKey);
    expect(Buffer.from(wrapped, 'base64').includes(key)).toBe(false);
    expect(Buffer.from(wrapped, 'base64')).toHaveLength(60);
    const master = app.get(AppConfig).masterKey;
    expect(unwrapDataKey(master, wrapped, u.id).equals(key)).toBe(true);

    // a different user gets a different key
    const other = await newUser('keys2');
    const c = await http().get('/v1/keys/data-key').set('Authorization', `Bearer ${other.token}`).expect(200);
    expect(c.body.dataKey).not.toBe(a.body.dataKey);
  });

  // ---------------------------------------------------------------- devices (FCM registration)
  describe('devices', () => {
    const fcmToken = (): string => `e2e-fcm:${uuidv7()}:APA91b${'x'.repeat(120)}`;
    const putDevice = (u: TestUser, body: unknown) =>
      http().put('/v1/devices').set('Authorization', `Bearer ${u.token}`).send(body as object);
    const deleteDevice = (u: TestUser, body: unknown) =>
      http().delete('/v1/devices').set('Authorization', `Bearer ${u.token}`).send(body as object);
    const rowFor = async (token: string) =>
      (
        await db.query<{ user_id: string; platform: string; updated_at: Date }>(
          'select user_id, platform, updated_at from public.device_tokens where token = $1',
          [token],
        )
      ).rows;

    it('401 without a token', async () => {
      for (const method of ['put', 'delete'] as const) {
        const r = await http()[method]('/v1/devices').send({ token: 'x', platform: 'ios' }).expect(401);
        expect(r.body).toEqual({ code: 'unauthorized', message: expect.any(String) });
      }
    });

    it('register → 204 and a row; re-register updates in place (no duplicate)', async () => {
      const u = await newUser('device');
      const token = fcmToken();
      const r = await putDevice(u, { token, platform: 'ios' }).expect(204);
      expect(r.text).toBe('');
      const [first] = await rowFor(token);
      expect(first).toMatchObject({ user_id: u.id, platform: 'ios' });

      await new Promise((res) => setTimeout(res, 15));
      await putDevice(u, { token, platform: 'ios' }).expect(204);
      const again = await rowFor(token);
      expect(again).toHaveLength(1);
      expect(again[0].updated_at.getTime()).toBeGreaterThan(first.updated_at.getTime());
      expect(await count('device_tokens', u.id)).toBe(1);
    });

    it('a token that moves to another account is reassigned to it', async () => {
      const a = await newUser('device-a');
      const b = await newUser('device-b');
      const token = fcmToken();
      await putDevice(a, { token, platform: 'android' }).expect(204);
      await putDevice(b, { token, platform: 'android' }).expect(204);
      const rows = await rowFor(token);
      expect(rows).toHaveLength(1);
      expect(rows[0].user_id).toBe(b.id);
      expect(await count('device_tokens', a.id)).toBe(0);
    });

    it('delete is scoped to the owner and idempotent', async () => {
      const owner = await newUser('device-owner');
      const other = await newUser('device-other');
      const token = fcmToken();
      await putDevice(owner, { token, platform: 'ios' }).expect(204);

      await deleteDevice(other, { token }).expect(204); // not theirs: no-op
      expect(await rowFor(token)).toHaveLength(1);

      await deleteDevice(owner, { token }).expect(204);
      expect(await rowFor(token)).toHaveLength(0);
      await deleteDevice(owner, { token }).expect(204); // idempotent
    });

    it('validation → 400 invalid_request, nothing stored, token never echoed', async () => {
      const u = await newUser('device-invalid');
      for (const body of [
        {},
        { token: '', platform: 'ios' },
        { token: 'ok', platform: 'web' },
        { token: 'y'.repeat(4097), platform: 'android' },
        { token: 12345, platform: 'ios' },
      ]) {
        const r = await putDevice(u, body).expect(400);
        expect(r.body.code).toBe('invalid_request');
        expect(JSON.stringify(r.body)).not.toContain('yyyy');
      }
      const d = await deleteDevice(u, {}).expect(400);
      expect(d.body.code).toBe('invalid_request');
      expect(await count('device_tokens', u.id)).toBe(0);
    });
  });
});
