import { Reflector } from '@nestjs/core';
import { IS_PUBLIC } from '../../src/auth/public.decorator';
import {
  GoTrueReviewSessionMinter,
  REVIEW_SIGN_IN_LIMIT,
  ReviewSignInController,
  ReviewSignInService,
  reviewAccountFromEnv,
  sameSecret,
  type ReviewSession,
  type ReviewSessionMinter,
} from '../../src/auth/review-sign-in';
import { ApiError } from '../../src/common/api-error';

/**
 * POST /v1/auth/review-sign-in (docs/setup/app-review.md): off unless configured, one generic 401 for any mismatch,
 * rate-limited per client, a session only for the configured account, audited without the code / email / tokens.
 */

const ENV = { REVIEW_ACCOUNT_EMAIL: 'Review@Aura.test', REVIEW_ACCOUNT_CODE: '481516' } as NodeJS.ProcessEnv;
const SESSION: ReviewSession = { userId: '0199a1b2-0000-7000-8000-000000000001', accessToken: 'at', refreshToken: 'rt', expiresIn: 3600 };

class FakeMinter implements ReviewSessionMinter {
  calls: string[] = [];
  result: ReviewSession | null | Error = SESSION;
  async mint(email: string): Promise<ReviewSession | null> {
    this.calls.push(email);
    if (this.result instanceof Error) throw this.result;
    return this.result;
  }
}

class FakeLimiter {
  hits = new Map<string, number>();
  bucket(v: string): string {
    return `b(${v})`;
  }
  async hit(name: string, limit: number): Promise<boolean> {
    const n = (this.hits.get(name) ?? 0) + 1;
    this.hits.set(name, n);
    return n <= limit;
  }
}

class FakeDb {
  audits: Array<{ sql: string; params: unknown[] }> = [];
  async query(sql: string, params: unknown[]): Promise<{ rows: Array<{ id: string }> }> {
    this.audits.push({ sql, params });
    return { rows: [{ id: '1' }] };
  }
}

const setup = () => {
  const minter = new FakeMinter();
  const limiter = new FakeLimiter();
  const db = new FakeDb();
  const service = new ReviewSignInService(minter, limiter as never, db as never, { masterKey: Buffer.alloc(32, 7) } as never);
  return { minter, limiter, db, service };
};

const fail = (p: Promise<unknown>): Promise<ApiError> => p.then(() => { throw new Error('expected a refusal'); }, (e: unknown) => e as ApiError);

describe('review sign-in: configuration', () => {
  it('both env vars set (a 6-digit code, what the app field takes) → on; email normalised', () => {
    expect(reviewAccountFromEnv(ENV)).toEqual({ email: 'review@aura.test', code: '481516' });
  });

  it.each([
    [{}],
    [{ REVIEW_ACCOUNT_EMAIL: 'review@aura.test' }],
    [{ REVIEW_ACCOUNT_CODE: '481516' }],
    [{ REVIEW_ACCOUNT_EMAIL: ' ', REVIEW_ACCOUNT_CODE: '481516' }],
    [{ REVIEW_ACCOUNT_EMAIL: 'review@aura.test', REVIEW_ACCOUNT_CODE: '12345' }],
    [{ REVIEW_ACCOUNT_EMAIL: 'review@aura.test', REVIEW_ACCOUNT_CODE: '1234567' }],
    [{ REVIEW_ACCOUNT_EMAIL: 'review@aura.test', REVIEW_ACCOUNT_CODE: 'abcdef' }],
    [{ REVIEW_ACCOUNT_EMAIL: 'not-an-email', REVIEW_ACCOUNT_CODE: '481516' }],
  ])('off for %j', (env) => {
    expect(reviewAccountFromEnv(env as NodeJS.ProcessEnv)).toBeNull();
  });

  it('sameSecret compares any lengths without throwing', () => {
    expect(sameSecret('abc', 'abc')).toBe(true);
    expect(sameSecret('abc', 'abcd')).toBe(false);
    expect(sameSecret('', 'x')).toBe(false);
  });

  it('the route is public (no Supabase session yet)', () => {
    expect(new Reflector().get(IS_PUBLIC, ReviewSignInController.prototype.signIn)).toBe(true);
  });
});

describe('review sign-in: the service', () => {
  it('env unset → 404, before any rate-limit or mint', async () => {
    const { service, minter, limiter } = setup();
    const e = await fail(service.signIn({ email: 'review@aura.test', code: '481516' }, '1.2.3.4', {}));
    expect(e).toMatchObject({ status: 404, code: 'not_found' });
    expect(minter.calls).toEqual([]);
    expect(limiter.hits.size).toBe(0);
  });

  it('matching email (any case, spaces) and code → a session for the configured account, audited without secrets', async () => {
    const { service, minter, db } = setup();
    const out = await service.signIn({ email: '  REVIEW@aura.TEST ', code: ' 481516 ' }, '1.2.3.4', ENV);
    expect(out).toEqual({ access_token: 'at', refresh_token: 'rt', expires_in: 3600, token_type: 'bearer' });
    expect(minter.calls).toEqual(['review@aura.test']);
    expect(db.audits).toHaveLength(1);
    const params = JSON.stringify(db.audits[0].params);
    expect(params).toContain('review_sign_in');
    expect(params).toMatch(/[0-9a-f]{64}/); // subject hash, not the id
    for (const secret of ['481516', 'review@aura.test', 'at', 'rt', SESSION.userId]) {
      expect(db.audits[0].params.map(String)).not.toContain(secret);
    }
    expect(params).not.toContain(SESSION.userId);
    expect(params).not.toContain('481516');
  });

  it.each([
    ['wrong code', { email: 'review@aura.test', code: '00000000' }],
    ['another email with the right code', { email: 'someone@aura.test', code: '481516' }],
    ['another email, wrong code', { email: 'someone@aura.test', code: '123456' }],
    ['malformed body', { email: 42 }],
    ['no body', undefined],
  ])('%s → the same generic 401 invalid_code, nothing minted or audited', async (_label, body) => {
    const { service, minter, db } = setup();
    const e = await fail(service.signIn(body, '1.2.3.4', ENV));
    expect(e).toBeInstanceOf(ApiError);
    expect(e).toMatchObject({ status: 401, code: 'invalid_code', message: "That code didn't work." });
    expect(minter.calls).toEqual([]);
    expect(db.audits).toEqual([]);
  });

  it(`rate limit: ${REVIEW_SIGN_IN_LIMIT} attempts per client address per hour, then 429 (even with the right code)`, async () => {
    const { service, limiter } = setup();
    for (let i = 0; i < REVIEW_SIGN_IN_LIMIT; i++) {
      expect(await fail(service.signIn({ email: 'x@aura.test', code: '000000' }, '9.9.9.9', ENV))).toMatchObject({ status: 401 });
    }
    expect(await fail(service.signIn({ email: 'review@aura.test', code: '481516' }, '9.9.9.9', ENV))).toMatchObject({ status: 429, code: 'rate_limited' });
    // Another client is not affected; the bucket is an HMAC of the address, never the address itself.
    await expect(service.signIn({ email: 'review@aura.test', code: '481516' }, '8.8.8.8', ENV)).resolves.toMatchObject({ access_token: 'at' });
    expect([...limiter.hits.keys()].every((k) => k.startsWith('review-sign-in:b('))).toBe(true);
  });

  it('no service role key / GoTrue failure → 503, never a session', async () => {
    const a = setup();
    a.minter.result = null;
    expect(await fail(a.service.signIn({ email: 'review@aura.test', code: '481516' }, '1.1.1.1', ENV))).toMatchObject({ status: 503, code: 'review_sign_in_unavailable' });
    const b = setup();
    b.minter.result = new Error('generate_link 500');
    expect(await fail(b.service.signIn({ email: 'review@aura.test', code: '481516' }, '1.1.1.1', ENV))).toMatchObject({ status: 503 });
    expect([...a.db.audits, ...b.db.audits]).toEqual([]);
  });
});

describe('review sign-in: the GoTrue admin flow', () => {
  it('generate_link (magiclink, service key) → its email_otp → verify (type email) → the session', async () => {
    const calls: Array<{ url: string; body: Record<string, unknown>; headers: Record<string, string> }> = [];
    const fakeFetch = (async (url: string, init: RequestInit) => {
      const body = JSON.parse(String(init.body)) as Record<string, unknown>;
      calls.push({ url, body, headers: init.headers as Record<string, string> });
      if (url.endsWith('/admin/generate_link')) return new Response(JSON.stringify({ id: 'u-1', email_otp: '424242', action_link: 'x' }), { status: 200 });
      return new Response(JSON.stringify({ access_token: 'A', refresh_token: 'R', expires_in: 1800, token_type: 'bearer' }), { status: 200 });
    }) as unknown as typeof fetch;
    const m = new GoTrueReviewSessionMinter('http://gotrue.test', { SUPABASE_SERVICE_ROLE_KEY: 'svc' } as NodeJS.ProcessEnv, fakeFetch);
    expect(await m.mint('review@aura.test')).toEqual({ userId: 'u-1', accessToken: 'A', refreshToken: 'R', expiresIn: 1800 });
    expect(calls[0]).toMatchObject({ url: 'http://gotrue.test/auth/v1/admin/generate_link', body: { type: 'magiclink', email: 'review@aura.test' } });
    expect(calls[0].headers.Authorization).toBe('Bearer svc');
    expect(calls[1]).toMatchObject({ url: 'http://gotrue.test/auth/v1/verify', body: { type: 'email', email: 'review@aura.test', token: '424242' } });
  });

  it('no service role key → null (no call); a GoTrue error → throws', async () => {
    let called = false;
    const noCall = (async () => {
      called = true;
      return new Response('{}');
    }) as unknown as typeof fetch;
    expect(await new GoTrueReviewSessionMinter('http://g', {} as NodeJS.ProcessEnv, noCall).mint('r@a.test')).toBeNull();
    expect(called).toBe(false);
    const failing = (async () => new Response('{"msg":"nope"}', { status: 500 })) as unknown as typeof fetch;
    await expect(new GoTrueReviewSessionMinter('http://g', { SUPABASE_SERVICE_ROLE_KEY: 'k' } as NodeJS.ProcessEnv, failing).mint('r@a.test')).rejects.toThrow('generate_link 500');
  });
});
