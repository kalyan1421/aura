import { CanActivate, ExecutionContext, Injectable, Logger, NestInterceptor, type CallHandler } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import { concatMap, type Observable } from 'rxjs';
import { ALLOW_ACCOUNT_CLOSED } from '../auth/account-closed.guard';
import type { AuthedRequest } from '../auth/current-user.decorator';
import { IS_PUBLIC } from '../auth/public.decorator';
import { AppConfig } from '../config/app-config';
import { pgCode } from '../db/db';
import { DbService } from '../db/db.service';
import { deviceBanned, isInstallBanned, recordInstall } from './device-bans';
import { installHash, readInstall } from './install-id';

/**
 * Global guard (registered by DevicesModule, after the auth guards): a request that carries the install id of a
 * banned install → `403 device_banned`. Skips @Public() routes (config, health, the grievance form) and the routes a
 * closed account keeps (@AllowAccountClosed(): `/v1/account*` — status, deletion — and the safety reads), so a
 * banned phone can still delete its account and ask for a review. The app sends the header on sign-in / profile,
 * device registration and room matching (src/devices/install-id.ts). One indexed lookup, only when the header is there.
 */
@Injectable()
export class DeviceBanGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly db: DbService,
    private readonly config: AppConfig,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    if (ctx.getType() !== 'http') return true;
    const targets = [ctx.getHandler(), ctx.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;
    if (this.reflector.getAllAndOverride<boolean>(ALLOW_ACCOUNT_CLOSED, targets)) return true;
    const install = readInstall(ctx.switchToHttp().getRequest<Request>());
    if (!install) return true;
    if (await isInstallBanned(this.db, installHash(this.config.masterKey, install.id))) throw deviceBanned();
    return true;
  }
}

/**
 * Global interceptor: after an authenticated request with an install id SUCCEEDS, remember that the account used this
 * install (`device_installs`), so a later ban of the account reaches its phones. Never on a refused request — e.g. an
 * under-13 profile stores nothing at all (REQ-ACC-03). Best effort: a failure here is logged (no ids) and never fails
 * the request.
 */
@Injectable()
export class InstallSeenInterceptor implements NestInterceptor {
  private readonly logger = new Logger('InstallSeen');

  constructor(
    private readonly db: DbService,
    private readonly config: AppConfig,
  ) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (ctx.getType() !== 'http') return next.handle();
    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    const install = readInstall(req);
    if (!install) return next.handle();
    return next.handle().pipe(
      concatMap(async (value: unknown) => {
        const user = req.user;
        if (user) {
          try {
            await recordInstall(this.db, this.config.masterKey, user.id, install);
          } catch (err) {
            // 23503: the account is gone (purged between the auth check and now) — nothing to remember.
            if (pgCode(err) !== '23503') this.logger.warn(`could not record an install (${pgCode(err) ?? 'error'})`);
          }
        }
        return value;
      }),
    );
  }
}
