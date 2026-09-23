/**
 * FCM HTTP v1 transport (src/notifications/fcm.transport.ts): service-account loading (never crashes), the
 * content-free message shape (Android VISIBILITY_PRIVATE + channel + tag, iOS generic alert + collapse id), OAuth
 * token caching and refresh, error classification (only an explicit UNREGISTERED prunes), and the fallback to the
 * log-only transport. No network: `fetch` is faked; the key pair is generated per run.
 */
import { generateKeyPairSync } from 'node:crypto';
import { Logger } from '@nestjs/common';
import { decodeJwt, decodeProtectedHeader } from 'jose';
import {
  buildFcmMessage,
  classifyFcmError,
  createNotificationTransport,
  FCM_SCOPE,
  FcmTransport,
  loadFcmServiceAccount,
  type FcmServiceAccount,
} from '../../src/notifications/fcm.transport';
import { LogOnlyNotificationTransport } from '../../src/notifications/log-only.transport';
import type { PushMessage } from '../../src/notifications/notification-types';

const PEM = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
const SA = {
  type: 'service_account',
  project_id: 'aura-test',
  client_email: 'fcm@aura-test.iam.gserviceaccount.com',
  private_key: PEM,
  token_uri: 'https://oauth2.googleapis.com/token',
};
const ACCOUNT: FcmServiceAccount = {
  projectId: 'aura-test',
  clientEmail: SA.client_email,
  privateKey: PEM,
  tokenUri: SA.token_uri,
};
const CAPSULE = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const msg = (over: Partial<PushMessage> = {}): PushMessage => ({
  type: 'capsule_unlocked',
  id: CAPSULE,
  body: 'Something you sealed is ready to open.',
  channelId: 'capsules',
  collapseKey: '2056002573',
  ttlSeconds: 86_400,
  ...over,
});

describe('loadFcmServiceAccount', () => {
  it('unset → no account and no problem (log-only, silently)', () => {
    expect(loadFcmServiceAccount({})).toEqual({ account: null, problem: null });
    expect(loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: '  ' })).toEqual({ account: null, problem: null });
  });

  it('reads inline JSON, base64 JSON, or a file path; FCM_PROJECT_ID overrides; literal \\n in keys is repaired', () => {
    expect(loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: JSON.stringify(SA) }).account).toEqual(ACCOUNT);
    const b64 = Buffer.from(JSON.stringify(SA)).toString('base64');
    expect(loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: b64, FCM_PROJECT_ID: 'other' }).account?.projectId).toBe('other');
    const escaped = JSON.stringify({ ...SA, private_key: PEM.replace(/\n/g, '\\n') });
    expect(loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: escaped }).account?.privateKey).toBe(PEM);
    const read = jest.fn(() => JSON.stringify(SA));
    expect(loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_FILE: '/secrets/fcm.json' }, read).account).toEqual(ACCOUNT);
    expect(read).toHaveBeenCalledWith('/secrets/fcm.json');
    expect(loadFcmServiceAccount({ GOOGLE_APPLICATION_CREDENTIALS: '/g.json' }, read).account).toEqual(ACCOUNT);
  });

  it('a broken configuration is described without echoing any value', () => {
    const cases = [
      loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: '{not json' }),
      loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({ ...SA, private_key: '' }) }),
      loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({ ...SA, type: 'authorized_user' }) }),
      loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({ ...SA, private_key: 'secret-but-not-pem' }) }),
      loadFcmServiceAccount({ FCM_SERVICE_ACCOUNT_FILE: '/missing.json' }, () => {
        throw new Error('ENOENT');
      }),
    ];
    for (const c of cases) {
      expect(c.account).toBeNull();
      expect(c.problem).toEqual(expect.any(String));
      expect(c.problem).not.toContain('secret');
      expect(c.problem).not.toContain('missing.json');
    }
  });

  it('createNotificationTransport: FCM when configured, log-only otherwise (never throws)', () => {
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    try {
      expect(createNotificationTransport({ FCM_SERVICE_ACCOUNT_JSON: JSON.stringify(SA) })).toBeInstanceOf(FcmTransport);
      expect(createNotificationTransport({})).toBeInstanceOf(LogOnlyNotificationTransport);
      expect(createNotificationTransport({ FCM_SERVICE_ACCOUNT_JSON: 'garbage' })).toBeInstanceOf(LogOnlyNotificationTransport);
      expect(warn).toHaveBeenCalledTimes(1);
    } finally {
      warn.mockRestore();
    }
  });
});

describe('buildFcmMessage', () => {
  it('is content-free: data holds only type and the opaque id; one generic line; no title', () => {
    const m = buildFcmMessage({ token: 'tok', platform: 'android' }, msg(), Date.UTC(2027, 9, 8, 4, 30));
    expect(m.token).toBe('tok');
    expect(m.data).toEqual({ type: 'capsule_unlocked', id: CAPSULE });
    expect(m.notification).toEqual({ body: 'Something you sealed is ready to open.' });
    expect(JSON.stringify(m)).not.toMatch(/title/i);
  });

  it('Android: private visibility, the type channel, a replace tag and a TTL', () => {
    const m = buildFcmMessage({ token: 'tok', platform: 'android' }, msg(), 0) as { android: Record<string, unknown> };
    expect(m.android).toEqual({
      priority: 'HIGH',
      ttl: '86400s',
      collapse_key: '2056002573',
      notification: { channel_id: 'capsules', visibility: 'PRIVATE', tag: '2056002573', default_sound: true },
    });
  });

  it('iOS: the same generic alert, the collapse id (= the app\'s local notice id for a capsule) and an expiry', () => {
    const now = Date.UTC(2027, 9, 8, 4, 30);
    const m = buildFcmMessage({ token: 'tok', platform: 'ios' }, msg(), now) as { apns: { headers: Record<string, string>; payload: unknown } };
    expect(m.apns.headers).toEqual({
      'apns-priority': '10',
      'apns-push-type': 'alert',
      'apns-collapse-id': '2056002573',
      'apns-expiration': String(now / 1000 + 86_400),
    });
    expect(m.apns.payload).toEqual({ aps: { alert: { body: 'Something you sealed is ready to open.' }, sound: 'default', 'thread-id': 'capsules' } });
  });

  it('a push without a record id carries only its type', () => {
    const m = buildFcmMessage({ token: 't', platform: 'ios' }, msg({ type: 'daily_reminder', id: null, collapseKey: 'daily_reminder' }), 0);
    expect(m.data).toEqual({ type: 'daily_reminder' });
  });
});

describe('classifyFcmError', () => {
  const body = (errorCode: string, status = 'NOT_FOUND') => ({
    error: { status, details: [{ '@type': 'type.googleapis.com/google.firebase.fcm.v1.FcmError', errorCode }] },
  });
  it('only an explicit UNREGISTERED prunes the token', () => {
    expect(classifyFcmError(404, body('UNREGISTERED'))).toBe('unregistered');
    expect(classifyFcmError(400, body('UNREGISTERED', 'INVALID_ARGUMENT'))).toBe('unregistered');
    expect(classifyFcmError(404, { error: { status: 'NOT_FOUND' } })).toBe('failed'); // e.g. a wrong project id: never prune
    expect(classifyFcmError(400, body('INVALID_ARGUMENT', 'INVALID_ARGUMENT'))).toBe('failed');
    expect(classifyFcmError(403, body('SENDER_ID_MISMATCH', 'PERMISSION_DENIED'))).toBe('failed');
  });
  it('quota and server errors are temporary', () => {
    expect(classifyFcmError(429, body('QUOTA_EXCEEDED', 'RESOURCE_EXHAUSTED'))).toBe('transient');
    expect(classifyFcmError(503, null)).toBe('transient');
    expect(classifyFcmError(500, 'not json')).toBe('transient');
  });
});

describe('FcmTransport', () => {
  type Call = { url: string; init: RequestInit };
  const json = (status: number, b: unknown) => new Response(JSON.stringify(b), { status, headers: { 'content-type': 'application/json' } });

  function harness(sendResponses: (() => Response)[], tokenStatus = 200) {
    const calls: Call[] = [];
    let now = Date.UTC(2026, 9, 8, 14, 30);
    let tokenN = 0;
    const fetchFn = jest.fn(async (url: string | URL | Request, init?: RequestInit) => {
      calls.push({ url: String(url), init: init ?? {} });
      if (String(url) === SA.token_uri) {
        tokenN += 1;
        return tokenStatus === 200 ? json(200, { access_token: `at-${tokenN}`, expires_in: 3600 }) : json(tokenStatus, { error: 'invalid_grant' });
      }
      const next = sendResponses.shift();
      return next ? next() : json(200, { name: 'projects/aura-test/messages/1' });
    });
    const t = new FcmTransport(ACCOUNT, fetchFn as unknown as typeof fetch, () => now);
    return { t, calls, advance: (ms: number) => (now += ms), sends: () => calls.filter((c) => c.url !== SA.token_uri) };
  }

  beforeAll(() => {
    jest.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
  });
  afterAll(() => jest.restoreAllMocks());

  it('signs a JWT-bearer grant for the FCM scope, then posts the v1 message with the access token', async () => {
    const h = harness([]);
    expect(await h.t.send({ token: 'device-1', platform: 'android' }, msg())).toBe('sent');
    const [grant, send] = h.calls;
    expect(grant.url).toBe(SA.token_uri);
    const form = new URLSearchParams(String(grant.init.body));
    expect(form.get('grant_type')).toBe('urn:ietf:params:oauth:grant-type:jwt-bearer');
    const assertion = form.get('assertion') as string;
    expect(decodeProtectedHeader(assertion)).toMatchObject({ alg: 'RS256', typ: 'JWT' });
    expect(decodeJwt(assertion)).toMatchObject({ iss: SA.client_email, aud: SA.token_uri, scope: FCM_SCOPE });
    expect(send.url).toBe('https://fcm.googleapis.com/v1/projects/aura-test/messages:send');
    expect((send.init.headers as Record<string, string>).Authorization).toBe('Bearer at-1');
    expect(JSON.parse(String(send.init.body)).message.data).toEqual({ type: 'capsule_unlocked', id: CAPSULE });
  });

  it('caches the access token until 5 min before it expires', async () => {
    const h = harness([]);
    await h.t.send({ token: 'a', platform: 'ios' }, msg());
    await h.t.send({ token: 'b', platform: 'ios' }, msg());
    expect(h.calls.filter((c) => c.url === SA.token_uri)).toHaveLength(1);
    h.advance(56 * 60_000);
    await h.t.send({ token: 'c', platform: 'ios' }, msg());
    expect(h.calls.filter((c) => c.url === SA.token_uri)).toHaveLength(2);
  });

  it('a 401 refreshes the token once and retries', async () => {
    const h = harness([() => json(401, { error: { status: 'UNAUTHENTICATED' } })]);
    expect(await h.t.send({ token: 'a', platform: 'android' }, msg())).toBe('sent');
    expect(h.sends()).toHaveLength(2);
    expect((h.sends()[1].init.headers as Record<string, string>).Authorization).toBe('Bearer at-2');
  });

  it('maps FCM errors: UNREGISTERED → unregistered, 503 → transient, network error → transient', async () => {
    const unreg = { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } };
    const h = harness([
      () => json(404, unreg),
      () => json(503, { error: { status: 'UNAVAILABLE' } }),
      () => {
        throw new TypeError('fetch failed');
      },
    ]);
    expect(await h.t.send({ token: 'dead', platform: 'android' }, msg())).toBe('unregistered');
    expect(await h.t.send({ token: 'x', platform: 'android' }, msg())).toBe('transient');
    expect(await h.t.send({ token: 'y', platform: 'android' }, msg())).toBe('transient');
  });

  it('bad credentials (OAuth 400/401) are permanent failures, not retried forever', async () => {
    const h = harness([], 400);
    expect(await h.t.send({ token: 'a', platform: 'android' }, msg())).toBe('failed');
    expect(h.sends()).toHaveLength(0);
  });

  it('never logs the token, the copy or the ids', async () => {
    const warn = Logger.prototype.warn as jest.Mock;
    warn.mockClear();
    const h = harness([() => json(403, { error: { status: 'PERMISSION_DENIED', details: [{ errorCode: 'THIRD_PARTY_AUTH_ERROR' }] } })]);
    expect(await h.t.send({ token: 'secret-device-token', platform: 'ios' }, msg())).toBe('failed');
    const logged = warn.mock.calls.map((c) => String(c[0])).join('\n');
    expect(logged).toContain('THIRD_PARTY_AUTH_ERROR');
    for (const s of ['secret-device-token', CAPSULE, 'Something you sealed']) expect(logged).not.toContain(s);
  });
});
