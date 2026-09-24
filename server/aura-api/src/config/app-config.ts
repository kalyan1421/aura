import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parseEnv } from 'node:util';
import { envSchema, type Env } from './config.schema';

/** Validated, immutable runtime configuration. Inject `AppConfig` anywhere. */
export class AppConfig {
  readonly env: Env['NODE_ENV'];
  readonly port: number;
  readonly workerHealthPort: number;
  readonly databaseUrl: string;
  readonly dbPoolMax: number;
  readonly redisUrl: string;
  readonly supabaseUrl: string;
  readonly jwtSecret: string | undefined;
  /** Explicit JWKS URL, else derived from SUPABASE_URL (used only for asymmetric tokens). */
  readonly jwksUrl: string;
  /** Expected `iss`: SUPABASE_JWT_ISSUER, else `${SUPABASE_URL}/auth/v1` (what GoTrue stamps). */
  readonly jwtIssuer: string;
  readonly masterKey: Buffer;
  /** Express `trust proxy` (SR-2); undefined = trust nothing. See config.schema.ts `trustProxySchema`. */
  readonly trustProxy: number | readonly string[] | undefined;

  constructor(e: Env) {
    this.env = e.NODE_ENV;
    this.port = e.PORT;
    this.workerHealthPort = e.WORKER_HEALTH_PORT;
    this.databaseUrl = e.DATABASE_URL;
    this.dbPoolMax = e.DB_POOL_MAX;
    this.redisUrl = e.REDIS_URL;
    this.supabaseUrl = e.SUPABASE_URL.replace(/\/+$/, '');
    this.jwtSecret = e.SUPABASE_JWT_SECRET;
    this.jwksUrl = e.SUPABASE_JWKS_URL ?? `${this.supabaseUrl}/auth/v1/.well-known/jwks.json`;
    this.jwtIssuer = e.SUPABASE_JWT_ISSUER ?? `${this.supabaseUrl}/auth/v1`;
    this.masterKey = Buffer.from(e.AURA_MASTER_KEY, 'base64');
    this.trustProxy = Array.isArray(e.TRUST_PROXY) ? Object.freeze([...e.TRUST_PROXY]) : e.TRUST_PROXY;
    Object.freeze(this);
  }
}

export class ConfigError extends Error {}

/** Validate an env record; throws a readable ConfigError listing every problem (never values). */
export function parseConfig(env: Record<string, string | undefined>): AppConfig {
  const r = envSchema.safeParse(env);
  if (!r.success) {
    const lines = r.error.issues.map((i) => `  - ${i.path.join('.') || '(env)'}: ${i.message}`);
    throw new ConfigError(`Invalid environment:\n${lines.join('\n')}`);
  }
  return new AppConfig(r.data);
}

/** Merge a dotenv file into `env` without overriding variables that are already set. */
export function loadEnvFile(file: string, env: NodeJS.ProcessEnv = process.env): void {
  if (!existsSync(file)) return;
  for (const [k, v] of Object.entries(parseEnv(readFileSync(file, 'utf8')))) {
    if (env[k] === undefined) env[k] = v;
  }
}

export const DEFAULT_ENV_FILE = resolve(__dirname, '..', '..', '.env');

/** Load `.env` (if present, real env vars win) then validate process.env. */
export function loadConfig(envFile = DEFAULT_ENV_FILE): AppConfig {
  loadEnvFile(envFile);
  return parseConfig(process.env);
}
