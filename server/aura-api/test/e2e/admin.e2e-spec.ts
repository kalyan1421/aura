/**
 * Admin console v0, end to end against the live local stack: NestJS app, Postgres (migration 20261005000013), Supabase
 * Auth with REAL TOTP enrolment (AAL2 tokens issued by GoTrue), Redis, Mailpit (SMTP :55525, API :55524) and a local
 * HTTP receiver standing in for the paging webhook (ntfy / Slack / PagerDuty).
 *
 * Covers: staff auth boundary (allowlist, AAL2, app accounts refused, sign-out revokes, REQ-ADM-02), report → queue →
 * ban (minors & grooming SOP) → evidence retained past the room purge → mandatory-report checklist, export and record;
 * grievance form → ticket + acknowledgement email in Mailpit → resolve with the appeal route; legal order → page on the
 * webhook + email → escalation at 5 min → acknowledge stops the repeats ("A test takedown order pages AK"); machine
 * intake; audit chain; and a scan that no console response carries DOBs, app emails or raw app account ids.
 * Needs `supabase start` with TOTP MFA enabled and Mailpit SMTP on 55525 (supabase/config.toml), Redis on 6391.
 */
import { createHash, createHmac, randomBytes, randomUUID } from 'node:crypto';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import http from 'node:http';
import type { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { purgeAccount } from '../../src/account/account-purge';
import { PrivateMediaStore } from '../../src/account/private-media';
import { PagingService } from '../../src/admin/paging/paging.service';
import { QueuesService } from '../../src/queues/queues.service';
import { runRoomLifecycle } from '../../src/rooms/room-lifecycle';
import { purgeExpiredEvidence } from '../../src/safety/evidence';
import { ReportsService } from '../../src/safety/reports.service';
import { SUPABASE_URL, bootApp, createUser, dbPool, deleteUser, localAnonKey, localServiceKey, type TestUser } from './support';

jest.setTimeout(90_000);

const MAILPIT = process.env.MAILPIT_URL ?? 'http://127.0.0.1:55524';
const SMTP = process.env.E2E_SMTP_URL ?? 'smtp://127.0.0.1:55525';
const ADULT_DOB = '1994-07-21';
const MINOR_DOB = `${new Date().getUTCFullYear() - 16}-03-09`;
const RUN = randomBytes(3).toString('hex');
const OFFICER_EMAIL = `e2e-grievance-officer-${RUN}@aura.test`;
const ONCALL_EMAIL = `e2e-oncall-${RUN}@aura.test`;
const WEBHOOK_TOKEN = `e2e-webhook-${RUN}`;
const INTAKE_TOKEN = `e2e-intake-${randomBytes(24).toString('hex')}`;
const ARCHIVE_EMAIL = `e2e-audit-archive-${RUN}@aura.test`;
const SSO_DOMAIN = 'aura.test';
const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, ms));

// ------------------------------------------------------------------ helpers: TOTP (RFC 6238), webhook receiver, Mailpit
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

interface Hit {
  path: string;
  auth: string | undefined;
  body: string;
  json: Record<string, unknown> | null;
}

class Receiver {
  readonly hits: Hit[] = [];
  private server = http.createServer((req, res) => {
    let body = '';
    req.on('data', (c: Buffer) => (body += c.toString('utf8')));
    req.on('end', () => {
      let json: Record<string, unknown> | null = null;
      try {
        json = JSON.parse(body) as Record<string, unknown>;
      } catch {
        json = null;
      }
      this.hits.push({ path: req.url ?? '', auth: req.headers.authorization, body, json });
      res.writeHead(200, { 'Content-Type': 'text/plain' }).end('ok');
    });
  });

  async start(): Promise<number> {
    await new Promise<void>((r) => this.server.listen(0, '127.0.0.1', () => r()));
    return (this.server.address() as AddressInfo).port;
  }

  async waitFor(pred: (h: Hit) => boolean, timeoutMs = 10_000): Promise<Hit> {
    const end = Date.now() + timeoutMs;
    for (;;) {
      const h = this.hits.find(pred);
      if (h) return h;
      if (Date.now() > end) throw new Error('webhook receiver: nothing matched in time');
      await sleep(100);
    }
  }

  close(): Promise<void> {
    return new Promise((r) => this.server.close(() => r()));
  }
}

interface MailSummary {
  ID: string;
  Subject: string;
  To: Array<{ Address: string }>;
}

async function mailTo(address: string, subjectHas: string, timeoutMs = 10_000): Promise<{ id: string; subject: string; text: string }> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const r = await fetch(`${MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:"${address}"`)}`);
    const list = ((await r.json()) as { messages?: MailSummary[] }).messages ?? [];
    const m = list.find((x) => x.Subject.includes(subjectHas));
    if (m) {
      const full = (await (await fetch(`${MAILPIT}/api/v1/message/${m.ID}`)).json()) as { Text: string; Subject: string };
      return { id: m.ID, subject: full.Subject, text: full.Text };
    }
    if (Date.now() > end) throw new Error(`mailpit: no message to ${address} with "${subjectHas}"`);
    await sleep(150);
  }
}

// ------------------------------------------------------------------ suite
describe('Admin console v0 (e2e, live Supabase Auth + TOTP, Postgres, Redis, Mailpit, webhook)', () => {
  let app: INestApplication;
  let db: Pool;
  let paging: PagingService;
  const receiver = new Receiver();
  const users: TestUser[] = [];
  const staffIds = new Set<string>();
  const mailIds: string[] = [];
  const recorded: Array<{ where: string; body: unknown }> = [];
  const savedEnv: Record<string, string | undefined> = {};
  let savedMatching: Record<string, unknown> | undefined;
  let suiteStart: Date | undefined;
  const legalOrderIds: string[] = [];
  const testPageIds: string[] = [];
  const grievanceEmails: string[] = [];
  const deletionCaseIds: string[] = [];
  let exportDir = '';

  type Staff = TestUser & { aal1: string };
  let owner: Staff;
  let moderator: Staff;

  const http_ = () => request(app.getHttpServer());

  async function adm(u: { token: string }, method: 'get' | 'post', path: string, body?: unknown, record = true): Promise<request.Response> {
    let r = http_()[method](path).set('Authorization', `Bearer ${u.token}`);
    if (body !== undefined) r = r.send(body as object);
    const res = await r;
    if (record) recorded.push({ where: `${method.toUpperCase()} ${path} → ${res.status}`, body: res.body });
    return res;
  }

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

  /** Real Supabase MFA: enroll TOTP, challenge, verify → an AAL2 access token for the same session. */
  async function enrollTotp(aal1: string): Promise<string> {
    const factor = await gotrue('/factors', aal1, { factor_type: 'totp', friendly_name: `e2e-${randomBytes(3).toString('hex')}` });
    const secret = (factor.totp as { secret: string }).secret;
    const challenge = await gotrue(`/factors/${factor.id as string}/challenge`, aal1);
    const verified = await gotrue(`/factors/${factor.id as string}/verify`, aal1, { challenge_id: challenge.id, code: totp(secret) });
    return verified.access_token as string;
  }

  async function staff(label: string, role: 'owner' | 'moderator' | 'analyst', mfa = true): Promise<Staff> {
    const u = await createUser(label);
    users.push(u);
    staffIds.add(u.id);
    await db.query('insert into public.admin_staff (staff_id, role, display_name) values ($1, $2, $3)', [u.id, role, `E2E ${label}`]);
    return { ...u, aal1: u.token, token: mfa ? await enrollTotp(u.token) : u.token };
  }

  async function appUser(label: string, dob = ADULT_DOB): Promise<TestUser> {
    const u = await createUser(label);
    users.push(u);
    await http_()
      .post('/v1/profile')
      .set('Authorization', `Bearer ${u.token}`)
      .send({ birthDate: dob, uiLocale: 'en', timezone: 'Europe/Berlin', country: 'IN' })
      .expect(200);
    // Rooms need the current community guidelines accepted (REQ-SAFE-04).
    await http_()
      .post('/v1/safety/guidelines/accept')
      .set('Authorization', `Bearer ${u.token}`)
      .send({ version: 1 })
      .expect(200);
    return u;
  }

  const freshRooms = () =>
    db.query(
      `delete from public.rooms r where not exists (
         select 1 from public.room_members m join auth.users u on u.id = m.user_id
          where m.room_id = r.id and coalesce(u.email, '') not like 'e2e-%@aura.test')`,
    );

  async function clearRateLimits(): Promise<void> {
    const redis = app.get(QueuesService).redis;
    const keys = await redis.keys('aura:rl:grievance:*');
    const intake = await redis.keys('aura:rl:legal-intake:*');
    const deletion = await redis.keys('aura:rl:deletion-link:*'); // 30 link requests per client per hour: repeated runs
    if (keys.length + intake.length + deletion.length) await redis.del(...keys, ...intake, ...deletion);
  }

  beforeAll(async () => {
    const port = await receiver.start();
    exportDir = await mkdtemp(join(tmpdir(), 'aura-e2e-audit-export-'));
    const env: Record<string, string> = {
      ADMIN_AUDIT_EXPORT_DIR: exportDir,
      ADMIN_AUDIT_EXPORT_EMAIL: ARCHIVE_EMAIL,
      ADMIN_SSO_PROVIDER: '',
      ADMIN_SSO_ALLOWED_DOMAINS: '',
      ADMIN_ALLOW_EMAIL_LOGIN: '',
      PUBLIC_API_URL: 'http://127.0.0.1:3310',
      SMTP_URL: SMTP,
      MAIL_FROM: 'Aura e2e <no-reply@aura.test>',
      GRIEVANCE_OFFICER_EMAIL: OFFICER_EMAIL,
      GRIEVANCE_OFFICER_NAME: 'AK (Grievance Officer, e2e)',
      GRIEVANCE_RATE_PER_IP_HOUR: '4',
      PAGING_WEBHOOK_URL: `http://127.0.0.1:${port}/page`,
      PAGING_WEBHOOK_FORMAT: 'json',
      PAGING_WEBHOOK_TOKEN: WEBHOOK_TOKEN,
      PAGING_ESCALATION_WEBHOOK_URL: `http://127.0.0.1:${port}/call`,
      PAGING_ESCALATION_WEBHOOK_FORMAT: 'json',
      PAGING_EMAIL_TO: ONCALL_EMAIL,
      PAGING_RETRY_DELAYS_MS: '0,50',
      LEGAL_INTAKE_TOKEN: INTAKE_TOKEN,
      ADMIN_CONSOLE_URL: 'http://localhost:3320',
      ADMIN_ALLOWED_EMAILS: '',
    };
    for (const [k, v] of Object.entries(env)) {
      savedEnv[k] = process.env[k];
      process.env[k] = v;
    }
    app = await bootApp();
    db = dbPool();
    suiteStart = (await db.query<{ now: Date }>('select now()')).rows[0].now;
    paging = app.get(PagingService);
    paging.wait = async () => undefined;
    await clearRateLimits();
    savedMatching = (await db.query('select * from public.matching_config where id')).rows[0];
    await db.query(`update public.matching_config set thin_join_threshold = 0, partition_live_min = 1, adjacent_live_min = 48 where id`);
    owner = await staff('adm-owner', 'owner');
    moderator = await staff('adm-mod', 'moderator');
  });

  afterAll(async () => {
    await paging?.idle().catch(() => undefined);
    if (db) {
      if (savedMatching) {
        const keys = Object.keys(savedMatching).filter((k) => k !== 'id');
        await db.query(`update public.matching_config set ${keys.map((k, i) => `${k} = $${i + 1}`).join(', ')} where id`, keys.map((k) => savedMatching?.[k]));
      }
      const ids = users.map((u) => u.id);
      const mine = `select id from public.reports where reporter_user_id = any($1::uuid[]) or target_user_id = any($1::uuid[])`;
      await db.query(`delete from public.admin_pages where kind = 'report' and ref_id in (${mine})`, [ids]);
      await db.query(`delete from public.evidence_holds where report_id in (${mine}) or account_ids && $1::uuid[]`, [ids]);
      await db.query(`delete from public.reports where id in (${mine})`, [ids]);
      const gids = (await db.query<{ id: string }>('select id from public.admin_grievances where complainant_email = any($1::text[])', [grievanceEmails])).rows.map((r) => r.id);
      await db.query(`delete from public.admin_pages where ref_id = any($1::uuid[])`, [[...gids, ...legalOrderIds]]);
      await db.query('delete from public.admin_grievances where id = any($1::uuid[])', [gids]);
      await db.query('delete from public.admin_legal_orders where id = any($1::uuid[])', [legalOrderIds]);
      await db.query('delete from public.admin_pages where id = any($1::uuid[])', [testPageIds]);
      await db.query('delete from public.admin_deletion_cases where id = any($1::uuid[])', [deletionCaseIds]);
      // The sweep is global: it may also have paged other suites' open reports during this run. Only admin code raises
      // pages, so every report page created in this window is this suite's doing.
      if (suiteStart) await db.query(`delete from public.admin_pages where kind = 'report' and created_at >= $1`, [suiteStart]);
    }
    await Promise.all(users.map((u) => deleteUser(u.id)));
    if (db) {
      await freshRooms();
      await db.end();
    }
    if (app) {
      await clearRateLimits().catch(() => undefined);
      await app.close();
    }
    for (const [k, v] of Object.entries(savedEnv)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    await receiver.close();
    if (exportDir) await rm(exportDir, { recursive: true, force: true });
    if (mailIds.length) {
      await fetch(`${MAILPIT}/api/v1/messages`, { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ IDs: mailIds }) }).catch(
        () => undefined,
      );
    }
  });

  // ================================================================== staff authentication (REQ-ADM-01 / 02)
  describe('staff authentication', () => {
    it('no token → 401; an app account (even with a valid session) → 403 not_staff', async () => {
      expect((await http_().get('/admin/queue')).status).toBe(401);
      const stranger = await appUser('adm-stranger');
      const r = await adm(stranger, 'get', '/admin/queue');
      expect(r.status).toBe(403);
      expect(r.body.code).toBe('not_staff');
      expect((await adm(stranger, 'get', '/admin/session')).body.code).toBe('not_staff');
    });

    it('an allow-listed account without TOTP (AAL1) only reaches the sign-in preflight', async () => {
      const fresh = await staff('adm-fresh', 'owner', false);
      expect((await adm({ token: fresh.aal1 }, 'get', '/admin/queue')).body.code).toBe('mfa_required');
      expect((await adm({ token: fresh.aal1 }, 'get', '/admin/session')).body).toMatchObject({ mfa: 'enroll', staff: { role: 'owner' } });
      // After enrolling, the old AAL1 token is still refused; the AAL2 one works.
      const aal2 = await enrollTotp(fresh.aal1);
      expect((await adm({ token: fresh.aal1 }, 'get', '/admin/queue')).body.code).toBe('mfa_required');
      expect((await adm({ token: fresh.aal1 }, 'get', '/admin/session')).body.mfa).toBe('challenge');
      expect((await adm({ token: aal2 }, 'get', '/admin/session')).body).toMatchObject({ mfa: 'verified', staff: { role: 'owner' } });
    });

    it('staff accounts must not be app accounts', async () => {
      const both = await staff('adm-both', 'moderator');
      await http_()
        .post('/v1/profile')
        .set('Authorization', `Bearer ${both.token}`)
        .send({ birthDate: ADULT_DOB, uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' })
        .expect(200);
      expect((await adm(both, 'get', '/admin/queue')).body.code).toBe('staff_account_is_app_account');
    });

    it('a staff account can be deleted through Supabase Auth (the allowlist row goes, the removal is audited)', async () => {
      const temp = await staff('adm-temp', 'analyst', false);
      const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${temp.id}`, {
        method: 'DELETE',
        headers: { apikey: localServiceKey(), Authorization: `Bearer ${localServiceKey()}` },
      });
      expect(res.status).toBe(200);
      expect((await db.query('select count(*)::int as n from public.admin_staff where staff_id = $1', [temp.id])).rows[0].n).toBe(0);
      const audit = await db.query(`select actor from public.moderation_actions where action = 'staff_removed' and detail->>'staffId' = $1`, [temp.id]);
      expect(audit.rows).toEqual([{ actor: 'db:supabase_auth_admin' }]);
    });

    it('login is audited once per session', async () => {
      await adm(owner, 'post', '/admin/session/started').then((r) => expect(r.status).toBe(204));
      await adm(owner, 'post', '/admin/session/started').then((r) => expect(r.status).toBe(204));
      const n = await db.query(`select count(*)::int as n from public.moderation_actions where action = 'staff_login' and actor = $1`, [`staff:${owner.id}`]);
      expect(n.rows[0].n).toBe(1);
    });

    it('REQ-ADM-02: a Moderator calling POST /admin/devices/{id}/ban gets 403 and the attempt is audited', async () => {
      const r = await adm(moderator, 'post', `/admin/devices/${randomUUID()}/ban`);
      expect(r.status).toBe(403);
      expect(r.body.code).toBe('forbidden_role');
      const row = await db.query(
        `select reason_code, detail from public.moderation_actions where actor = $1 and action = 'access_denied' order by id desc limit 1`,
        [`staff:${moderator.id}`],
      );
      expect(row.rows[0]).toMatchObject({ reason_code: 'forbidden_role', detail: { route: 'POST /admin/devices/:deviceId/ban', role: 'moderator' } });
      // The Owner passes the role gate (the route itself lives in src/devices, REQ-ADM-14).
      expect((await adm(owner, 'post', `/admin/devices/${randomUUID()}/ban`)).status).not.toBe(403);
      for (const path of ['/admin/grievances', '/admin/legal-orders', '/admin/audit', '/admin/config', '/admin/pages', '/admin/mandatory-reports']) {
        expect((await adm(moderator, 'get', path)).status).toBe(403);
      }
    });
  });

  // ================================================================== report → queue → ban → evidence retained
  describe('minors & grooming: report → queue → instant ban → evidence retained → mandatory report', () => {
    let subject: TestUser;
    let kid: TestUser;
    let adult: TestUser;
    let roomId: string;
    let subjectMember: string;
    let kidPseudonym: string;
    let minorsReport: string;
    let harassmentReport: string;
    let holdId: string;

    beforeAll(async () => {
      await freshRooms();
      subject = await appUser('adm-subject');
      kid = await appUser('adm-kid', MINOR_DOB);
      adult = await appUser('adm-adult');
      const match = (u: TestUser) =>
        http_().post('/v1/rooms/match').set('Authorization', `Bearer ${u.token}`).send({ quadrant: 'rain', moodId: 'lonely', timezone: 'Europe/Berlin' });
      const s = await match(subject);
      expect(s.status).toBe(200);
      roomId = s.body.room.roomId;
      subjectMember = s.body.me.memberId;
      const k = await match(kid);
      const a = await match(adult);
      expect([k.body.room.roomId, a.body.room.roomId]).toEqual([roomId, roomId]);
      kidPseudonym = k.body.me.pseudonym;
      const report = (u: TestUser, reason: number) =>
        http_()
          .post('/v1/safety/reports')
          .set('Authorization', `Bearer ${u.token}`)
          .send({ target: { kind: 'member', roomId, memberId: subjectMember }, reason, note: 'asked which school I go to' });
      minorsReport = (await report(kid, 5)).body.reportId; // contact info, a minor involved → L1, 2 h, pages
      harassmentReport = (await report(adult, 2)).body.reportId; // adults only → L2
      expect(minorsReport).toEqual(expect.any(String));
      expect(harassmentReport).toEqual(expect.any(String));
    });

    it('queue: lane then oldest, SLA timer, "Under 18" flag, subject as an HMAC; the minors item pages the Owner', async () => {
      const q = await adm(owner, 'get', '/admin/queue?limit=500');
      expect(q.status).toBe(200);
      const ids = q.body.items.map((x: { reportId: string }) => x.reportId);
      expect(ids.indexOf(minorsReport)).toBeLessThan(ids.indexOf(harassmentReport));
      const item = q.body.items.find((x: { reportId: string }) => x.reportId === minorsReport);
      expect(item).toMatchObject({ lane: 'minors_grooming', involvesMinor: true, pages: true, subject: { hash: expect.stringMatching(/^[0-9a-f]{64}$/) } });
      // 2 h clock (the safety module stamps the due time from the API clock, created_at from the DB clock)
      expect(Math.abs(Date.parse(item.slaDueAt) - Date.parse(item.createdAt) - 2 * 3_600_000)).toBeLessThan(5_000);
      expect(q.body.lanes.map((l: { lane: string }) => l.lane)).toEqual(['crisis', 'minors_grooming', 'harassment', 'spam']);

      const work = await adm(owner, 'get', '/admin/work');
      const order = work.body.items.map((x: { id: string }) => x.id);
      expect(order.indexOf(minorsReport)).toBeLessThan(order.indexOf(harassmentReport));

      // The worker's sweep raises the 24×7 page; the payload says lane + minor flag, never content.
      await paging.sweep();
      await paging.runDue();
      const page = await receiver.waitFor((h) => h.path === '/page' && h.json?.kind === 'report' && h.json?.lane === 'minors_grooming');
      expect(page.auth).toBe(`Bearer ${WEBHOOK_TOKEN}`);
      expect(page.json).toMatchObject({ event: 'aura.page', minorInvolved: true, reason: 'minors_urgent' });
      expect(page.body).not.toContain('school');
      expect(page.body).not.toContain(subject.id);
    });

    it('item view: evidence with pseudonyms and hashes; the reporter is never identified; no DOB anywhere', async () => {
      const r = await adm(owner, 'get', `/admin/reports/${minorsReport}`);
      expect(r.status).toBe(200);
      expect(r.body.report).toMatchObject({ lane: 'minors_grooming', reasonKey: 'contact_info', note: 'asked which school I go to', reporters: { count: 2 } });
      expect(r.body.report.reporters.reasons.sort()).toEqual(['contact_info', 'harassment']);
      expect(r.body.subject).toMatchObject({ under18: false, activeStrikes: 0, accountAgeDays: 0, hash: expect.stringMatching(/^[0-9a-f]{64}$/) });
      expect(r.body.room).toMatchObject({ roomId, quadrant: 'rain', languagePool: 'en', tzRegion: 'europe_africa' });
      expect(r.body.evidence.people).toEqual(expect.arrayContaining([expect.objectContaining({ role: 'subject', subjectHash: r.body.subject.hash })]));
      expect(r.body.allowedActions).toContain('ban');
      const blob = JSON.stringify(r.body);
      expect(blob).not.toContain(kidPseudonym);
      expect(blob).not.toContain(kid.id);
      expect(blob).not.toContain(subject.id);
      expect((await adm(moderator, 'get', `/admin/reports/${minorsReport}`)).body.allowedActions).not.toContain('ban');
    });

    it('a Moderator cannot ban (403, audited); the Owner bans in one action: account + devices closed, 180-day hold, SOP task', async () => {
      // Two installs the subject used (src/devices records them; seeded here as their HMACs).
      const installs = [randomBytes(32).toString('hex'), randomBytes(32).toString('hex')];
      for (const h of installs) {
        await db.query(`insert into public.device_installs (user_id, install_hash, platform) values ($1, $2, 'android')`, [subject.id, h]);
      }
      const denied = await adm(moderator, 'post', `/admin/reports/${minorsReport}/actions`, { action: 'ban', reasonCode: 'grooming' });
      expect(denied.status).toBe(403);
      expect((await db.query('select 1 from public.device_bans where install_hash = any($1::text[])', [installs])).rowCount).toBe(0);
      const ban = await adm(owner, 'post', `/admin/reports/${minorsReport}/actions`, { action: 'ban', reasonCode: 'grooming' });
      expect(ban.status).toBe(200);
      expect(ban.body).toMatchObject({
        status: 'actioned',
        sanctionId: expect.any(String),
        mandatoryReport: { evidenceHoldId: expect.any(String) },
        devices: { devices: 2, newlyBanned: 2, snapshotted: true },
      });
      holdId = ban.body.mandatoryReport.evidenceHoldId;

      // REQ-ADM-14: the devices are banned in the same action, audited with the Owner, and the evidence snapshot keeps
      // their HMACs (never an install id, never the account id).
      const bans = await db.query<{ install_hash: string; report_id: string; created_by: string; reason_code: string }>(
        'select install_hash, report_id, created_by, reason_code from public.device_bans where install_hash = any($1::text[]) and lifted_at is null',
        [installs],
      );
      expect(bans.rows).toHaveLength(2);
      expect(bans.rows.every((b) => b.report_id === minorsReport && b.created_by === `staff:${owner.id}` && b.reason_code === 'grooming')).toBe(true);
      const snap = await db.query<{ d: { installHashes: string[]; at: string } }>(`select snapshot -> 'devicesAtBan' as d from public.evidence_holds where id = $1`, [holdId]);
      expect(snap.rows[0].d.installHashes.sort()).toEqual([...installs].sort());
      expect(JSON.stringify(snap.rows[0].d)).not.toContain(subject.id);
      const deviceAudit = await db.query(`select actor, detail from public.moderation_actions where report_id = $1 and action = 'device_ban'`, [minorsReport]);
      expect(deviceAudit.rows).toEqual([{ actor: `staff:${owner.id}`, detail: { scope: 'account', devices: 2, newlyBanned: 2 } }]);

      const closed = await http_().get('/v1/rooms').set('Authorization', `Bearer ${subject.token}`);
      expect(closed.status).toBe(403);
      expect(closed.body.code).toBe('account_closed');
      const hold = await db.query<{ days: number; mandatory: boolean }>(
        `select round(extract(epoch from (hold_until - now())) / 86400)::int as days, mandatory_report_required as mandatory
           from public.evidence_holds where id = $1`,
        [holdId],
      );
      expect(hold.rows[0].mandatory).toBe(true);
      expect(hold.rows[0].days).toBeGreaterThanOrEqual(179);
      const audit = await db.query(`select actor, reason_code from public.moderation_actions where report_id = $1 and action = 'ban'`, [minorsReport]);
      expect(audit.rows).toEqual([{ actor: `staff:${owner.id}`, reason_code: 'grooming' }]);
      const page = await db.query(`select status from public.admin_pages where kind = 'report' and ref_id = $1`, [minorsReport]);
      expect(page.rows[0].status).toBe('resolved'); // the item is closed: no more repeats
    });

    it('evidence survives the room purge (24 h + 7 d) and stays reviewable', async () => {
      await db.query(
        `update public.rooms set created_at = now() - interval '8 days 2 hours', opened_at = now() - interval '8 days 1 hour',
                joins_close_at = now() - interval '7 days 6 hours', memory_at = now() - interval '7 days 2 hours',
                purge_at = now() - interval '1 minute' where id = $1`,
        [roomId],
      );
      const s = await runRoomLifecycle(db);
      expect(s.errors).toEqual([]);
      expect((await db.query('select count(*)::int as n from public.rooms where id = $1', [roomId])).rows[0].n).toBe(0);
      const r = await adm(owner, 'get', `/admin/reports/${minorsReport}`);
      expect(r.body.room).toBeNull();
      expect(r.body.evidence).toMatchObject({ evidenceHoldId: holdId, mandatoryReportRequired: true, room: { quadrant: 'rain' } });
      expect(r.body.evidence.people.find((p: { role: string }) => p.role === 'subject')).toBeTruthy();
    });

    it('mandatory-report checklist, break-glass export (audited, reporter withheld) and record', async () => {
      const list = await adm(owner, 'get', '/admin/mandatory-reports');
      const task = list.body.items.find((x: { evidenceHoldId: string }) => x.evidenceHoldId === holdId);
      expect(task.checklist).toMatchObject({
        evidence_preserved: { done: true, auto: true },
        account_banned: { done: true, auto: true },
        bundle_exported: { done: false },
        counsel_consulted: { done: false, auto: false },
      });
      expect((await adm(owner, 'post', `/admin/mandatory-reports/${holdId}/checklist`, { item: 'counsel_consulted', done: true })).status).toBe(204);

      const exp = await adm(owner, 'post', `/admin/evidence/${holdId}/export`, { purpose: 'mandatory_report' }, false);
      expect(exp.status).toBe(200);
      expect(exp.headers['content-disposition']).toContain(`aura-evidence-${holdId}.json`);
      expect(exp.body.integrity.canonicalJsonSha256).toMatch(/^[0-9a-f]{64}$/);
      const bundle = JSON.stringify(exp.body);
      expect(bundle).toContain(subject.id); // identifiers leave only through this audited step
      expect(bundle).not.toContain(kid.id);
      expect(bundle).not.toContain(kidPseudonym);
      const audited = await db.query(`select reason_code, detail->>'sha256' as sha from public.moderation_actions where action = 'evidence_export' and report_id = $1`, [
        minorsReport,
      ]);
      expect(audited.rows).toEqual([{ reason_code: 'mandatory_report', sha: exp.body.integrity.canonicalJsonSha256 }]);
      expect((await adm(moderator, 'post', `/admin/evidence/${holdId}/export`, { purpose: 'mandatory_report' }, false)).status).toBe(403);

      const after = (await adm(owner, 'get', '/admin/mandatory-reports')).body.items.find((x: { evidenceHoldId: string }) => x.evidenceHoldId === holdId);
      expect(after.checklist).toMatchObject({ bundle_exported: { done: true }, counsel_consulted: { done: true } });
      expect((await adm(owner, 'post', `/admin/mandatory-reports/${holdId}/record`, { reportedTo: 'NCRP (drill)', reportRef: `E2E-${RUN}` })).status).toBe(204);
      const pending = (await adm(owner, 'get', '/admin/mandatory-reports')).body.items.map((x: { evidenceHoldId: string }) => x.evidenceHoldId);
      expect(pending).not.toContain(holdId);
    });

    it('unban is Owner-only', async () => {
      const bans = await adm(owner, 'get', '/admin/sanctions?active=true');
      const ban = bans.body.sanctions.find((s: { reportId: string; kind: string }) => s.reportId === minorsReport && s.kind === 'account_ban');
      expect(ban).toBeTruthy();
      expect((await adm(moderator, 'post', `/admin/sanctions/${ban.sanctionId}/lift`, { reasonCode: 'appeal_upheld' })).status).toBe(403);
      expect((await adm(owner, 'post', `/admin/sanctions/${ban.sanctionId}/lift`, { reasonCode: 'appeal_upheld' })).status).toBe(204);
      expect((await http_().get('/v1/rooms').set('Authorization', `Bearer ${subject.token}`)).status).toBe(200);
    });

    it('the Moderator works the harassment report (strike → warning notice), audited with the staff actor', async () => {
      const r = await adm(moderator, 'post', `/admin/reports/${harassmentReport}/actions`, { action: 'strike', reasonCode: 'harassment' });
      expect(r.status).toBe(200);
      expect(r.body).toMatchObject({ status: 'actioned', activeStrikes: 1 });
      const again = await adm(moderator, 'post', `/admin/reports/${harassmentReport}/actions`, { action: 'dismiss', reasonCode: 'no_violation' });
      expect(again.status).toBe(409);
      expect(again.body.code).toBe('report_closed');
      const row = await db.query(`select actor from public.moderation_actions where report_id = $1 and action = 'strike'`, [harassmentReport]);
      expect(row.rows[0].actor).toBe(`staff:${moderator.id}`);
    });
  });

  // ================================================================== grievances
  describe('grievance form → ticket + acknowledgement email; inbox; resolve with the appeal route', () => {
    const complainant = `e2e-complainant-${RUN}@aura.test`;
    let ticket: string;
    let grievanceId: string;

    beforeAll(() => {
      grievanceEmails.push(complainant, `e2e-ncii-${RUN}@aura.test`, `e2e-limit-${RUN}@aura.test`);
    });

    it('the officer contact and timelines are public', async () => {
      const r = await http_().get('/v1/grievances/officer').expect(200);
      expect(r.body.officer).toEqual({ name: 'AK (Grievance Officer, e2e)', email: OFFICER_EMAIL, address: null });
      expect(r.body.timelines).toMatchObject({ acknowledgeWithinHours: 24, resolveWithinHours: { general: 168, unlawful_content: 36, nudity_csam: 2, ncii: 2 } });
    });

    it('POST /v1/grievances (no login) → 201 ticket; the acknowledgement lands in Mailpit; the officer gets a content-free notice', async () => {
      const r = await http_()
        .post('/v1/grievances')
        .send({ category: 'general', email: complainant, name: 'Asha', description: 'Someone in a room kept sending the same gesture to me.', channel: 'in_app' })
        .expect(201);
      expect(r.body.ticket).toMatch(/^GRV-[0-9A-HJKMNP-TV-Z]{8}$/);
      expect(Date.parse(r.body.resolveBy) - Date.parse(r.body.receivedAt)).toBe(7 * 24 * 3_600_000);
      expect(r.body.appeal).toContain('Grievance Appellate Committee');
      ticket = r.body.ticket;

      const ack = await mailTo(complainant, ticket);
      mailIds.push(ack.id);
      expect(ack.subject).toContain('we received your grievance');
      expect(ack.text).toContain('This email acknowledges your grievance');
      expect(ack.text).toContain(OFFICER_EMAIL);
      expect(ack.text).not.toContain('same gesture'); // never quotes the complaint back
      const notice = await mailTo(OFFICER_EMAIL, ticket);
      mailIds.push(notice.id);
      expect(notice.text).not.toContain('same gesture');
      expect(notice.text).not.toContain(complainant);
    });

    it('validation and the honeypot; rate-limited per client', async () => {
      await http_().post('/v1/grievances').send({ category: 'gossip', email: complainant, description: 'x'.repeat(20) }).expect(400);
      await http_().post('/v1/grievances').send({ category: 'general', email: complainant, description: 'x'.repeat(20), website: 'spam.example' }).expect(400);
      // 4 accepted per client per hour in this suite (invalid requests don't count): #1 above, then #2–#4 here, then 429
      await http_().post('/v1/grievances').send({ category: 'data_request', email: `e2e-limit-${RUN}@aura.test`, description: 'Please delete my data.' }).expect(201);
      const ncii = await http_().post('/v1/grievances').send({ category: 'ncii', email: `e2e-ncii-${RUN}@aura.test`, description: 'My photo is being shared.' }).expect(201);
      await http_().post('/v1/grievances').send({ category: 'general', email: `e2e-limit-${RUN}@aura.test`, description: 'Another complaint here.' }).expect(201);
      const limited = await http_().post('/v1/grievances').send({ category: 'general', email: `e2e-limit-${RUN}@aura.test`, description: 'One more complaint.' });
      expect(limited.status).toBe(429);
      // NCII: 2-hour clock and a 24×7 page (payload without content)
      expect(Date.parse(ncii.body.resolveBy) - Date.parse(ncii.body.receivedAt)).toBe(2 * 3_600_000);
      const page = await receiver.waitFor((h) => h.path === '/page' && h.json?.kind === 'grievance' && h.json?.ticket === ncii.body.ticket);
      expect(page.body).not.toContain('photo');
    });

    it('the Owner inbox shows timers and contact; resolving emails a decision with the appeal route', async () => {
      const list = await adm(owner, 'get', '/admin/grievances');
      const g = list.body.grievances.find((x: { ticket: string }) => x.ticket === ticket);
      expect(g).toMatchObject({ status: 'acknowledged', category: 'general', overdue: false, ackEmailSentAt: expect.any(String) });
      grievanceId = g.grievanceId;
      const detail = await adm(owner, 'get', `/admin/grievances/${grievanceId}`);
      expect(detail.body).toMatchObject({ complainantEmail: complainant, description: expect.stringContaining('same gesture') });
      const res = await adm(owner, 'post', `/admin/grievances/${grievanceId}/resolve`, {
        outcome: 'action_taken',
        reply: 'We reviewed the room and restricted the account that sent the gestures.',
      });
      expect(res.status).toBe(200);
      expect(res.body).toMatchObject({ status: 'resolved', outcome: 'action_taken', replyEmailed: true });
      const reply = await mailTo(complainant, `decision on your grievance ${ticket}`);
      mailIds.push(reply.id);
      expect(reply.text).toContain('restricted the account');
      expect(reply.text).toContain('Grievance Appellate Committee');
      expect(reply.text).toContain('https://gac.gov.in');
      const audit = await db.query(`select action from public.moderation_actions where detail->>'grievanceId' = $1 order by id`, [grievanceId]);
      expect(audit.rows.map((x: { action: string }) => x.action)).toEqual(['grievance_received', 'grievance_resolved']);
    });
  });

  // ================================================================== legal orders + 24×7 paging
  describe('legal orders: a test takedown order pages AK (week 13 exit criterion)', () => {
    let orderId: string;
    let orderTicket: string;
    let pageId: string;

    it('the Owner records a test order → it pages at once on the webhook and by email, content-free', async () => {
      const before = receiver.hits.length;
      const r = await adm(owner, 'post', '/admin/legal-orders', {
        source: 'government',
        authority: 'E2E Drill Authority',
        reference: `E2E/${RUN}`,
        summary: 'Remove reflection X from room Y (drill)',
        isTest: true,
      });
      expect(r.status).toBe(201);
      orderId = r.body.legalOrderId;
      orderTicket = r.body.ticket;
      legalOrderIds.push(orderId);
      expect(orderTicket).toMatch(/^LO-[0-9A-HJKMNP-TV-Z]{8}$/);
      expect(Date.parse(r.body.dueAt) - Date.parse(r.body.receivedAt)).toBe(3 * 3_600_000);

      const hit = await receiver.waitFor((h) => h.path === '/page' && h.json?.ticket === orderTicket);
      expect(receiver.hits.length).toBeGreaterThan(before);
      expect(hit.auth).toBe(`Bearer ${WEBHOOK_TOKEN}`);
      expect(hit.json).toMatchObject({ event: 'aura.page', kind: 'legal_order', isTest: true, round: 0, escalationLevel: 0 });
      expect(String(hit.json?.title)).toContain('TEST | Legal order');
      expect(hit.body).not.toContain('Drill Authority');
      expect(hit.body).not.toContain('reflection X');
      pageId = String(hit.json?.pageId);

      const mail = await mailTo(ONCALL_EMAIL, orderTicket);
      mailIds.push(mail.id);
      expect(mail.subject).toContain('[Aura page]');
      expect(mail.text).toContain(`/paging/${pageId}`);
      expect(mail.text).not.toContain('reflection X');

      const log = await db.query<{ channel: string; ok: boolean; round: number; level: number }>(
        `select channel, ok, round, level from public.admin_page_deliveries where page_id = $1 order by id`,
        [pageId],
      );
      expect(log.rows).toEqual(
        expect.arrayContaining([
          { channel: 'webhook', ok: true, round: 0, level: 0 },
          { channel: 'email', ok: true, round: 0, level: 0 },
        ]),
      );
    });

    it('unacknowledged at 5 minutes → the escalation (voice-call) webhook fires and the page repeats', async () => {
      const t5 = new Date(Date.now() + 6 * 60_000);
      await paging.runDue(t5);
      const call = await receiver.waitFor((h) => h.path === '/call' && h.json?.pageId === pageId);
      expect(call.json).toMatchObject({ escalationLevel: 1, round: 1, kind: 'legal_order' });
      const view = await adm(owner, 'get', `/admin/pages/${pageId}`);
      expect(view.body).toMatchObject({ status: 'open', round: 2, escalationLevel: 1 });
      expect(view.body.deliveryLog.some((d: { channel: string; level: number }) => d.channel === 'escalation_webhook' && d.level === 1)).toBe(true);
    });

    it('acknowledging stops the repeats and acknowledges the order; closing records whether the 3 h clock was met', async () => {
      const ack = await adm(owner, 'post', `/admin/pages/${pageId}/ack`);
      expect(ack.status).toBe(200);
      expect(ack.body).toMatchObject({ status: 'acknowledged', acknowledgedBy: `staff:${owner.id}` });
      expect((await adm(owner, 'get', `/admin/legal-orders/${orderId}`)).body.status).toBe('acknowledged');
      const hitsBefore = receiver.hits.filter((h) => h.json?.pageId === pageId).length;
      await paging.runDue(new Date(Date.now() + 12 * 60_000));
      await sleep(300);
      expect(receiver.hits.filter((h) => h.json?.pageId === pageId).length).toBe(hitsBefore);

      const closed = await adm(owner, 'post', `/admin/legal-orders/${orderId}/close`, { status: 'actioned', note: 'Drill: content disabled within the window.' });
      expect(closed.status).toBe(200);
      expect(closed.body).toMatchObject({ status: 'actioned', closedBy: `staff:${owner.id}` });
      const trail = await db.query(`select action from public.moderation_actions where detail->>'legalOrderId' = $1 or detail->>'pageId' = $2 order by id`, [orderId, pageId]);
      expect(trail.rows.map((x: { action: string }) => x.action)).toEqual(['legal_order_received', 'page_raised', 'page_acknowledged', 'legal_order_closed']);
    });

    it('machine intake (emailed orders via a relay): token required; pages like the console', async () => {
      const body = { source: 'court', authority: 'E2E Court', summary: 'Disable access to item Z (drill)', isTest: true };
      expect((await http_().post('/v1/intake/legal-orders').send(body)).status).toBe(401);
      expect((await http_().post('/v1/intake/legal-orders').set('Authorization', 'Bearer wrong-token-of-some-length').send(body)).status).toBe(401);
      const r = await http_().post('/v1/intake/legal-orders').set('Authorization', `Bearer ${INTAKE_TOKEN}`).send(body).expect(201);
      legalOrderIds.push(r.body.legalOrderId);
      const hit = await receiver.waitFor((h) => h.path === '/page' && h.json?.ticket === r.body.ticket);
      expect(hit.body).not.toContain('item Z');
      const row = await db.query(`select created_by, intake_channel from public.admin_legal_orders where id = $1`, [r.body.legalOrderId]);
      expect(row.rows[0]).toEqual({ created_by: 'intake:legal_orders', intake_channel: 'intake_api' });
    });

    it('a manual test page; the paging status panel names channels only (no URLs or tokens)', async () => {
      const t = await adm(owner, 'post', '/admin/pages/test');
      expect(t.status).toBe(201);
      testPageIds.push(t.body.pageId);
      await receiver.waitFor((h) => h.path === '/page' && h.json?.pageId === t.body.pageId);
      await adm(owner, 'post', `/admin/pages/${t.body.pageId}/ack`).then((r) => expect(r.status).toBe(200));
      const s = await adm(owner, 'get', '/admin/paging/status');
      expect(s.body.channels).toEqual([
        { name: 'webhook', level: 0 },
        { name: 'email', level: 0 },
        { name: 'escalation_webhook', level: 1 },
      ]);
      expect(s.body.lastTest).toMatchObject({ pageId: t.body.pageId, status: 'acknowledged' });
      expect(JSON.stringify(s.body)).not.toContain('127.0.0.1');
      expect(JSON.stringify(s.body)).not.toContain(WEBHOOK_TOKEN);
    });
  });

  // ================================================================== REQ-ADM-01: SSO (Google Workspace) + TOTP
  describe('REQ-ADM-01: SSO first factor + TOTP, email sign-in refused (a second app booted as production would be)', () => {
    let ssoApp: INestApplication;
    const saved: Record<string, string | undefined> = {};

    /**
     * A staff account signed in the way Google SSO does it: a Google identity whose ID token carried `hd` (Supabase keeps
     * it in identity_data.custom_claims) and a session whose authentication method is `oauth`. The live GoTrue then
     * issues the tokens (refresh → amr oauth; TOTP → AAL2), exactly as after a real Google sign-in.
     */
    async function ssoUser(label: string, domain: string, opts: { staffRole?: 'owner' | 'moderator'; app?: boolean } = {}): Promise<{ id: string; aal1: string; aal2: string }> {
      const u = await createUser(label);
      users.push(u);
      if (opts.staffRole) {
        staffIds.add(u.id);
        await db.query('insert into public.admin_staff (staff_id, role, display_name) values ($1, $2, $3)', [u.id, opts.staffRole, `E2E ${label}`]);
      }
      if (opts.app) {
        await http_().post('/v1/profile').set('Authorization', `Bearer ${u.token}`).send({ birthDate: ADULT_DOB, uiLocale: 'en', timezone: 'Asia/Kolkata', country: 'IN' }).expect(200);
      }
      const sub = `google-${randomBytes(8).toString('hex')}`;
      await db.query(
        `insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
         values ($1, $2, jsonb_build_object('sub', $1::text, 'email', $3::text, 'email_verified', true, 'custom_claims', jsonb_build_object('hd', $4::text)),
                 'google', now(), now(), now())`,
        [sub, u.id, u.email, domain],
      );
      // A fresh session for this user, then mark its first factor as the OAuth sign-in and refresh.
      const pw = `pw-${randomBytes(12).toString('hex')}`;
      await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${u.id}`, {
        method: 'PUT',
        headers: { apikey: localServiceKey(), Authorization: `Bearer ${localServiceKey()}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: pw }),
      });
      const s = (await (
        await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
          method: 'POST',
          headers: { apikey: localAnonKey(), 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: u.email, password: pw }),
        })
      ).json()) as { access_token: string; refresh_token: string };
      const sid = JSON.parse(Buffer.from(s.access_token.split('.')[1], 'base64url').toString()).session_id as string;
      await db.query(`update auth.mfa_amr_claims set authentication_method = 'oauth' where session_id = $1`, [sid]);
      const r = (await (
        await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
          method: 'POST',
          headers: { apikey: localAnonKey(), 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: s.refresh_token }),
        })
      ).json()) as { access_token: string };
      const amr = JSON.parse(Buffer.from(r.access_token.split('.')[1], 'base64url').toString()).amr as Array<{ method: string }>;
      expect(amr.map((m) => m.method)).toEqual(['oauth']);
      return { id: u.id, aal1: r.access_token, aal2: opts.staffRole ? await enrollTotp(r.access_token) : r.access_token };
    }

    const sso = (token: string, path: string) => request(ssoApp.getHttpServer()).get(path).set('Authorization', `Bearer ${token}`);

    beforeAll(async () => {
      const env = { ADMIN_SSO_PROVIDER: 'google', ADMIN_SSO_ALLOWED_DOMAINS: SSO_DOMAIN, ADMIN_ALLOW_EMAIL_LOGIN: 'false' };
      for (const [k, v] of Object.entries(env)) {
        saved[k] = process.env[k];
        process.env[k] = v;
      }
      ssoApp = await bootApp();
    });

    afterAll(async () => {
      await ssoApp?.close();
      for (const [k, v] of Object.entries(saved)) {
        if (v === undefined) delete process.env[k];
        else process.env[k] = v;
      }
    });

    it('a Workspace (hd) SSO sign-in + TOTP reaches the console, reported as sso', async () => {
      const s = await ssoUser('adm-sso', SSO_DOMAIN, { staffRole: 'owner' });
      expect((await sso(s.aal2, '/admin/session')).body).toMatchObject({ mfa: 'verified', firstFactor: 'sso', staff: { role: 'owner' } });
      expect((await sso(s.aal2, '/admin/queue')).status).toBe(200);
      // SSO login without MFA is denied (only the preflight answers, to start TOTP).
      expect((await sso(s.aal1, '/admin/queue')).body.code).toBe('mfa_required');
    });

    it('the email / password sign-in is refused when SSO is required: 403 sso_required (audited)', async () => {
      const r = await sso(owner.token, '/admin/queue');
      expect(r.status).toBe(403);
      expect(r.body.code).toBe('sso_required');
      expect((await sso(owner.aal1, '/admin/session')).body.code).toBe('sso_required');
    });

    it('a Google account outside the Workspace domain is refused', async () => {
      const s = await ssoUser('adm-sso-other', 'elsewhere.test', { staffRole: 'moderator' });
      expect((await sso(s.aal2, '/admin/queue')).body.code).toBe('sso_required');
    });

    it('negative: an app user account can never sign in, even with a Workspace SSO session', async () => {
      const s = await ssoUser('adm-sso-app', SSO_DOMAIN, { app: true });
      expect((await sso(s.aal1, '/admin/session')).body.code).toBe('not_staff');
    });
  });

  // ================================================================== REQ-ADM-05: crisis phone alert
  describe('REQ-ADM-05: an L0 item in India’s Lantern Hour reaches the Owner’s phone within 60 s, repeats every 5 min until acknowledged', () => {
    let reporter: TestUser;
    let subject: TestUser;
    let roomId: string;
    let subjectMember: string;
    let reports: ReportsService;

    beforeAll(async () => {
      await freshRooms();
      reports = app.get(ReportsService);
      subject = await appUser('adm-crisis-subject');
      reporter = await appUser('adm-crisis-reporter');
      const match = (u: TestUser) =>
        http_().post('/v1/rooms/match').set('Authorization', `Bearer ${u.token}`).send({ quadrant: 'storm', moodId: 'anxious', timezone: 'Asia/Kolkata' });
      const s = await match(subject);
      expect(s.status).toBe(200);
      roomId = s.body.room.roomId;
      subjectMember = s.body.me.memberId;
      expect((await match(reporter)).body.room.roomId).toBe(roomId);
    });

    afterAll(() => {
      reports.clock = () => new Date();
    });

    /** The page raised for a report (the fast path raises it in the background; the sweep in the worker). */
    const pageFor = async (reportId: string, timeoutMs = 60_000): Promise<string> => {
      const end = Date.now() + timeoutMs;
      for (;;) {
        const r = await db.query<{ id: string }>(`select id from public.admin_pages where kind = 'report' and ref_id = $1`, [reportId]);
        if (r.rows[0]) return r.rows[0].id;
        if (Date.now() > end) throw new Error('no page was raised for the report');
        await sleep(50);
      }
    };

    const crisisReport = async (note: string): Promise<string> => {
      const r = await http_()
        .post('/v1/safety/reports')
        .set('Authorization', `Bearer ${reporter.token}`)
        .send({ target: { kind: 'member', roomId, memberId: subjectMember }, reason: 1, note });
      expect(r.status).toBe(201);
      expect(r.body.showHelplines).toBe(true);
      return r.body.reportId;
    };

    it('filed in India’s Lantern Hour → the push arrives at once (content-free), the call joins at 5 min, repeats until acknowledged', async () => {
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
      reports.clock = () => new Date(`${today}T21:30:00+05:30`); // India's Lantern Hour
      const started = Date.now();
      const reportId = await crisisReport('they said they want to disappear tonight');
      const pageId = await pageFor(reportId);
      const hit = await receiver.waitFor((h) => h.path === '/page' && h.json?.pageId === pageId, 60_000);
      expect(Date.now() - started).toBeLessThan(60_000); // REQ-ADM-05: within 60 s (the API's fast path; no worker needed)
      expect(hit.json).toMatchObject({ event: 'aura.page', reason: 'crisis_lantern_hour', lane: 'crisis', round: 0, escalationLevel: 0 });
      // Payload: ids, lane, flags and timers only — never content, pseudonyms or account ids.
      expect(hit.body).not.toContain('disappear');
      expect(hit.body).not.toContain(subject.id);
      expect(hit.body).not.toContain(reporter.id);
      const report = await db.query<{ pages: boolean; mins: number }>(
        `select pages, round(extract(epoch from (sla_due_at - $2::timestamptz)) / 60)::int as mins from public.reports where id = $1`,
        [reportId, reports.clock()],
      );
      expect(report.rows[0]).toEqual({ pages: true, mins: 15 });

      await paging.runDue(new Date(Date.now() + 6 * 60_000));
      const call = await receiver.waitFor((h) => h.path === '/call' && h.json?.pageId === pageId);
      expect(call.json).toMatchObject({ escalationLevel: 1, round: 1, lane: 'crisis' });
      await paging.runDue(new Date(Date.now() + 12 * 60_000));
      expect((await adm(owner, 'get', `/admin/pages/${pageId}`)).body).toMatchObject({ status: 'open', round: 3 });

      expect((await adm(owner, 'post', `/admin/pages/${pageId}/ack`)).status).toBe(200);
      const before = receiver.hits.filter((h) => h.json?.pageId === pageId).length;
      await paging.runDue(new Date(Date.now() + 20 * 60_000));
      await sleep(200);
      expect(receiver.hits.filter((h) => h.json?.pageId === pageId).length).toBe(before);
      await adm(owner, 'post', `/admin/reports/${reportId}/actions`, { action: 'dismiss', reasonCode: 'crisis_support' });
    });

    it('a fresh crisis page is not held up by a backlog of due repeats (first deliveries go first; the fast path drains)', async () => {
      const backlog = await db.query<{ id: string }>(
        `insert into public.admin_pages (kind, reason, is_test, round, next_attempt_at)
         select 'test', 'test_manual', true, 5, now() - interval '10 minutes' from generate_series(1, 30) returning id`,
      );
      testPageIds.push(...backlog.rows.map((r) => r.id));
      const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
      reports.clock = () => new Date(`${today}T22:15:00+05:30`);
      const started = Date.now();
      const reportId = await crisisReport('backlog check');
      const pageId = await pageFor(reportId);
      await receiver.waitFor((h) => h.path === '/page' && h.json?.pageId === pageId, 60_000);
      expect(Date.now() - started).toBeLessThan(60_000);
      await paging.idle();
      const left = await db.query(`select count(*)::int as n from public.admin_pages where id = any($1::uuid[]) and status = 'open'`, [backlog.rows.map((r) => r.id)]);
      expect(left.rows[0].n).toBe(0); // the drain went past the first batch of 20 (these stale drills expire)
      await adm(owner, 'post', `/admin/pages/${pageId}/ack`);
      await adm(owner, 'post', `/admin/reports/${reportId}/actions`, { action: 'dismiss', reasonCode: 'crisis_support' });
    });

    it('outside Lantern Hour: no page at filing; still open 5 minutes later → it pages (24×7, no overnight exception)', async () => {
      // 03:00 IST tomorrow — overnight in India, and no region's Lantern Hour. Tomorrow, so the report's SLA (stamped from
      // this clock) is never within minutes of the real time the sweep runs at.
      const tomorrow = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date(Date.now() + 86_400_000));
      reports.clock = () => new Date(`${tomorrow}T03:00:00+05:30`);
      const reportId = await crisisReport('worried about them');
      await paging.idle();
      expect((await db.query('select pages from public.reports where id = $1', [reportId])).rows[0].pages).toBe(false);
      await paging.sweep();
      expect((await db.query(`select 1 from public.admin_pages where kind = 'report' and ref_id = $1`, [reportId])).rowCount).toBe(0);
      await db.query(`update public.reports set created_at = now() - interval '6 minutes' where id = $1`, [reportId]);
      await paging.sweep();
      await paging.runDue();
      const pageId = await pageFor(reportId);
      const hit = await receiver.waitFor((h) => h.path === '/page' && h.json?.pageId === pageId);
      expect(hit.json).toMatchObject({ kind: 'report', lane: 'crisis', reason: 'crisis_unassigned' });
      expect(hit.body).not.toContain('worried');
      await adm(owner, 'post', `/admin/pages/${pageId}/ack`);
      await adm(owner, 'post', `/admin/reports/${reportId}/actions`, { action: 'dismiss', reasonCode: 'crisis_support' });
    });
  });

  // ================================================================== REQ-ADM-07: strike automation (console)
  describe('REQ-ADM-07: the 4th active strike bans; 90-day-old strikes stop counting; a crisis-flagged item never strikes', () => {
    let roomId: string;
    const members: Record<string, string> = {};
    const people: Record<string, TestUser> = {};

    beforeAll(async () => {
      await freshRooms();
      for (const name of ['s4', 's90', 'sc', 'r1', 'r2']) {
        people[name] = await appUser(`adm-strike-${name}`);
        const m = await http_()
          .post('/v1/rooms/match')
          .set('Authorization', `Bearer ${people[name].token}`)
          .send({ quadrant: 'moonlight', moodId: 'calm', timezone: 'Asia/Tokyo' });
        expect(m.status).toBe(200);
        roomId ??= m.body.room.roomId;
        members[name] = m.body.me.memberId;
      }
    });

    const report = async (by: string, about: string, reason: number): Promise<string> => {
      const r = await http_()
        .post('/v1/safety/reports')
        .set('Authorization', `Bearer ${people[by].token}`)
        .send({ target: { kind: 'member', roomId, memberId: members[about] }, reason });
      expect([200, 201]).toContain(r.status);
      return r.body.reportId;
    };
    const strike = (reportId: string) => adm(moderator, 'post', `/admin/reports/${reportId}/actions`, { action: 'strike', reasonCode: 'harassment' });

    it('strikes 1–3 climb the ladder; the 4th bans automatically (audited as the ladder, evidence held 180 days)', async () => {
      const reportIds: string[] = [];
      for (let i = 1; i <= 4; i++) {
        const id = await report(i % 2 ? 'r1' : 'r2', 's4', i % 2 ? 2 : 4);
        reportIds.push(id);
        const r = await strike(id);
        expect(r.status).toBe(200);
        expect(r.body.activeStrikes).toBe(i);
        if (i < 4) expect(r.body.autoBan).toBeNull();
        else expect(r.body.autoBan).toMatchObject({ sanctionId: expect.any(String), alreadyBanned: false, evidenceHolds: 4 });
      }
      const me = await http_().get('/v1/safety/me').set('Authorization', `Bearer ${people.s4.token}`);
      expect(me.body).toMatchObject({ rooms: 'suspended', until: null }); // permanent social ban (never says why)
      const ban = await db.query(`select kind, source, ends_at from public.sanctions where report_id = $1 and kind = 'social_ban'`, [reportIds[3]]);
      expect(ban.rows).toEqual([{ kind: 'social_ban', source: 'auto', ends_at: null }]);
      const audit = await db.query(`select actor, action, reason_code from public.moderation_actions where report_id = $1 order by id`, [reportIds[3]]);
      expect(audit.rows.map((x: { actor: string; action: string }) => [x.actor, x.action])).toEqual([
        [`staff:${moderator.id}`, 'strike'],
        ['system:strike_ladder', 'auto_strike_ban'],
      ]);
      const holds = await db.query<{ days: number }>(
        `select round(extract(epoch from (e.hold_until - now())) / 86400)::int as days
           from public.reports r join public.evidence_holds e on e.id = r.evidence_hold_id where r.id = any($1::uuid[])`,
        [reportIds],
      );
      expect(holds.rows.every((h) => h.days >= 179)).toBe(true);
    });

    it('strikes older than 90 days stop counting: with two expired, the next strike is the 2nd (a shadow-mute, no ban)', async () => {
      for (let i = 1; i <= 3; i++) expect((await strike(await report(i % 2 ? 'r1' : 'r2', 's90', i % 2 ? 2 : 4))).body.activeStrikes).toBe(i);
      await db.query(
        `update public.strikes set created_at = now() - interval '95 days', expires_at = now() - interval '5 days'
          where id in (select id from public.strikes where user_id = $1 order by created_at limit 2)`,
        [people.s90.id],
      );
      const r = await strike(await report('r1', 's90', 5));
      expect(r.body).toMatchObject({ activeStrikes: 2, autoBan: null });
      expect((await db.query(`select kind from public.sanctions where user_id = $1 and kind = 'social_ban'`, [people.s90.id])).rowCount).toBe(0);
    });

    it('negative: a crisis-flagged item never adds a strike (409, nothing recorded)', async () => {
      const crisis = await report('r2', 'sc', 1);
      const harassment = await report('r1', 'sc', 2);
      const r = await strike(harassment);
      expect(r.status).toBe(409);
      expect(r.body.code).toBe('crisis_never_strikes');
      expect((await strike(crisis)).body.code).toBe('crisis_never_strikes');
      expect((await db.query('select 1 from public.strikes where user_id = $1', [people.sc.id])).rowCount).toBe(0);
      await adm(owner, 'post', `/admin/reports/${crisis}/actions`, { action: 'dismiss', reasonCode: 'crisis_support' });
    });
  });

  // ================================================================== REQ-ADM-11: deletion cases
  describe('REQ-ADM-11: an emailed deletion request, verified by a link to the account’s own email, then the app’s deletion', () => {
    let holder: TestUser;
    let reporterU: TestUser;
    let caseId: string;
    let token: string;
    let holdId: string;

    beforeAll(async () => {
      await freshRooms();
      holder = await appUser('adm-del-holder');
      reporterU = await appUser('adm-del-reporter');
      const match = (u: TestUser) =>
        http_().post('/v1/rooms/match').set('Authorization', `Bearer ${u.token}`).send({ quadrant: 'sunrise', moodId: 'joyful', timezone: 'America/Chicago' });
      const h = await match(holder);
      await match(reporterU);
      // A report ABOUT the holder: its evidence hold must outlive the account (legal hold).
      const r = await http_()
        .post('/v1/safety/reports')
        .set('Authorization', `Bearer ${reporterU.token}`)
        .send({ target: { kind: 'member', roomId: h.body.room.roomId, memberId: h.body.me.memberId }, reason: 6 });
      holdId = (await db.query<{ evidence_hold_id: string }>('select evidence_hold_id from public.reports where id = $1', [r.body.reportId])).rows[0].evidence_hold_id;
    });

    it('the Owner opens a case; the link goes to the account’s address (not a URL with personal data); a Moderator cannot', async () => {
      expect((await adm(moderator, 'post', '/admin/deletion-cases', { email: holder.email, channel: 'email', receivedAt: new Date().toISOString() })).status).toBe(403);
      const r = await adm(owner, 'post', '/admin/deletion-cases', {
        email: holder.email.toUpperCase(),
        channel: 'email',
        receivedAt: new Date(Date.now() - 3_600_000).toISOString(),
      });
      expect(r.status).toBe(201);
      caseId = r.body.caseId;
      deletionCaseIds.push(caseId);
      expect(r.body).toMatchObject({ status: 'awaiting_verification', linkEmailed: true, ticket: expect.stringMatching(/^DEL-[0-9A-HJKMNP-TV-Z]{8}$/) });
      expect(r.body.accountEmailMasked).toMatch(/^e•••@aura\.test$/);
      expect(r.body.legalHold.records).toBeGreaterThanOrEqual(1);
      const mail = await mailTo(holder.email, r.body.ticket);
      mailIds.push(mail.id);
      const link = /(https?:\/\/\S+\/v1\/deletion-requests\/([A-Za-z0-9_-]{43}))/.exec(mail.text);
      expect(link).not.toBeNull();
      token = (link as RegExpExecArray)[2];
      expect((link as RegExpExecArray)[1]).not.toContain(holder.email.split('@')[0]);
      expect(mail.text).toContain('nothing is deleted without your confirmation');
      // A second case for the same account is refused while this one is open.
      expect((await adm(owner, 'post', '/admin/deletion-cases', { email: holder.email, channel: 'email', receivedAt: new Date().toISOString() })).body.code).toBe(
        'open_case_exists',
      );
    });

    it('negative: nothing is deleted before the account holder confirms; opening the link changes nothing', async () => {
      const early = await adm(owner, 'post', `/admin/deletion-cases/${caseId}/delete`, { mode: 'grace' });
      expect(early.status).toBe(409);
      expect(early.body.code).toBe('case_not_verified');
      const page = await http_().get(`/v1/deletion-requests/${token}`).expect(200);
      expect(page.headers['content-type']).toContain('text/html');
      expect(page.headers['cache-control']).toBe('no-store');
      expect(page.text).toContain(`${token}/confirm`);
      expect(page.text).not.toContain(holder.email);
      expect((await adm(owner, 'get', `/admin/deletion-cases/${caseId}`)).body.status).toBe('awaiting_verification');
      expect((await http_().post(`/v1/deletion-requests/${'A'.repeat(43)}/confirm`)).status).toBe(404);
    });

    it('the holder confirms (once); the Owner starts the deletion (immediate, with a reason); every step audited', async () => {
      const ok = await http_().post(`/v1/deletion-requests/${token}/confirm`).expect(200);
      expect(ok.text).toContain('request confirmed');
      expect((await http_().post(`/v1/deletion-requests/${token}/confirm`)).status).toBe(404); // single use
      expect((await adm(owner, 'get', `/admin/deletion-cases/${caseId}`)).body).toMatchObject({ status: 'verified', allowed: { startDeletion: true } });
      const del = await adm(owner, 'post', `/admin/deletion-cases/${caseId}/delete`, { mode: 'immediate', reasonCode: 'requester_asked_immediate' });
      expect(del.status).toBe(200);
      expect(del.body).toMatchObject({ status: 'deletion_scheduled', deletion: { mode: 'immediate', pending: true } });
      // The app's own deletion: the account is deactivated (every /v1 route answers account_deletion_pending).
      expect((await http_().get('/v1/rooms').set('Authorization', `Bearer ${holder.token}`)).body.code).toBe('account_deletion_pending');
      const trail = await db.query(`select actor, action from public.moderation_actions where detail->>'caseId' = $1 order by id`, [caseId]);
      expect(trail.rows.map((x: { action: string }) => x.action)).toEqual([
        'deletion_case_opened',
        'deletion_link_sent',
        'deletion_case_verified',
        'deletion_scheduled',
      ]);
      expect(trail.rows[2].actor).toBe('public:deletion_link');
      const blob = JSON.stringify((await db.query(`select * from public.moderation_actions where detail->>'caseId' = $1`, [caseId])).rows);
      expect(blob).not.toContain(holder.id);
      expect(blob).not.toContain(holder.email);
    });

    it('the purge deletes the account and completes the case; negative: the evidence hold about it survives until hold_until', async () => {
      const out = await purgeAccount(db, app.get(PrivateMediaStore), holder.id);
      expect(out.status).toBe('purged');
      expect((await db.query('select 1 from auth.users where id = $1', [holder.id])).rowCount).toBe(0);
      const c = await adm(owner, 'get', `/admin/deletion-cases/${caseId}`);
      expect(c.body).toMatchObject({ status: 'completed', subjectHash: null, accountEmailMasked: null, legalHold: { records: 1 } });
      const hold = await db.query<{ subject: boolean; future: boolean }>(
        `select $2::uuid = any(account_ids) as subject, hold_until > now() as future from public.evidence_holds where id = $1`,
        [holdId, holder.id],
      );
      expect(hold.rows).toEqual([{ subject: true, future: true }]);
      // 181 days later: past hold_until, the lifecycle worker's expiry removes it.
      await db.query(`update public.evidence_holds set created_at = now() - interval '181 days', hold_until = now() - interval '1 day' where id = $1`, [holdId]);
      await purgeExpiredEvidence(db);
      expect((await db.query('select 1 from public.evidence_holds where id = $1', [holdId])).rowCount).toBe(0);
    });
  });

  // ================================================================== staff editor
  describe('staff editor (Owner): add, change role, disable — audited with the Owner as actor', () => {
    it('adds an existing non-app account, refuses app accounts, and a disabled member is out at once', async () => {
      const cand = await createUser('adm-cand');
      users.push(cand);
      staffIds.add(cand.id);
      expect((await adm(moderator, 'post', '/admin/staff', { email: cand.email, role: 'moderator', displayName: 'Cand' })).status).toBe(403);
      const added = await adm(owner, 'post', '/admin/staff', { email: cand.email, role: 'moderator', displayName: 'Cand' });
      expect(added.status).toBe(201);
      expect(added.body.staffId).toBe(cand.id);
      const stranger = await appUser('adm-cand-app');
      expect((await adm(owner, 'post', '/admin/staff', { email: stranger.email, role: 'moderator', displayName: 'App' })).body.code).toBe('app_account');
      expect((await adm(owner, 'post', `/admin/staff/${owner.id}`, { disabled: true })).body.code).toBe('cannot_change_self');

      const list = await adm(owner, 'get', '/admin/staff');
      expect(list.body.staff.find((s: { staffId: string }) => s.staffId === cand.id)).toMatchObject({ role: 'moderator', disabled: false, totpEnrolled: false });

      const aal2 = await enrollTotp(cand.token);
      expect((await adm({ token: aal2 }, 'get', '/admin/queue')).status).toBe(200);
      expect((await adm(owner, 'post', `/admin/staff/${cand.id}`, { role: 'analyst' })).body).toEqual({ staffId: cand.id, changed: true });
      expect((await adm({ token: aal2 }, 'get', '/admin/queue')).body.code).toBe('forbidden_role');
      expect((await adm(owner, 'post', `/admin/staff/${cand.id}`, { disabled: true })).status).toBe(200);
      expect((await adm({ token: aal2 }, 'get', '/admin/session')).body.code).toBe('not_staff');
      const trail = await db.query(`select actor, action from public.moderation_actions where detail->>'staffId' = $1 order by id`, [cand.id]);
      expect(trail.rows).toEqual([
        { actor: `staff:${owner.id}`, action: 'staff_granted' },
        { actor: `staff:${owner.id}`, action: 'staff_changed' },
        { actor: `staff:${owner.id}`, action: 'staff_disabled' },
      ]);
    });
  });

  // ================================================================== the 2-hour queue session cap
  describe('queue sessions are capped at 2 h (PRD 19): non-urgent items close, paging and crisis items stay open', () => {
    it('423 queue_session_cap for a non-urgent item after 2 h of review; a crisis item still opens', async () => {
      await freshRooms();
      const a = await appUser('adm-cap-a');
      const b = await appUser('adm-cap-b');
      const match = (u: TestUser) =>
        http_().post('/v1/rooms/match').set('Authorization', `Bearer ${u.token}`).send({ quadrant: 'rain', moodId: 'lonely', timezone: 'Asia/Tokyo' });
      const ma = await match(a);
      await match(b);
      const file = async (reason: number) =>
        (
          await http_()
            .post('/v1/safety/reports')
            .set('Authorization', `Bearer ${b.token}`)
            .send({ target: { kind: 'member', roomId: ma.body.room.roomId, memberId: ma.body.me.memberId }, reason })
        ).body.reportId as string;
      const plain = await file(6);
      const crisis = await file(1);
      const redis = app.get(QueuesService).redis;
      const key = `aura:admin:queue-session:${moderator.id}`;
      await redis.set(key, JSON.stringify({ startedAt: Date.now() - 121 * 60_000, lastAt: Date.now() - 60_000, cappedAt: null }), 'EX', 3600);
      try {
        const r = await adm(moderator, 'get', `/admin/reports/${plain}`);
        expect(r.status).toBe(423);
        expect(r.body.code).toBe('queue_session_cap');
        expect((await adm(moderator, 'get', `/admin/reports/${crisis}`)).status).toBe(200);
        expect((await adm(moderator, 'get', '/admin/session')).body.queueSession).toMatchObject({ capped: true, maxMinutes: 120, breakMinutes: 15 });
        expect((await adm(moderator, 'get', '/admin/queue')).status).toBe(200); // the list itself is never capped
        const audit = await db.query(`select 1 from public.moderation_actions where actor = $1 and action = 'queue_session_capped'`, [`staff:${moderator.id}`]);
        expect(audit.rowCount).toBe(1);
      } finally {
        await redis.del(key);
      }
      await adm(owner, 'post', `/admin/reports/${crisis}/actions`, { action: 'dismiss', reasonCode: 'crisis_support' });
      await adm(owner, 'post', `/admin/reports/${plain}/actions`, { action: 'dismiss', reasonCode: 'no_violation' });
    });
  });

  // ================================================================== nightly audit export
  describe('the audit log is exported (nightly; the Owner can run it now): file + email, hash-checked, audited', () => {
    it('exports every row since the last export, verifies the chain, and the next export continues after it', async () => {
      const first = await adm(owner, 'post', '/admin/audit/exports', undefined, false);
      expect(first.status).toBe(200);
      expect(first.body).toMatchObject({ status: 'exported', destinations: ['file', 'email'], manifest: { chainVerified: true } });
      const m = first.body.manifest as { fromId: number; toId: number; rows: number; filename: string; ndjsonSha256: string; lastRowHash: string };
      const files = await readdir(exportDir);
      expect(files).toEqual(expect.arrayContaining([m.filename, m.filename.replace(/\.ndjson$/, '.manifest.json')]));
      const nd = await readFile(join(exportDir, m.filename));
      expect(createHash('sha256').update(nd).digest('hex')).toBe(m.ndjsonSha256);
      expect(nd.toString('utf8').trim().split('\n')).toHaveLength(m.rows);
      const mail = await mailTo(ARCHIVE_EMAIL, `#${m.fromId}-${m.toId}`);
      mailIds.push(mail.id);
      expect(mail.text).toContain(m.ndjsonSha256);

      await adm(owner, 'post', '/admin/pages/test').then((r) => testPageIds.push(r.body.pageId)); // a few more audit rows
      const second = await adm(owner, 'post', '/admin/audit/exports', undefined, false);
      expect(second.body.manifest).toMatchObject({ fromId: m.toId + 1, previousToId: m.toId, linksToPrevious: true, chainVerified: true });
      const status = await adm(owner, 'get', '/admin/audit/exports');
      expect(status.body.configured).toMatchObject({ dir: true, email: true });
      expect(status.body.last[0]).toMatchObject({ trigger: 'manual', fromId: m.toId + 1 });
      expect((await adm(moderator, 'post', '/admin/audit/exports')).status).toBe(403);
    });
  });

  // ================================================================== config, audit chain, privacy boundary, sign-out
  describe('kill switches, audit log, privacy boundary, sign-out', () => {
    it('flipping a kill switch is Owner-only and audited with its reason', async () => {
      const before = (await adm(owner, 'get', '/admin/config')).body.flags.find((f: { key: string }) => f.key === 'rooms_pool_hi');
      expect(before).toBeTruthy();
      expect((await adm(owner, 'post', '/admin/config/flags/rooms_pool_hi', { enabled: before.enabled, reasonCode: 'e2e_no_change' })).status).toBe(200);
      expect((await adm(owner, 'post', '/admin/config/flags/does_not_exist', { enabled: true, reasonCode: 'x' })).status).toBe(404);
      const row = await db.query(`select detail from public.moderation_actions where action = 'config_flag' and reason_code = 'e2e_no_change' order by id desc limit 1`);
      expect(row.rows[0].detail).toEqual({ key: 'rooms_pool_hi', enabled: before.enabled, previous: before.enabled });
    });

    it('the audit log reads back with staff names and the hash chain verifies', async () => {
      const log = await adm(owner, 'get', '/admin/audit?limit=200');
      expect(log.status).toBe(200);
      expect(log.body.entries.some((e: { actorLabel: string }) => e.actorLabel === 'E2E adm-owner')).toBe(true);
      expect((await adm(owner, 'get', '/admin/audit/verify')).body.ok).toBe(true);
    });

    it('no console response carries a DOB, an app account email or raw app account id (the export aside)', async () => {
      const appUsers = users.filter((u) => !staffIds.has(u.id)); // staff ids legitimately appear in staff audit rows
      const blob = JSON.stringify(recorded);
      expect(recorded.length).toBeGreaterThan(20);
      for (const dob of [ADULT_DOB, MINOR_DOB]) expect(blob).not.toContain(dob);
      expect(blob).not.toMatch(/birth_?date/i);
      for (const u of appUsers) {
        expect(blob).not.toContain(u.id);
        expect(blob).not.toContain(u.email);
      }
    });

    it('signing out revokes the console at once (the session row is gone), even with an unexpired token', async () => {
      await adm(moderator, 'post', '/admin/session/ended').then((r) => expect(r.status).toBe(204));
      await gotrue('/logout?scope=local', moderator.token);
      const r = await adm(moderator, 'get', '/admin/queue');
      expect(r.status).toBe(401);
      expect(r.body.code).toBe('session_expired');
    });
  });
});
