/**
 * Account & safety follow-ups against the live local stack (Supabase Auth + Postgres + Storage, Redis) and a fake
 * Sign in with Apple server (node:http, verifies the ES256 client secret like Apple):
 *  1. POST /v1/account/apple-auth → sealed refresh token; revoked when the deletion is requested (best effort) and by
 *     the purge (deferred while Apple is down, abandoned after APPLE_REVOKE_RETRY_HOURS).
 *  2. POST /v1/profile `ageSignal` → the invisible under-18 flag (`user_is_minor`, the rooms/safety read path), never
 *     returned; `under13` refused with nothing stored.
 *  3. The account-wide ban guard: `403 account_closed` everywhere but /v1/account*, GET /v1/safety*, /health.
 *  4. The retention job: audit chain intact, closed reports kept unless a retention is configured.
 */
import { generateKeyPairSync } from 'node:crypto';
import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { Logger, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { jwtVerify, SignJWT } from 'jose';
import type { Pool } from 'pg';
import request from 'supertest';
import { APPLE_REVOKE_RETRY_HOURS, PERSONAL_TABLES, purgeDueAccounts } from '../../src/account/account-purge';
import { AppleSignInClient } from '../../src/account/apple-sign-in';
import { AppleTokenVault, openAppleToken } from '../../src/account/apple-tokens';
import { PrivateMediaStore } from '../../src/account/private-media';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import { uuidv7 } from '../../src/common/uuid';
import { AppConfig } from '../../src/config/app-config';
import { runRetention } from '../../src/queues/retention';
import { auraDay, localDate } from '../../src/rules';
import { verifyAuditChain } from '../../src/safety/audit';
import { anyMinor } from '../../src/safety/safety.queries';
import { createUser, dbPool, deleteUser, type TestUser } from './support';

const TZ = 'Asia/Kolkata';
const BUNDLE = 'com.akvega.aura';
const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const APPLE_CONFIG = {
  teamId: 'AQLMTLP6PD',
  keyId: 'E2E0KEY001',
  privateKey: privateKey.export({ format: 'pem', type: 'pkcs8' }).toString(),
  clientId: BUNDLE,
};

/** Just enough of appleid.apple.com: single-use codes, refresh tokens, revoke; checks the client secret. */
class FakeApple {
  server!: Server;
  url = '';
  mode: 'ok' | 'down' = 'ok';
  codes = new Map<string, { sub: string; refresh: string }>();
  revoked: string[] = [];
  badSecrets = 0;

  async start(): Promise<void> {
    this.server = createServer((req, res) => {
      let raw = '';
      req.on('data', (c: Buffer) => (raw += c.toString('utf8')));
      req.on('end', () => void this.handle(req.url ?? '', new URLSearchParams(raw), res));
    });
    await new Promise<void>((resolve) => this.server.listen(0, '127.0.0.1', resolve));
    this.url = `http://127.0.0.1:${(this.server.address() as AddressInfo).port}`;
  }

  stop(): Promise<void> {
    return new Promise((resolve) => this.server.close(() => resolve()));
  }

  /** A fresh one-time code for an Apple user; returns [code, refresh token]. */
  issue(sub: string): [string, string] {
    const code = `code-${uuidv7()}`;
    const refresh = `rt-${uuidv7()}`;
    this.codes.set(code, { sub, refresh });
    return [code, refresh];
  }

  private async handle(path: string, form: URLSearchParams, res: import('node:http').ServerResponse): Promise<void> {
    const send = (status: number, body?: unknown) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(body === undefined ? '' : JSON.stringify(body));
    };
    if (this.mode === 'down') return send(503);
    try {
      const { payload } = await jwtVerify(form.get('client_secret') ?? '', publicKey, {
        issuer: APPLE_CONFIG.teamId,
        audience: 'https://appleid.apple.com',
        subject: form.get('client_id') ?? '',
      });
      if (!payload.exp || !payload.iat) throw new Error('no exp');
    } catch {
      this.badSecrets++;
      return send(400, { error: 'invalid_client' });
    }
    if (path === '/auth/token') {
      const grant = this.codes.get(form.get('code') ?? '');
      if (!grant || form.get('grant_type') !== 'authorization_code') return send(400, { error: 'invalid_grant' });
      this.codes.delete(form.get('code') ?? ''); // single use
      const idToken = await new SignJWT({})
        .setProtectedHeader({ alg: 'ES256', kid: 'fake-apple' })
        .setIssuer('https://appleid.apple.com')
        .setAudience(form.get('client_id') ?? '')
        .setSubject(grant.sub)
        .setIssuedAt()
        .setExpirationTime('10m')
        .sign(privateKey);
      return send(200, { access_token: 'at', token_type: 'Bearer', expires_in: 3600, refresh_token: grant.refresh, id_token: idToken });
    }
    if (path === '/auth/revoke') {
      if (form.get('token_type_hint') !== 'refresh_token') return send(400, { error: 'invalid_request' });
      this.revoked.push(form.get('token') ?? '');
      return send(200);
    }
    send(404);
  }
}

describe('account follow-ups (e2e, live local Supabase + Redis + fake Apple)', () => {
  let app: INestApplication;
  let db: Pool;
  let config: AppConfig;
  const apple = new FakeApple();
  const users: TestUser[] = [];

  const http = () => request(app.getHttpServer());
  const as = (u: TestUser, r: request.Test) => r.set('Authorization', `Bearer ${u.token}`);
  const newUser = async (label: string): Promise<TestUser> => {
    const u = await createUser(`fu-${label}`);
    users.push(u);
    return u;
  };
  const onboard = (u: TestUser, over: Record<string, unknown> = {}) =>
    as(u, http().post('/v1/profile')).send({ birthDate: '1996-04-17', uiLocale: 'en', timezone: TZ, country: 'IN', ...over });
  const count = async (table: string, userId: string): Promise<number> =>
    Number((await db.query(`select count(*) from public.${table} where user_id = $1`, [userId])).rows[0].count);
  const authUsers = async (userId: string): Promise<number> =>
    Number((await db.query('select count(*) from auth.users where id = $1', [userId])).rows[0].count);
  const isMinor = async (userId: string): Promise<boolean> =>
    (await db.query<{ m: boolean }>('select public.user_is_minor($1) as m', [userId])).rows[0].m;
  /** Links an Apple identity to the user, as GoTrue does after a native Sign in with Apple. */
  const linkIdentity = async (u: TestUser): Promise<string> => {
    const sub = `001${uuidv7().replace(/-/g, '').slice(0, 20)}.e2e`;
    await db.query(
      `insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
       values ($1, $2, jsonb_build_object('sub', $1::text, 'email', $3::text), 'apple', now(), now(), now())`,
      [sub, u.id, u.email],
    );
    return sub;
  };
  const appleAuth = (u: TestUser, body: unknown) => as(u, http().post('/v1/account/apple-auth')).send(body as object);
  const makeDue = (u: TestUser, ago = '1 hour') =>
    db.query(
      `update public.account_deletions
          set requested_at = now() - interval '8 days' - $2::interval, scheduled_for = now() - $2::interval
        where user_id = $1`,
      [u.id, ago],
    );
  const purge = () => purgeDueAccounts(db, app.get(PrivateMediaStore), 500, undefined, app.get(AppleTokenVault));
  const ban = (u: TestUser, over = '') =>
    db.query(
      `insert into public.sanctions (user_id, kind, reason_code, source, created_by${over ? ', starts_at, ends_at' : ''})
       values ($1, 'account_ban', 'e2e', 'moderator', 'staff:e2e'${over})`,
      [u.id],
    );

  beforeAll(async () => {
    await apple.start();
    Logger.overrideLogger(['error', 'warn']);
    const ref = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(AppleTokenVault)
      .useFactory({
        factory: (c: AppConfig) =>
          new AppleTokenVault(c.masterKey, new AppleSignInClient({ config: APPLE_CONFIG, baseUrl: apple.url, timeoutMs: 3_000 })),
        inject: [AppConfig],
      })
      .compile();
    app = ref.createNestApplication({ bodyParser: false });
    configureApp(app);
    await app.init();
    await app.listen(0, '127.0.0.1');
    config = app.get(AppConfig);
    db = dbPool();
  });

  afterAll(async () => {
    await Promise.all(users.map((u) => deleteUser(u.id)));
    await db?.end();
    await app?.close();
    await apple.stop();
  });

  beforeEach(() => {
    apple.mode = 'ok';
  });

  it('the new personal tables are in PERSONAL_TABLES (the purge removes them)', () => {
    expect(PERSONAL_TABLES).toEqual(expect.arrayContaining(['apple_auth_tokens', 'minor_signals']));
  });

  // ================================================================ 1. Sign in with Apple token
  describe('POST /v1/account/apple-auth', () => {
    it('exchanges the code and keeps the refresh token sealed (204), for this account’s Apple identity only', async () => {
      const u = await newUser('apple-link');
      const sub = await linkIdentity(u);
      const [code, refresh] = apple.issue(sub);
      const res = await appleAuth(u, { authorizationCode: code }).expect(204);
      expect(res.headers['cache-control']).toBe('no-store');
      const row = (await db.query('select client_id, wrapped_refresh_token from public.apple_auth_tokens where user_id = $1', [u.id])).rows[0];
      expect(row.client_id).toBe(BUNDLE);
      expect(row.wrapped_refresh_token).not.toContain(refresh);
      expect(openAppleToken(config.masterKey, u.id, row.wrapped_refresh_token)).toBe(refresh);
      expect(apple.badSecrets).toBe(0);

      // single-use code → 400 apple_code_rejected; the stored token is untouched
      expect((await appleAuth(u, { authorizationCode: code }).expect(400)).body.code).toBe('apple_code_rejected');
      // a newer sign-in replaces the token (never revoking the old one: that would end the new one too)
      const [code2, refresh2] = apple.issue(sub);
      await appleAuth(u, { authorizationCode: code2 }).expect(204);
      const row2 = (await db.query('select wrapped_refresh_token from public.apple_auth_tokens where user_id = $1', [u.id])).rows[0];
      expect(openAppleToken(config.masterKey, u.id, row2.wrapped_refresh_token)).toBe(refresh2);
      expect(apple.revoked).not.toContain(refresh);
    });

    it('another Apple account → 409 apple_identity_mismatch; bad body → 400; no token → 401; Apple down → 503', async () => {
      const u = await newUser('apple-mismatch');
      await linkIdentity(u);
      const [code] = apple.issue('someone-else.e2e');
      expect((await appleAuth(u, { authorizationCode: code }).expect(409)).body.code).toBe('apple_identity_mismatch');
      expect(await count('apple_auth_tokens', u.id)).toBe(0);
      expect((await appleAuth(u, { authorizationCode: '' }).expect(400)).body.code).toBe('invalid_request');
      expect((await appleAuth(u, [1]).expect(400)).body.code).toBe('invalid_request');
      await http().post('/v1/account/apple-auth').send({ authorizationCode: 'x' }).expect(401);
      apple.mode = 'down';
      const [code2] = apple.issue('whoever');
      expect((await appleAuth(u, { authorizationCode: code2 }).expect(503)).body.code).toBe('apple_unavailable');
    });

    it('requesting the deletion revokes the token at Apple straight away (best effort) and drops the row', async () => {
      const u = await newUser('apple-revoke-now');
      await onboard(u).expect(200);
      const [code, refresh] = apple.issue(await linkIdentity(u));
      await appleAuth(u, { authorizationCode: code }).expect(204);
      await as(u, http().post('/v1/account/deletion')).expect(202);
      expect(apple.revoked).toContain(refresh);
      expect(await count('apple_auth_tokens', u.id)).toBe(0);
    });

    it('Apple down at request time → the deletion still succeeds; the purge revokes, then deletes everything', async () => {
      const u = await newUser('apple-revoke-purge');
      await onboard(u, { ageSignal: 'under18' }).expect(200);
      const sub = await linkIdentity(u);
      const [code, refresh] = apple.issue(sub);
      await appleAuth(u, { authorizationCode: code }).expect(204);
      apple.mode = 'down';
      await as(u, http().post('/v1/account/deletion')).expect(202);
      expect(await count('apple_auth_tokens', u.id)).toBe(1);

      // still usable during the grace period (a new sign-in would store a new token)
      apple.mode = 'ok';
      const [code2, refresh2] = apple.issue(sub);
      await appleAuth(u, { authorizationCode: code2 }).expect(204);
      await makeDue(u);

      apple.mode = 'down';
      const deferred = await purge();
      expect(deferred.deferred).toBeGreaterThanOrEqual(1);
      expect(await count('profiles', u.id)).toBe(0); // personal rows go first…
      expect(await count('minor_signals', u.id)).toBe(0);
      expect(await count('apple_auth_tokens', u.id)).toBe(1); // …the token waits for Apple
      expect(await authUsers(u.id)).toBe(1);

      apple.mode = 'ok';
      const done = await purge();
      expect(done.failed).toBe(0);
      expect(done.appleRevoked).toBeGreaterThanOrEqual(1);
      expect(apple.revoked).toContain(refresh2);
      expect(apple.revoked).not.toContain(refresh); // replaced before: revoking any token ends the authorization
      expect(await count('apple_auth_tokens', u.id)).toBe(0);
      expect(await authUsers(u.id)).toBe(0);
    });

    it(`Apple unreachable for more than ${APPLE_REVOKE_RETRY_HOURS} h after the grace period → the token is dropped unrevoked and the purge finishes`, async () => {
      const u = await newUser('apple-abandon');
      const [code] = apple.issue(await linkIdentity(u));
      await appleAuth(u, { authorizationCode: code }).expect(204);
      apple.mode = 'down';
      await as(u, http().post('/v1/account/deletion')).expect(202);
      await makeDue(u, `${APPLE_REVOKE_RETRY_HOURS + 1} hours`);
      const s = await purge();
      expect(s.appleAbandoned).toBeGreaterThanOrEqual(1);
      expect(await count('apple_auth_tokens', u.id)).toBe(0);
      expect(await authUsers(u.id)).toBe(0);
    });

    it('a code sent once the purge owns the account → 409 account_deletion_in_progress, and that token is revoked at once', async () => {
      const u = await newUser('apple-too-late');
      const sub = await linkIdentity(u);
      await as(u, http().post('/v1/account/deletion')).expect(202);
      await makeDue(u);
      const [code, refresh] = apple.issue(sub);
      expect((await appleAuth(u, { authorizationCode: code }).expect(409)).body.code).toBe('account_deletion_in_progress');
      expect(apple.revoked).toContain(refresh);
      expect(await count('apple_auth_tokens', u.id)).toBe(0);
    });
  });

  // ================================================================ 2. age signals
  describe('POST /v1/profile ageSignal', () => {
    it('under18 with an adult DOB → minor for every server-side protection, never in any response', async () => {
      const plain = await newUser('signal-none');
      const plainRes = await onboard(plain).expect(200);
      const u = await newUser('signal-u18');
      const res = await onboard(u, { ageSignal: 'under18' }).expect(200);
      expect(Object.keys(res.body.profile).sort()).toEqual(Object.keys(plainRes.body.profile).sort());
      expect(JSON.stringify(res.body)).not.toMatch(/minor|signal|under/i);

      expect(await isMinor(u.id)).toBe(true);
      expect(await isMinor(plain.id)).toBe(false);
      expect(await anyMinor(db, [u.id])).toBe(true); // what reports / gestures read (minors lane, stricter moderation)
      const until = (await db.query<{ d: string }>('select minor_until::text as d from public.minor_signals where user_id = $1', [u.id])).rows[0].d;
      const expected = (await db.query<{ d: string }>(`select ($1::date + interval '5 years')::date::text as d`, [localDate(new Date(), TZ)])).rows[0].d;
      expect(until).toBe(expected); // the user's own date + 5 years (the youngest in the band turning 18)
      for (const path of ['/v1/me/snapshot', '/v1/account']) {
        expect(JSON.stringify((await as(u, http().get(path)).expect(200)).body)).not.toMatch(/minor|signal/i);
      }
    });

    it('only ever extends: a later under18 never shortens, adult / null / absent change nothing', async () => {
      const u = await newUser('signal-extend');
      await onboard(u, { ageSignal: 'under18' }).expect(200);
      await db.query(`update public.minor_signals set minor_until = current_date + interval '9 years' where user_id = $1`, [u.id]);
      const before = (await db.query('select minor_until::text as d from public.minor_signals where user_id = $1', [u.id])).rows[0].d;
      await onboard(u, { ageSignal: 'under18', uiLocale: 'te' }).expect(200);
      await onboard(u, { ageSignal: 'adult' }).expect(200);
      await onboard(u, { ageSignal: null }).expect(200);
      await onboard(u).expect(200);
      expect((await db.query('select minor_until::text as d from public.minor_signals where user_id = $1', [u.id])).rows[0].d).toBe(before);
      expect(await isMinor(u.id)).toBe(true);

      const a = await newUser('signal-adult');
      await onboard(a, { ageSignal: 'adult' }).expect(200);
      expect(await count('minor_signals', a.id)).toBe(0);
      expect(await isMinor(a.id)).toBe(false);
    });

    it('under13 → 403 under_13 whatever the DOB, and nothing is stored', async () => {
      const u = await newUser('signal-u13');
      const res = await onboard(u, { ageSignal: 'under13' }).expect(403);
      expect(res.body.code).toBe('under_13');
      expect(await count('profiles', u.id)).toBe(0);
      expect(await count('minor_signals', u.id)).toBe(0);
      expect(await count('avatar_state', u.id)).toBe(0);
    });

    it('invalid values → 400 invalid_request; a DOB-locked profile still records a new under-18 signal', async () => {
      const u = await newUser('signal-invalid');
      expect((await onboard(u, { ageSignal: 'child' }).expect(400)).body.code).toBe('invalid_request');
      await onboard(u).expect(200);
      expect((await onboard(u, { birthDate: '1990-01-01', ageSignal: 'under18' }).expect(409)).body.code).toBe('birth_date_locked');
      expect(await isMinor(u.id)).toBe(true);
    });
  });

  // ================================================================ 3. account-wide ban
  describe('account closed (active account_ban)', () => {
    const mutation = () => ({
      id: uuidv7(),
      entity: 'check_in',
      op: 'upsert',
      deviceTs: new Date().toISOString(),
      localDay: auraDay(new Date(), TZ),
      tz: TZ,
      payload: { id: uuidv7(), moodId: 'calm', tags: [], noteCt: null, source: 'app' },
    });

    it('every /v1 route but /v1/account* and GET /v1/safety* → 403 account_closed; lifting restores', async () => {
      const u = await newUser('closed');
      await onboard(u).expect(200);
      await as(u, http().get('/v1/account')).expect(200, { deletionScheduledFor: null });
      await ban(u);

      for (const call of [
        () => as(u, http().post('/v1/sync/push')).send({ deviceId: uuidv7(), mutations: [mutation()] }),
        () => onboard(u),
        () => as(u, http().get('/v1/me/snapshot')),
        () => as(u, http().get('/v1/keys/data-key')),
        () => as(u, http().put('/v1/devices')).send({ token: `e2e-fcm:${uuidv7()}`, platform: 'ios' }),
        () => as(u, http().post('/v1/media/upload-url')).send({ kind: 'voice', recordId: uuidv7(), bytes: 10 }),
        () => as(u, http().get('/v1/rooms')),
        () => as(u, http().post('/v1/rooms/match')).send({ quadrant: 'storm', moodId: 'anxious' }),
        () => as(u, http().post('/v1/safety/reports')).send({ target: { kind: 'room', roomId: uuidv7() }, reason: 8 }),
      ]) {
        const res = await call().expect(403);
        expect(res.body).toEqual({ code: 'account_closed', message: "This account was closed for breaking Aura's rules." });
      }
      expect(await count('check_ins', u.id)).toBe(0);
      await http().get('/health').expect(200);

      const status = await as(u, http().get('/v1/account')).expect(200);
      expect(status.body).toEqual({ deletionScheduledFor: null, accountClosed: true });
      expect((await as(u, http().get('/v1/safety/me')).expect(200)).body.rooms).toBe('closed');
      await as(u, http().get('/v1/safety/reports')).expect(200);
      await as(u, http().get('/v1/safety/blocks')).expect(200);

      // A closed account can still delete itself (and a pending deletion answers first everywhere else)…
      await as(u, http().post('/v1/account/deletion')).expect(202);
      expect((await as(u, http().get('/v1/me/snapshot')).expect(403)).body.code).toBe('account_deletion_pending');
      const both = (await as(u, http().get('/v1/account')).expect(200)).body;
      expect(both).toEqual({ deletionScheduledFor: expect.any(String), accountClosed: true });
      // …or keep it, which leaves it closed.
      await as(u, http().delete('/v1/account/deletion')).expect(200);
      expect((await as(u, http().get('/v1/me/snapshot')).expect(403)).body.code).toBe('account_closed');

      await db.query(`update public.sanctions set lifted_at = now() where user_id = $1 and kind = 'account_ban'`, [u.id]);
      await as(u, http().get('/v1/me/snapshot')).expect(200);
      expect((await as(u, http().post('/v1/sync/push')).send({ deviceId: uuidv7(), mutations: [mutation()] }).expect(200)).body.results[0].status).toBe(
        'applied',
      );
      await as(u, http().get('/v1/account')).expect(200, { deletionScheduledFor: null });
    });

    it('only an active account_ban closes the account (expired, future, or room-only sanctions do not)', async () => {
      const u = await newUser('closed-windows');
      await onboard(u).expect(200);
      await ban(u, `, now() - interval '2 days', now() - interval '1 day'`); // over
      await ban(u, `, now() + interval '1 day', null`); // not started
      await db.query(
        `insert into public.sanctions (user_id, kind, reason_code, source) values ($1, 'social_ban', 'e2e', 'moderator'), ($1, 'room_suspension', 'e2e', 'moderator')`,
        [u.id],
      );
      await as(u, http().get('/v1/me/snapshot')).expect(200);
      expect((await as(u, http().get('/v1/rooms')).expect(403)).body.code).toBe('rooms_suspended');
      await as(u, http().get('/v1/account')).expect(200, { deletionScheduledFor: null });
    });
  });

  // ================================================================ 4. retention
  describe('retention job', () => {
    it('keeps the audit chain verifiable and never deletes audit rows inside the 3-year retention', async () => {
      const before = Number((await db.query('select count(*) from public.moderation_actions')).rows[0].count);
      const r = await runRetention(db);
      expect(r.auditPruned).toBe(0); // everything in a dev database is younger than 3 years
      expect(Number((await db.query('select count(*) from public.moderation_actions')).rows[0].count)).toBeGreaterThanOrEqual(before);
      expect(await verifyAuditChain(db)).toBe(true);
      await expect(db.query('delete from public.moderation_actions where id = (select min(id) from public.moderation_actions)')).rejects.toMatchObject({
        code: 'AR010',
      });
    });

    it('closed reports are kept by default; with a retention set, only closed reports resolved that long ago go', async () => {
      const cfg = (await db.query('select closed_report_retention_days as d from public.safety_config')).rows[0];
      expect(cfg.d).toBeNull();
      const report = async (status: string, resolvedDaysAgo: number | null): Promise<string> =>
        (
          await db.query<{ id: string }>(
            `insert into public.reports (reason, lane, target_kind, target_ref, sla_due_at, status, resolved_at, created_at)
             values (8, 'spam', 'room', gen_random_uuid(), now(), $1,
                     case when $2::int is null then null else now() - make_interval(days => $2::int) end,
                     now() - interval '500 days')
             returning id`,
            [status, resolvedDaysAgo],
          )
        ).rows[0].id;
      const oldClosed = await report('dismissed', 45);
      const recentClosed = await report('actioned', 5);
      const open = await report('open', null);
      const exists = async (id: string) => (await db.query('select 1 from public.reports where id = $1', [id])).rowCount === 1;
      try {
        await expect(runRetention(db)).resolves.toMatchObject({ reportsPruned: 0, closedReportRetentionDays: null });
        expect(await exists(oldClosed)).toBe(true);

        await db.query('update public.safety_config set closed_report_retention_days = 30');
        const r = await runRetention(db);
        expect(r.closedReportRetentionDays).toBe(30);
        expect(r.reportsPruned).toBeGreaterThanOrEqual(1);
        expect(await exists(oldClosed)).toBe(false);
        expect(await exists(recentClosed)).toBe(true);
        expect(await exists(open)).toBe(true);
      } finally {
        await db.query('update public.safety_config set closed_report_retention_days = null');
        await db.query('delete from public.reports where id = any($1::uuid[])', [[oldClosed, recentClosed, open]]);
      }
    });
  });
});
