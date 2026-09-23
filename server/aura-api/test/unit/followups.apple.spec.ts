/**
 * Sign in with Apple token revocation (App Review 5.1.1(v); PRD F8 REQ-ACC-11 "Apple token revoked"): the REST client
 * (ES256 client secret, code exchange, revoke, error mapping) against a fake Apple, sealing at rest, the vault, and
 * the account service's POST /v1/account/apple-auth + best-effort revoke on deletion. The same flows run against the
 * real DB, API and a fake Apple HTTP server in test/e2e/account-followups.e2e-spec.ts.
 */
import { generateKeyPairSync, type KeyObject } from 'node:crypto';
import { decodeProtectedHeader, jwtVerify, SignJWT } from 'jose';
import { AccountService } from '../../src/account/account.service';
import {
  AppleRejectedError,
  AppleSignInClient,
  AppleUnavailableError,
  appleConfigFromEnv,
  normalizeP8,
  type AppleSignInConfig,
} from '../../src/account/apple-sign-in';
import {
  AppleIdentityMismatchError,
  AppleTokenUnreadableError,
  AppleTokenVault,
  openAppleToken,
  sealAppleToken,
} from '../../src/account/apple-tokens';
import { ApiError } from '../../src/common/api-error';
import type { Queryable } from '../../src/db/db';
import type { QueryResult, QueryResultRow } from 'pg';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const OTHER = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const MASTER = Buffer.alloc(32, 7);
const APPLE_SUB = '001234.abcdef0123456789.0042';
const CODE = 'c1a2b3.0.mrsx.one-time-code';
const REFRESH = 'r7f1e2d3c4b5a6.0.mrsx.refresh-token-value';

const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const PEM = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();
const PUBLIC: KeyObject = publicKey;

const CONFIG: AppleSignInConfig = { teamId: 'AQLMTLP6PD', keyId: 'ABC123DEFG', privateKey: PEM, clientId: 'com.akvega.aura' };

interface Call {
  url: string;
  form: URLSearchParams;
}

/** Apple stand-in: records form posts, answers with `reply` (default: 200 + a token response). */
function fakeApple(reply?: (c: Call) => Response | Promise<Response>) {
  const calls: Call[] = [];
  const fetchFn = (async (url: string, init: RequestInit) => {
    const call = { url, form: new URLSearchParams(String(init.body)) };
    calls.push(call);
    if (reply) return reply(call);
    return tokenResponse();
  }) as unknown as typeof fetch;
  return { calls, fetchFn };
}

async function idToken(aud = CONFIG.clientId, sub = APPLE_SUB): Promise<string> {
  return new SignJWT({ email: 'relay@privaterelay.appleid.com' })
    .setProtectedHeader({ alg: 'ES256', kid: 'apple-test' })
    .setIssuer('https://appleid.apple.com')
    .setAudience(aud)
    .setSubject(sub)
    .setIssuedAt()
    .setExpirationTime('10m')
    .sign(privateKey);
}

async function tokenResponse(over: Record<string, unknown> = {}): Promise<Response> {
  return new Response(
    JSON.stringify({ access_token: 'a', token_type: 'Bearer', expires_in: 3600, refresh_token: REFRESH, id_token: await idToken(), ...over }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
}

const errorResponse = (status: number, error?: string): Response =>
  new Response(error ? JSON.stringify({ error }) : 'nope', { status });

/** `config: null` = no APPLE_* configuration. */
const client = (reply?: (c: Call) => Response | Promise<Response>, config: AppleSignInConfig | null = CONFIG) => {
  const apple = fakeApple(reply);
  return {
    ...apple,
    client: new AppleSignInClient({ config: config ?? undefined, baseUrl: 'https://apple.test', fetch: apple.fetchFn }),
  };
};

describe('configuration (APPLE_* env)', () => {
  const full = { APPLE_TEAM_ID: 'AQLMTLP6PD', APPLE_KEY_ID: 'ABC123DEFG', APPLE_PRIVATE_KEY: PEM, APPLE_CLIENT_ID: 'com.akvega.aura' };

  it('all four values → configured; any missing → not configured (503 apple_unavailable, purge waits)', () => {
    expect(AppleSignInClient.fromEnv(full).configured).toBe(true);
    expect(AppleSignInClient.fromEnv(full).clientId).toBe('com.akvega.aura');
    for (const k of Object.keys(full)) {
      const env = { ...full, [k]: '  ' };
      expect(appleConfigFromEnv(env)).toBeUndefined();
      expect(AppleSignInClient.fromEnv(env).configured).toBe(false);
    }
    expect(AppleSignInClient.fromEnv({}).configured).toBe(false);
  });

  it('a malformed team / key / client id counts as not configured', () => {
    expect(AppleSignInClient.fromEnv({ ...full, APPLE_TEAM_ID: 'team' }).configured).toBe(false);
    expect(AppleSignInClient.fromEnv({ ...full, APPLE_KEY_ID: 'abc123defg' }).configured).toBe(false);
    expect(AppleSignInClient.fromEnv({ ...full, APPLE_CLIENT_ID: 'not a bundle id' }).configured).toBe(false);
  });

  it('the .p8 works with real newlines, \\n escapes (one-line env values) or just its base64 body', async () => {
    const escaped = PEM.replace(/\n/g, '\\n');
    const body = PEM.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '');
    for (const raw of [PEM, escaped, body]) {
      expect(normalizeP8(raw)).toContain('-----BEGIN PRIVATE KEY-----');
      const c = new AppleSignInClient({ config: { ...CONFIG, privateKey: raw } });
      await expect(jwtVerify(await c.clientSecret(), PUBLIC)).resolves.toBeDefined();
    }
  });

  it('a key that is not an ES256 .p8 → AppleUnavailableError at first use (never the key in the message)', async () => {
    const c = new AppleSignInClient({ config: { ...CONFIG, privateKey: 'bm90LWEta2V5' }, fetch: fakeApple().fetchFn });
    const err = await c.exchangeCode(CODE).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AppleUnavailableError);
    expect((err as Error).message).not.toContain('bm90LWEta2V5');
  });
});

describe('AppleSignInClient', () => {
  const at = new Date('2026-10-08T10:00:00Z');

  it('client secret: ES256 JWT, kid = key id, iss = team, sub = client, aud = appleid.apple.com, 1 h', async () => {
    const c = new AppleSignInClient({ config: CONFIG, now: () => at });
    const secret = await c.clientSecret();
    expect(decodeProtectedHeader(secret)).toEqual({ alg: 'ES256', kid: 'ABC123DEFG' });
    const { payload } = await jwtVerify(secret, PUBLIC, { currentDate: at });
    expect(payload).toEqual({
      iss: 'AQLMTLP6PD',
      sub: 'com.akvega.aura',
      aud: 'https://appleid.apple.com',
      iat: at.getTime() / 1000,
      exp: at.getTime() / 1000 + 3600,
    });
    const other = await jwtVerify(await c.clientSecret('com.akvega.aura.signin'), PUBLIC, { currentDate: at });
    expect(other.payload.sub).toBe('com.akvega.aura.signin');
  });

  it('exchangeCode posts the code form to /auth/token and returns the refresh token + Apple user id', async () => {
    const { client: c, calls } = client();
    await expect(c.exchangeCode(CODE)).resolves.toEqual({ refreshToken: REFRESH, subject: APPLE_SUB, clientId: 'com.akvega.aura' });
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe('https://apple.test/auth/token');
    const f = Object.fromEntries(calls[0].form);
    expect(f).toEqual({ client_id: 'com.akvega.aura', client_secret: expect.any(String), code: CODE, grant_type: 'authorization_code' });
    await expect(jwtVerify(f.client_secret, PUBLIC)).resolves.toMatchObject({ payload: { sub: 'com.akvega.aura' } });
  });

  it('an id_token for another client gives no subject (the vault then refuses to store the token)', async () => {
    const { client: c } = client(async () => tokenResponse({ id_token: await idToken('com.someone.else') }));
    await expect(c.exchangeCode(CODE)).resolves.toMatchObject({ subject: null });
    const { client: c2 } = client(async () => tokenResponse({ id_token: 'garbage' }));
    await expect(c2.exchangeCode(CODE)).resolves.toMatchObject({ subject: null });
  });

  it.each([
    ['400 invalid_grant (expired / used code)', () => errorResponse(400, 'invalid_grant'), AppleRejectedError],
    ['400 invalid_request', () => errorResponse(400, 'invalid_request'), AppleRejectedError],
    ['400 invalid_client (our key / team / client id)', () => errorResponse(400, 'invalid_client'), AppleUnavailableError],
    ['401', () => errorResponse(401), AppleUnavailableError],
    ['500', () => errorResponse(500), AppleUnavailableError],
    ['200 without a refresh token', () => tokenResponse({ refresh_token: undefined }), AppleUnavailableError],
    ['200 that is not JSON', () => new Response('<html>', { status: 200 }), AppleUnavailableError],
  ])('exchange: %s', async (_, reply, type) => {
    const { client: c } = client(reply as () => Response);
    const err = await c.exchangeCode(CODE).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(type);
    expect((err as Error).message).not.toContain(CODE);
  });

  it('network failure and timeout → AppleUnavailableError (unreachable / timeout)', async () => {
    const down = new AppleSignInClient({
      config: CONFIG,
      fetch: (async () => {
        throw new TypeError('fetch failed');
      }) as unknown as typeof fetch,
    });
    await expect(down.exchangeCode(CODE)).rejects.toMatchObject({ name: 'AppleUnavailableError', reason: 'unreachable' });
    const slow = new AppleSignInClient({
      config: CONFIG,
      timeoutMs: 20,
      fetch: ((_: string, init: RequestInit) =>
        new Promise((_resolve, reject) => {
          init.signal?.addEventListener('abort', () => reject(init.signal?.reason));
        })) as unknown as typeof fetch,
    });
    await expect(slow.exchangeCode(CODE)).rejects.toMatchObject({ name: 'AppleUnavailableError', reason: 'timeout' });
  });

  it('revoke posts the refresh token with token_type_hint to /auth/revoke, signed for the token’s own client', async () => {
    const { client: c, calls } = client(() => new Response('', { status: 200 }));
    await c.revokeRefreshToken(REFRESH, 'com.akvega.aura');
    expect(calls[0].url).toBe('https://apple.test/auth/revoke');
    const f = Object.fromEntries(calls[0].form);
    expect(f).toEqual({ client_id: 'com.akvega.aura', client_secret: expect.any(String), token: REFRESH, token_type_hint: 'refresh_token' });
    expect((await jwtVerify(f.client_secret, PUBLIC)).payload.sub).toBe('com.akvega.aura');
  });

  it('revoke: an already-invalid token (invalid_grant) is done; other refusals and outages throw', async () => {
    await expect(client(() => errorResponse(400, 'invalid_grant')).client.revokeRefreshToken(REFRESH)).resolves.toBeUndefined();
    await expect(client(() => errorResponse(400, 'unsupported_token_type')).client.revokeRefreshToken(REFRESH)).rejects.toBeInstanceOf(
      AppleRejectedError,
    );
    const err = await client(() => errorResponse(503)).client.revokeRefreshToken(REFRESH).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(AppleUnavailableError);
    expect((err as Error).message).not.toContain(REFRESH);
  });

  it('not configured → AppleUnavailableError without calling Apple', async () => {
    const { client: c, calls } = client(undefined, null);
    expect(c.configured).toBe(false);
    await expect(c.exchangeCode(CODE)).rejects.toMatchObject({ reason: 'not configured' });
    await expect(c.revokeRefreshToken(REFRESH, 'com.akvega.aura')).rejects.toBeInstanceOf(AppleUnavailableError);
    expect(calls).toHaveLength(0);
  });
});

describe('refresh tokens at rest (AURA_MASTER_KEY, like user_data_keys)', () => {
  it('round-trips, never contains the token, and is bound to the user id', () => {
    const sealed = sealAppleToken(MASTER, USER, REFRESH);
    expect(sealed).not.toContain(REFRESH);
    expect(Buffer.from(sealed, 'base64').toString('latin1')).not.toContain(REFRESH);
    expect(openAppleToken(MASTER, USER, sealed)).toBe(REFRESH);
    expect(openAppleToken(MASTER, USER.toUpperCase(), sealed)).toBe(REFRESH);
    expect(sealAppleToken(MASTER, USER, REFRESH)).not.toBe(sealed); // fresh IV each time
    expect(() => openAppleToken(MASTER, OTHER, sealed)).toThrow(); // copied onto another account's row
    expect(() => openAppleToken(Buffer.alloc(32, 8), USER, sealed)).toThrow(); // another master key
    const tampered = Buffer.from(sealed, 'base64');
    tampered[14] ^= 1;
    expect(() => openAppleToken(MASTER, USER, tampered.toString('base64'))).toThrow();
  });
});

const result = <R extends QueryResultRow>(rows: unknown[], rowCount = rows.length): QueryResult<R> =>
  ({ rows, rowCount }) as unknown as QueryResult<R>;

/** Answers the vault's three queries from an in-memory row; records them. */
class TokenDb implements Queryable {
  row: { client_id: string; wrapped_refresh_token: string } | null = null;
  identities = new Set<string>([`${USER}|${APPLE_SUB}`]);
  sql: string[] = [];
  async query<R extends QueryResultRow = QueryResultRow>(text: string, params: unknown[] = []): Promise<QueryResult<R>> {
    return result<R>(...this.answer(text, params));
  }
  private answer(text: string, params: unknown[]): [unknown[], number] {
    this.sql.push(text);
    if (text.includes('from auth.identities')) {
      const hit = this.identities.has(`${params[0]}|${params[1]}`);
      return [hit ? [{}] : [], hit ? 1 : 0];
    }
    if (text.startsWith('insert into public.apple_auth_tokens')) {
      this.row = { client_id: params[1] as string, wrapped_refresh_token: params[2] as string };
      return [[], 1];
    }
    if (text.startsWith('select client_id, wrapped_refresh_token')) {
      return [this.row ? [this.row] : [], this.row ? 1 : 0];
    }
    if (text.startsWith('delete from public.apple_auth_tokens')) {
      const hit = this.row && (params.length < 2 || this.row.wrapped_refresh_token === params[1]);
      if (hit) this.row = null;
      return [[], hit ? 1 : 0];
    }
    if (text.includes('pg_advisory_xact_lock')) return [[], 1];
    if (text.includes('from public.account_deletions')) return [[], 0];
    throw new Error(`unexpected query: ${text}`);
  }
}

describe('AppleTokenVault', () => {
  const grant = { refreshToken: REFRESH, subject: APPLE_SUB, clientId: 'com.akvega.aura' };

  it("stores a grant sealed, only for the account's own Apple identity", async () => {
    const db = new TokenDb();
    const vault = new AppleTokenVault(MASTER, client().client);
    await vault.store(db, USER, grant);
    expect(db.row?.client_id).toBe('com.akvega.aura');
    expect(db.row?.wrapped_refresh_token).not.toContain(REFRESH);
    expect(openAppleToken(MASTER, USER, db.row!.wrapped_refresh_token)).toBe(REFRESH);

    const other = new TokenDb();
    await expect(vault.store(other, OTHER, grant)).rejects.toBeInstanceOf(AppleIdentityMismatchError);
    await expect(vault.store(other, USER, { ...grant, subject: 'someone-else' })).rejects.toBeInstanceOf(AppleIdentityMismatchError);
    await expect(vault.store(other, USER, { ...grant, subject: null })).rejects.toBeInstanceOf(AppleUnavailableError);
    expect(other.row).toBeNull();
  });

  it('revokeStored: nothing stored → none, without calling Apple', async () => {
    const { client: c, calls } = client();
    await expect(new AppleTokenVault(MASTER, c).revokeStored(new TokenDb(), USER)).resolves.toBe('none');
    expect(calls).toHaveLength(0);
  });

  it('revokeStored: revokes the decrypted token at Apple, then deletes exactly that row', async () => {
    const db = new TokenDb();
    db.row = { client_id: 'com.akvega.aura', wrapped_refresh_token: sealAppleToken(MASTER, USER, REFRESH) };
    const { client: c, calls } = client(() => new Response('', { status: 200 }));
    await expect(new AppleTokenVault(MASTER, c).revokeStored(db, USER)).resolves.toBe('revoked');
    expect(calls.map((x) => x.form.get('token'))).toEqual([REFRESH]);
    expect(db.row).toBeNull();
    expect(db.sql.at(-1)).toContain('and wrapped_refresh_token = $2'); // a token stored meanwhile survives
  });

  it('revokeStored: Apple down or not configured → throws and keeps the row (the purge retries)', async () => {
    const sealed = sealAppleToken(MASTER, USER, REFRESH);
    for (const c of [client(() => errorResponse(502)).client, client(undefined, null).client]) {
      const db = new TokenDb();
      db.row = { client_id: 'com.akvega.aura', wrapped_refresh_token: sealed };
      await expect(new AppleTokenVault(MASTER, c).revokeStored(db, USER)).rejects.toBeInstanceOf(AppleUnavailableError);
      expect(db.row).not.toBeNull();
    }
  });

  it('revokeStored: Apple refuses the revoke → refused (row gone); an unreadable token → AppleTokenUnreadableError', async () => {
    const db = new TokenDb();
    db.row = { client_id: 'com.akvega.aura', wrapped_refresh_token: sealAppleToken(MASTER, USER, REFRESH) };
    await expect(new AppleTokenVault(MASTER, client(() => errorResponse(400, 'invalid_request')).client).revokeStored(db, USER)).resolves.toBe(
      'refused',
    );
    expect(db.row).toBeNull();
    db.row = { client_id: 'com.akvega.aura', wrapped_refresh_token: sealAppleToken(MASTER, OTHER, REFRESH) };
    await expect(new AppleTokenVault(MASTER, client().client).revokeStored(db, USER)).rejects.toBeInstanceOf(AppleTokenUnreadableError);
  });
});

// ---------------------------------------------------------------- AccountService (POST /v1/account/apple-auth)
const fakeDbService = (db: TokenDb, due = false) => ({
  query: (t: string, p?: unknown[]) => db.query(t, p),
  withTx: async <T>(fn: (tx: Queryable) => Promise<T>) =>
    fn({
      query: <R extends QueryResultRow>(t: string, p?: unknown[]) =>
        t.includes('from public.account_deletions') ? Promise.resolve(result<R>(due ? [{}] : [])) : db.query<R>(t, p),
    }),
});

describe('AccountService.linkApple', () => {
  const service = (vault: AppleTokenVault | undefined, db = new TokenDb(), due = false) =>
    new AccountService(fakeDbService(db, due) as never, {} as never, vault);

  it('stores the token for a valid code → resolves (204)', async () => {
    const db = new TokenDb();
    const { client: c } = client();
    await expect(service(new AppleTokenVault(MASTER, c), db).linkApple(USER, { authorizationCode: CODE })).resolves.toBeUndefined();
    expect(openAppleToken(MASTER, USER, db.row!.wrapped_refresh_token)).toBe(REFRESH);
    expect(db.sql.findIndex((s) => s.includes('pg_advisory_xact_lock'))).toBeLessThan(
      db.sql.findIndex((s) => s.startsWith('insert into public.apple_auth_tokens')),
    );
  });

  it('bad body → 400 invalid_request; no vault or not configured → 503 apple_unavailable (the app ignores it)', async () => {
    const vault = new AppleTokenVault(MASTER, client().client);
    for (const body of [undefined, {}, { authorizationCode: '' }, { authorizationCode: 42 }, 'code']) {
      await expect(service(vault).linkApple(USER, body)).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    }
    await expect(service(undefined).linkApple(USER, { authorizationCode: CODE })).rejects.toMatchObject({ status: 503, code: 'apple_unavailable' });
    const off = new AppleTokenVault(MASTER, client(undefined, null).client);
    await expect(service(off).linkApple(USER, { authorizationCode: CODE })).rejects.toMatchObject({ status: 503, code: 'apple_unavailable' });
  });

  it('Apple refuses the code → 400 apple_code_rejected; Apple down → 503; another Apple account → 409', async () => {
    const rejected = new AppleTokenVault(MASTER, client(() => errorResponse(400, 'invalid_grant')).client);
    await expect(service(rejected).linkApple(USER, { authorizationCode: CODE })).rejects.toMatchObject({ status: 400, code: 'apple_code_rejected' });
    const down = new AppleTokenVault(MASTER, client(() => errorResponse(500)).client);
    await expect(service(down).linkApple(USER, { authorizationCode: CODE })).rejects.toMatchObject({ status: 503, code: 'apple_unavailable' });
    const db = new TokenDb();
    db.identities.clear();
    const err = await service(new AppleTokenVault(MASTER, client().client), db)
      .linkApple(USER, { authorizationCode: CODE })
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 409, code: 'apple_identity_mismatch' });
    expect(db.row).toBeNull();
  });

  it('an account already being purged → 409 account_deletion_in_progress, and the fresh token is revoked at once', async () => {
    const db = new TokenDb();
    const { client: c, calls } = client((call) => (call.url.endsWith('/auth/revoke') ? new Response('', { status: 200 }) : tokenResponse()));
    await expect(service(new AppleTokenVault(MASTER, c), db, true).linkApple(USER, { authorizationCode: CODE })).rejects.toMatchObject({
      status: 409,
      code: 'account_deletion_in_progress',
    });
    expect(db.row).toBeNull();
    expect(calls.map((x) => x.url)).toEqual(['https://apple.test/auth/token', 'https://apple.test/auth/revoke']);
    expect(calls[1].form.get('token')).toBe(REFRESH);
  });
});

describe('AccountService.requestDeletion revokes the Apple token best-effort', () => {
  const repo = {
    schedule: async (_: unknown, __: string, at: Date, when: Date) => ({ requestedAt: at, scheduledFor: when }),
    deleteDeviceTokens: async () => 0,
  };

  it('revoked right after the deletion is scheduled', async () => {
    const db = new TokenDb();
    db.row = { client_id: 'com.akvega.aura', wrapped_refresh_token: sealAppleToken(MASTER, USER, REFRESH) };
    const { client: c, calls } = client(() => new Response('', { status: 200 }));
    const s = new AccountService(fakeDbService(db) as never, repo as never, new AppleTokenVault(MASTER, c));
    await expect(s.requestDeletion(USER, undefined, new Date('2026-10-08T10:00:00Z'))).resolves.toEqual({
      deletionScheduledFor: '2026-10-15T10:00:00.000Z',
    });
    expect(calls.map((x) => x.form.get('token'))).toEqual([REFRESH]);
    expect(db.row).toBeNull();
  });

  it('Apple down → the request still succeeds and the token stays for the purge', async () => {
    const db = new TokenDb();
    db.row = { client_id: 'com.akvega.aura', wrapped_refresh_token: sealAppleToken(MASTER, USER, REFRESH) };
    const s = new AccountService(fakeDbService(db) as never, repo as never, new AppleTokenVault(MASTER, client(() => errorResponse(503)).client));
    await expect(s.requestDeletion(USER, undefined)).resolves.toHaveProperty('deletionScheduledFor');
    expect(db.row).not.toBeNull();
  });
});
