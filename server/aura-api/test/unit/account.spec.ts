/**
 * Account deletion (F8 REQ-ACC-11): 7-day date math, idempotent request / cancel against an in-memory
 * table, the pending-deletion guard's exemptions, and the Storage API client. The same flows run
 * against the real DB + Storage (and the purge) in test/e2e.
 */
import { Controller, Delete, Get, INestApplication, Module, Post, Put } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { CancelResult, DeletionRow } from '../../src/account/account.repository';
import { DELETION_GRACE_DAYS, deletionDateFor } from '../../src/account/account.schema';
import { AccountService } from '../../src/account/account.service';
import { MediaStoreError, MediaStoreUnavailableError, PrivateMediaStore } from '../../src/account/private-media';
import { AuthGuard } from '../../src/auth/auth.guard';
import { CurrentUser } from '../../src/auth/current-user.decorator';
import { InvalidTokenError, JwtVerifier, type AuthUser } from '../../src/auth/jwt-verifier';
import { AllowPendingDeletion, PendingDeletionGuard } from '../../src/auth/pending-deletion.guard';
import { Public } from '../../src/auth/public.decorator';
import { ApiError } from '../../src/common/api-error';
import { ApiExceptionFilter } from '../../src/common/api-exception.filter';
import { DbService } from '../../src/db/db.service';

const A = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const B = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const DAY = 86_400_000;

describe('deletion date math', () => {
  it('is exactly 7 × 24 h after the request', () => {
    expect(DELETION_GRACE_DAYS).toBe(7);
    const t = new Date('2026-10-08T10:00:00.000Z');
    expect(deletionDateFor(t).toISOString()).toBe('2026-10-15T10:00:00.000Z');
    expect(deletionDateFor(t).getTime() - t.getTime()).toBe(7 * DAY);
  });

  it.each([
    ['month end', '2026-10-28T23:59:59.999Z', '2026-11-04T23:59:59.999Z'],
    ['year end', '2026-12-29T04:00:00.000Z', '2027-01-05T04:00:00.000Z'],
    ['leap day', '2028-02-25T12:00:00.000Z', '2028-03-03T12:00:00.000Z'],
    ['EU DST change (instants ignore local clocks)', '2026-10-22T01:30:00.000Z', '2026-10-29T01:30:00.000Z'],
  ])('%s', (_, from, to) => {
    expect(deletionDateFor(new Date(from)).toISOString()).toBe(to);
  });
});

/** Mirrors `public.account_deletions` + the caller's device tokens; `clock` stands in for clock_timestamp(). */
class MemAccounts {
  rows = new Map<string, DeletionRow>();
  tokens = new Map<string, string>(); // token → user
  clock = new Date('2026-10-08T10:00:00.000Z');

  async find(_: unknown, userId: string): Promise<DeletionRow | null> {
    return this.rows.get(userId) ?? null;
  }
  async schedule(_: unknown, userId: string, requestedAt: Date, scheduledFor: Date): Promise<DeletionRow> {
    if (!this.rows.has(userId)) this.rows.set(userId, { requestedAt, scheduledFor });
    return this.rows.get(userId)!;
  }
  async cancel(_: unknown, userId: string): Promise<CancelResult> {
    const row = this.rows.get(userId);
    if (!row) return 'none';
    if (row.scheduledFor.getTime() <= this.clock.getTime()) return 'due';
    this.rows.delete(userId);
    return 'cancelled';
  }
  async deleteDeviceTokens(_: unknown, userId: string): Promise<number> {
    let n = 0;
    for (const [t, u] of this.tokens) if (u === userId && this.tokens.delete(t)) n++;
    return n;
  }
}

/** DbService stand-in: withTx runs inline; the advisory lock query is recorded. */
const fakeDb = () => {
  const sql: string[] = [];
  const q = { query: async (text: string) => (sql.push(text), { rows: [], rowCount: 0 }) };
  return { sql, db: { ...q, withTx: async <T>(fn: (tx: typeof q) => Promise<T>) => fn(q) } };
};

describe('AccountService', () => {
  let repo: MemAccounts;
  let service: AccountService;
  let sql: string[];

  beforeEach(() => {
    repo = new MemAccounts();
    const f = fakeDb();
    sql = f.sql;
    service = new AccountService(f.db as never, repo as never);
  });

  it('GET → null when nothing is scheduled', async () => {
    await expect(service.status(A)).resolves.toEqual({ deletionScheduledFor: null });
  });

  it('request → +7 days; a repeat returns the SAME date (never moves it)', async () => {
    const t0 = new Date('2026-10-08T10:00:00.000Z');
    const first = await service.requestDeletion(A, undefined, t0);
    expect(first).toEqual({ deletionScheduledFor: '2026-10-15T10:00:00.000Z' });
    const again = await service.requestDeletion(A, {}, new Date(t0.getTime() + 3 * DAY));
    expect(again).toEqual(first);
    await expect(service.status(A)).resolves.toEqual(first);
    expect(repo.rows.size).toBe(1);
    expect(sql.filter((s) => s.includes('pg_advisory_xact_lock'))).toHaveLength(2); // serialised per user
  });

  it("removes the caller's device tokens immediately (and only theirs)", async () => {
    repo.tokens.set('t1', A).set('t2', A).set('t3', B);
    await service.requestDeletion(A, undefined);
    expect([...repo.tokens]).toEqual([['t3', B]]);
    repo.tokens.set('t4', A); // re-registered somehow before the guard kicked in
    await service.requestDeletion(A, undefined);
    expect([...repo.tokens]).toEqual([['t3', B]]);
  });

  it('cancel → null, idempotent, and a new request afterwards starts a fresh 7 days', async () => {
    await service.requestDeletion(A, undefined, new Date('2026-10-08T10:00:00.000Z'));
    await expect(service.cancelDeletion(A, undefined)).resolves.toEqual({ deletionScheduledFor: null });
    await expect(service.cancelDeletion(A, {})).resolves.toEqual({ deletionScheduledFor: null });
    await expect(service.status(A)).resolves.toEqual({ deletionScheduledFor: null });
    const later = await service.requestDeletion(A, undefined, new Date('2026-10-09T08:00:00.000Z'));
    expect(later.deletionScheduledFor).toBe('2026-10-16T08:00:00.000Z');
  });

  it('cancel without any schedule is a no-op 200', async () => {
    await expect(service.cancelDeletion(B, undefined)).resolves.toEqual({ deletionScheduledFor: null });
  });

  it('cancel after the grace period → 409 account_deletion_in_progress, schedule kept', async () => {
    await service.requestDeletion(A, undefined, new Date('2026-10-01T10:00:00.000Z'));
    repo.clock = new Date('2026-10-08T10:00:00.000Z'); // exactly due
    const err = await service.cancelDeletion(A, undefined).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 409, code: 'account_deletion_in_progress' });
    expect(repo.rows.has(A)).toBe(true);
  });

  it('a body that is not a JSON object → 400 invalid_request, nothing scheduled', async () => {
    await expect(service.requestDeletion(A, [])).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    await expect(service.requestDeletion(A, 'yes')).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    await expect(service.cancelDeletion(A, [1])).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    expect(repo.rows.size).toBe(0);
    await expect(service.requestDeletion(A, { reason: 'ignored' })).resolves.toHaveProperty('deletionScheduledFor');
  });

  it('a deleted auth user (FK 23503) → 401 unknown_user', async () => {
    const failing = { schedule: jest.fn().mockRejectedValue(Object.assign(new Error('fk'), { code: '23503' })) };
    const s = new AccountService(fakeDb().db as never, failing as never);
    await expect(s.requestDeletion(A, undefined)).rejects.toMatchObject({ status: 401, code: 'unknown_user' });
  });
});

// ---------------------------------------------------------------- guard exemptions
const USER: AuthUser = { id: A, role: 'authenticated', isAnonymous: false };

@Controller()
class OpenController {
  @Public()
  @Get('health')
  health(): { status: 'ok' } {
    return { status: 'ok' };
  }

  @Post('v1/sync/push')
  push(): { ok: true } {
    return { ok: true };
  }

  @Put('v1/devices')
  device(@CurrentUser() u: AuthUser): { id: string } {
    return { id: u.id };
  }
}

@AllowPendingDeletion()
@Controller('v1/account')
class FakeAccountController {
  @Get()
  status(): { deletionScheduledFor: string } {
    return { deletionScheduledFor: '2026-10-15T10:00:00.000Z' };
  }

  @Delete('deletion')
  cancel(): { deletionScheduledFor: null } {
    return { deletionScheduledFor: null };
  }
}

class FakeVerifier {
  async verify(token: string): Promise<AuthUser> {
    if (token === 'good') return USER;
    throw new InvalidTokenError('nope');
  }
}

/** Answers the guard's primary-key lookup; counts calls. */
class FakeDb {
  pending = new Set<string>();
  lookups = 0;
  async query(text: string, params: unknown[]): Promise<{ rows: unknown[]; rowCount: number }> {
    expect(text).toMatch(/from public\.account_deletions where user_id = \$1/);
    this.lookups++;
    const hit = this.pending.has(params[0] as string);
    return { rows: hit ? [{}] : [], rowCount: hit ? 1 : 0 };
  }
}

describe('PendingDeletionGuard (global, after AuthGuard)', () => {
  let app: INestApplication;
  const db = new FakeDb();

  @Module({
    controllers: [OpenController, FakeAccountController],
    providers: [
      { provide: JwtVerifier, useClass: FakeVerifier },
      { provide: DbService, useValue: db },
      { provide: APP_GUARD, useClass: AuthGuard },
      { provide: APP_GUARD, useClass: PendingDeletionGuard },
    ],
  })
  class ProbeModule {}

  beforeAll(async () => {
    const ref = await Test.createTestingModule({ imports: [ProbeModule] }).compile();
    app = ref.createNestApplication();
    app.useGlobalFilters(new ApiExceptionFilter());
    await app.init();
  });
  afterAll(() => app.close());
  beforeEach(() => {
    db.pending.clear();
    db.lookups = 0;
  });

  const http = () => request(app.getHttpServer());
  const authed = (r: request.Test) => r.set('Authorization', 'Bearer good');

  it('no deletion scheduled → routes work, one lookup per authenticated request', async () => {
    await authed(http().post('/v1/sync/push')).expect(201, { ok: true });
    await authed(http().put('/v1/devices')).expect(200, { id: A });
    expect(db.lookups).toBe(2);
  });

  it('scheduled → every other /v1 route is 403 {code: account_deletion_pending}', async () => {
    db.pending.add(A);
    for (const r of [() => http().post('/v1/sync/push'), () => http().put('/v1/devices')]) {
      const res = await authed(r()).expect(403);
      expect(res.body).toEqual({ code: 'account_deletion_pending', message: expect.any(String) });
    }
  });

  it('/v1/account* stays usable while scheduled, without a lookup', async () => {
    db.pending.add(A);
    await authed(http().get('/v1/account')).expect(200);
    await authed(http().delete('/v1/account/deletion')).expect(200, { deletionScheduledFor: null });
    expect(db.lookups).toBe(0);
  });

  it('/health (@Public) needs no token and no lookup', async () => {
    db.pending.add(A);
    await http().get('/health').expect(200, { status: 'ok' });
    expect(db.lookups).toBe(0);
  });

  it('authentication still comes first: no/bad token → 401 before any lookup', async () => {
    db.pending.add(A);
    await http().post('/v1/sync/push').expect(401);
    await http().get('/v1/account').set('Authorization', 'Bearer bad').expect(401);
    expect(db.lookups).toBe(0);
  });

  it('fails closed if it ever runs without a verified user', async () => {
    const reflector = { getAllAndOverride: () => false };
    const guard = new PendingDeletionGuard(reflector as never, db as never);
    const ctx = {
      getHandler: () => undefined,
      getClass: () => undefined,
      switchToHttp: () => ({ getRequest: () => ({}) }),
    };
    await expect(guard.canActivate(ctx as never)).rejects.toMatchObject({ status: 401 });
  });
});

// ---------------------------------------------------------------- Storage API client
describe('PrivateMediaStore', () => {
  const calls: { url: string; init: RequestInit }[] = [];
  const okFetch = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response('[]', { status: 200 });
  }) as unknown as typeof fetch;

  beforeEach(() => (calls.length = 0));

  it('nothing to delete → no request, even without a key', async () => {
    const store = new PrivateMediaStore({ supabaseUrl: 'http://x', fetch: okFetch });
    await expect(store.remove([])).resolves.toBe(0);
    expect(calls).toHaveLength(0);
  });

  it('objects but no service key → MediaStoreUnavailableError (the purge defers the account)', async () => {
    const store = PrivateMediaStore.fromEnv('http://x', {});
    expect(store.configured).toBe(false);
    await expect(store.remove([`${A}/voice/1.bin`])).rejects.toBeInstanceOf(MediaStoreUnavailableError);
  });

  it('DELETEs through the Storage API in batches of 100, with the service key', async () => {
    const store = new PrivateMediaStore({ supabaseUrl: 'http://127.0.0.1:55521/', serviceKey: 'svc', fetch: okFetch });
    const names = Array.from({ length: 250 }, (_, i) => `${A}/voice/${i}.bin`);
    await expect(store.remove(names)).resolves.toBe(250);
    expect(calls.map((c) => c.url)).toEqual(Array(3).fill('http://127.0.0.1:55521/storage/v1/object/private-media'));
    expect(calls[0].init.method).toBe('DELETE');
    expect(calls[0].init.headers).toMatchObject({ apikey: 'svc', Authorization: 'Bearer svc' });
    const sent = calls.flatMap((c) => (JSON.parse(String(c.init.body)) as { prefixes: string[] }).prefixes);
    expect(sent).toEqual(names);
    expect(calls.map((c) => (JSON.parse(String(c.init.body)) as { prefixes: string[] }).prefixes.length)).toEqual([100, 100, 50]);
  });

  it('a non-2xx reply → MediaStoreError whose message never echoes paths / user ids', async () => {
    const failing = (async () =>
      new Response(JSON.stringify({ error: `denied ${A}/voice/1.bin` }), { status: 403 })) as unknown as typeof fetch;
    const store = new PrivateMediaStore({ supabaseUrl: 'http://x', serviceKey: 'svc', fetch: failing });
    const err = await store.remove([`${A}/voice/1.bin`]).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(MediaStoreError);
    expect((err as Error).message).toBe('storage delete failed: HTTP 403');
    expect((err as Error).message).not.toContain(A);
  });
});
