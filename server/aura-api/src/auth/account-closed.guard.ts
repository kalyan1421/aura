import { CanActivate, ExecutionContext, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { isAccountClosed } from '../account/account.repository';
import { ApiError } from '../common/api-error';
import { DbService } from '../db/db.service';
import { accountClosed } from '../safety/safety.queries';
import type { AuthedRequest } from './current-user.decorator';
import { IS_PUBLIC } from './public.decorator';

export const ALLOW_ACCOUNT_CLOSED = 'aura:allowAccountClosed';

/**
 * Keep a route usable for an account closed for breaking the rules: `/v1/account*` (status, deletion, export — PRD F8
 * "in-app delete" and DPDP/GDPR erasure stay available to everyone) and the read-only `GET /v1/safety*` routes the app
 * uses to show the closed state (contracts/api/v1-rooms.md §0).
 */
export const AllowAccountClosed = (): MethodDecorator & ClassDecorator => SetMetadata(ALLOW_ACCOUNT_CLOSED, true);

/**
 * Global guard #3, registered after AuthGuard and PendingDeletionGuard (src/auth/auth.module.ts): while the caller has
 * an active `account_ban` sanction, every authenticated route except @AllowAccountClosed() ones →
 * `403 account_closed` (contracts/api/v1.md "Account closed"). A pending deletion answers first
 * (`account_deletion_pending`). @Public() routes (/health) skip it. One indexed lookup per authenticated request.
 */
@Injectable()
export class AccountClosedGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly db: DbService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const targets = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;
    if (this.reflector.getAllAndOverride<boolean>(ALLOW_ACCOUNT_CLOSED, targets)) return true;

    const user = ctx.switchToHttp().getRequest<AuthedRequest>().user;
    // Fail closed: AuthGuard must have verified the caller first (never skip the check silently).
    if (!user) throw ApiError.unauthorized();
    // Same code and message as the rooms/safety routes; never says why (19 admin console: no tipping off).
    if (await isAccountClosed(this.db, user.id)) throw accountClosed();
    return true;
  }
}
