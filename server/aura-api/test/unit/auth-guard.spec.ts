import { Controller, Get, INestApplication, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthGuard } from '../../src/auth/auth.guard';
import { CurrentUser } from '../../src/auth/current-user.decorator';
import { InvalidTokenError, JwtVerifier, type AuthUser } from '../../src/auth/jwt-verifier';
import { Public } from '../../src/auth/public.decorator';
import { ApiExceptionFilter } from '../../src/common/api-exception.filter';

const USER: AuthUser = { id: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d', role: 'authenticated', isAnonymous: false };

@Controller()
class ProbeController {
  @Public()
  @Get('open')
  open(): { ok: true } {
    return { ok: true };
  }

  @Get('me')
  me(@CurrentUser() u: AuthUser): AuthUser {
    return u;
  }
}

class FakeVerifier {
  async verify(token: string): Promise<AuthUser> {
    if (token === 'good') return USER;
    if (token === 'guest') return { ...USER, isAnonymous: true };
    throw new InvalidTokenError('nope');
  }
}

@Module({
  controllers: [ProbeController],
  providers: [{ provide: JwtVerifier, useClass: FakeVerifier }, { provide: APP_GUARD, useClass: AuthGuard }],
})
class ProbeModule {}

describe('AuthGuard (global) + error shape', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const ref = await Test.createTestingModule({ imports: [ProbeModule] }).compile();
    app = ref.createNestApplication();
    app.useGlobalFilters(new ApiExceptionFilter());
    await app.init();
  });
  afterAll(() => app.close());

  it('lets @Public() routes through', () => request(app.getHttpServer()).get('/open').expect(200, { ok: true }));

  it('401 {code,message} without a token', async () => {
    const r = await request(app.getHttpServer()).get('/me').expect(401);
    expect(r.body).toEqual({ code: 'unauthorized', message: expect.any(String) });
  });

  it('401 for a non-Bearer scheme or a bad token', async () => {
    await request(app.getHttpServer()).get('/me').set('Authorization', 'Basic good').expect(401);
    const r = await request(app.getHttpServer()).get('/me').set('Authorization', 'Bearer bad').expect(401);
    expect(r.body.code).toBe('unauthorized');
  });

  it('SR-5: refuses a valid but anonymous Supabase session (401 anonymous_session), even on a normal route', async () => {
    const r = await request(app.getHttpServer()).get('/me').set('Authorization', 'Bearer guest').expect(401);
    expect(r.body).toEqual({ code: 'anonymous_session', message: expect.any(String) });
  });

  it('exposes the verified user via @CurrentUser()', () =>
    request(app.getHttpServer()).get('/me').set('Authorization', 'Bearer good').expect(200, USER));

  it('unknown routes are 404 {code:not_found}', async () => {
    const r = await request(app.getHttpServer()).get('/nope').set('Authorization', 'Bearer good').expect(404);
    expect(r.body.code).toBe('not_found');
  });
});
