/**
 * F1 voice notes (contracts/api/v1.md "Media: voice notes"): path rules, MediaService validation and
 * error mapping against a fake Storage client, the Storage API signing calls, and the HTTP surface
 * behind the global guards. The full upload → sync → download → delete flow runs in test/e2e.
 */
import { INestApplication, Logger, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import {
  encodeObjectPath,
  MediaStoreError,
  MediaStoreUnavailableError,
  PrivateMediaStore,
  signedUrlExpiry,
  type SignedMediaUrl,
} from '../../src/account/private-media';
import { AuthGuard } from '../../src/auth/auth.guard';
import { InvalidTokenError, JwtVerifier, type AuthUser } from '../../src/auth/jwt-verifier';
import { PendingDeletionGuard } from '../../src/auth/pending-deletion.guard';
import { ApiExceptionFilter } from '../../src/common/api-exception.filter';
import { uuidv7 } from '../../src/common/uuid';
import { DbService } from '../../src/db/db.service';
import { isOwnMediaPath, voiceObjectPath } from '../../src/media/media-paths';
import { MediaController } from '../../src/media/media.controller';
import { DOWNLOAD_URL_TTL_SECONDS, MAX_MEDIA_BYTES, UPLOAD_URL_TTL_SECONDS } from '../../src/media/media.schema';
import { MediaService } from '../../src/media/media.service';

const A = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const B = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const NOW = new Date('2026-10-08T10:00:00.000Z');
const BASE = 'http://127.0.0.1:55521';

/** A Storage-style signed URL whose token expires at `exp` (seconds). */
const tokenUrl = (path: string, exp: number): string => {
  const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${BASE}/storage/v1/object/${path}?token=${b64({ alg: 'HS256' })}.${b64({ url: path, exp })}.sig`;
};

describe('media paths', () => {
  it('voice objects are <user_id>/voice/<check-in id>, lower-case', () => {
    const id = uuidv7();
    expect(voiceObjectPath(A, id)).toBe(`${A}/voice/${id}`);
    expect(voiceObjectPath(A.toUpperCase(), id.toUpperCase())).toBe(`${A}/voice/${id}`);
  });

  it.each([
    [`${A}/voice/${uuidv7()}`, true],
    [`${A}/capsules/${uuidv7()}/0.bin`, true],
    [`${A}/x`, true],
    [`${B}/voice/${uuidv7()}`, false],
    [A, false],
    [`${A}/`, false],
    [`${A}//x`, false],
    [`${A}/voice/`, false],
    [`${A}/../${B}/voice/x`, false],
    [`${A}/voice/..`, false],
    [`${A}/voice/.`, false],
    [`${A}/voice/%2e%2e`, false],
    [`${A}/voice/a..b`, false],
    [`${A}/voice/x\\..\\y`, false],
    [`${A}/voice/x?y`, false],
    [`${A}/voice/x#y`, false],
    [`${A}/voice/x y`, false],
    [`/${A}/voice/x`, false],
    [`${A.toUpperCase()}/voice/x`, false],
    [`${A}/a/b/c/d/e`, false],
    [`${A}/${'x'.repeat(600)}`, false],
    ['', false],
  ])('isOwnMediaPath(A, %j) → %s', (path, ok) => {
    expect(isOwnMediaPath(A, path)).toBe(ok);
  });

  it('encodeObjectPath refuses dot segments and empty segments (URL parsers would resolve them)', () => {
    expect(encodeObjectPath(`${A}/voice/x`)).toBe(`${A}/voice/x`);
    for (const bad of [`${A}/../x`, `${A}/./x`, `${A}/%2E%2e/x`, `${A}//x`, `/${A}`]) {
      expect(() => encodeObjectPath(bad)).toThrow(TypeError);
    }
  });

  it('signedUrlExpiry reads the token exp, null when unreadable', () => {
    expect(signedUrlExpiry(tokenUrl('x', 1_790_000_000))?.toISOString()).toBe(new Date(1_790_000_000_000).toISOString());
    expect(signedUrlExpiry(`${BASE}/x`)).toBeNull();
    expect(signedUrlExpiry(`${BASE}/x?token=garbage`)).toBeNull();
  });
});

/** PrivateMediaStore stand-in for MediaService. */
class FakeStore {
  configured = true;
  uploads: string[] = [];
  downloads: [string, number][] = [];
  existing = new Set<string>();
  failWith: Error | null = null;
  uploadExp = new Date(NOW.getTime() + 2 * 3600_000);

  async signUpload(name: string): Promise<SignedMediaUrl> {
    if (this.failWith) throw this.failWith;
    this.uploads.push(name);
    return { url: `${BASE}/storage/v1/object/upload/sign/private-media/${name}?token=t`, expiresAt: this.uploadExp };
  }
  async signDownload(name: string, expiresIn: number): Promise<SignedMediaUrl | null> {
    if (this.failWith) throw this.failWith;
    this.downloads.push([name, expiresIn]);
    if (!this.existing.has(name)) return null;
    return { url: `${BASE}/storage/v1/object/sign/private-media/${name}?token=t`, expiresAt: new Date(NOW.getTime() + expiresIn * 1000) };
  }
}

describe('MediaService', () => {
  let store: FakeStore;
  let service: MediaService;
  const recordId = uuidv7();
  const upload = (body: unknown) => service.uploadUrl(A, body, NOW);
  const download = (body: unknown) => service.downloadUrl(A, body, NOW);

  beforeAll(() => Logger.overrideLogger(false));
  beforeEach(() => {
    store = new FakeStore();
    service = new MediaService(store as unknown as PrivateMediaStore);
  });

  it('upload-url → { path, uploadUrl, expiresAt } for <user_id>/voice/<recordId>, capped at 10 minutes', async () => {
    const r = await upload({ kind: 'voice', recordId: recordId.toUpperCase(), bytes: 412_345 });
    expect(r).toEqual({
      path: `${A}/voice/${recordId}`,
      uploadUrl: `${BASE}/storage/v1/object/upload/sign/private-media/${A}/voice/${recordId}?token=t`,
      expiresAt: new Date(NOW.getTime() + UPLOAD_URL_TTL_SECONDS * 1000).toISOString(),
    });
    expect(UPLOAD_URL_TTL_SECONDS).toBe(600);
    expect(store.uploads).toEqual([`${A}/voice/${recordId}`]);
  });

  it('upload-url reports the token expiry when Storage issues a shorter one', async () => {
    store.uploadExp = new Date(NOW.getTime() + 60_000);
    const r = await upload({ kind: 'voice', recordId, bytes: 10 });
    expect(r.expiresAt).toBe(store.uploadExp.toISOString());
  });

  it('bytes: 1 and 1,048,576 are fine; larger → 400 media_too_large; 0 / negative / fractional / string → 400 invalid_request', async () => {
    expect(MAX_MEDIA_BYTES.voice).toBe(1_048_576);
    await expect(upload({ kind: 'voice', recordId, bytes: 1 })).resolves.toHaveProperty('path');
    await expect(upload({ kind: 'voice', recordId, bytes: 1_048_576 })).resolves.toHaveProperty('path');
    for (const bytes of [1_048_577, 50 * 1024 * 1024, 1e20]) {
      await expect(upload({ kind: 'voice', recordId, bytes })).rejects.toMatchObject({ status: 400, code: 'media_too_large' });
    }
    for (const bytes of [0, -5, 1.5, '1000', null, undefined]) {
      await expect(upload({ kind: 'voice', recordId, bytes })).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    }
    expect(store.uploads).toHaveLength(2);
  });

  it.each([
    ['unknown kind', { kind: 'photo', recordId, bytes: 10 }],
    ['missing kind', { recordId, bytes: 10 }],
    ['non-UUID recordId', { kind: 'voice', recordId: '../x', bytes: 10 }],
    ['missing recordId', { kind: 'voice', bytes: 10 }],
    ['non-object body', [1, 2]],
    ['no body', undefined],
  ])('upload-url: %s → 400 invalid_request, nothing signed', async (_, body) => {
    await expect(upload(body)).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    expect(store.uploads).toEqual([]);
  });

  it('download-url → { downloadUrl, expiresAt } (5 minutes) for an own object', async () => {
    const path = `${A}/voice/${recordId}`;
    store.existing.add(path);
    const r = await download({ path });
    expect(r).toEqual({
      downloadUrl: `${BASE}/storage/v1/object/sign/private-media/${path}?token=t`,
      expiresAt: new Date(NOW.getTime() + DOWNLOAD_URL_TTL_SECONDS * 1000).toISOString(),
    });
    expect(store.downloads).toEqual([[path, 300]]);
  });

  it("download-url: another user's path, traversal or garbage → 404 not_found without asking Storage", async () => {
    const theirs = `${B}/voice/${recordId}`;
    store.existing.add(theirs);
    for (const path of [theirs, `${A}/../${B}/voice/${recordId}`, `${A}/voice/..`, 'x', '']) {
      await expect(download({ path })).rejects.toMatchObject({ status: 404, code: 'not_found' });
    }
    expect(store.downloads).toEqual([]);
  });

  it('download-url: an own path that does not exist → 404 not_found', async () => {
    await expect(download({ path: `${A}/voice/${uuidv7()}` })).rejects.toMatchObject({ status: 404, code: 'not_found' });
    expect(store.downloads).toHaveLength(1);
  });

  it('download-url: non-string / missing path → 400 invalid_request', async () => {
    for (const body of [{ path: 42 }, {}, undefined]) {
      await expect(download(body)).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    }
  });

  it('no service key → 503 media_unavailable for both routes (validation still answers first)', async () => {
    store.configured = false;
    await expect(upload({ kind: 'voice', recordId, bytes: 10 })).rejects.toMatchObject({ status: 503, code: 'media_unavailable' });
    await expect(download({ path: `${A}/voice/${recordId}` })).rejects.toMatchObject({ status: 503, code: 'media_unavailable' });
    await expect(upload({ kind: 'voice', recordId, bytes: 2_000_000 })).rejects.toMatchObject({ code: 'media_too_large' });
    await expect(download({ path: `${B}/voice/${recordId}` })).rejects.toMatchObject({ code: 'not_found' });
    expect(store.uploads).toEqual([]);
  });

  it.each([
    ['a Storage error reply', new MediaStoreError(500, 'sign upload')],
    ['a missing key at call time', new MediaStoreUnavailableError()],
    ['a network failure', new TypeError('fetch failed')],
    ['a timeout', Object.assign(new Error('The operation was aborted due to timeout'), { name: 'TimeoutError' })],
  ])('%s → 503 media_unavailable', async (_, err) => {
    store.failWith = err;
    await expect(upload({ kind: 'voice', recordId, bytes: 10 })).rejects.toMatchObject({ status: 503, code: 'media_unavailable' });
    await expect(download({ path: `${A}/voice/${recordId}` })).rejects.toMatchObject({ status: 503, code: 'media_unavailable' });
  });

  it('a programming error is not disguised as an outage', async () => {
    store.failWith = new RangeError('bug');
    await expect(upload({ kind: 'voice', recordId, bytes: 10 })).rejects.toBeInstanceOf(RangeError);
  });
});

describe('PrivateMediaStore signing (Storage API)', () => {
  const calls: { url: string; init: RequestInit }[] = [];
  const reply =
    (status: number, body: unknown) =>
    (async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
    }) as unknown as typeof fetch;
  const path = `${A}/voice/${uuidv7()}`;
  const exp = Math.floor(NOW.getTime() / 1000) + 7200;

  beforeEach(() => (calls.length = 0));

  it('signUpload: POST /object/upload/sign/private-media/<path> with x-upsert and the service key', async () => {
    const rel = `/object/upload/sign/private-media/${path}?token=${tokenUrl('x', exp).split('token=')[1]}`;
    const store = new PrivateMediaStore({ supabaseUrl: `${BASE}/`, serviceKey: 'svc', fetch: reply(200, { url: rel, token: 't' }) });
    const r = await store.signUpload(path);
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe(`${BASE}/storage/v1/object/upload/sign/private-media/${path}`);
    expect(calls[0].init.method).toBe('POST');
    expect(calls[0].init.headers).toMatchObject({ apikey: 'svc', Authorization: 'Bearer svc', 'x-upsert': 'true' });
    expect(r).toEqual({ url: `${BASE}/storage/v1${rel}`, expiresAt: new Date(exp * 1000) });
  });

  it('signDownload: POST /object/sign/private-media/<path> {expiresIn}; absolute URL back', async () => {
    const rel = `/object/sign/private-media/${path}?token=${tokenUrl('x', exp).split('token=')[1]}`;
    const store = new PrivateMediaStore({ supabaseUrl: BASE, serviceKey: 'svc', fetch: reply(200, { signedURL: rel }) });
    const r = await store.signDownload(path, 300);
    expect(calls[0].url).toBe(`${BASE}/storage/v1/object/sign/private-media/${path}`);
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ expiresIn: 300 });
    expect(r).toEqual({ url: `${BASE}/storage/v1${rel}`, expiresAt: new Date(exp * 1000) });
  });

  it('signDownload: Storage "not found" (400 {statusCode:"404"} or 404) → null', async () => {
    const s1 = new PrivateMediaStore({
      supabaseUrl: BASE,
      serviceKey: 'svc',
      fetch: reply(400, { statusCode: '404', error: 'not_found', message: 'Object not found' }),
    });
    await expect(s1.signDownload(path, 300)).resolves.toBeNull();
    const s2 = new PrivateMediaStore({ supabaseUrl: BASE, serviceKey: 'svc', fetch: reply(404, {}) });
    await expect(s2.signDownload(path, 300)).resolves.toBeNull();
  });

  it('other failures → MediaStoreError whose message never echoes the path', async () => {
    for (const [status, body] of [
      [500, { error: `boom ${path}` }],
      [400, { statusCode: '400', error: 'InvalidJWT', message: path }],
      [200, { nope: true }],
    ] as const) {
      const store = new PrivateMediaStore({ supabaseUrl: BASE, serviceKey: 'svc', fetch: reply(status, body) });
      for (const call of [() => store.signUpload(path), () => store.signDownload(path, 300)]) {
        const err = await call().catch((e: unknown) => e);
        expect(err).toBeInstanceOf(MediaStoreError);
        expect((err as Error).message).toMatch(/^storage sign (upload|download) failed: HTTP \d+$/);
        expect((err as Error).message).not.toContain(A);
      }
    }
  });

  it('no service key → MediaStoreUnavailableError before any request; traversal never reaches fetch', async () => {
    const keyless = new PrivateMediaStore({ supabaseUrl: BASE, fetch: reply(200, {}) });
    await expect(keyless.signUpload(path)).rejects.toBeInstanceOf(MediaStoreUnavailableError);
    await expect(keyless.signDownload(path, 300)).rejects.toBeInstanceOf(MediaStoreUnavailableError);
    const store = new PrivateMediaStore({ supabaseUrl: BASE, serviceKey: 'svc', fetch: reply(200, {}) });
    await expect(store.signDownload(`${A}/../${B}/voice/x`, 300)).rejects.toBeInstanceOf(TypeError);
    expect(calls).toHaveLength(0);
  });
});

// ---------------------------------------------------------------- HTTP surface behind the global guards
describe('/v1/media over HTTP (AuthGuard + PendingDeletionGuard)', () => {
  let app: INestApplication;
  const store = new FakeStore();
  const pending = new Set<string>();

  class FakeVerifier {
    async verify(token: string): Promise<AuthUser> {
      if (token === 'good') return { id: A, role: 'authenticated', isAnonymous: false };
      throw new InvalidTokenError('nope');
    }
  }
  const db = {
    query: async (_: string, params: unknown[]) => {
      const hit = pending.has(params[0] as string);
      return { rows: hit ? [{}] : [], rowCount: hit ? 1 : 0 };
    },
  };

  @Module({
    controllers: [MediaController],
    providers: [
      MediaService,
      { provide: PrivateMediaStore, useValue: store },
      { provide: JwtVerifier, useClass: FakeVerifier },
      { provide: DbService, useValue: db },
      { provide: APP_GUARD, useClass: AuthGuard },
      { provide: APP_GUARD, useClass: PendingDeletionGuard },
    ],
  })
  class ProbeModule {}

  beforeAll(async () => {
    Logger.overrideLogger(false);
    const ref = await Test.createTestingModule({ imports: [ProbeModule] }).compile();
    app = ref.createNestApplication();
    app.useGlobalFilters(new ApiExceptionFilter());
    await app.init();
  });
  afterAll(() => app.close());
  beforeEach(() => {
    pending.clear();
    store.configured = true;
  });

  const post = (route: string, body: object, token = 'good') =>
    request(app.getHttpServer()).post(`/v1/media/${route}`).set('Authorization', `Bearer ${token}`).send(body);

  it('200 with Cache-Control: no-store', async () => {
    const recordId = uuidv7();
    const r = await post('upload-url', { kind: 'voice', recordId, bytes: 1000 }).expect(200);
    expect(r.headers['cache-control']).toBe('no-store');
    expect(r.body).toEqual({ path: `${A}/voice/${recordId}`, uploadUrl: expect.any(String), expiresAt: expect.any(String) });
    store.existing.add(r.body.path);
    const d = await post('download-url', { path: r.body.path }).expect(200);
    expect(d.headers['cache-control']).toBe('no-store');
    expect(d.body).toEqual({ downloadUrl: expect.any(String), expiresAt: expect.any(String) });
  });

  it('401 without a valid token', async () => {
    for (const route of ['upload-url', 'download-url']) {
      const r = await post(route, {}, 'bad').expect(401);
      expect(r.body.code).toBe('unauthorized');
    }
  });

  it('403 account_deletion_pending while a deletion is scheduled', async () => {
    pending.add(A);
    for (const [route, body] of [
      ['upload-url', { kind: 'voice', recordId: uuidv7(), bytes: 10 }],
      ['download-url', { path: `${A}/voice/${uuidv7()}` }],
    ] as const) {
      const r = await post(route, body).expect(403);
      expect(r.body).toEqual({ code: 'account_deletion_pending', message: expect.any(String) });
    }
  });

  it('503 media_unavailable without a service key; 404 / 400 bodies are { code, message }', async () => {
    store.configured = false;
    const r = await post('upload-url', { kind: 'voice', recordId: uuidv7(), bytes: 10 }).expect(503);
    expect(r.body).toEqual({ code: 'media_unavailable', message: expect.any(String) });
    store.configured = true;
    const nf = await post('download-url', { path: `${B}/voice/${uuidv7()}` }).expect(404);
    expect(nf.body).toEqual({ code: 'not_found', message: expect.any(String) });
    const big = await post('upload-url', { kind: 'voice', recordId: uuidv7(), bytes: 2_000_000 }).expect(400);
    expect(big.body).toEqual({ code: 'media_too_large', message: expect.any(String) });
  });
});
