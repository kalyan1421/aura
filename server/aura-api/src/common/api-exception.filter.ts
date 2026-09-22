import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import type { Response } from 'express';
import { ApiError } from './api-error';

const STATUS_CODES: Record<number, string> = {
  400: 'bad_request',
  401: 'unauthorized',
  403: 'forbidden',
  404: 'not_found',
  405: 'method_not_allowed',
  409: 'conflict',
  413: 'payload_too_large',
  415: 'unsupported_media_type',
  429: 'rate_limited',
};

/**
 * Normalises every error to `{ code, message }`. Never logs request bodies
 * (mood notes, DOB, capsule text must not reach logs — CLAUDE.md).
 */
@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('ApiExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    if (res.headersSent) return;

    if (exception instanceof ApiError) {
      res.status(exception.status).json({ code: exception.code, message: exception.message });
      return;
    }
    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();
      const message =
        typeof body === 'string'
          ? body
          : typeof (body as { message?: unknown }).message === 'string'
            ? (body as { message: string }).message
            : exception.message;
      if (status === HttpStatus.BAD_REQUEST && /json/i.test(message)) {
        // Parser messages quote the body — never echo client content.
        res.status(status).json({ code: 'invalid_json', message: 'Request body is not valid JSON.' });
        return;
      }
      res.status(status).json({ code: STATUS_CODES[status] ?? 'error', message });
      return;
    }
    // body-parser errors (too large / bad JSON) that bypass Nest's wrapping
    const status = (exception as { status?: unknown })?.status;
    if (typeof status === 'number' && status >= 400 && status < 500) {
      const type = (exception as { type?: string }).type;
      const code = type === 'entity.too.large' ? 'payload_too_large' : type === 'entity.parse.failed' ? 'invalid_json' : (STATUS_CODES[status] ?? 'bad_request');
      res.status(status).json({ code, message: code.replace(/_/g, ' ') });
      return;
    }
    const err = exception as Error;
    this.logger.error(`unhandled ${err?.name ?? 'error'}: ${err?.message ?? String(exception)}`, err?.stack);
    res.status(HttpStatus.INTERNAL_SERVER_ERROR).json({ code: 'internal_error', message: 'Something went wrong.' });
  }
}
