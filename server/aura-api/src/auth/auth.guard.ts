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
    let user;
    try {
      user = await this.verifier.verify(m[1]);
    } catch (err) {
      if (err instanceof InvalidTokenError) throw ApiError.unauthorized('Invalid or expired access token.');
      throw err;
    }
    // SR-5 (docs/security/milestone-b-review.md): Aura has no guest accounts. Anonymous sign-ins are off in
    // supabase/config.toml, but they are one dashboard toggle away on a hosted project — and an anonymous session would
    // otherwise be a full account (rooms, reflections, gifts) with no identity behind it. Fail closed here as well.
    if (user.isAnonymous) throw ApiError.unauthorized('Sign in to use Aura.', 'anonymous_session');
    req.user = user;
    return true;
  }
}
