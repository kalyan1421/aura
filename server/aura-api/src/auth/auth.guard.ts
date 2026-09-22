import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ApiError } from '../common/api-error';
import type { AuthedRequest } from './current-user.decorator';
import { InvalidTokenError, JwtVerifier } from './jwt-verifier';
import { IS_PUBLIC } from './public.decorator';

/** Global guard: every route needs `Authorization: Bearer <Supabase access token>` unless @Public(). */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly verifier: JwtVerifier,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [ctx.getHandler(), ctx.getClass()]);
    if (isPublic) return true;

    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    const header = req.headers.authorization;
    const m = typeof header === 'string' ? /^Bearer\s+(\S+)\s*$/i.exec(header) : null;
    if (!m) throw ApiError.unauthorized();
    try {
      req.user = await this.verifier.verify(m[1]);
      return true;
    } catch (err) {
      if (err instanceof InvalidTokenError) throw ApiError.unauthorized('Invalid or expired access token.');
      throw err;
    }
  }
}
