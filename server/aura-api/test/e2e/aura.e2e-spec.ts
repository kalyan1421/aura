import { randomBytes, randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { PERSONAL_TABLES, purgeAccount, purgeDueAccounts } from '../../src/account/account-purge';
import { PrivateMediaStore } from '../../src/account/private-media';
import { ApiError } from '../../src/common/api-error';
import { uuidv7 } from '../../src/common/uuid';
import { AppConfig } from '../../src/config/app-config';
import { unwrapDataKey } from '../../src/keys/envelope';
import { purgeOldSyncMutations } from '../../src/queues/maintenance';
import { ProfileService } from '../../src/profile/profile.service';
import { addDays, auraDay, isLocalDay, localDate } from '../../src/rules';
import { bootApp, createUser, dbPool, deleteUser, localAnonKey, localServiceKey, SUPABASE_URL, type TestUser } from './support';

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
      ['get', '/v1/account'],
      ['post', '/v1/account/deletion'],
      ['delete', '/v1/account/deletion'],
      ['post', '/v1/media/upload-url'],
      ['post', '/v1/media/download-url'],
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
        { ...checkIn(), entity: 'not_an_entity' },
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

  // ---------------------------------------------------------------- text limits + 24 h edit window
  describe('text limits (grapheme clusters) and the 24 h check-in edit window', () => {
    const TELUGU = 'స్త్రీ'; // one character, 6 UTF-16 units
    const H = 3600_000;
    const ago = (ms: number) => new Date(Date.now() - ms);
    const reasons = (r: request.Response) => r.body.results.map((x: { status: string; reason?: string }) => x.reason ?? x.status);
    const moodOf = async (id: string) =>
      (await db.query<{ mood_id: string }>('select mood_id from public.check_ins where id = $1', [id])).rows[0]?.mood_id;
    let u: TestUser;
    beforeAll(async () => {
      u = await newUser('limits');
      await onboard(u).expect(200);
    });

    it('tags ≤ 20 and habit names ≤ 30 characters, counted as people see them (Telugu stored intact)', async () => {
      const tagged = (tags: string[]) => {
        const c = checkIn('calm');
        return { ...c, payload: { ...c.payload, tags } };
      };
      const custom = (name: string) => {
        const id = uuidv7();
        return { ...habit(id, null), payload: { id, kind: 'custom', name, active: true } };
      };
      const okTag = tagged([TELUGU.repeat(20)]);
      const okName = custom(TELUGU.repeat(30)); // 180 code points: the old DB CHECK (<= 40) refused this
      const r = await pushAs(u, [okTag, tagged(['x'.repeat(21)]), okName, custom('x'.repeat(31))]).expect(200);
      expect(reasons(r)).toEqual(['applied', 'tag_too_long', 'applied', 'habit_name_too_long']);
      const tags = (await db.query<{ tags: string[] }>('select tags from public.check_ins where id = $1', [okTag.payload.id])).rows[0];
      expect(tags.tags).toEqual([TELUGU.repeat(20)]);
      const name = (await db.query<{ name: string }>('select name from public.habits where id = $1', [okName.payload.id])).rows[0];
      expect(name.name).toBe(TELUGU.repeat(30));
    });

    const made = (msAgo: number) => {
      const t = ago(msAgo);
      return checkIn('calm', { deviceTs: t.toISOString(), localDay: auraDay(t, TZ) });
    };

    it("without editedAt, edits are judged by the mutation's deviceTs: ≤ 24 h after the check-in, ≤ 5 min ahead", async () => {
      const editAt = (c: ReturnType<typeof checkIn>, t: Date, moodId: string) => ({
        ...c,
        id: uuidv7(),
        deviceTs: t.toISOString(),
        payload: { ...c.payload, moodId },
      });
      const recent = made(23 * H);
      const old = made(30 * H);
      expect(reasons(await pushAs(u, [recent, old]).expect(200))).toEqual(['applied', 'applied']);

      const r = await pushAs(u, [
        editAt(recent, new Date(), 'joyful'), // 23 h after it was made
        editAt(old, new Date(), 'joyful'), // 30 h after → closed
        editAt(recent, new Date(Date.now() + 6 * 60_000), 'anxious'), // future-stamped beyond 5 min
      ]).expect(200);
      expect(reasons(r)).toEqual(['applied', 'edit_window_closed', 'edit_window_closed']);
      expect(await moodOf(recent.payload.id)).toBe('joyful');
      expect(await moodOf(old.payload.id)).toBe('calm');

      // made offline 7 h ago (23 h after the check-in), synced only now (30 h after) → still applies
      const offline = await pushAs(u, [editAt(old, ago(7 * H), 'anxious')]).expect(200);
      expect(reasons(offline)).toEqual(['applied']);
      expect(await moodOf(old.payload.id)).toBe('anxious');

      // deletes are allowed any time
      expect(reasons(await pushAs(u, [del('check_in', old.payload.id)]).expect(200))).toEqual(['applied']);
      expect(await moodOf(old.payload.id)).toBeUndefined();
    });

    it('payload.editedAt (deviceTs stays the original time) decides the window; ignored on a first insert', async () => {
      /** How the app sends an edit: same deviceTs/localDay as the original, editedAt = when the user edited. */
      const edited = (c: ReturnType<typeof checkIn>, at: Date, moodId: string) => ({
        ...c,
        id: uuidv7(),
        payload: { ...c.payload, moodId, editedAt: at.toISOString() },
      });
      const deviceTsOf = async (id: string) =>
        (await db.query<{ device_ts: Date }>('select device_ts from public.check_ins where id = $1', [id])).rows[0]?.device_ts;
      const old = made(30 * H);
      const fresh = made(H);
      expect(reasons(await pushAs(u, [old, fresh]).expect(200))).toEqual(['applied', 'applied']);

      const r = await pushAs(u, [
        edited(old, ago(5 * H), 'joyful'), // 25 h after the check-in → closed
        edited(old, ago(7 * H), 'anxious'), // 23 h after (made offline, synced at 30 h) → applied
        edited(fresh, new Date(Date.now() + 6 * 60_000), 'joyful'), // > 5 min ahead of the server → closed
        { ...edited(old, ago(6 * H), 'joyful'), payload: { ...old.payload, editedAt: 'yesterday' } },
      ]).expect(200);
      expect(reasons(r)).toEqual(['edit_window_closed', 'applied', 'edit_window_closed', 'invalid_payload']);
      expect(await moodOf(old.payload.id)).toBe('anxious');
      expect(await moodOf(fresh.payload.id)).toBe('calm');
      expect((await deviceTsOf(old.payload.id))?.toISOString()).toBe(new Date(old.deviceTs).toISOString());

      // an edit whose original upsert never reached the server arrives as the insert: judged as the original event
      const unsynced = checkIn('calm');
      const first = await pushAs(u, [edited(unsynced, ago(48 * H), 'joyful')]).expect(200);
      expect(reasons(first)).toEqual(['applied']);
      expect(await moodOf(unsynced.payload.id)).toBe('joyful');
      expect((await deviceTsOf(unsynced.payload.id))?.toISOString()).toBe(new Date(unsynced.deviceTs).toISOString());
      const ledger = await db.query(
        `select local_day from public.starlight_ledger where reason = 'checkin' and source_id = $1`,
        [unsynced.payload.id],
      );
      expect(ledger.rows).toEqual([{ local_day: unsynced.localDay }]); // credited as the live original event
    });
  });

  // ---------------------------------------------------------------- media: voice notes (F1)
  describe('media: voice notes', () => {
    const as = (u: TestUser, r: request.Test) => r.set('Authorization', `Bearer ${u.token}`);
    const uploadUrl = (u: TestUser, body: Record<string, unknown>) => as(u, http().post('/v1/media/upload-url')).send(body);
    const downloadUrl = (u: TestUser, path: unknown) => as(u, http().post('/v1/media/download-url')).send({ path });
    const svc = () => ({ apikey: localServiceKey(), Authorization: `Bearer ${localServiceKey()}` });
    /** What the app does: PUT the ciphertext to the signed URL (no auth header — the token is in the URL). */
    const putBytes = (url: string, bytes: Buffer, extra: Record<string, string> = {}) =>
      fetch(url, { method: 'PUT', headers: { 'Content-Type': 'application/octet-stream', ...extra }, body: bytes });
    const objectRow = async (path: string) =>
      (
        await db.query<{ size: string; mimetype: string }>(
          `select metadata->>'size' as size, metadata->>'mimetype' as mimetype
             from storage.objects where bucket_id = 'private-media' and name = $1`,
          [path],
        )
      ).rows[0] ?? null;
    /** The blob itself, read with the service key (null when Storage no longer has it). */
    const blob = async (path: string): Promise<Buffer | null> => {
      const res = await fetch(`${SUPABASE_URL}/storage/v1/object/authenticated/private-media/${path}`, { headers: svc() });
      const body = Buffer.from(await res.arrayBuffer());
      return res.status === 200 ? body : null;
    };
    const voicePathOf = async (id: string): Promise<string | null | undefined> =>
      (await db.query<{ voice_path: string | null }>('select voice_path from public.check_ins where id = $1', [id])).rows[0]
        ?.voice_path;
    /** Request an upload URL for `recordId` and PUT `bytes` to it; returns the object path. */
    const recordVoice = async (u: TestUser, recordId: string, bytes: Buffer): Promise<string> => {
      const r = await uploadUrl(u, { kind: 'voice', recordId, bytes: bytes.length }).expect(200);
      const put = await putBytes(r.body.uploadUrl, bytes);
      expect(put.status).toBe(200);
      await put.arrayBuffer();
      return r.body.path;
    };
    const withVoice = (id: string, voicePath: unknown, moodId = 'calm') => {
      const m = checkIn(moodId);
      return { ...m, payload: { ...m.payload, id, voicePath } };
    };
    const editOf = (m: ReturnType<typeof withVoice>, payload: Record<string, unknown>) => ({
      ...m,
      id: uuidv7(),
      payload: { ...m.payload, ...payload },
    });

    let owner: TestUser;
    let stranger: TestUser;
    beforeAll(async () => {
      owner = await newUser('voice-owner');
      stranger = await newUser('voice-stranger');
      await onboard(owner).expect(200);
      await onboard(stranger).expect(200);
    });
    afterAll(async () => {
      // Test users are deleted via the Auth admin API, which leaves Storage alone: clear their prefixes.
      const media = app.get(PrivateMediaStore);
      for (const u of [owner, stranger]) if (u) await media.remove(await media.listUserObjects(db, u.id));
    });

    it('upload URL → PUT ciphertext → push check_in with voicePath → download URL serves the same bytes', async () => {
      const id = uuidv7();
      const t0 = Date.now();
      const up = await uploadUrl(owner, { kind: 'voice', recordId: id, bytes: 4096 }).expect(200);
      expect(up.headers['cache-control']).toBe('no-store');
      expect(up.body).toEqual({ path: `${owner.id}/voice/${id}`, uploadUrl: expect.any(String), expiresAt: expect.any(String) });
      expect(up.body.uploadUrl.startsWith(`${SUPABASE_URL}/storage/v1/object/upload/sign/private-media/${owner.id}/voice/${id}?token=`)).toBe(true);
      expect(Math.abs(new Date(up.body.expiresAt).getTime() - (t0 + 600_000))).toBeLessThan(15_000);

      const ciphertext = randomBytes(4096);
      const put = await putBytes(up.body.uploadUrl, ciphertext);
      expect(put.status).toBe(200);
      await put.arrayBuffer();
      expect(await objectRow(up.body.path)).toEqual({ size: '4096', mimetype: 'application/octet-stream' });

      const r = await pushAs(owner, [withVoice(id, up.body.path)]).expect(200);
      expect(r.body.results[0].status).toBe('applied');
      expect(await voicePathOf(id)).toBe(up.body.path);

      const down = await downloadUrl(owner, up.body.path).expect(200);
      expect(down.headers['cache-control']).toBe('no-store');
      expect(down.body).toEqual({ downloadUrl: expect.any(String), expiresAt: expect.any(String) });
      expect(Math.abs(new Date(down.body.expiresAt).getTime() - (Date.now() + 300_000))).toBeLessThan(15_000);
      const got = await fetch(down.body.downloadUrl);
      expect(got.status).toBe(200);
      expect(Buffer.from(await got.arrayBuffer()).equals(ciphertext)).toBe(true);
    });

    it('a retried upload overwrites the same object (upsert); the signed PUT needs no auth header', async () => {
      const id = uuidv7();
      const first = await recordVoice(owner, id, randomBytes(100));
      const again = await uploadUrl(owner, { kind: 'voice', recordId: id, bytes: 200 }).expect(200);
      expect(again.body.path).toBe(first);
      const second = randomBytes(200);
      const put = await putBytes(again.body.uploadUrl, second, { 'x-upsert': 'true' });
      expect(put.status).toBe(200);
      await put.arrayBuffer();
      expect((await blob(first))?.equals(second)).toBe(true);
      expect((await objectRow(first))?.size).toBe('200');
    });

    it("another user gets 404 for the owner's path; malformed paths are 404 too; bad bodies 400", async () => {
      const id = uuidv7();
      const path = await recordVoice(owner, id, randomBytes(64));
      for (const p of [path, `${stranger.id}/../${owner.id}/voice/${id}`, `${stranger.id}/voice/..`]) {
        const r = await downloadUrl(stranger, p).expect(404);
        expect(r.body).toEqual({ code: 'not_found', message: expect.any(String) });
      }
      // an own path that does not exist looks exactly the same
      const missing = await downloadUrl(stranger, `${stranger.id}/voice/${id}`).expect(404);
      expect(missing.body.code).toBe('not_found');
      // the stranger's upload URL for the same record id lands in the stranger's own prefix
      const theirs = await uploadUrl(stranger, { kind: 'voice', recordId: id, bytes: 10 }).expect(200);
      expect(theirs.body.path).toBe(`${stranger.id}/voice/${id}`);
      // …and can never be attached to a check-in as the owner's path
      const r = await pushAs(stranger, [withVoice(uuidv7(), path)]).expect(200);
      expect(r.body.results[0]).toMatchObject({ status: 'rejected', reason: 'invalid_voice_path' });

      expect((await downloadUrl(owner, 42).expect(400)).body.code).toBe('invalid_request');
      const big = await uploadUrl(owner, { kind: 'voice', recordId: uuidv7(), bytes: 1_048_577 }).expect(400);
      expect(big.body).toEqual({ code: 'media_too_large', message: expect.any(String) });
      await uploadUrl(owner, { kind: 'voice', recordId: uuidv7(), bytes: 1_048_576 }).expect(200);
      expect((await uploadUrl(owner, { kind: 'photo', recordId: uuidv7(), bytes: 10 }).expect(400)).body.code).toBe('invalid_request');
      expect((await uploadUrl(owner, { kind: 'voice', recordId: 'x', bytes: 10 }).expect(400)).body.code).toBe('invalid_request');
    });

    it('voicePath must be <user_id>/voice/<check-in id> → otherwise rejected: invalid_voice_path', async () => {
      const id = uuidv7();
      const r = await pushAs(owner, [
        withVoice(id, `${stranger.id}/voice/${id}`),
        withVoice(uuidv7(), `${owner.id}/voice/${id}`),
        withVoice(uuidv7(), `${owner.id}/voice/../x`),
        withVoice(uuidv7(), 7),
      ]).expect(200);
      expect(r.body.results.map((x: { reason?: string }) => x.reason)).toEqual(Array(4).fill('invalid_voice_path'));
      expect(await voicePathOf(id)).toBeUndefined();
    });

    it('an edit without voicePath keeps it; an edit to null clears it and deletes the object', async () => {
      const id = uuidv7();
      const path = await recordVoice(owner, id, randomBytes(128));
      const c = withVoice(id, path);
      await pushAs(owner, [c]).expect(200);
      const { voicePath: _keep, ...noVoice } = c.payload;
      const keep = await pushAs(owner, [{ ...c, id: uuidv7(), payload: { ...noVoice, moodId: 'joyful' } }]).expect(200);
      expect(keep.body.results[0].status).toBe('applied');
      expect(await voicePathOf(id)).toBe(path);
      expect(await blob(path)).not.toBeNull();

      const cleared = await pushAs(owner, [editOf(c, { voicePath: null })]).expect(200);
      expect(cleared.body.results[0].status).toBe('applied');
      expect(await voicePathOf(id)).toBeNull();
      expect(await objectRow(path)).toBeNull();
      expect(await blob(path)).toBeNull();
      await downloadUrl(owner, path).expect(404);
    });

    it('deleting the check-in removes its voice object (Starlight stays)', async () => {
      const id = uuidv7();
      const path = await recordVoice(owner, id, randomBytes(256));
      await pushAs(owner, [withVoice(id, path)]).expect(200);
      const starlight = Number((await as(owner, http().get('/v1/me/snapshot')).expect(200)).body.starlight.total);
      expect(await objectRow(path)).not.toBeNull();

      const r = await pushAs(owner, [del('check_in', id)]).expect(200);
      expect(r.body.results[0].status).toBe('applied');
      expect(r.body.snapshot.starlight.total).toBe(starlight);
      expect(await voicePathOf(id)).toBeUndefined();
      expect(await objectRow(path)).toBeNull();
      expect(await blob(path)).toBeNull();
    });

    it('media routes are 403 account_deletion_pending during the grace period', async () => {
      const u = await newUser('voice-pending');
      await onboard(u).expect(200);
      const id = uuidv7();
      await uploadUrl(u, { kind: 'voice', recordId: id, bytes: 10 }).expect(200);
      await as(u, http().post('/v1/account/deletion')).expect(202);
      for (const call of [
        () => uploadUrl(u, { kind: 'voice', recordId: id, bytes: 10 }),
        () => downloadUrl(u, `${u.id}/voice/${id}`),
      ]) {
        const r = await call().expect(403);
        expect(r.body).toEqual({ code: 'account_deletion_pending', message: expect.any(String) });
      }
      await as(u, http().delete('/v1/account/deletion')).expect(200);
      await uploadUrl(u, { kind: 'voice', recordId: id, bytes: 10 }).expect(200);
    });
  });

  // ---------------------------------------------------------------- account deletion (F8 REQ-ACC-11)
  describe('account deletion', () => {
    const trialSubscriptions: string[] = [];
    afterAll(async () => {
      if (trialSubscriptions.length) await db.query('delete from public.subscriptions where id = any($1::uuid[])', [trialSubscriptions]);
    });
    const as = (u: TestUser, r: request.Test) => r.set('Authorization', `Bearer ${u.token}`);
    const status = (u: TestUser) => as(u, http().get('/v1/account'));
    const requestDeletion = (u: TestUser) => as(u, http().post('/v1/account/deletion'));
    const cancelDeletion = (u: TestUser) => as(u, http().delete('/v1/account/deletion'));
    const fcmToken = (): string => `e2e-fcm:${uuidv7()}:APA91b${'z'.repeat(40)}`;
    const makeDue = (u: TestUser) =>
      db.query(
        `update public.account_deletions
            set requested_at = now() - interval '8 days', scheduled_for = now() - interval '1 day'
          where user_id = $1`,
        [u.id],
      );
    const storageHeaders = () => ({ apikey: localServiceKey(), Authorization: `Bearer ${localServiceKey()}` });
    /** Stands in for a NestJS-signed upload (client-encrypted bytes under `<user_id>/…`). */
    const upload = async (path: string): Promise<void> => {
      const res = await fetch(`${SUPABASE_URL}/storage/v1/object/private-media/${path}`, {
        method: 'POST',
        headers: { ...storageHeaders(), 'Content-Type': 'application/octet-stream' },
        body: randomBytes(64),
      });
      if (!res.ok) throw new Error(`upload failed: ${res.status}`);
    };
    const blobStatus = async (path: string): Promise<number> => {
      const res = await fetch(`${SUPABASE_URL}/storage/v1/object/authenticated/private-media/${path}`, { headers: storageHeaders() });
      await res.arrayBuffer();
      return res.status;
    };
    const mediaOf = async (userId: string): Promise<string[]> =>
      (
        await db.query<{ name: string }>(
          `select name from storage.objects where bucket_id = 'private-media' and name like $1 || '/%' order by name`,
          [userId],
        )
      ).rows.map((r) => r.name);
    const countsFor = async (userId: string): Promise<Record<string, number>> => {
      const out: Record<string, number> = {};
      for (const t of PERSONAL_TABLES) out[t] = await count(t, userId);
      return out;
    };
    const authRows = async (userId: string) =>
      (
        await db.query<{ users: string; identities: string; sessions: string; audit: string }>(
          `select (select count(*) from auth.users where id = $1) as users,
                  (select count(*) from auth.identities where user_id = $1) as identities,
                  (select count(*) from auth.sessions where user_id = $1) as sessions,
                  (select count(*) from auth.audit_log_entries
                    where payload->>'actor_id' = $1::text or payload->'traits'->>'user_id' = $1::text) as audit`,
          [userId],
        )
      ).rows[0];
    /** A user with data in every personal table + two private-media objects. */
    const populate = async (u: TestUser): Promise<string[]> => {
      await onboard(u).expect(200);
      const h = uuidv7();
      // F4: a trigger capsule (ciphertext only; no unlock job, unlike a date capsule)
      const capsule = {
        id: uuidv7(),
        entity: 'capsule',
        op: 'seal',
        deviceTs: now(),
        payload: { id: uuidv7(), payloadCt: Buffer.from('capsule-ciphertext').toString('base64'), unlockType: 'mood', triggerQuadrant: 'rain' },
      };
      const r = await pushAs(u, [checkIn(), habit(h, 'breathe'), log(h), capsule]).expect(200);
      expect(r.body.results.map((x: { status: string }) => x.status)).toEqual(['applied', 'applied', 'applied', 'applied']);
      await as(u, http().get('/v1/keys/data-key')).expect(200);
      await as(u, http().put('/v1/devices')).send({ token: fcmToken(), platform: 'ios' }).expect(204);
      await db.query('insert into public.notification_prefs (user_id, reminder_time) values ($1, $2)', [u.id, '21:00']);
      await db.query(`insert into public.user_consents (user_id, purpose, policy_version) values ($1, 'core', 'v1')`, [u.id]);
      // F5/F9: a room membership (through the API), plus a sanction and a strike as the moderation service writes them.
      // Matching needs the current community guidelines accepted first (REQ-SAFE-04).
      await as(u, http().post('/v1/safety/guidelines/accept')).send({ version: 1 }).expect(200);
      const matched = await as(u, http().post('/v1/rooms/match')).send({ quadrant: 'storm', moodId: 'anxious' }).expect(200);
      // F6: a reflection (a strike above would hold it; stored either way). Before the strike is inserted.
      await as(u, http().post(`/v1/rooms/${matched.body.room.roomId as string}/reflections`))
        .send({ reflectionId: randomUUID(), text: 'a quiet evening' })
        .expect((r) => expect([200, 201]).toContain(r.status));
      await db.query(`insert into public.sanctions (user_id, kind, reason_code, source) values ($1, 'warning', 'e2e', 'moderator')`, [u.id]);
      await db.query(
        `insert into public.strikes (user_id, reason_code, created_by, expires_at) values ($1, 'e2e', 'staff:e2e', now() + interval '90 days')`,
        [u.id],
      );
      // F8 follow-ups: an under-18 platform-signal flag and a (sealed-looking) Sign in with Apple token, as the API
      // writes them (test/e2e/account-followups.e2e-spec.ts covers the real flows).
      await db.query(`insert into public.minor_signals (user_id, minor_until) values ($1, current_date + 1)`, [u.id]);
      // REQ-ADM-14 (migration 20261005000017): an app install the account used (hashed id).
      await db.query(`insert into public.device_installs (user_id, install_hash, platform) values ($1, $2, 'ios')`, [u.id, randomBytes(32).toString('hex')]);
      // F5 "Tell me when they open" (migration 20261005000019): a waiting opt-in for the Hindi + Hinglish pool.
      await db.query(`insert into public.room_pool_waitlist (user_id, pool) values ($1, 'hi')`, [u.id]);
      // F12 (migration 20261005000020): the store token, the derived entitlement, a cosmetic sky + its pairing and
      // Stardust, as NestJS writes them (test/e2e/billing.e2e-spec.ts covers the real flows).
      await as(u, http().get('/v1/billing/entitlement')).expect(200); // billing_accounts + entitlements
      await db.query(`insert into public.user_cosmetics (user_id, cosmetic_id, source, redemption_id) values ($1, 'first_light', 'stardust', $2)`, [u.id, randomUUID()]);
      await db.query(`insert into public.sky_preferences (user_id, sky_theme, soundscape) values ($1, 'first_light', 'bells')`, [u.id]);
      await db.query(`insert into public.stardust_ledger (user_id, amount, reason, ref_id) values ($1, 10, 'gift_received', $2)`, [u.id, randomUUID()]);
      // PRD 12 trial-ending email (migration 20261005000025): the per-trial ledger row. Its subscription is a purchase
      // record (de-identified by the purge, kept), so this suite removes it afterwards.
      const trial = await db.query<{ id: string }>(
        `insert into public.subscriptions (owner_user_id, store, store_ref, product_id, environment, state, trial_ends_at, expires_at)
         values ($1, 'apple', $2, 'aura_plus_monthly', 'sandbox', 'trial', now() + interval '2 days', now() + interval '2 days') returning id`,
        [u.id, `e2e-purge-${randomBytes(6).toString('hex')}`],
      );
      trialSubscriptions.push(trial.rows[0].id);
      await db.query(`insert into public.trial_ending_emails (subscription_id, user_id, state, reason) values ($1, $2, 'skipped', 'no_email')`, [
        trial.rows[0].id,
        u.id,
      ]);
      // F15 + F14 Milestone B (migration 20261005000023): a Sanctuary session record (through the sync push), a planned
      // user-timed push and a gestures-received log row (notification_activity comes from the sync push's trigger).
      const session = { id: uuidv7(), entity: 'sanctuary_session', op: 'upsert', deviceTs: now(), localDay: localDate(new Date(), 'Asia/Kolkata'), tz: 'Asia/Kolkata', payload: { id: uuidv7(), activity: 'breathe', variant: 'calm', durationS: 64 } };
      expect((await pushAs(u, [session]).expect(200)).body.results[0].status).toBe('applied');
      await db.query(`insert into public.notification_schedule (user_id, kind, next_at, tz) values ($1, 'lantern_hour', now() + interval '1 hour', 'Asia/Kolkata')`, [u.id]);
      await db.query('insert into public.gesture_push_log (user_id, room_id, local_day) values ($1, $2, current_date)', [u.id, matched.body.room.roomId]);
      // F7 Breath Ripples (migration 20261005000021): "Breathe together" in the room opens an invite and a waiting
      // ticket (through the API); a seat in a session, as the matcher writes it.
      await as(u, http().post('/v1/ripples/match')).send({ ticketId: uuidv7(), entry: 'room', roomId: matched.body.room.roomId }).expect(200);
      const rs = await db.query<{ id: string }>(
        `insert into public.ripple_sessions (entry, start_rule, t0, settle_ms, inhale_ms, exhale_ms, cycles, fade_ms, pacer_version, ends_at, purge_at)
         values ('quick', 'timeout', now(), 10000, 4000, 6000, 16, 10000, 1, now() + interval '180 seconds', now() + interval '7 days') returning id`,
      );
      await db.query(`insert into public.ripple_seats (session_id, seat, kind, user_id, pseudonym) values ($1, 1, 'human', $2, 'Quiet Comet')`, [rs.rows[0].id, u.id]);
      // F16 Quiet Together (migration 20261005000027): a membership through the API, and a gesture in its log.
      const quiet = await as(u, http().post('/v1/quiet/join')).send({ mode: 'rest', timezone: 'Asia/Kolkata' }).expect(200);
      await as(u, http().post(`/v1/quiet/sessions/${quiet.body.session.sessionId as string}/gestures`)).send({ type: 'stargaze' }).expect(202);
      await db.query(`insert into public.apple_auth_tokens (user_id, client_id, wrapped_refresh_token) values ($1, 'com.akvega.aura', $2)`, [
        u.id,
        randomBytes(64).toString('base64'),
      ]);
      // F13 (migration 20261005000026): a keepsake awarded through the API (the capsule sealed above) and the Lantern
      // Hour tally as NestJS writes it (test/e2e/keepsakes.e2e-spec.ts covers the real flows).
      const earned = await as(u, http().get('/v1/keepsakes')).expect(200);
      expect(earned.body.keepsakes.map((k: { key: string }) => k.key)).toContain('capsule_sealed_first');
      await db.query('insert into public.keepsake_tallies (user_id, lantern_nights, lantern_through) values ($1, 1, now()) on conflict (user_id) do nothing', [u.id]);
      const paths = [`${u.id}/voice/${uuidv7()}.bin`, `${u.id}/capsules/${uuidv7()}/0.bin`];
      for (const p of paths) await upload(p);
      return paths;
    };

    it('PERSONAL_TABLES covers every public table with a user_id column (add new personal tables to the purge)', async () => {
      const r = await db.query<{ table_name: string }>(
        `select table_name from information_schema.columns
          where table_schema = 'public' and column_name = 'user_id' and table_name <> 'account_deletions'
          order by table_name`,
      );
      expect(r.rows.map((x) => x.table_name)).toEqual([...PERSONAL_TABLES].sort());
    });

    it('request → 202 +7 days (idempotent), tokens removed, every other /v1 route 403 until cancelled', async () => {
      const u = await newUser('delete-grace');
      await onboard(u).expect(200);
      await as(u, http().put('/v1/devices')).send({ token: fcmToken(), platform: 'android' }).expect(204);
      await status(u).expect(200, { deletionScheduledFor: null });

      const t0 = Date.now();
      const first = await requestDeletion(u).expect(202);
      const when = new Date(first.body.deletionScheduledFor).getTime();
      expect(first.body).toEqual({ deletionScheduledFor: new Date(when).toISOString() });
      expect(Math.abs(when - (t0 + 7 * 86_400_000))).toBeLessThan(60_000);
      expect(await count('device_tokens', u.id)).toBe(0);

      const again = await requestDeletion(u).send({}).expect(202);
      expect(again.body).toEqual(first.body); // a repeat never moves the date
      const st = await status(u).expect(200);
      expect(st.headers['cache-control']).toBe('no-store');
      expect(st.body).toEqual(first.body);

      for (const call of [
        () => pushAs(u, [checkIn()]),
        () => onboard(u),
        () => as(u, http().get('/v1/me/snapshot')),
        () => as(u, http().get('/v1/keys/data-key')),
        () => as(u, http().put('/v1/devices')).send({ token: fcmToken(), platform: 'ios' }),
        () => as(u, http().delete('/v1/devices')).send({ token: 'x' }),
      ]) {
        const r = await call().expect(403);
        expect(r.body).toEqual({ code: 'account_deletion_pending', message: expect.any(String) });
      }
      expect(await count('check_ins', u.id)).toBe(0); // nothing new was written
      expect(await count('device_tokens', u.id)).toBe(0);
      await http().get('/health').expect(200);

      await cancelDeletion(u).expect(200, { deletionScheduledFor: null });
      await cancelDeletion(u).expect(200, { deletionScheduledFor: null }); // idempotent
      await status(u).expect(200, { deletionScheduledFor: null });
      expect((await pushAs(u, [checkIn()]).expect(200)).body.results[0].status).toBe('applied');
      await onboard(u).expect(200);
    });

    it('works for an account that never finished onboarding', async () => {
      const u = await newUser('delete-noprofile');
      await requestDeletion(u).expect(202);
      await status(u).expect(200).expect((r) => expect(r.body.deletionScheduledFor).toEqual(expect.any(String)));
      await onboard(u).expect(403);
      await cancelDeletion(u).expect(200, { deletionScheduledFor: null });
      await onboard(u).expect(200);
    });

    it('rejects a non-object body → 400 invalid_request, nothing scheduled', async () => {
      const u = await newUser('delete-badbody');
      const r = await requestDeletion(u).send([1, 2]).expect(400);
      expect(r.body.code).toBe('invalid_request');
      await status(u).expect(200, { deletionScheduledFor: null });
    });

    it('once the grace period has ended, cancel → 409 account_deletion_in_progress', async () => {
      const u = await newUser('delete-late');
      await requestDeletion(u).expect(202);
      await makeDue(u);
      const r = await cancelDeletion(u).expect(409);
      expect(r.body).toEqual({ code: 'account_deletion_in_progress', message: expect.any(String) });
      await status(u).expect(200).expect((x) => expect(x.body.deletionScheduledFor).not.toBeNull());
      await pushAs(u, []).expect(403);
    });

    it('purge removes every personal row, private-media object and the auth user — and nobody else’s', async () => {
      const media = app.get(PrivateMediaStore);
      expect(media.configured).toBe(true);

      const victim = await newUser('delete-victim');
      const bystander = await newUser('delete-bystander');
      const notYet = await newUser('delete-notyet');
      const victimPaths = await populate(victim);
      const bystanderPaths = await populate(bystander);
      await requestDeletion(notYet).expect(202);

      await requestDeletion(victim).expect(202);
      // a token that slipped in during the grace period (e.g. written by a future F14 job) goes too
      await db.query(`insert into public.device_tokens (user_id, platform, token) values ($1, 'ios', $2)`, [victim.id, fcmToken()]);
      await makeDue(victim);

      const before = await countsFor(victim.id);
      expect(Object.entries(before).filter(([, n]) => n === 0)).toEqual([]);
      expect(await mediaOf(victim.id)).toEqual([...victimPaths].sort());
      const bystanderBefore = await countsFor(bystander.id);

      const summary = await purgeDueAccounts(db, media);
      expect(summary).toMatchObject({ failed: 0, deferred: 0, errors: [] });
      expect(summary.purged).toBeGreaterThanOrEqual(1);
      expect(summary.mediaObjects).toBeGreaterThanOrEqual(2);

      // victim: nothing left — rows, schedule, media (row AND blob), auth user, identities, sessions, audit trail
      expect(Object.values(await countsFor(victim.id)).every((n) => n === 0)).toBe(true);
      expect(await count('account_deletions', victim.id)).toBe(0);
      expect(await mediaOf(victim.id)).toEqual([]);
      for (const p of victimPaths) expect(await blobStatus(p)).not.toBe(200);
      expect(await authRows(victim.id)).toEqual({ users: '0', identities: '0', sessions: '0', audit: '0' });

      // bystander untouched (rows, media, auth); not-yet-due account still scheduled
      expect(await countsFor(bystander.id)).toEqual(bystanderBefore);
      expect(await mediaOf(bystander.id)).toEqual([...bystanderPaths].sort());
      for (const p of bystanderPaths) expect(await blobStatus(p)).toBe(200);
      expect((await authRows(bystander.id)).users).toBe('1');
      await as(bystander, http().get('/v1/me/snapshot')).expect(200);
      expect(await count('account_deletions', notYet.id)).toBe(1);
      expect((await authRows(notYet.id)).users).toBe('1');

      // idempotent / safe to re-run
      await expect(purgeAccount(db, media, victim.id)).resolves.toEqual({ status: 'skipped' });
      const rerun = await purgeDueAccounts(db, media);
      expect(rerun).toMatchObject({ failed: 0 });

      // the victim's still-unexpired access token can't resurrect anything
      await status(victim).expect(200, { deletionScheduledFor: null });
      await requestDeletion(victim).expect(401).expect((r) => expect(r.body.code).toBe('unknown_user'));
      await onboard(victim).expect(401);

      await media.remove(await mediaOf(bystander.id));
    });

    it('a purge that finds media but has no service key defers the account (nothing of its auth user is lost)', async () => {
      const u = await newUser('delete-nokey');
      await onboard(u).expect(200);
      const path = `${u.id}/voice/${uuidv7()}.bin`;
      await upload(path);
      await requestDeletion(u).expect(202);
      await makeDue(u);

      const keyless = new PrivateMediaStore({ supabaseUrl: SUPABASE_URL });
      const s = await purgeDueAccounts(db, keyless);
      expect(s.deferred).toBeGreaterThanOrEqual(1);
      expect(await count('profiles', u.id)).toBe(0); // personal rows already gone (step 1)
      expect(await mediaOf(u.id)).toEqual([path]); // media and auth user wait for a configured run
      expect((await authRows(u.id)).users).toBe('1');
      expect(await count('account_deletions', u.id)).toBe(1);

      const s2 = await purgeDueAccounts(db, app.get(PrivateMediaStore)); // resumes
      expect(s2).toMatchObject({ failed: 0, deferred: 0 });
      expect(await mediaOf(u.id)).toEqual([]);
      expect((await authRows(u.id)).users).toBe('0');
    });
  });
});
