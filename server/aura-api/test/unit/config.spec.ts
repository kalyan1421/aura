import { ConfigError, parseConfig } from '../../src/config/app-config';

const base = {
  DATABASE_URL: 'postgresql://postgres:postgres@127.0.0.1:55522/postgres',
  REDIS_URL: 'redis://127.0.0.1:6391',
  SUPABASE_URL: 'http://127.0.0.1:55521/',
  AURA_MASTER_KEY: Buffer.alloc(32, 7).toString('base64'),
};

describe('config (zod)', () => {
  it('parses a minimal env with defaults and derived JWT settings', () => {
    const c = parseConfig(base);
    expect(c.port).toBe(3310);
    expect(c.workerHealthPort).toBe(3311);
    expect(c.supabaseUrl).toBe('http://127.0.0.1:55521');
    expect(c.jwksUrl).toBe('http://127.0.0.1:55521/auth/v1/.well-known/jwks.json');
    expect(c.jwtIssuer).toBe('http://127.0.0.1:55521/auth/v1');
    expect(c.jwtSecret).toBeUndefined();
    expect(c.masterKey).toHaveLength(32);
  });

  it('SR-2 TRUST_PROXY: off by default; a hop count or a proxy list; `true` and junk are refused', () => {
    expect(parseConfig(base).trustProxy).toBeUndefined();
    expect(parseConfig({ ...base, TRUST_PROXY: '' }).trustProxy).toBeUndefined();
    expect(parseConfig({ ...base, TRUST_PROXY: 'false' }).trustProxy).toBeUndefined();
    expect(parseConfig({ ...base, TRUST_PROXY: '1' }).trustProxy).toBe(1);
    expect(parseConfig({ ...base, TRUST_PROXY: 'loopback, 10.0.0.0/8 ,fd00::/8' }).trustProxy).toEqual(['loopback', '10.0.0.0/8', 'fd00::/8']);
    for (const bad of ['true', 'TRUE', '11', 'everything', '10.0.0.0/8; drop']) {
      expect(() => parseConfig({ ...base, TRUST_PROXY: bad })).toThrow(/TRUST_PROXY/);
    }
  });

  it('treats empty optional vars as unset and honours overrides', () => {
    const c = parseConfig({ ...base, SUPABASE_JWT_SECRET: '', SUPABASE_JWKS_URL: 'https://x.test/jwks', PORT: '4000' });
    expect(c.jwtSecret).toBeUndefined();
    expect(c.jwksUrl).toBe('https://x.test/jwks');
    expect(c.port).toBe(4000);
  });

  it.each([
    ['master key of 16 bytes', { AURA_MASTER_KEY: Buffer.alloc(16).toString('base64') }, 'AURA_MASTER_KEY'],
    ['master key not base64', { AURA_MASTER_KEY: 'not base64!' }, 'AURA_MASTER_KEY'],
    ['missing DATABASE_URL', { DATABASE_URL: undefined }, 'DATABASE_URL'],
    ['non-redis REDIS_URL', { REDIS_URL: 'http://x' }, 'REDIS_URL'],
    ['short JWT secret', { SUPABASE_JWT_SECRET: 'short' }, 'SUPABASE_JWT_SECRET'],
  ])('rejects %s', (_, over, field) => {
    expect(() => parseConfig({ ...base, ...over })).toThrow(ConfigError);
    expect(() => parseConfig({ ...base, ...over })).toThrow(field);
  });

  it('never echoes secret values in the error', () => {
    try {
      parseConfig({ ...base, SUPABASE_JWT_SECRET: 'tiny-secret' });
      fail('expected throw');
    } catch (e) {
      expect(String(e)).not.toContain('tiny-secret');
    }
  });
});
