import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { Request } from 'express';
import { ApiError } from '../common/api-error';
import type { AuthUser } from './jwt-verifier';

export type AuthedRequest = Request & { user?: AuthUser };

/** The verified Supabase user (`sub`) for this request. */
export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): AuthUser => {
  const user = ctx.switchToHttp().getRequest<AuthedRequest>().user;
  if (!user) throw ApiError.unauthorized();
  return user;
});
