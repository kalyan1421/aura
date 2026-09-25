/**
 * App Review sign-in end to end (docs/setup/app-review.md): the real Nest app against the live local Supabase Auth,
 * Postgres and Redis. With REVIEW_ACCOUNT_EMAIL / REVIEW_ACCOUNT_CODE unset the route is 404; set, only the configured
 * account with the configured code gets a real GoTrue session (it authenticates against the API and refreshes with
 * GoTrue), every other combination is the same generic 401, attempts are limited per client address, and each use is
 * in the hash-chained audit log as a subject hash only.
 */
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { AppConfig } from '../../src/config/app-config';
import { QueuesService } from '../../src/queues/queues.service';
import { subjectHash } from '../../src/safety/audit';
import { SUPABASE_URL, bootApp, createUser, dbPool, deleteUser, localAnonKey, type TestUser } from './support';

jest.setTimeout(60_000);

const CODE = '739150';

describe('POST /v1/auth/review-sign-in (e2e)', () => {
  let app: INestApplication;
  let db: Pool;
  let reviewer: TestUser;
  const saved: Record<string, string | undefined> = {};
  const http = () => request(app.getHttpServer());
  const post = (body: unknown) => http().post('/v1/auth/review-sign-in').send(body as object);

  const resetLimit = async (): Promise<void> => {
    const redis = app.get(QueuesService).redis;
    const keys = await redis.keys('aura:rl:review-sign-in:*');
    if (keys.length) await redis.del(...keys);
  };
  const configure = (email: string | undefined, code: string | undefined): void => {
    if (email === undefined) delete process.env.REVIEW_ACCOUNT_EMAIL;
    else process.env.REVIEW_ACCOUNT_EMAIL = email;
    if (code === undefined) delete process.env.REVIEW_ACCOUNT_CODE;
    else process.env.REVIEW_ACCOUNT_CODE = code;
  };

  beforeAll(async () => {
    for (const k of ['REVIEW_ACCOUNT_EMAIL', 'REVIEW_ACCOUNT_CODE']) saved[k] = process.env[k];
    app = await bootApp();
    db = dbPool();
    reviewer = await createUser('review');
    await resetLimit();
  });

  afterAll(async () => {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    if (app) await resetLimit();
    if (reviewer) await deleteUser(reviewer.id);
    await db?.end();
    await app?.close();
  });

  beforeEach(resetLimit);

  it('env unset (either one) → 404, whatever is sent', async () => {
    configure(undefined, undefined);
    expect((await post({ email: reviewer.email, code: CODE }).expect(404)).body.code).toBe('not_found');
    configure(reviewer.email, undefined);
    await post({ email: reviewer.email, code: CODE }).expect(404);
    configure(undefined, CODE);
    await post({ email: reviewer.email, code: CODE }).expect(404);
  });

  it('the configured email (any case) + code → a real session for that account, audited without secrets', async () => {
    configure(reviewer.email.toUpperCase(), CODE);
    const r = await post({ email: ` ${reviewer.email.toUpperCase()} `, code: CODE }).expect(200);
    expect(r.headers['cache-control']).toBe('no-store');
    expect(r.body).toMatchObject({ token_type: 'bearer' });
    expect(typeof r.body.access_token).toBe('string');
    expect(typeof r.body.refresh_token).toBe('string');
    expect(r.body.expires_in).toBeGreaterThan(0);
    expect(Object.keys(r.body).sort()).toEqual(['access_token', 'expires_in', 'refresh_token', 'token_type']);

    // It is that account's session: the API accepts it and sees the same user.
    const ent = await http().get('/v1/billing/entitlement').set('Authorization', `Bearer ${r.body.access_token}`).expect(200);
    expect(ent.body.accountToken).toBeDefined();
    const me = await fetch(`${SUPABASE_URL}/auth/v1/user`, { headers: { apikey: localAnonKey(), Authorization: `Bearer ${r.body.access_token}` } });
    expect(((await me.json()) as { id: string }).id).toBe(reviewer.id);
    // The refresh token works with GoTrue (what the app's setSession does).
    const refreshed = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: { apikey: localAnonKey(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: r.body.refresh_token }),
    });
    expect(refreshed.status).toBe(200);

    const hash = subjectHash(app.get(AppConfig).masterKey, reviewer.id);
    const audit = await db.query<{ actor: string; detail: unknown }>(
      `select actor, detail from public.moderation_actions where action = 'review_sign_in' and subject_hash = $1 order by id desc limit 1`,
      [hash],
    );
    expect(audit.rows).toEqual([{ actor: 'system', detail: {} }]);
    const row = JSON.stringify(audit.rows[0]);
    expect(row).not.toContain(CODE);
    expect(row).not.toContain(reviewer.email);
  });

  it('wrong code, another email, a malformed body → the same generic 401 (no hint which part was wrong)', async () => {
    configure(reviewer.email, CODE);
    const bodies = [
      { email: reviewer.email, code: '000000' },
      { email: 'someone-else@aura.test', code: CODE },
      { email: 'someone-else@aura.test', code: '123456' },
      { email: 42 },
    ];
    const answers = [];
    for (const b of bodies) {
      const r = await post(b).expect(401);
      answers.push(r.body);
    }
    expect(new Set(answers.map((a) => JSON.stringify(a))).size).toBe(1);
    expect(answers[0]).toEqual({ code: 'invalid_code', message: "That code didn't work." });
  });

  it('5 attempts per client address per hour, then 429 — even with the right code', async () => {
    configure(reviewer.email, CODE);
    for (let i = 0; i < 5; i++) await post({ email: reviewer.email, code: '111111' }).expect(401);
    expect((await post({ email: reviewer.email, code: CODE }).expect(429)).body.code).toBe('rate_limited');
  });
});
