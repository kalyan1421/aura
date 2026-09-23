/**
 * Device bans (src/devices): the install header (opaque, validated, hashed with a key derived from AURA_MASTER_KEY),
 * the global DeviceBanGuard (which routes it skips, 403 device_banned), the InstallSeenInterceptor (records only after
 * a successful authenticated call) and the SQL helpers' audit + idempotency contract, against fakes. The real tables
 * are exercised in test/e2e/remote-config.e2e-spec.ts.
 */
import { randomBytes } from 'node:crypto';
import type { CallHandler, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { lastValueFrom, of, throwError } from 'rxjs';
import { ALLOW_ACCOUNT_CLOSED } from '../../src/auth/account-closed.guard';
import { IS_PUBLIC } from '../../src/auth/public.decorator';
import { ApiError } from '../../src/common/api-error';
import { DeviceBanGuard, InstallSeenInterceptor } from '../../src/devices/device-ban.guard';
import { banDevicesForAccount, liftDeviceBan, recordInstall } from '../../src/devices/device-bans';
import { INSTALL_HEADER, PLATFORM_HEADER, installHash, readInstall } from '../../src/devices/install-id';

const MASTER = randomBytes(32);
const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const INSTALL = randomBytes(32).toString('base64url');

describe('install header', () => {
  it('accepts base64url ids of 16–64 bytes and an optional platform', () => {
    expect(readInstall({ headers: { [INSTALL_HEADER]: INSTALL, [PLATFORM_HEADER]: 'ios' } })).toEqual({ id: INSTALL, platform: 'ios' });
    expect(readInstall({ headers: { [INSTALL_HEADER]: INSTALL } })).toEqual({ id: INSTALL, platform: null });
    expect(readInstall({ headers: { [INSTALL_HEADER]: INSTALL, [PLATFORM_HEADER]: 'windows' } })?.platform).toBeNull();
    expect(readInstall({ headers: { [INSTALL_HEADER]: randomBytes(16).toString('base64url') } })).not.toBeNull();
  });

  it.each([['absent', undefined], ['too short', 'abc'], ['not base64url', `${INSTALL.slice(0, 40)}+/=`], ['too long', 'a'.repeat(87)]])(
    '%s → unknown install (never an error)',
    (_, value) => {
      expect(readInstall({ headers: value === undefined ? {} : { [INSTALL_HEADER]: value } })).toBeNull();
    },
  );

  it('is stored only as an HMAC under a key derived from the master key', () => {
    const h = installHash(MASTER, INSTALL);
    expect(h).toMatch(/^[0-9a-f]{64}$/);
    expect(h).not.toContain(Buffer.from(INSTALL, 'base64url').toString('hex').slice(0, 16));
    expect(installHash(MASTER, INSTALL)).toBe(h);
    expect(installHash(randomBytes(32), INSTALL)).not.toBe(h);
  });
});

function httpCtx(req: Record<string, unknown>, meta: Record<string, unknown> = {}): ExecutionContext {
  const handler = (): void => undefined;
  for (const [k, v] of Object.entries(meta)) Reflect.defineMetadata(k, v, handler);
  return {
    getType: () => 'http',
    getHandler: () => handler,
    getClass: () => class {},
    switchToHttp: () => ({ getRequest: () => req }),
  } as unknown as ExecutionContext;
}

describe('DeviceBanGuard', () => {
  const banned = new Set<string>();
  const db = {
    query: jest.fn(async (_sql: string, params: unknown[]) => ({ rowCount: banned.has(params[0] as string) ? 1 : 0, rows: [] })),
  };
  const guard = new DeviceBanGuard(new Reflector(), db as never, { masterKey: MASTER } as never);
  const req = (id?: string) => ({ headers: id ? { [INSTALL_HEADER]: id } : {} });

  beforeEach(() => {
    banned.clear();
    db.query.mockClear();
  });

  it('no header or a malformed one → through, without a query', async () => {
    await expect(guard.canActivate(httpCtx(req()))).resolves.toBe(true);
    await expect(guard.canActivate(httpCtx(req('bad')))).resolves.toBe(true);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('a known-good install → through; a banned one → 403 device_banned (no reason given)', async () => {
    await expect(guard.canActivate(httpCtx(req(INSTALL)))).resolves.toBe(true);
    banned.add(installHash(MASTER, INSTALL));
    const err = await guard.canActivate(httpCtx(req(INSTALL))).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 403, code: 'device_banned', message: "This device can't use Aura." });
  });

  it('public routes and the routes a closed account keeps (account, safety reads) are never refused', async () => {
    banned.add(installHash(MASTER, INSTALL));
    await expect(guard.canActivate(httpCtx(req(INSTALL), { [IS_PUBLIC]: true }))).resolves.toBe(true);
    await expect(guard.canActivate(httpCtx(req(INSTALL), { [ALLOW_ACCOUNT_CLOSED]: true }))).resolves.toBe(true);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('queries by the hash, never the raw id', async () => {
    await guard.canActivate(httpCtx(req(INSTALL)));
    expect(JSON.stringify(db.query.mock.calls)).not.toContain(INSTALL);
  });
});

describe('InstallSeenInterceptor', () => {
  const queries: Array<{ sql: string; params: unknown[] }> = [];
  const db = { query: jest.fn(async (sql: string, params: unknown[]) => (queries.push({ sql, params }), { rows: [], rowCount: 1 })) };
  const interceptor = new InstallSeenInterceptor(db as never, { masterKey: MASTER } as never);
  const next = (value: unknown): CallHandler => ({ handle: () => of(value) });

  beforeEach(() => {
    queries.length = 0;
  });

  it('after a successful authenticated call: records the hashed install for the account, returns the response', async () => {
    const r = { headers: { [INSTALL_HEADER]: INSTALL, [PLATFORM_HEADER]: 'android' }, user: { id: USER } };
    await expect(lastValueFrom(interceptor.intercept(httpCtx(r), next({ ok: 1 })))).resolves.toEqual({ ok: 1 });
    expect(queries).toHaveLength(1);
    expect(queries[0].params).toEqual([USER, installHash(MASTER, INSTALL), 'android', 19]);
  });

  it('never on a refused call (e.g. an under-13 profile stores nothing), never without a user or a header', async () => {
    const r = { headers: { [INSTALL_HEADER]: INSTALL }, user: { id: USER } };
    await expect(lastValueFrom(interceptor.intercept(httpCtx(r), { handle: () => throwError(() => new Error('under_13')) }))).rejects.toThrow('under_13');
    await lastValueFrom(interceptor.intercept(httpCtx({ headers: { [INSTALL_HEADER]: INSTALL } }), next(null)));
    await lastValueFrom(interceptor.intercept(httpCtx({ headers: {}, user: { id: USER } }), next(null)));
    expect(queries).toHaveLength(0);
  });

  it('a failing write never fails the request', async () => {
    const failing = new InstallSeenInterceptor({ query: jest.fn().mockRejectedValue(Object.assign(new Error('x'), { code: '57P01' })) } as never, {
      masterKey: MASTER,
    } as never);
    const r = { headers: { [INSTALL_HEADER]: INSTALL }, user: { id: USER } };
    await expect(lastValueFrom(failing.intercept(httpCtx(r), next('fine')))).resolves.toBe('fine');
  });
});

describe('ban helpers', () => {
  function recorder(rows: Record<string, unknown[]> = {}) {
    const calls: Array<{ sql: string; params: unknown[] }> = [];
    return {
      calls,
      query: jest.fn(async (sql: string, params: unknown[] = []) => {
        calls.push({ sql, params });
        const key = Object.keys(rows).find((k) => sql.includes(k));
        const r = key ? rows[key] : [];
        return { rows: r, rowCount: r.length };
      }),
    };
  }

  it('banDevicesForAccount bans every install of the account and audits counts with the subject HMAC (never the id)', async () => {
    const q = recorder({
      'select install_hash from public.device_installs': [{ install_hash: 'a'.repeat(64) }, { install_hash: 'b'.repeat(64) }],
      'insert into public.device_bans': [{ install_hash: 'a'.repeat(64) }],
      'insert into public.moderation_actions': [{ id: '1' }],
    });
    const out = await banDevicesForAccount(q as never, MASTER, USER, { reasonCode: 'minor_sexual_content', actor: 'staff:x', reportId: null });
    expect(out).toEqual({ devices: 2, newlyBanned: 1 });
    const audit = q.calls.find((c) => c.sql.includes('moderation_actions'));
    expect(audit?.params.slice(0, 5)).toEqual(['staff:x', 'device_ban', null, expect.stringMatching(/^[0-9a-f]{64}$/), 'minor_sexual_content']);
    expect(JSON.stringify(audit?.params)).not.toContain(USER);
    expect(JSON.parse(audit?.params[5] as string)).toEqual({ scope: 'account', devices: 2, newlyBanned: 1 });
  });

  it('refuses bad reason codes and missing actors', async () => {
    const q = recorder();
    await expect(banDevicesForAccount(q as never, MASTER, USER, { reasonCode: 'Bad Reason', actor: 'staff:x' })).rejects.toMatchObject({ status: 400 });
    await expect(banDevicesForAccount(q as never, MASTER, USER, { reasonCode: 'ok', actor: '' })).rejects.toMatchObject({ status: 400 });
    expect(q.calls).toHaveLength(0);
  });

  it('lifting an unknown or already-lifted ban → 404; a lift is audited', async () => {
    await expect(liftDeviceBan(recorder() as never, '0192f0c2-7a4e-7c1a-9b3d-000000000001', { actor: 'staff:x', reasonCode: 'appeal_upheld' })).rejects.toMatchObject({
      status: 404,
    });
    const q = recorder({
      'update public.device_bans': [{ id: 'ban-1', lifted_at: new Date('2026-09-24T00:00:00Z'), report_id: null, subject_hash: null }],
      'insert into public.moderation_actions': [{ id: '2' }],
    });
    await expect(liftDeviceBan(q as never, 'ban-1', { actor: 'staff:x', reasonCode: 'appeal_upheld' })).resolves.toEqual({
      banId: 'ban-1',
      liftedAt: '2026-09-24T00:00:00.000Z',
    });
    expect(q.calls.some((c) => c.sql.includes('moderation_actions') && c.params[1] === 'device_ban_lift')).toBe(true);
  });

  it('recordInstall keeps the account bounded (the oldest installs go past the cap)', async () => {
    const q = recorder();
    await recordInstall(q as never, MASTER, USER, { id: INSTALL, platform: null });
    expect(q.calls[0].sql).toMatch(/on conflict \(user_id, install_hash\) do update/);
    expect(q.calls[0].sql).toMatch(/offset \$4/);
    expect(q.calls[0].params).toEqual([USER, installHash(MASTER, INSTALL), null, 19]);
  });
});
