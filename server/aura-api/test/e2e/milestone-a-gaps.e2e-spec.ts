/**
 * Milestone A gaps, end to end against the live local stack (NestJS app, Postgres with migration 20261005000019,
 * Supabase Auth with real TOTP staff, Redis, Mailpit):
 *
 *  1. The helpline directory as a signed bundle: Moderator reads, Owner stores / publishes / rolls back; an invalid
 *     directory and a publish that drops numbers phones show are refused; `GET /v1/config` points at it; the envelope
 *     `GET /v1/helplines` serves verifies with the dev key and carries the vectors the app re-derives; audit rows.
 *  2. "Tell me when they open": the sync entity `room_pool_waitlist`, the sweep (once per opt-in, deleted rows, no push
 *     for a scheduled deletion or a closed account, nothing twice) and the delivered push (content-free, te-Latn copy,
 *     the `rooms` channel). The pool's flag is stubbed on the sweep and the delivery instead of flipped in the shared
 *     database, so parallel suites (rooms) never see the Hindi pool open.
 *  3. Localized emails: the grievance acknowledgement in the account's app language (Telugu) and the deletion link in
 *     Tenglish, the link untouched.
 */
import { createHmac, randomBytes } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { uuidv7 } from '../../src/common/uuid';
import { NotificationDelivery } from '../../src/notifications/delivery.service';
import { NotificationDispatcher } from '../../src/notifications/notification-dispatcher';
import { NOTIFICATION_JOB, type DeviceTarget, type PushMessage } from '../../src/notifications/notification-types';
import { PoolOpenSweep } from '../../src/notifications/pool-waitlist';
import { QueuesService } from '../../src/queues/queues.service';
import { HelplinesService } from '../../src/remote-config/helplines.service';
import { baselineHelplines, resolutionVectors } from '../../src/remote-config/helplines/document';
import { RemoteConfigService } from '../../src/remote-config/remote-config.service';
import { BundleSigner, canonicalJson, trustedKeys, verifyBundle } from '../../src/remote-config/signing';
import { localDate } from '../../src/rules';
import { SUPABASE_URL, bootApp, createUser, dbPool, deleteUser, localAnonKey, type TestUser } from './support';

jest.setTimeout(90_000);

const DEV_KEYS = trustedKeys([BundleSigner.dev().publicKeyBase64]);
const MAILPIT = process.env.MAILPIT_URL ?? 'http://127.0.0.1:55524';
const SMTP = process.env.E2E_SMTP_URL ?? 'smtp://127.0.0.1:55525';
const OFFICER_EMAIL = 'grievance-gaps-e2e@aura.test';
const TZ = 'Asia/Kolkata';

function base32Decode(s: string): Buffer {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const c of s.replace(/=+$/, '').toUpperCase()) {
    const i = alphabet.indexOf(c);
    if (i < 0) continue;
    value = (value << 5) | i;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

function totp(secret: string, at = Date.now()): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(at / 30_000)));
  const h = createHmac('sha1', base32Decode(secret)).update(counter).digest();
  const o = h[h.length - 1] & 0xf;
  return String((h.readUInt32BE(o) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function mailTo(address: string, subjectHas: string, timeoutMs = 10_000): Promise<{ id: string; subject: string; text: string }> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const r = await fetch(`${MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:"${address}"`)}`);
    const list = ((await r.json()) as { messages?: Array<{ ID: string; Subject: string }> }).messages ?? [];
    const m = list.find((x) => x.Subject.includes(subjectHas));
    if (m) {
      const full = (await (await fetch(`${MAILPIT}/api/v1/message/${m.ID}`)).json()) as { Text: string; Subject: string };
      return { id: m.ID, subject: full.Subject, text: full.Text };
    }
    if (Date.now() > end) throw new Error(`mailpit: no message to ${address} with "${subjectHas}"`);
    await sleep(150);
  }
}

class FakeTransport {
  readonly name = 'e2e-fake';
  sent: Array<{ target: DeviceTarget; message: PushMessage }> = [];
  async send(target: DeviceTarget, message: PushMessage): Promise<'sent'> {
    this.sent.push({ target, message });
    return 'sent';
  }
}

describe('Milestone A gaps (e2e): helpline bundle, pool-open push, localized emails', () => {
  let app: INestApplication;
  let db: Pool;
  let owner: TestUser;
  let moderator: TestUser;
  const users: TestUser[] = [];
  const savedEnv: Record<string, string | undefined> = {};
  const mailIds: string[] = [];
  const grievanceEmails: string[] = [];
  const deletionCaseIds: string[] = [];
  let savedLive: { version: number } | null = null;
  let storedBefore: number[] = [];
  const transport = new FakeTransport();

  const http = () => request(app.getHttpServer());
  const as = (u: { token: string }, r: request.Test): request.Test => r.set('Authorization', `Bearer ${u.token}`);
  const refresh = (): void => {
    app.get(RemoteConfigService).invalidate();
    (app.get(HelplinesService) as unknown as { cached: unknown }).cached = null;
  };

  async function gotrue(path: string, token: string, body?: unknown): Promise<Record<string, unknown>> {
    const res = await fetch(`${SUPABASE_URL}/auth/v1${path}`, {
      method: 'POST',
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`gotrue ${path}: ${res.status} ${text}`);
    return text ? (JSON.parse(text) as Record<string, unknown>) : {};
  }

  async function staff(label: string, role: 'owner' | 'moderator'): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    await db.query('insert into public.admin_staff (staff_id, role, display_name) values ($1, $2, $3)', [u.id, role, `E2E ${label}`]);
    const factor = await gotrue('/factors', u.token, { factor_type: 'totp', friendly_name: `e2e-${randomBytes(3).toString('hex')}` });
    const secret = (factor.totp as { secret: string }).secret;
    const challenge = await gotrue(`/factors/${factor.id as string}/challenge`, u.token);
    const verified = await gotrue(`/factors/${factor.id as string}/verify`, u.token, { challenge_id: challenge.id, code: totp(secret) });
    return { ...u, token: verified.access_token as string };
  }

  async function appUser(label: string, uiLocale: string): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    await as(u, http().post('/v1/profile')).send({ birthDate: '1996-03-14', uiLocale, timezone: TZ, country: 'IN' }).expect(200);
    return u;
  }

  beforeAll(async () => {
    const env: Record<string, string> = {
      ADMIN_ALLOWED_EMAILS: '',
      LEXICON_SIGNING_KEY: '',
      REMOTE_CONFIG_CACHE_MS: '0',
      SMTP_URL: SMTP,
      MAIL_FROM: 'Aura e2e <no-reply@aura.test>',
      GRIEVANCE_OFFICER_EMAIL: OFFICER_EMAIL,
      GRIEVANCE_OFFICER_NAME: 'AK (Grievance Officer, gaps e2e)',
      GRIEVANCE_RATE_PER_IP_HOUR: '1000',
      GRIEVANCE_RATE_GLOBAL_HOUR: '1000',
      PUBLIC_API_URL: 'http://127.0.0.1:3310',
    };
    for (const [k, v] of Object.entries(env)) {
      savedEnv[k] = process.env[k];
      process.env[k] = v;
    }
    app = await bootApp();
    (app.get(NotificationDelivery) as unknown as { transport: unknown }).transport = transport;
    db = dbPool();
    savedLive = (await db.query<{ version: number }>(`select version from public.signed_bundle_current where kind = 'helplines'`)).rows[0] ?? null;
    storedBefore = (await db.query<{ version: number }>(`select version from public.signed_bundle_versions where kind = 'helplines'`)).rows.map((r) => r.version);
    owner = await staff('gaps-owner', 'owner');
    moderator = await staff('gaps-mod', 'moderator');
  });

  afterAll(async () => {
    if (db) {
      // The live directory back the way it was, then this run's versions (only non-live ones can go).
      const live = (await db.query<{ version: number }>(`select version from public.signed_bundle_current where kind = 'helplines'`)).rows[0];
      if (savedLive && live?.version !== savedLive.version) {
        await app.get(HelplinesService).publish('staff:e2e-cleanup', { version: savedLive.version, reasonCode: 'e2e_cleanup', allowRemovals: true });
      } else if (!savedLive) {
        await db.query(`delete from public.signed_bundle_current where kind = 'helplines'`);
      }
      await db.query(`delete from public.signed_bundle_versions where kind = 'helplines' and not (version = any($1::int[]))
                        and version <> coalesce((select version from public.signed_bundle_current where kind = 'helplines'), -1)`, [storedBefore]);
      if (grievanceEmails.length) await db.query('delete from public.admin_grievances where complainant_email = any($1::text[])', [grievanceEmails]);
      if (deletionCaseIds.length) await db.query('delete from public.admin_deletion_cases where id = any($1::uuid[])', [deletionCaseIds]);
      const q = app.get(QueuesService).queue('notifications');
      for (const j of await q.getJobs(['waiting', 'prioritized', 'delayed'])) {
        if (users.some((u) => u.id === j.data?.userId)) await j.remove().catch(() => undefined);
      }
    }
    await Promise.all(users.map((u) => deleteUser(u.id)));
    if (db) await db.end();
    if (app) await app.close();
    for (const [k, v] of Object.entries(savedEnv)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    if (mailIds.length) {
      await fetch(`${MAILPIT}/api/v1/messages`, { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ IDs: mailIds }) }).catch(
        () => undefined,
      );
    }
  });

  // ================================================================== 1. helpline directory
  describe('signed helpline directory', () => {
    let next: number;

    const newest = async (): Promise<number> =>
      (await db.query<{ v: number | null }>(`select max(version) as v from public.signed_bundle_versions where kind = 'helplines'`)).rows[0].v ?? 0;

    it('a Moderator reads it and cannot change it; the Owner stores the bundled directory', async () => {
      expect((await as(moderator, http().get('/admin/helplines'))).status).toBe(200);
      expect((await as(moderator, http().post('/admin/helplines/versions')).send({ helplines: baselineHelplines() })).status).toBe(403);
      expect((await as(moderator, http().post('/admin/helplines/publish')).send({ version: 1, reasonCode: 'x' })).status).toBe(403);
      const have = await as(owner, http().get('/admin/helplines')).expect(200);
      expect(have.body).toMatchObject({ kind: 'helplines', bundledVersion: 1, requiredCountries: ['IN', 'US'] });
      if (!have.body.versions.some((v: { version: number }) => v.version === 1)) {
        const r = await as(owner, http().post('/admin/helplines/versions/baseline')).expect(201);
        expect(r.body).toMatchObject({ version: 1, lines: 5 });
      }
    });

    it('refuses a directory against the contract (shown ≠ dialled, a bundled region dropped)', async () => {
      next = (await newest()) + 1;
      const bad = baselineHelplines();
      bad.version = next;
      bad.countries.IN[0].dial = '14417';
      delete (bad.countries as Record<string, unknown>).US;
      const r = await as(owner, http().post('/admin/helplines/versions')).send({ helplines: bad }).expect(422);
      expect(r.body.code).toBe('helplines_invalid');
      expect(r.body.details.join('\n')).toMatch(/digits of number must be exactly dial/);
      expect(r.body.details.join('\n')).toMatch(/US: every region the app bundles/);
    });

    it('stores a changed number, refuses to publish it without "allow removals", then publishes it signed', async () => {
      const doc = baselineHelplines();
      doc.version = next;
      doc.verifiedOn = '2026-09-24';
      doc.countries.US[0].number = '1-988';
      doc.countries.US[0].dial = '1988';
      const stored = await as(owner, http().post('/admin/helplines/versions')).send({ helplines: doc, note: 'e2e' }).expect(201);
      expect(stored.body.diff).toMatchObject({ changed: ['us.988'] });

      const refused = await as(owner, http().post('/admin/helplines/publish')).send({ version: next, reasonCode: 'e2e_publish' }).expect(409);
      expect(refused.body.code).toBe('helplines_removed');

      const pub = await as(owner, http().post('/admin/helplines/publish')).send({ version: next, reasonCode: 'e2e_publish', allowRemovals: true }).expect(200);
      expect(pub.body).toMatchObject({ version: next, action: 'helplines_publish', keyId: 'ba9afcf9c1f7ab25' });
      refresh();

      const config = await http().get('/v1/config').expect(200);
      expect(config.body.bundles.helplines).toEqual({ version: next, seq: pub.body.seq });
      const got = await http().get('/v1/helplines').expect(200);
      const payload = verifyBundle(got.body, DEV_KEYS, 'helplines');
      expect(payload).toMatchObject({ kind: 'helplines', version: next, seq: pub.body.seq });
      expect((payload.content as typeof doc).countries.US[0].dial).toBe('1988');
      expect(canonicalJson(payload.vectors)).toBe(canonicalJson(resolutionVectors(doc)));
      await http().get('/v1/helplines').set('If-None-Match', got.headers.etag).expect(304);
      expect(() => verifyBundle(got.body, DEV_KEYS, 'crisis_lexicon')).toThrow(/wrong_kind/);
    });

    it('rolls back to the bundled directory: a new signature with a higher seq, audited', async () => {
      const before = (await http().get('/v1/config').expect(200)).body.bundles.helplines.seq as number;
      const r = await as(owner, http().post('/admin/helplines/publish')).send({ version: 1, reasonCode: 'e2e_rollback', allowRemovals: true }).expect(200);
      expect(r.body).toMatchObject({ version: 1, previousVersion: next, action: 'helplines_rollback' });
      expect(r.body.seq).toBeGreaterThan(before);
      refresh();
      const payload = verifyBundle((await http().get('/v1/helplines').expect(200)).body, DEV_KEYS, 'helplines');
      expect(payload.content).toEqual(baselineHelplines());
      const audit = await db.query<{ action: string; reason_code: string }>(
        `select action, reason_code from public.moderation_actions where detail ->> 'kind' = 'helplines' and actor = $1 order by id`,
        [`staff:${owner.id}`],
      );
      expect(audit.rows.map((a) => a.action)).toEqual(expect.arrayContaining(['helplines_upload', 'helplines_publish', 'helplines_rollback']));
    });
  });

  // ================================================================== 2. "Tell me when they open"
  describe('"Tell me when they open" (room_pool_waitlist → rooms_pool_open)', () => {
    let waiting: TestUser;
    let deleting: TestUser;
    let closed: TestUser;
    const token = `e2e-fcm-${randomBytes(12).toString('hex')}`;
    const DEVICE = uuidv7();

    const tap = (u: TestUser, payload: Record<string, unknown> = { pool: 'hi' }, op = 'upsert') => {
      const now = new Date();
      return as(u, http().post('/v1/sync/push'))
        .send({
          deviceId: DEVICE,
          mutations: [{ id: uuidv7(), entity: 'room_pool_waitlist', op, deviceTs: now.toISOString(), localDay: localDate(now, TZ), tz: TZ, payload }],
        })
        .expect(200);
    };
    const rows = async (u: TestUser) =>
      (await db.query('select pool from public.room_pool_waitlist where user_id = $1', [u.id])).rows as Array<{ pool: string }>;
    const queued = async (u: TestUser) =>
      (await app.get(QueuesService).queue('notifications').getJobs(['waiting', 'prioritized', 'delayed'])).filter((j) => j.data?.userId === u.id);
    const sweep = (open: boolean) => {
      const s = app.get(PoolOpenSweep);
      jest.spyOn(s as unknown as { flagOn: () => Promise<boolean> }, 'flagOn').mockResolvedValue(open);
      return s.sweep();
    };

    beforeAll(async () => {
      waiting = await appUser('pool-wait', 'te-Latn');
      deleting = await appUser('pool-deleting', 'en');
      closed = await appUser('pool-closed', 'en');
      await as(waiting, http().put('/v1/devices')).send({ token, platform: 'android' }).expect(204);
    });

    it('the tap is recorded once through the sync push; a wrong pool is rejected', async () => {
      expect((await tap(waiting)).body.results[0].status).toBe('applied');
      expect((await tap(waiting)).body.results[0].status).toBe('applied');
      expect(await rows(waiting)).toEqual([{ pool: 'hi' }]);
      expect((await tap(waiting, { pool: 'te' })).body.results[0]).toMatchObject({ status: 'rejected', reason: 'invalid_payload' });
      for (const u of [deleting, closed]) await tap(u);
      await db.query(`insert into public.account_deletions (user_id, scheduled_for) values ($1, now() + interval '7 days')`, [deleting.id]);
      await db.query(`insert into public.sanctions (user_id, kind, reason_code, source) values ($1, 'account_ban', 'e2e', 'moderator')`, [closed.id]);
    });

    it('while the pool is closed nothing is sent and the opt-ins wait', async () => {
      await sweep(false);
      expect(await rows(waiting)).toHaveLength(1);
      expect(await queued(waiting)).toHaveLength(0);
    });

    it('once open: one push for the account that waited, none for a scheduled deletion or a closed account, opt-ins gone', async () => {
      await sweep(true);
      for (const u of [waiting, deleting, closed]) expect(await rows(u)).toEqual([]);
      const jobs = await queued(waiting);
      expect(jobs).toHaveLength(1);
      expect(jobs[0].data).toEqual({ userId: waiting.id, type: 'rooms_pool_open', id: null });
      expect(await queued(deleting)).toHaveLength(0);
      expect(await queued(closed)).toHaveLength(0);

      // Sweeping again, or the flag going off and on, sends nothing more.
      await sweep(true);
      await sweep(false);
      await sweep(true);
      expect(await queued(waiting)).toHaveLength(1);

      // The worker delivers it: content-free, the person's language, the "Rooms & Lantern Hour" channel.
      const delivery = app.get(NotificationDelivery);
      jest.spyOn(delivery as unknown as { flagOn: () => Promise<boolean> }, 'flagOn').mockResolvedValue(true);
      const noon = new Date(`${localDate(new Date(), TZ)}T06:30:00Z`); // 12:00 IST, outside quiet hours
      await app.get(NotificationDispatcher).handle({ name: NOTIFICATION_JOB, data: jobs[0].data, timestamp: noon.getTime() } as never, undefined, noon);
      const mine = transport.sent.filter((s) => s.target.token === token).map((s) => s.message);
      expect(mine).toEqual([
        expect.objectContaining({ type: 'rooms_pool_open', id: null, body: 'Hindi, Hinglish rooms ippudu modalayyaayi.', channelId: 'rooms' }),
      ]);
      await jobs[0].remove().catch(() => undefined);
    });
  });

  // ================================================================== 3. localized emails
  describe('localized emails', () => {
    it('the grievance acknowledgement comes in the account’s app language (Telugu)', async () => {
      const u = await appUser('mail-te', 'te');
      grievanceEmails.push(u.email);
      const r = await http()
        .post('/v1/grievances')
        .send({ category: 'general', email: u.email, description: 'Someone kept sending the same gesture.', channel: 'web_form' })
        .expect(201);
      const ack = await mailTo(u.email, r.body.ticket);
      mailIds.push(ack.id);
      expect(ack.subject).toBe(`Aura: మీ ఫిర్యాదు ${r.body.ticket} మాకు అందింది`);
      expect(ack.text).toContain('నమస్కారం,');
      expect(ack.text).toContain(OFFICER_EMAIL);
      expect(ack.text).not.toContain('same gesture');
      const notice = await mailTo(OFFICER_EMAIL, r.body.ticket);
      mailIds.push(notice.id);
    });

    it('no account for the address: the grievance’s own language, else English', async () => {
      const email = `e2e-gaps-noacct-${randomBytes(4).toString('hex')}@aura.test`;
      grievanceEmails.push(email);
      const r = await http().post('/v1/grievances').send({ category: 'general', email, description: 'A complaint in Tenglish.', locale: 'te-Latn' }).expect(201);
      const ack = await mailTo(email, r.body.ticket);
      mailIds.push(ack.id);
      expect(ack.subject).toContain('maaku andindi');
    });

    it('the deletion link comes in the account’s language (Tenglish); the link carries only the token', async () => {
      const holder = await appUser('mail-del', 'te-Latn');
      const r = await as(owner, http().post('/admin/deletion-cases'))
        .send({ email: holder.email, channel: 'email', receivedAt: new Date(Date.now() - 60_000).toISOString() })
        .expect(201);
      deletionCaseIds.push(r.body.caseId);
      expect(r.body.linkEmailed).toBe(true);
      const mail = await mailTo(holder.email, r.body.ticket);
      mailIds.push(mail.id);
      expect(mail.subject).toBe(`Aura: mee account delete request ni confirm cheyandi (${r.body.ticket})`);
      const urls = mail.text.match(/https?:\/\/\S+/g) ?? [];
      expect(urls).toHaveLength(1);
      expect(urls[0]).toMatch(/\/v1\/deletion-requests\/[A-Za-z0-9_-]{43}$/);
      expect(urls[0]).not.toContain(holder.email.split('@')[0]);
    });
  });
});
