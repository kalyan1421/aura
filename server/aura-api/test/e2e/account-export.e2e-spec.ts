/**
 * F8 REQ-ACC-12 data export — the server half (`GET /v1/account/export`, contracts/api/v1.md "Data export") against the
 * live local stack: the person's own server-held records, nothing about anyone else, no moderation detail, and it keeps
 * working during a deletion grace period and on a closed account (like deletion itself). Uses its own users only; no
 * global row is changed.
 */
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { uuidv7 } from '../../src/common/uuid';
import { bootApp, createUser, dbPool, deleteUser, type TestUser } from './support';

jest.setTimeout(60_000);

const DOB = '1999-02-14';

describe('Data export (e2e, REQ-ACC-12)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  let u: TestUser;

  const http = () => request(app.getHttpServer());
  const as = (user: TestUser) => ({
    get: (path: string) => http().get(path).set('Authorization', `Bearer ${user.token}`),
    post: (path: string, body: unknown) => http().post(path).set('Authorization', `Bearer ${user.token}`).send(body as object),
    put: (path: string, body: unknown) => http().put(path).set('Authorization', `Bearer ${user.token}`).send(body as object),
  });

  beforeAll(async () => {
    app = await bootApp();
    db = dbPool();
    u = await createUser('export');
    users.push(u);
    await as(u).post('/v1/profile', { birthDate: DOB, uiLocale: 'te-Latn', timezone: 'Asia/Kolkata', country: 'IN' }).expect(200);
    await as(u).post('/v1/safety/guidelines/accept', { version: 1 }).expect(200);
    await as(u).put('/v1/safety/corpus-consent', { enabled: false }).expect(200);
    // A content-free Sanctuary record (the only write path is the sync push).
    const now = new Date();
    const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit' }).format(
      new Date(now.getTime() - 4 * 3600_000),
    );
    const push = await as(u)
      .post('/v1/sync/push', {
        deviceId: uuidv7(),
        mutations: [
          {
            id: uuidv7(),
            entity: 'sanctuary_session',
            op: 'upsert',
            deviceTs: now.toISOString(),
            localDay: today,
            tz: 'Asia/Kolkata',
            payload: { id: uuidv7(), activity: 'breathe', variant: 'calm', durationS: 75 },
          },
        ],
      })
      .expect(200);
    expect(push.body.results[0].status).toBe('applied');
  });

  afterAll(async () => {
    for (const x of users) await deleteUser(x.id);
    await db.end();
    await app.close();
  });

  it('401 without a token', async () => {
    await http().get('/v1/account/export').expect(401);
  });

  it('the person’s own server-held records, no-store', async () => {
    const r = await as(u).get('/v1/account/export').expect(200);
    expect(r.headers['cache-control']).toBe('no-store');
    expect(r.body).toMatchObject({
      format: 'aura.export.server.v1',
      profile: { birthDate: DOB, uiLocale: 'te-Latn', languagePool: 'te', timezone: 'Asia/Kolkata', country: 'IN' },
      progress: { glowStreak: 0, longestGlowStreak: 0, lifetimeGlowDays: 0, restBank: 1 },
      purchases: [],
      subscriptions: [],
      stardust: { balance: 0, entries: [] },
      guidelinesAccepted: [expect.objectContaining({ version: 1 })],
      consents: [expect.objectContaining({ purpose: 'moderation_corpus', withdrawnAt: expect.any(String) })],
      reflections: [],
    });
    expect(r.body.sanctuarySessions).toEqual([expect.objectContaining({ activity: 'breathe', variant: 'calm', durationS: 75 })]);
  });

  it('never an id, token, email or moderation detail', async () => {
    const r = await as(u).get('/v1/account/export').expect(200);
    const text = JSON.stringify(r.body);
    expect(text).not.toContain(u.id);
    expect(text).not.toContain(u.email);
    for (const key of ['userId', 'user_id', 'memberId', 'roomId', 'reportId', 'accountToken', 'account_token', 'storeRef', 'store_ref', 'lane', 'strike', 'sanction', 'installId']) {
      expect(text).not.toContain(`"${key}"`);
    }
  });

  it('works during a deletion grace period and on a closed account (like deletion)', async () => {
    const v = await createUser('export-closed');
    users.push(v);
    await as(v).post('/v1/profile', { birthDate: DOB, uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' }).expect(200);
    await as(v).post('/v1/account/deletion', {}).expect(202);
    await as(v).get('/v1/account/export').expect(200);
    await http().delete('/v1/account/deletion').set('Authorization', `Bearer ${v.token}`).send({}).expect(200);
    await db.query(`insert into public.sanctions (user_id, kind, reason_code, source, created_by) values ($1, 'account_ban', 'e2e_export', 'moderator', 'e2e')`, [v.id]);
    const r = await as(v).get('/v1/account/export').expect(200);
    expect(r.body.profile.birthDate).toBe(DOB);
  });
});
