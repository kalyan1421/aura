import { generateKeyPairSync } from 'node:crypto';
import { createLocalJWKSet, exportJWK, SignJWT, type JWK } from 'jose';
import { HttpAppStoreServerApi, StoreUnavailableError } from '../../src/billing/apple/app-store-api';
import { HttpPlayDeveloperApi } from '../../src/billing/google/play-api';
import { PushAuthError, PubSubPushVerifier } from '../../src/billing/google/pubsub-auth';
import { loadServiceAccount } from '../../src/billing/google/service-account';

type Call = { url: string; init?: RequestInit };
const fakeFetch = (routes: (url: string, init?: RequestInit) => Response, calls: Call[] = []): typeof fetch =>
  (async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    calls.push({ url, init });
    return routes(url, init);
  }) as typeof fetch;
const json = (body: unknown, status = 200): Response => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const ec = generateKeyPairSync('ec', { namedCurve: 'P-256' });
const P8 = ec.privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();
const rsa = generateKeyPairSync('rsa', { modulusLength: 2048 });
const RSA_PEM = rsa.privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();

describe('App Store Server API client', () => {
  const cfg = { issuerId: 'iss-1', keyId: 'KEY123', privateKey: P8.replace(/\n/g, '\\n'), bundleId: 'com.akvega.aura' };

  it('asks production first, then the sandbox on 404; authenticates with an ES256 JWT for the bundle', async () => {
    const calls: Call[] = [];
    const api = new HttpAppStoreServerApi(cfg, {
      fetch: fakeFetch((url) => (url.startsWith('https://prod') ? json({ errorCode: 4040010 }, 404) : json({ signedTransactionInfo: 'JWS' })), calls),
      productionUrl: 'https://prod',
      sandboxUrl: 'https://sandbox',
    });
    await expect(api.transaction('2000000123')).resolves.toBe('JWS');
    expect(calls.map((c) => c.url)).toEqual(['https://prod/inApps/v1/transactions/2000000123', 'https://sandbox/inApps/v1/transactions/2000000123']);
    const auth = (calls[0].init?.headers as Record<string, string>).Authorization;
    const [h, p] = auth.replace('Bearer ', '').split('.').slice(0, 2).map((x) => JSON.parse(Buffer.from(x, 'base64url').toString()));
    expect(h).toMatchObject({ alg: 'ES256', kid: 'KEY123', typ: 'JWT' });
    expect(p).toMatchObject({ iss: 'iss-1', aud: 'appstoreconnect-v1', bid: 'com.akvega.aura' });
  });

  it('unknown in both → null; 5xx / network / not configured → StoreUnavailableError', async () => {
    const both404 = new HttpAppStoreServerApi(cfg, { fetch: fakeFetch(() => json({}, 404)) });
    await expect(both404.statuses('1')).resolves.toBeNull();
    const down = new HttpAppStoreServerApi(cfg, { fetch: fakeFetch(() => json({}, 503)) });
    await expect(down.statuses('1')).rejects.toBeInstanceOf(StoreUnavailableError);
    const net = new HttpAppStoreServerApi(cfg, { fetch: (async () => { throw new Error('ECONNRESET'); }) as typeof fetch });
    await expect(net.transaction('1')).rejects.toBeInstanceOf(StoreUnavailableError);
    await expect(new HttpAppStoreServerApi(null).transaction('1')).rejects.toMatchObject({ reason: 'not_configured' });
  });

  it('statuses flattens every group’s lastTransactions', async () => {
    const api = new HttpAppStoreServerApi(cfg, {
      fetch: fakeFetch(() => json({ data: [{ lastTransactions: [{ originalTransactionId: '1', status: 1, signedTransactionInfo: 'A' }] }] })),
    });
    await expect(api.statuses('1')).resolves.toEqual([{ originalTransactionId: '1', status: 1, signedTransactionInfo: 'A' }]);
  });
});

describe('Play Developer API client', () => {
  const account = { clientEmail: 'play@aura.iam.gserviceaccount.com', privateKey: RSA_PEM, tokenUri: 'https://oauth.test/token' };

  it('gets an OAuth token once, then reads subscriptionsv2 / products and acknowledges / consumes', async () => {
    const calls: Call[] = [];
    const api = new HttpPlayDeveloperApi(account, 'com.akvega.aura', {
      baseUrl: 'https://play.test/v3',
      fetch: fakeFetch((url) => {
        if (url === 'https://oauth.test/token') return json({ access_token: 'AT', expires_in: 3600 });
        if (url.includes('/subscriptionsv2/')) return json({ subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE' });
        if (url.endsWith(':acknowledge') || url.endsWith(':consume')) return new Response('', { status: 200 });
        if (url.includes('/purchases/products/')) return json({ purchaseState: 0 });
        return json({}, 404);
      }, calls),
    });
    await expect(api.subscription('tok/en')).resolves.toMatchObject({ subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE' });
    await api.acknowledgeSubscription('aura_plus_monthly', 'tok');
    await expect(api.product('gift_warm_tea', 'tok')).resolves.toEqual({ purchaseState: 0 });
    await api.consumeProduct('gift_warm_tea', 'tok');
    expect(calls.filter((c) => c.url === 'https://oauth.test/token')).toHaveLength(1);
    expect(calls.map((c) => c.url)).toContain('https://play.test/v3/applications/com.akvega.aura/purchases/subscriptionsv2/tokens/tok%2Fen');
    expect(calls.map((c) => c.url)).toContain('https://play.test/v3/applications/com.akvega.aura/purchases/subscriptions/aura_plus_monthly/tokens/tok:acknowledge');
    expect(calls.map((c) => c.url)).toContain('https://play.test/v3/applications/com.akvega.aura/purchases/products/gift_warm_tea/tokens/tok:consume');
    expect((calls[1].init?.headers as Record<string, string>).Authorization).toBe('Bearer AT');
  });

  it('404 → null; 500 → unavailable; voided purchases follow pagination', async () => {
    let page = 0;
    const api = new HttpPlayDeveloperApi(account, 'com.akvega.aura', {
      baseUrl: 'https://play.test/v3',
      fetch: fakeFetch((url) => {
        if (url === 'https://oauth.test/token') return json({ access_token: 'AT' });
        if (url.includes('voidedpurchases')) {
          page += 1;
          return page === 1 ? json({ voidedPurchases: [{ purchaseToken: 'a' }], tokenPagination: { nextPageToken: 'n' } }) : json({ voidedPurchases: [{ purchaseToken: 'b' }] });
        }
        if (url.includes('/products/gone/')) return json({}, 410);
        return json({}, 500);
      }),
    });
    await expect(api.product('gone', 't')).resolves.toBeNull();
    await expect(api.subscription('t')).rejects.toBeInstanceOf(StoreUnavailableError);
    await expect(api.voided(0)).resolves.toEqual([{ purchaseToken: 'a' }, { purchaseToken: 'b' }]);
  });

  it('service-account loading never throws and never echoes values', () => {
    expect(loadServiceAccount(undefined, undefined)).toEqual({ account: null, problem: null });
    expect(loadServiceAccount('{"client_email":"x"}', undefined).problem).toMatch(/private_key/);
    const b64 = Buffer.from(JSON.stringify({ client_email: 'a@b', private_key: RSA_PEM })).toString('base64');
    expect(loadServiceAccount(b64, undefined).account?.clientEmail).toBe('a@b');
    expect(loadServiceAccount(undefined, '/nope', () => { throw new Error('x'); }).problem).toMatch(/cannot be read/);
  });
});

describe('Pub/Sub push authentication (Play RTDN)', () => {
  const google = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const other = generateKeyPairSync('rsa', { modulusLength: 2048 });
  let jwks: ReturnType<typeof createLocalJWKSet>;
  beforeAll(async () => {
    const jwk = (await exportJWK(google.publicKey)) as JWK;
    jwks = createLocalJWKSet({ keys: [{ ...jwk, kid: 'g1', alg: 'RS256', use: 'sig' }] });
  });
  const AUD = 'https://api.aura.test/v1/billing/webhooks/google';
  const SA = 'rtdn-push@aura.iam.gserviceaccount.com';
  const token = (claims: Record<string, unknown>, key = google.privateKey, iss = 'https://accounts.google.com', aud = AUD): Promise<string> =>
    new SignJWT({ email: SA, email_verified: true, ...claims })
      .setProtectedHeader({ alg: 'RS256', kid: 'g1' })
      .setIssuer(iss)
      .setAudience(aud)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(key);
  const reason = async (p: Promise<unknown>): Promise<string> => p.then(() => 'ok', (e) => (e instanceof PushAuthError ? e.reason : 'other'));

  it('accepts Google’s OIDC token for our audience and push service account', async () => {
    const v = new PubSubPushVerifier({ audience: AUD, serviceAccountEmail: SA }, jwks);
    expect(await reason(v.verify(`Bearer ${await token({})}`))).toBe('ok');
  });
  it('refuses: no token, wrong key, wrong audience, wrong issuer, another service account, unverified email', async () => {
    const v = new PubSubPushVerifier({ audience: AUD, serviceAccountEmail: SA }, jwks);
    expect(await reason(v.verify(undefined))).toBe('missing_token');
    expect(await reason(v.verify(`Bearer ${await token({}, other.privateKey)}`))).toBe('invalid_token');
    expect(await reason(v.verify(`Bearer ${await token({}, google.privateKey, 'https://accounts.google.com', 'https://evil.test')}`))).toBe('invalid_token');
    expect(await reason(v.verify(`Bearer ${await token({}, google.privateKey, 'https://evil.test')}`))).toBe('invalid_token');
    expect(await reason(v.verify(`Bearer ${await token({ email: 'someone@else.test' })}`))).toBe('wrong_sender');
    expect(await reason(v.verify(`Bearer ${await token({ email_verified: false })}`))).toBe('wrong_sender');
  });
  it('fails closed when not configured', async () => {
    const v = new PubSubPushVerifier({ audience: null, serviceAccountEmail: SA }, jwks);
    expect(await reason(v.verify(`Bearer ${await token({})}`))).toBe('not_configured');
  });
});
