/**
 * Devices (FCM registration): validation, upsert/reassign semantics and owner-scoped delete against an
 * in-memory table. The same scenarios run against the real DB in test/e2e.
 */
import { ApiError } from '../../src/common/api-error';
import { MAX_TOKEN_CHARS, registerDeviceSchema, unregisterDeviceSchema } from '../../src/devices/devices.schema';
import { DevicesService } from '../../src/devices/devices.service';

const A = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const B = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const TOKEN = 'fcm-token:APA91bExample_-123';

/** Mirrors `public.device_tokens` (token unique). */
class MemDevices {
  rows = new Map<string, { userId: string; platform: string; updatedAt: number }>();
  clock = 0;

  async upsert(_: unknown, userId: string, token: string, platform: string): Promise<void> {
    this.rows.set(token, { userId, platform, updatedAt: ++this.clock });
  }

  async delete(_: unknown, userId: string, token: string): Promise<number> {
    if (this.rows.get(token)?.userId !== userId) return 0;
    this.rows.delete(token);
    return 1;
  }
}

describe('device request schemas', () => {
  it('accepts the contract examples', () => {
    expect(registerDeviceSchema.parse({ token: TOKEN, platform: 'ios' })).toEqual({ token: TOKEN, platform: 'ios' });
    expect(registerDeviceSchema.parse({ token: 'x', platform: 'android' }).platform).toBe('android');
    expect(unregisterDeviceSchema.parse({ token: TOKEN })).toEqual({ token: TOKEN });
    expect(registerDeviceSchema.safeParse({ token: 'x'.repeat(MAX_TOKEN_CHARS), platform: 'ios' }).success).toBe(true);
  });

  it.each([
    ['empty token', { token: '', platform: 'ios' }],
    ['token too long', { token: 'x'.repeat(MAX_TOKEN_CHARS + 1), platform: 'ios' }],
    ['non-string token', { token: 42, platform: 'ios' }],
    ['missing token', { platform: 'android' }],
    ['unknown platform', { token: TOKEN, platform: 'web' }],
    ['missing platform', { token: TOKEN }],
  ])('PUT rejects %s', (_, body) => {
    expect(registerDeviceSchema.safeParse(body).success).toBe(false);
  });

  it('DELETE needs a token', () => {
    expect(unregisterDeviceSchema.safeParse({}).success).toBe(false);
    expect(unregisterDeviceSchema.safeParse({ token: '' }).success).toBe(false);
  });
});

describe('DevicesService', () => {
  let repo: MemDevices;
  let service: DevicesService;

  beforeEach(() => {
    repo = new MemDevices();
    service = new DevicesService({} as never, repo as never);
  });

  it('registers, and re-registering the same token updates it in place', async () => {
    await service.register(A, { token: TOKEN, platform: 'ios' });
    expect(repo.rows.get(TOKEN)).toMatchObject({ userId: A, platform: 'ios', updatedAt: 1 });
    await service.register(A, { token: TOKEN, platform: 'ios' });
    expect(repo.rows.size).toBe(1);
    expect(repo.rows.get(TOKEN)?.updatedAt).toBe(2);
  });

  it('a token that moves to another account is reassigned to it', async () => {
    await service.register(A, { token: TOKEN, platform: 'android' });
    await service.register(B, { token: TOKEN, platform: 'android' });
    expect(repo.rows.size).toBe(1);
    expect(repo.rows.get(TOKEN)?.userId).toBe(B);
  });

  it('delete is scoped to the owner and idempotent', async () => {
    await service.register(B, { token: TOKEN, platform: 'ios' });
    await service.unregister(A, { token: TOKEN }); // not A's token: no-op, no error
    expect(repo.rows.get(TOKEN)?.userId).toBe(B);
    await service.unregister(B, { token: TOKEN });
    expect(repo.rows.size).toBe(0);
    await expect(service.unregister(B, { token: TOKEN })).resolves.toBeUndefined();
  });

  it('invalid bodies → 400 invalid_request whose message never contains the token', async () => {
    const long = 'secret-token-'.repeat(400);
    const err = await service.register(A, { token: long, platform: 'ios' }).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 400, code: 'invalid_request' });
    expect((err as ApiError).message).not.toContain('secret-token');
    await expect(service.register(A, { token: TOKEN, platform: 'web' })).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    await expect(service.unregister(A, undefined)).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    expect(repo.rows.size).toBe(0);
  });

  it('a deleted auth user (FK 23503) → 401 unknown_user', async () => {
    const failing = { upsert: jest.fn().mockRejectedValue(Object.assign(new Error('fk'), { code: '23503' })) };
    const s = new DevicesService({} as never, failing as never);
    await expect(s.register(A, { token: TOKEN, platform: 'ios' })).rejects.toMatchObject({ status: 401, code: 'unknown_user' });
  });
});
