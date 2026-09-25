import { z } from 'zod';

const base64Key32 = z
  .string()
  .trim()
  .refine((v) => /^[A-Za-z0-9+/]+={0,2}$/.test(v) && Buffer.from(v, 'base64').length === 32, {
    message: 'must be base64 of exactly 32 bytes (openssl rand -base64 32)',
  });

const optionalNonEmpty = <T extends z.ZodType>(s: T) =>
  z.preprocess((v) => (typeof v === 'string' && v.trim() === '' ? undefined : v), s.optional());

/**
 * SR-2 (docs/security/milestone-b-review.md): Express `trust proxy`, so `req.ip` is the client behind a load balancer
 * and the per-client limits on the public routes (grievance form, deletion links, legal intake) stay per client instead
 * of collapsing into one bucket for everyone. Unset / `false` / `0` = trust nothing (req.ip is the socket peer).
 * A hop count (`1` = one load balancer in front) or a comma list of proxy addresses / CIDRs / Express keywords
 * (`loopback`, `linklocal`, `uniquelocal`). `true` is refused: it trusts any client-sent X-Forwarded-For, which would
 * let anyone pick their own rate-limit bucket.
 */
const PROXY_TOKEN = /^(loopback|linklocal|uniquelocal|[0-9a-fA-F:.]+(\/\d{1,3})?)$/;
export const trustProxySchema = z
  .string()
  .trim()
  .transform((v, ctx): number | string[] | undefined => {
    const lower = v.toLowerCase();
    if (lower === '' || lower === 'false' || lower === '0') return undefined;
    if (/^\d+$/.test(lower)) {
      const hops = Number(lower);
      if (hops >= 1 && hops <= 10) return hops;
    } else {
      const list = v.split(',').map((t) => t.trim()).filter(Boolean);
      if (list.length > 0 && list.every((t) => PROXY_TOKEN.test(t))) return list;
    }
    ctx.addIssue({
      code: 'custom',
      message: 'must be a hop count 1–10 or a comma list of proxy addresses / CIDRs (loopback, linklocal, uniquelocal); `true` is not allowed',
    });
    return z.NEVER;
  });

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3310),
  WORKER_HEALTH_PORT: z.coerce.number().int().min(1).max(65535).default(3311),
  DATABASE_URL: z.string().regex(/^postgres(ql)?:\/\//, 'must be a postgres:// URL'),
  DB_POOL_MAX: z.coerce.number().int().min(1).max(100).default(10),
  // PEM of the database server's CA (e.g. Supabase Root 2021 CA). Set → TLS with full verification against it.
  DATABASE_CA_CERT: optionalNonEmpty(z.string().includes('BEGIN CERTIFICATE', { message: 'must be a PEM certificate' })),
  REDIS_URL: z.string().regex(/^rediss?:\/\//, 'must be a redis:// URL'),
  SUPABASE_URL: z.url(),
  SUPABASE_JWT_SECRET: optionalNonEmpty(z.string().min(32, 'must be at least 32 characters')),
  SUPABASE_JWKS_URL: optionalNonEmpty(z.url()),
  SUPABASE_JWT_ISSUER: optionalNonEmpty(z.string()),
  AURA_MASTER_KEY: base64Key32,
  TRUST_PROXY: z.preprocess((v) => (v === undefined ? '' : v), trustProxySchema),
});

export type Env = z.infer<typeof envSchema>;
