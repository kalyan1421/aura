/**
 * E2E harness: real Nest app + live local Supabase (Auth + Postgres) + Redis.
 * Test users are created with the Auth admin API and signed in with a password grant, so the
 * guard verifies real GoTrue-issued ES256 tokens against the JWKS (see supabase/LOCAL.md).
 */
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { Logger, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { SignJWT, importJWK, type JWK } from 'jose';
import { Pool } from 'pg';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import { DEFAULT_ENV_FILE, loadEnvFile } from '../../src/config/app-config';

loadEnvFile(DEFAULT_ENV_FILE);

export const SUPABASE_URL = (process.env.SUPABASE_URL ?? 'http://127.0.0.1:55521').replace(/\/+$/, '');
const ANON = process.env.SUPABASE_ANON_KEY ?? '';
let SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';

export async function bootApp(): Promise<INestApplication> {
  await ensureServiceKey(); // may export a working SUPABASE_SERVICE_ROLE_KEY before the app reads its env
  Logger.overrideLogger(['error', 'warn']);
  const ref = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = ref.createNestApplication({ bodyParser: false });
  configureApp(app);
  await app.init();
  // Listen once on a fixed ephemeral port: otherwise supertest listen(0)s + closes per request, and a
  // request can race a closing server onto a port another local process has just taken (flaky 200s).
  await app.listen(0, '127.0.0.1');
  return app;
}

export function dbPool(): Pool {
  return new Pool({ connectionString: process.env.DATABASE_URL, max: 3 });
}

async function authFetch(path: string, key: string, body: unknown, method = 'POST'): Promise<Response> {
  return fetch(`${SUPABASE_URL}/auth/v1${path}`, {
    method,
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

export interface TestUser {
  id: string;
  email: string;
  token: string;
  /** The password the user signed up with (for password grants). */
  password?: string;
}

let adminWorks: boolean | undefined;
let keyReady: Promise<void> | undefined;

async function adminAccepts(key: string): Promise<boolean> {
  const r = await authFetch('/admin/users?per_page=1', key, undefined, 'GET').catch(() => undefined);
  return r?.ok === true;
}

/**
 * A service_role token signed with the local stack's own ES256 dev key, read from the running Auth container
 * (`docker exec … printenv GOTRUE_JWT_KEYS`). A newer local GoTrue signs with asymmetric keys and rejects the legacy
 * HS256 service key on `/admin/*`; Kong, PostgREST and Storage accept the minted token as both `apikey` and bearer.
 * Local development only: `undefined` when Docker or the container is not there.
 */
async function mintLocalServiceKey(): Promise<string | undefined> {
  try {
    const container = process.env.E2E_AUTH_CONTAINER ?? 'supabase_auth_aura';
    const raw = execFileSync('docker', ['exec', container, 'printenv', 'GOTRUE_JWT_KEYS'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    const jwk = (JSON.parse(raw) as JWK[]).find((k) => k.alg === 'ES256' && k.d);
    if (!jwk) return undefined;
    const now = Math.floor(Date.now() / 1000);
    return await new SignJWT({ role: 'service_role' })
      .setProtectedHeader({ alg: 'ES256', kid: jwk.kid, typ: 'JWT' })
      .setIssuer(`${SUPABASE_URL}/auth/v1`)
      .setAudience('authenticated')
      .setIssuedAt(now)
      .setExpirationTime(now + 6 * 3600)
      .sign(await importJWK(jwk, 'ES256'));
  } catch {
    return undefined;
  }
}

/**
 * Makes sure the service key in use works on GoTrue's `/admin/*`. Where the configured key already does (older stacks,
 * a hosted project) nothing changes. Otherwise a local key is minted (see above) and exported as
 * `SUPABASE_SERVICE_ROLE_KEY`, so the API under test (App Review sign-in uses the GoTrue admin API) works too. With
 * neither, {@link gotrueAdminWorks} is false and the helpers fall back to sign-up plus SQL.
 */
export function ensureServiceKey(): Promise<void> {
  keyReady ??= (async () => {
    if (await adminAccepts(SERVICE)) {
      adminWorks = true;
      return;
    }
    const minted = await mintLocalServiceKey();
    if (minted && (await adminAccepts(minted))) {
      SERVICE = minted;
      process.env.SUPABASE_SERVICE_ROLE_KEY = minted;
      adminWorks = true;
      return;
    }
    adminWorks = false;
  })();
  return keyReady;
}

/** Whether GoTrue's `/admin/*` accepts the service key in use (after {@link ensureServiceKey}). */
export async function gotrueAdminWorks(): Promise<boolean> {
  await ensureServiceKey();
  return adminWorks === true;
}

let sqlPool: Pool | undefined;
const sql = (): Pool => (sqlPool ??= new Pool({ connectionString: process.env.DATABASE_URL, max: 2 }));

/** Ends the fallback pool (a no-op when it was never needed). Call from `afterAll` if you like. */
export async function closeSupportPool(): Promise<void> {
  await sqlPool?.end();
  sqlPool = undefined;
}

export async function createUser(label: string): Promise<TestUser> {
  if (!ANON || !SERVICE) throw new Error('SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY missing (see .env.example)');
  const email = `e2e-${label}-${randomBytes(4).toString('hex')}@aura.test`;
  const password = `pw-${randomBytes(12).toString('hex')}`;
  if (await gotrueAdminWorks()) {
    const created = await authFetch('/admin/users', SERVICE, { email, password, email_confirm: true });
    if (!created.ok) throw new Error(`admin create user failed: ${created.status} ${await created.text()}`);
    const { id } = (await created.json()) as { id: string };
    const session = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { apikey: ANON, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    if (!session.ok) throw new Error(`password grant failed: ${session.status} ${await session.text()}`);
    const { access_token } = (await session.json()) as { access_token: string };
    return { id, email, token: access_token, password };
  }
  // Self sign-up with the anon key returns a session straight away (email confirmations are off locally).
  const signup = await fetch(`${SUPABASE_URL}/auth/v1/signup`, {
    method: 'POST',
    headers: { apikey: ANON, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!signup.ok) throw new Error(`sign-up failed: ${signup.status} ${await signup.text()}`);
  const body = (await signup.json()) as { access_token?: string; user?: { id: string }; id?: string };
  const id = body.user?.id ?? body.id;
  if (!body.access_token || !id) throw new Error('sign-up returned no session (are email confirmations off locally?)');
  return { id, email, token: body.access_token, password };
}

/** Deleting the auth user cascades every personal row (FKs are `on delete cascade`). */
export async function deleteUser(id: string): Promise<void> {
  if (await gotrueAdminWorks()) {
    await authFetch(`/admin/users/${id}`, SERVICE, undefined, 'DELETE').catch(() => undefined);
    return;
  }
  await sql().query('delete from auth.users where id = $1', [id]).catch(() => undefined);
}

/**
 * Deletes a user through GoTrue's admin API (so triggers that audit by DB role see `supabase_auth_admin`). Returns
 * the HTTP status. Needs {@link gotrueAdminWorks}: there is no honest substitute, so without it this throws.
 */
export async function removeUserViaAuth(id: string): Promise<number> {
  if (!(await gotrueAdminWorks())) {
    throw new Error('GoTrue admin is unavailable here (no working service key and no local Docker stack to mint one)');
  }
  const res = await authFetch(`/admin/users/${id}`, SERVICE, undefined, 'DELETE');
  return res.status;
}

/** Sets a user's password (GoTrue admin `PUT /admin/users/:id`, or bcrypt in SQL when admin is unavailable). */
export async function setUserPassword(id: string, password: string): Promise<void> {
  if (await gotrueAdminWorks()) {
    await authFetch(`/admin/users/${id}`, SERVICE, { password }, 'PUT');
    return;
  }
  await sql().query(`update auth.users set encrypted_password = extensions.crypt($2, extensions.gen_salt('bf')) where id = $1`, [id, password]);
}

export const localAnonKey = (): string => ANON;
export const localServiceKey = (): string => SERVICE;
