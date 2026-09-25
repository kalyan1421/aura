/**
 * AdminGuard (PRD 19 REQ-ADM-01 / REQ-ADM-02): allowlist, TOTP/AAL2, staff ≠ app account, short sessions, roles,
 * fail-closed routes, and audited refusals. Real JwtVerifier (HS256 test secret) and Nest routing; the database is a
 * fake that answers the guard's one query and records audit inserts.
 */
import { Controller, Get, INestApplication, Module, UseGuards } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { SignJWT, type JWTPayload } from 'jose';
import request from 'supertest';
import { AdminConfig, AdminConfigError, parseAdminConfig } from '../../src/admin/admin-config';
import { AdminGuard, AdminRoles, AllowBeforeMfa, CurrentStaff, firstFactor } from '../../src/admin/admin.guard';
import type { StaffUser } from '../../src/admin/admin-types';
import { RateLimiter } from '../../src/admin/rate-limit';
import { JwtVerifier } from '../../src/auth/jwt-verifier';
import { ApiExceptionFilter } from '../../src/common/api-exception.filter';
import { AppConfig } from '../../src/config/app-config';
import { DbService } from '../../src/db/db.service';

const SECRET = 'unit-test-secret-with-at-least-32-characters-ok';
const ISS = 'http://127.0.0.1:55521/auth/v1';
const STAFF_ID = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const SESSION_ID = '0192f0c2-7a4e-7c1a-9b3d-00000000000a';

@Controller('admin/probe')
@UseGuards(AdminGuard)
class ProbeController {
  @Get('session')
  @AdminRoles('owner', 'moderator', 'analyst')
  @AllowBeforeMfa()
  session(@CurrentStaff() s: StaffUser): Pick<StaffUser, 'role' | 'mfa' | 'actor' | 'firstFactor'> {
    return { role: s.role, mfa: s.mfa, actor: s.actor, firstFactor: s.firstFactor };
  }

  @Get('owner')
  @AdminRoles('owner')
  owner(@CurrentStaff() s: StaffUser): { actor: string } {
    return { actor: s.actor };
  }

  @Get('work')
  @AdminRoles('owner', 'moderator')
  work(): { ok: true } {
    return { ok: true };
  }

  @Get('unconfigured')
  unconfigured(): { ok: true } {
    return { ok: true };
  }
}

interface GuardRow {
  role: string | null;
  display_name: string | null;
  disabled: boolean | null;
  session_created_at: Date | null;
  session_not_after: Date | null;
  has_totp: boolean;
  is_app_account: boolean;
  google_domains?: string[];
  providers?: string[];
}

const OWNER_ROW = (): GuardRow => ({
  role: 'owner',
  display_name: 'AK',
  disabled: false,
  session_created_at: new Date(Date.now() - 5 * 60_000),
  session_not_after: null,
  has_totp: true,
  is_app_account: false,
});

interface AuditCall {
  actor: string;
  action: string;
  reportId: unknown;
  subjectHash: string | null;
  reasonCode: string | null;
  detail: Record<string, unknown>;
}

class FakeDb {
  row: GuardRow | null = OWNER_ROW();
  audits: AuditCall[] = [];

  async query(text: string, params: unknown[] = []): Promise<{ rows: unknown[]; rowCount: number }> {
    if (/insert into public\.moderation_actions/.test(text)) {
      this.audits.push({
        actor: params[0] as string,
        action: params[1] as string,
        reportId: params[2],
        subjectHash: params[3] as string | null,
        reasonCode: params[4] as string | null,
        detail: JSON.parse(params[5] as string) as Record<string, unknown>,
      });
      return { rows: [{ id: String(this.audits.length) }], rowCount: 1 };
    }
    if (/left join public\.admin_staff/.test(text)) return { rows: this.row ? [this.row] : [], rowCount: this.row ? 1 : 0 };
    throw new Error(`unexpected query: ${text.slice(0, 60)}`);
  }
}

class FakeLimiter {
  seen = new Set<string>();
  bucket(v: string): string {
    return v;
  }
  async once(name: string): Promise<boolean> {
    if (this.seen.has(name)) return false;
    this.seen.add(name);
    return true;
  }
  async hit(): Promise<boolean> {
    return true;
  }
}

type TokenOpts = { aal?: string; totp?: boolean; email?: string; sub?: string; session?: string | null; secret?: string; first?: string };

async function token(o: TokenOpts = {}): Promise<string> {
  const first = o.first ?? 'otp';
  const claims: JWTPayload = {
    sub: o.sub ?? STAFF_ID,
    role: 'authenticated',
    aud: 'authenticated',
    email: o.email ?? 'ak@akvega.test',
    aal: o.aal ?? 'aal2',
    amr: o.totp === false ? [{ method: first, timestamp: 1 }] : [{ method: 'totp', timestamp: 2 }, { method: first, timestamp: 1 }],
  };
  if (o.session !== null) claims.session_id = o.session ?? SESSION_ID;
  return new SignJWT(claims)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuer(ISS)
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(new TextEncoder().encode(o.secret ?? SECRET));
}

async function boot(env: Record<string, string> = {}): Promise<{ app: INestApplication; db: FakeDb }> {
  const db = new FakeDb();
  @Module({
    controllers: [ProbeController],
    providers: [
      AdminGuard,
      { provide: JwtVerifier, useValue: new JwtVerifier({ secret: SECRET, issuer: ISS }) },
      { provide: DbService, useValue: db },
      { provide: AdminConfig, useValue: parseAdminConfig({ NODE_ENV: 'test', ...env }) }, // SR-1: unset NODE_ENV fails closed
      { provide: AppConfig, useValue: { masterKey: Buffer.alloc(32, 7) } },
      { provide: RateLimiter, useValue: new FakeLimiter() },
    ],
  })
  class ProbeModule {}
  const ref = await Test.createTestingModule({ imports: [ProbeModule] }).compile();
  const app = ref.createNestApplication();
  app.useGlobalFilters(new ApiExceptionFilter());
  await app.init();
  return { app, db };
}

describe('AdminGuard', () => {
  let app: INestApplication;
  let db: FakeDb;

  beforeAll(async () => {
    ({ app, db } = await boot());
  });
  afterAll(() => app.close());
  beforeEach(() => {
    db.row = OWNER_ROW();
    db.audits = [];
  });

  const get = (path: string, t?: string) => {
    const r = request(app.getHttpServer()).get(`/admin/probe/${path}`);
    return t ? r.set('Authorization', `Bearer ${t}`) : r;
  };

  it('401 without a token, or with a token not signed by Supabase', async () => {
    expect((await get('owner').expect(401)).body.code).toBe('unauthorized');
    expect((await get('owner', await token({ secret: 'another-secret-with-at-least-32-characters-x' })).expect(401)).body.code).toBe('unauthorized');
  });

  it('an allow-listed owner with AAL2 via TOTP passes; the actor is staff:<id>', async () => {
    expect((await get('owner', await token()).expect(200)).body).toEqual({ actor: `staff:${STAFF_ID}` });
    expect((await get('work', await token()).expect(200)).body).toEqual({ ok: true });
    expect(db.audits).toEqual([]);
  });

  it('an app account that is not on the allowlist is refused (403 not_staff), audited once with an HMAC, never the id', async () => {
    db.row = { ...OWNER_ROW(), role: null, display_name: null, disabled: null, has_totp: false };
    const t = await token({ aal: 'aal1', totp: false });
    expect((await get('session', t).expect(403)).body.code).toBe('not_staff');
    expect((await get('owner', t).expect(403)).body.code).toBe('not_staff');
    expect(db.audits).toHaveLength(1); // de-duplicated per session and reason
    expect(db.audits[0]).toMatchObject({ actor: 'unknown', action: 'access_denied', reasonCode: 'not_staff', subjectHash: expect.stringMatching(/^[0-9a-f]{64}$/) });
    expect(JSON.stringify(db.audits)).not.toContain(STAFF_ID);
  });

  it('a disabled staff member is refused like a stranger', async () => {
    db.row = { ...OWNER_ROW(), disabled: true };
    expect((await get('owner', await token()).expect(403)).body.code).toBe('not_staff');
  });

  it('AAL1 (no TOTP in this session) is refused everywhere except the sign-in preflight', async () => {
    const aal1 = await token({ aal: 'aal1', totp: false });
    expect((await get('owner', aal1).expect(401)).body.code).toBe('mfa_required');
    expect((await get('work', aal1).expect(401)).body.code).toBe('mfa_required');
    expect((await get('session', aal1).expect(200)).body).toMatchObject({ role: 'owner', mfa: 'challenge' });
    db.row = { ...OWNER_ROW(), has_totp: false };
    expect((await get('session', aal1).expect(200)).body.mfa).toBe('enroll');
  });

  it('an AAL2 token is not enough once the TOTP factor is gone', async () => {
    db.row = { ...OWNER_ROW(), has_totp: false };
    expect((await get('owner', await token()).expect(401)).body.code).toBe('mfa_required');
  });

  it('staff accounts must be separate from app accounts', async () => {
    db.row = { ...OWNER_ROW(), is_app_account: true };
    expect((await get('owner', await token()).expect(403)).body.code).toBe('staff_account_is_app_account');
    expect(db.audits[0]).toMatchObject({ action: 'access_denied', reasonCode: 'app_account' });
  });

  it('sessions are short and revocable: signed-out (no session row), too old, or no session id → 401 session_expired', async () => {
    db.row = { ...OWNER_ROW(), session_created_at: null };
    expect((await get('owner', await token()).expect(401)).body.code).toBe('session_expired');
    db.row = { ...OWNER_ROW(), session_created_at: new Date(Date.now() - 13 * 3_600_000) };
    expect((await get('owner', await token()).expect(401)).body.code).toBe('session_expired');
    db.row = { ...OWNER_ROW(), session_not_after: new Date(Date.now() - 1000) };
    expect((await get('owner', await token()).expect(401)).body.code).toBe('session_expired');
    db.row = OWNER_ROW();
    expect((await get('owner', await token({ session: null })).expect(401)).body.code).toBe('session_expired');
  });

  it('REQ-ADM-02: a Moderator on an Owner route gets 403 and the attempt is audited (every time)', async () => {
    db.row = { ...OWNER_ROW(), role: 'moderator' };
    const t = await token();
    expect((await get('owner', t).expect(403)).body.code).toBe('forbidden_role');
    expect((await get('owner', t).expect(403)).body.code).toBe('forbidden_role');
    expect((await get('work', t).expect(200)).body).toEqual({ ok: true });
    expect(db.audits).toHaveLength(2);
    expect(db.audits[0]).toMatchObject({
      actor: `staff:${STAFF_ID}`,
      action: 'access_denied',
      reasonCode: 'forbidden_role',
      detail: { route: 'GET /admin/probe/owner', role: 'moderator' },
    });
  });

  it('an analyst reaches only analyst routes', async () => {
    db.row = { ...OWNER_ROW(), role: 'analyst' };
    expect((await get('work', await token()).expect(403)).body.code).toBe('forbidden_role');
    expect((await get('session', await token()).expect(200)).body.role).toBe('analyst');
  });

  it('fails closed: a route without @AdminRoles is refused even for the Owner', async () => {
    expect((await get('unconfigured', await token()).expect(403)).body.code).toBe('forbidden_role');
  });

  it('outside production the development sign-in (email code) is accepted and reported as such', async () => {
    const t = await token({ aal: 'aal1', totp: false });
    expect((await get('session', t).expect(200)).body).toMatchObject({ mfa: 'challenge', firstFactor: 'dev' });
  });

  it('ADMIN_ALLOWED_EMAILS is a second gate on top of the table', async () => {
    const other = await boot({ ADMIN_ALLOWED_EMAILS: 'ak@akvega.test' });
    try {
      const ok = await request(other.app.getHttpServer()).get('/admin/probe/owner').set('Authorization', `Bearer ${await token()}`);
      expect(ok.status).toBe(200);
      const no = await request(other.app.getHttpServer())
        .get('/admin/probe/owner')
        .set('Authorization', `Bearer ${await token({ email: 'someone@akvega.test' })}`);
      expect(no.status).toBe(403);
      expect(no.body.code).toBe('not_staff');
    } finally {
      await other.app.close();
    }
  });
});

// ================================================================== REQ-ADM-01: SSO first factor + TOTP
describe('AdminGuard — SSO (Google Workspace) + TOTP, as in production', () => {
  let app: INestApplication;
  let db: FakeDb;
  const SSO_ROW = (): GuardRow => ({ ...OWNER_ROW(), google_domains: ['akvega.test'], providers: ['google'] });

  beforeAll(async () => {
    ({ app, db } = await boot({ NODE_ENV: 'production', ADMIN_SSO_PROVIDER: 'google', ADMIN_SSO_ALLOWED_DOMAINS: 'AKVega.test' }));
  });
  afterAll(() => app.close());
  beforeEach(() => {
    db.row = SSO_ROW();
    db.audits = [];
  });

  const get = (path: string, t: string) => request(app.getHttpServer()).get(`/admin/probe/${path}`).set('Authorization', `Bearer ${t}`);

  it('SSO first factor (oauth, allowed Workspace domain) + TOTP → allowed, reported as sso', async () => {
    expect((await get('owner', await token({ first: 'oauth' })).expect(200)).body).toEqual({ actor: `staff:${STAFF_ID}` });
    expect((await get('session', await token({ first: 'oauth' })).expect(200)).body).toMatchObject({ mfa: 'verified', firstFactor: 'sso' });
  });

  it('REQ-ADM-01: SSO login without MFA is denied (only the sign-in preflight answers, to start TOTP)', async () => {
    const aal1 = await token({ first: 'oauth', aal: 'aal1', totp: false });
    expect((await get('owner', aal1).expect(401)).body.code).toBe('mfa_required');
    expect((await get('work', aal1).expect(401)).body.code).toBe('mfa_required');
    expect((await get('session', aal1).expect(200)).body).toMatchObject({ mfa: 'challenge', firstFactor: 'sso' });
  });

  it('in production the email-code (or password) sign-in is refused: 403 sso_required, audited once per session', async () => {
    for (const first of ['otp', 'magiclink', 'password']) {
      const r = await get('owner', await token({ first }));
      expect(r.status).toBe(403);
      expect(r.body.code).toBe('sso_required');
    }
    expect((await get('session', await token({ first: 'otp', aal: 'aal1', totp: false })).expect(403)).body.code).toBe('sso_required');
    expect(db.audits).toHaveLength(1);
    expect(db.audits[0]).toMatchObject({ actor: 'unknown', action: 'access_denied', reasonCode: 'sso_required' });
    expect(JSON.stringify(db.audits)).not.toContain(STAFF_ID);
  });

  it('a Google account outside the Workspace domain (or a consumer account without `hd`) is refused', async () => {
    db.row = { ...SSO_ROW(), google_domains: ['gmail-lookalike.test'] };
    expect((await get('owner', await token({ first: 'oauth' })).expect(403)).body.code).toBe('sso_required');
    db.row = { ...SSO_ROW(), google_domains: [] };
    expect((await get('owner', await token({ first: 'oauth' })).expect(403)).body.code).toBe('sso_required');
  });

  it('an OAuth sign-in by an account that also has another external identity (e.g. Apple) is not trusted as SSO', async () => {
    db.row = { ...SSO_ROW(), providers: ['google', 'apple'] };
    expect((await get('owner', await token({ first: 'oauth' })).expect(403)).body.code).toBe('sso_required');
    db.row = { ...SSO_ROW(), providers: ['google', 'email'] };
    expect((await get('owner', await token({ first: 'oauth' })).expect(200)).body).toEqual({ actor: `staff:${STAFF_ID}` });
  });

  it('REQ-ADM-01 negative: an app user account can never sign in, even with a valid SSO + TOTP session', async () => {
    db.row = { ...SSO_ROW(), is_app_account: true };
    expect((await get('owner', await token({ first: 'oauth' })).expect(403)).body.code).toBe('staff_account_is_app_account');
    db.row = { ...SSO_ROW(), role: null, display_name: null, disabled: null };
    expect((await get('owner', await token({ first: 'oauth' })).expect(403)).body.code).toBe('not_staff');
  });
});

describe('firstFactor (pure)', () => {
  const sso = { provider: 'google' as const, domains: new Set(['akvega.test']), accounts: new Set<string>() };
  const claims = (...methods: string[]): JWTPayload => ({ amr: methods.map((method, i) => ({ method, timestamp: i })) });
  const row = { google_domains: ['akvega.test'], providers: ['google'] };

  it('sso needs the oauth method, an allowed domain and no other external identity', () => {
    expect(firstFactor(claims('totp', 'oauth'), row, { sso, allowEmailLogin: false })).toBe('sso');
    expect(firstFactor(claims('totp', 'otp'), row, { sso, allowEmailLogin: false })).toBeNull();
    expect(firstFactor(claims('oauth'), { google_domains: ['other.test'], providers: ['google'] }, { sso, allowEmailLogin: false })).toBeNull();
  });

  it('a listed personal Google account counts as SSO; an unlisted or unverified one does not (ADMIN_SSO_ALLOWED_ACCOUNTS)', () => {
    const accounts = { provider: 'google' as const, domains: new Set<string>(), accounts: new Set(['owner@gmail.com']) };
    const gmail = { google_domains: [], providers: ['google', 'email'], google_emails: ['owner@gmail.com'] };
    expect(firstFactor(claims('totp', 'oauth'), gmail, { sso: accounts, allowEmailLogin: false })).toBe('sso');
    expect(firstFactor(claims('oauth'), { ...gmail, google_emails: ['someone@gmail.com'] }, { sso: accounts, allowEmailLogin: false })).toBeNull();
    // The SQL only returns verified Google emails; none listed means refused.
    expect(firstFactor(claims('oauth'), { ...gmail, google_emails: [] }, { sso: accounts, allowEmailLogin: false })).toBeNull();
    // Another external identity still disqualifies the OAuth sign-in.
    expect(firstFactor(claims('oauth'), { ...gmail, providers: ['google', 'apple'] }, { sso: accounts, allowEmailLogin: false })).toBeNull();
    // An email-code sign-in by the same account is never SSO.
    expect(firstFactor(claims('otp'), gmail, { sso: accounts, allowEmailLogin: false })).toBeNull();
  });

  it('the development sign-in only while allowed; second factors and refreshes never count as a first factor', () => {
    expect(firstFactor(claims('otp'), row, { sso: null, allowEmailLogin: true })).toBe('dev');
    expect(firstFactor(claims('otp'), row, { sso: null, allowEmailLogin: false })).toBeNull();
    expect(firstFactor(claims('totp', 'token_refresh'), row, { sso: null, allowEmailLogin: true })).toBeNull();
    expect(firstFactor(claims('oauth'), row, { sso: null, allowEmailLogin: false })).toBeNull(); // SSO not configured
  });
});

describe('admin config: sign-in defaults', () => {
  it('email sign-in is on only for NODE_ENV development / test and never in production; SSO needs its domains', () => {
    expect(parseAdminConfig({ NODE_ENV: 'development' }).allowEmailLogin).toBe(true);
    expect(parseAdminConfig({ NODE_ENV: 'test' }).allowEmailLogin).toBe(true);
    expect(parseAdminConfig({ NODE_ENV: 'development', ADMIN_ALLOW_EMAIL_LOGIN: 'false' }).allowEmailLogin).toBe(false);
    const prod = parseAdminConfig({ NODE_ENV: 'production' });
    expect(prod.allowEmailLogin).toBe(false);
    expect(prod.warnings()).toEqual([expect.stringContaining('no console sign-in is configured')]);
    // SR-1 (docs/security/milestone-b-review.md): refused at boot in production, not merely warned about …
    expect(() => parseAdminConfig({ NODE_ENV: 'production', ADMIN_ALLOW_EMAIL_LOGIN: 'true' })).toThrow(/ADMIN_ALLOW_EMAIL_LOGIN.*refused in production/);
    expect(() => parseAdminConfig({ NODE_ENV: 'production', ADMIN_ALLOW_EMAIL_LOGIN: 'yes' })).toThrow(AdminConfigError);
    // … and fails closed when NODE_ENV is unset or unknown (a production deploy that forgot NODE_ENV).
    expect(parseAdminConfig({}).allowEmailLogin).toBe(false);
    expect(parseAdminConfig({ NODE_ENV: 'staging' }).allowEmailLogin).toBe(false);
    expect(parseAdminConfig({ NODE_ENV: 'staging', ADMIN_ALLOW_EMAIL_LOGIN: 'true' }).allowEmailLogin).toBe(true); // explicit, non-production
    expect(() => parseAdminConfig({ ADMIN_SSO_PROVIDER: 'google' })).toThrow(/ADMIN_SSO_ALLOWED_DOMAINS/);
    expect(() => parseAdminConfig({ ADMIN_SSO_PROVIDER: 'okta', ADMIN_SSO_ALLOWED_DOMAINS: 'akvega.test' })).toThrow(/ADMIN_SSO_PROVIDER/);
    const c = parseAdminConfig({ NODE_ENV: 'production', ADMIN_SSO_PROVIDER: 'google', ADMIN_SSO_ALLOWED_DOMAINS: 'AKVega.com, akvega.in' });
    expect(c.sso).toEqual({ provider: 'google', domains: new Set(['akvega.com', 'akvega.in']), accounts: new Set() });
    const byAccount = parseAdminConfig({ NODE_ENV: 'production', ADMIN_SSO_PROVIDER: 'google', ADMIN_SSO_ALLOWED_ACCOUNTS: 'A@Gmail.com, b@gmail.com' });
    expect(byAccount.sso?.accounts).toEqual(new Set(['a@gmail.com', 'b@gmail.com']));
    expect(c.warnings()).toEqual([]);
  });
});
