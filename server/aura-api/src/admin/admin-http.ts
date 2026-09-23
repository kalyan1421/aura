import { Injectable, type CallHandler, type ExecutionContext, type NestInterceptor } from '@nestjs/common';
import type { Request, Response } from 'express';
import type { Observable } from 'rxjs';
import { isUuid } from '../common/uuid';
import { AdminErrors } from './admin-errors';

/** Console responses are never cached anywhere (they carry moderation data). */
@Injectable()
export class NoStoreInterceptor implements NestInterceptor {
  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const res = ctx.switchToHttp().getResponse<Response>();
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    return next.handle();
  }
}

/** Path ids are UUIDs; anything else is a plain 404 (never a database error). */
export function uuidParam(v: string): string {
  if (!isUuid(v)) throw AdminErrors.notFound();
  return v.toLowerCase();
}

/** The caller's address as Express sees it (behind a proxy, configure `trust proxy` so this is the client). */
export function clientAddress(req: Request): string | undefined {
  return req.ip ?? req.socket?.remoteAddress ?? undefined;
}
