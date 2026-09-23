/**
 * Account-wide ban guard (F9 / 19 admin console; contracts/api/v1.md "Account closed"): an account with an active
 * `account_ban` gets `403 account_closed` on every authenticated route except `/v1/account*` (status, deletion,
 * Apple token) and the read-only `GET /v1/safety*` routes; /health stays public; a pending deletion answers first.
 * The real controllers/module carry the wiring checked at the bottom. E2E: test/e2e/account-followups.e2e-spec.ts.
 */
import { Controller, Delete, Get, INestApplication, Module, Post } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AccountController } from '../../src/account/account.controller';
import { isAccountClosed } from '../../src/account/account.repository';
import { ALLOW_ACCOUNT_CLOSED, AccountClosedGuard, AllowAccountClosed } from '../../src/auth/account-closed.guard';
import { AuthGuard } from '../../src/auth/auth.guard';
import { AuthModule } from '../../src/auth/auth.module';
import { InvalidTokenError, JwtVerifier, type AuthUser } from '../../src/auth/jwt-verifier';
import { AllowPendingDeletion, PendingDeletionGuard } from '../../src/auth/pending-deletion.guard';
import { Public } from '../../src/auth/public.decorator';
import { ApiExceptionFilter } from '../../src/common/api-exception.filter';
import { DbService } from '../../src/db/db.service';
import { SafetyController } from '../../src/safety/safety.controller';

const A = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const USER: AuthUser = { id: A, role: 'authenticated', isAnonymous: false };

@Controller()
class AppRoutes {
  @Public()
  @Get('health')
  health(): { status: 'ok' } {
    return { status: 'ok' };
  }

  @Post('v1/sync/push')
  push(): { ok: true } {
    return { ok: true };
  }

  @Get('v1/me/snapshot')
  snapshot(): { ok: true } {
    return { ok: true };
  }

  @Get('v1/rooms')
  rooms(): { rooms: [] } {
    return { rooms: [] };
  }
}

@AllowPendingDeletion()
@AllowAccountClosed()
@Controller('v1/account')
class FakeAccountRoutes {
  @Get()
  status(): { deletionScheduledFor: null } {
    return { deletionScheduledFor: null };
  }

  @Post('deletion')
  requestDeletion(): { deletionScheduledFor: string } {
    return { deletionScheduledFor: '2026-10-15T10:00:00.000Z' };
  }

  @Delete('deletion')
  cancel(): { deletionScheduledFor: null } {
    return { deletionScheduledFor: null };
  }
}

@Controller('v1/safety')
class FakeSafetyRoutes {
  @Get('me')
  @AllowAccountClosed()
  me(): { rooms: 'closed' } {
    return { rooms: 'closed' };
  }

  @Post('reports')
  report(): { reportId: string } {
    return { reportId: 'r' };
  }
}

class FakeVerifier {
  async verify(token: string): Promise<AuthUser> {
    if (token === 'good') return USER;
    throw new InvalidTokenError('nope');
  }
}

/** Answers the pending-deletion and the account-closed lookups; counts each. */
class FakeDb {
  pending = new Set<string>();
  closed = new Set<string>();
  deletionLookups = 0;
  banLookups = 0;
  async query(text: string, params: unknown[]): Promise<{ rows: unknown[]; rowCount: number }> {
    const id = params[0] as string;
    let hit: boolean;
    if (/from public\.account_deletions where user_id = \$1/.test(text)) {
      this.deletionLookups++;
      hit = this.pending.has(id);
    } else if (/from public\.sanctions s where s\.user_id = \$1 and s\.kind = 'account_ban'/.test(text)) {
      this.banLookups++;
      hit = this.closed.has(id);
    } else {
      throw new Error(`unexpected query: ${text}`);
    }
    return { rows: hit ? [{}] : [], rowCount: hit ? 1 : 0 };
  }
}

describe('AccountClosedGuard (global, after AuthGuard and PendingDeletionGuard)', () => {
  let app: INestApplication;
  const db = new FakeDb();

  @Module({
    controllers: [AppRoutes, FakeAccountRoutes, FakeSafetyRoutes],
    providers: [
      { provide: JwtVerifier, useClass: FakeVerifier },
      { provide: DbService, useValue: db },
      { provide: APP_GUARD, useClass: AuthGuard },
      { provide: APP_GUARD, useClass: PendingDeletionGuard },
      { provide: APP_GUARD, useClass: AccountClosedGuard },
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
    db.closed.clear();
    db.deletionLookups = 0;
    db.banLookups = 0;
  });

  const http = () => request(app.getHttpServer());
  const authed = (r: request.Test) => r.set('Authorization', 'Bearer good');

  it('an account in good standing: every route works, one ban lookup per guarded request', async () => {
    await authed(http().post('/v1/sync/push')).expect(201, { ok: true });
    await authed(http().get('/v1/me/snapshot')).expect(200, { ok: true });
    await authed(http().post('/v1/safety/reports')).expect(201);
    expect(db.banLookups).toBe(3);
  });

  it('closed: every other /v1 route → 403 {code: account_closed} (the same calm message everywhere)', async () => {
    db.closed.add(A);
    for (const call of [
      () => http().post('/v1/sync/push'),
      () => http().get('/v1/me/snapshot'),
      () => http().get('/v1/rooms'),
      () => http().post('/v1/safety/reports'),
    ]) {
      const res = await authed(call()).expect(403);
      expect(res.body).toEqual({ code: 'account_closed', message: "This account was closed for breaking Aura's rules." });
    }
  });

  it('closed: /v1/account* (status, delete, keep) and GET /v1/safety/me still work, without a ban lookup', async () => {
    db.closed.add(A);
    await authed(http().get('/v1/account')).expect(200);
    await authed(http().post('/v1/account/deletion')).expect(201);
    await authed(http().delete('/v1/account/deletion')).expect(200);
    await authed(http().get('/v1/safety/me')).expect(200, { rooms: 'closed' });
    expect(db.banLookups).toBe(0);
  });

  it('a pending deletion answers first (account_deletion_pending), with no ban lookup', async () => {
    db.closed.add(A);
    db.pending.add(A);
    const res = await authed(http().post('/v1/sync/push')).expect(403);
    expect(res.body.code).toBe('account_deletion_pending');
    expect(db.banLookups).toBe(0);
  });

  it('/health needs no token and no lookup; a missing / bad token is 401 before any lookup', async () => {
    db.closed.add(A);
    await http().get('/health').expect(200, { status: 'ok' });
    await http().post('/v1/sync/push').expect(401);
    await http().get('/v1/account').set('Authorization', 'Bearer bad').expect(401);
    expect(db.banLookups + db.deletionLookups).toBe(0);
  });

  it('fails closed if it ever runs without a verified user', async () => {
    const reflector = { getAllAndOverride: () => false };
    const guard = new AccountClosedGuard(reflector as never, db as never);
    const ctx = { getHandler: () => undefined, getClass: () => undefined, switchToHttp: () => ({ getRequest: () => ({}) }) };
    await expect(guard.canActivate(ctx as never)).rejects.toMatchObject({ status: 401 });
  });
});

describe('the real wiring', () => {
  it('the lookup is one query on the active account_ban sanction (partial index sanctions_user_idx)', async () => {
    const seen: { text: string; params: unknown[] }[] = [];
    const q = { query: async (text: string, params: unknown[]) => (seen.push({ text, params }), { rows: [], rowCount: 0 }) };
    await expect(isAccountClosed(q as never, A)).resolves.toBe(false);
    expect(seen).toHaveLength(1);
    expect(seen[0].params).toEqual([A]);
    expect(seen[0].text).toMatch(/s\.kind = 'account_ban'/);
    expect(seen[0].text).toMatch(/s\.lifted_at is null and s\.starts_at <= now\(\) and \(s\.ends_at is null or s\.ends_at > now\(\)\)/);
  });

  it('AuthModule registers the guards in order: auth → pending deletion → account closed', () => {
    const providers = Reflect.getMetadata('providers', AuthModule) as { provide?: unknown; useClass?: unknown }[];
    const guards = providers.filter((p) => p.provide === APP_GUARD).map((p) => p.useClass);
    expect(guards).toEqual([AuthGuard, PendingDeletionGuard, AccountClosedGuard]);
  });

  it('exempt: the whole AccountController and only the GET routes of SafetyController', () => {
    expect(Reflect.getMetadata(ALLOW_ACCOUNT_CLOSED, AccountController)).toBe(true);
    const proto = SafetyController.prototype as unknown as Record<string, object>;
    const exempt = Object.getOwnPropertyNames(proto)
      .filter((m) => m !== 'constructor' && Reflect.getMetadata(ALLOW_ACCOUNT_CLOSED, proto[m]) === true)
      .sort();
    expect(exempt).toEqual(['me', 'myBlocks', 'myReports']);
    expect(Reflect.getMetadata(ALLOW_ACCOUNT_CLOSED, SafetyController)).toBeUndefined();
  });
});
