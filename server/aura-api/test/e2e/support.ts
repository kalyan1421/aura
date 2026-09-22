/**
 * E2E harness: real Nest app + live local Supabase (Auth + Postgres) + Redis.
 * Test users are created with the Auth admin API and signed in with a password grant, so the
 * guard verifies real GoTrue-issued ES256 tokens against the JWKS (see supabase/LOCAL.md).
 */
import { randomBytes } from 'node:crypto';
import { Logger, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Pool } from 'pg';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import { DEFAULT_ENV_FILE, loadEnvFile } from '../../src/config/app-config';

loadEnvFile(DEFAULT_ENV_FILE);

export const SUPABASE_URL = (process.env.SUPABASE_URL ?? 'http://127.0.0.1:55521').replace(/\/+$/, '');
const ANON = process.env.SUPABASE_ANON_KEY ?? '';
const SERVICE = process.env.SUPABASE_SERVICE_ROLE_KEY ?? '';

export interface TestUser {
  id: string;
  email: string;
  token: string;
}

export async function bootApp(): Promise<INestApplication> {
  Logger.overrideLogger(['error', 'warn']);
  const ref = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = ref.createNestApplication({ bodyParser: false });
  configureApp(app);
  await app.init();
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

export async function createUser(label: string): Promise<TestUser> {
  if (!ANON || !SERVICE) throw new Error('SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY missing (see .env.example)');
  const email = `e2e-${label}-${randomBytes(4).toString('hex')}@aura.test`;
  const password = `pw-${randomBytes(12).toString('hex')}`;
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
  return { id, email, token: access_token };
}

/** Deleting the auth user cascades every personal row (FKs are `on delete cascade`). */
export async function deleteUser(id: string): Promise<void> {
  await authFetch(`/admin/users/${id}`, SERVICE, undefined, 'DELETE').catch(() => undefined);
}

export const localAnonKey = (): string => ANON;
export const localServiceKey = (): string => SERVICE;
