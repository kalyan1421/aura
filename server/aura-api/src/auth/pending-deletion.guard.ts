import { CanActivate, ExecutionContext, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { isDeletionPending } from '../account/account.repository';
import { ApiError } from '../common/api-error';
import { DbService } from '../db/db.service';
import type { AuthedRequest } from './current-user.decorator';
import { IS_PUBLIC } from './public.decorator';

export const ALLOW_PENDING_DELETION = 'aura:allowPendingDeletion';

/** Keep a route usable while the caller's account deletion is scheduled (only `/v1/account*`). */
export const AllowPendingDeletion = (): MethodDecorator & ClassDecorator => SetMetadata(ALLOW_PENDING_DELETION, true);

export const deletionPending = (): ApiError =>
  ApiError.forbidden(
    'account_deletion_pending',
    'This account is scheduled for deletion. Keep it with DELETE /v1/account/deletion to use Aura again.',
  );

/**
 * Global guard #2, registered right after AuthGuard (src/auth/auth.module.ts): while a deletion is
 * scheduled, every authenticated route except @AllowPendingDeletion() ones → `403 account_deletion_pending`,
 * so nothing new is written during the grace period. @Public() routes (/health) skip it. Costs one
 * primary-key lookup per authenticated request.
 */
@Injectable()
export class PendingDeletionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly db: DbService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const targets = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;
    if (this.reflector.getAllAndOverride<boolean>(ALLOW_PENDING_DELETION, targets)) return true;

    const user = ctx.switchToHttp().getRequest<AuthedRequest>().user;
    // Fail closed: AuthGuard must have verified the caller first (never skip the check silently).
    if (!user) throw ApiError.unauthorized();
    if (await isDeletionPending(this.db, user.id)) throw deletionPending();
    return true;
  }
}
