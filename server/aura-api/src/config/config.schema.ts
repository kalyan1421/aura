import { z } from 'zod';

const base64Key32 = z
  .string()
  .trim()
  .refine((v) => /^[A-Za-z0-9+/]+={0,2}$/.test(v) && Buffer.from(v, 'base64').length === 32, {
    message: 'must be base64 of exactly 32 bytes (openssl rand -base64 32)',
  });

const optionalNonEmpty = <T extends z.ZodType>(s: T) =>
  z.preprocess((v) => (typeof v === 'string' && v.trim() === '' ? undefined : v), s.optional());

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3310),
  WORKER_HEALTH_PORT: z.coerce.number().int().min(1).max(65535).default(3311),
  DATABASE_URL: z.string().regex(/^postgres(ql)?:\/\//, 'must be a postgres:// URL'),
  DB_POOL_MAX: z.coerce.number().int().min(1).max(100).default(10),
  REDIS_URL: z.string().regex(/^rediss?:\/\//, 'must be a redis:// URL'),
  SUPABASE_URL: z.url(),
  SUPABASE_JWT_SECRET: optionalNonEmpty(z.string().min(32, 'must be at least 32 characters')),
  SUPABASE_JWKS_URL: optionalNonEmpty(z.url()),
  SUPABASE_JWT_ISSUER: optionalNonEmpty(z.string()),
  AURA_MASTER_KEY: base64Key32,
});

export type Env = z.infer<typeof envSchema>;
