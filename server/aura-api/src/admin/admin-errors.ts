import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import type { ModerationError } from '../safety/moderation.service';

/** Console error codes (`{ code, message }` like every Aura API error). */
export const AdminErrors = {
  notStaff: (): ApiError => ApiError.forbidden('not_staff', 'This account cannot use the admin console.'),
  forbiddenRole: (): ApiError => ApiError.forbidden('forbidden_role', 'Your console role cannot do this.'),
  appAccount: (): ApiError =>
    ApiError.forbidden('staff_account_is_app_account', 'Staff accounts must be separate from Aura app accounts.'),
  mfaRequired: (): ApiError => ApiError.unauthorized('Two-factor verification (TOTP) is required.', 'mfa_required'),
  sessionExpired: (): ApiError => ApiError.unauthorized('This console session has ended. Sign in again.', 'session_expired'),
  routeNotConfigured: (): ApiError => ApiError.forbidden('forbidden_role', 'This route has no console role configured.'),
  notFound: (what = 'Not found.'): ApiError => new ApiError(HttpStatus.NOT_FOUND, 'not_found', what),
  conflict: (code: string, message: string): ApiError => ApiError.conflict(code, message),
  badRequest: (message: string, code = 'invalid_request'): ApiError => ApiError.badRequest(code, message),
  rateLimited: (): ApiError =>
    new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'rate_limited', 'Too many requests. Please try again in an hour.'),
  unavailable: (code: string, message: string): ApiError => new ApiError(HttpStatus.SERVICE_UNAVAILABLE, code, message),
};

const MODERATION_STATUS: Record<ModerationError['code'], HttpStatus> = {
  report_not_found: HttpStatus.NOT_FOUND,
  sanction_not_found: HttpStatus.NOT_FOUND,
  evidence_not_found: HttpStatus.NOT_FOUND,
  report_closed: HttpStatus.CONFLICT,
  no_subject: HttpStatus.CONFLICT,
  crisis_never_strikes: HttpStatus.CONFLICT,
  invalid_duration: HttpStatus.BAD_REQUEST,
  invalid_input: HttpStatus.BAD_REQUEST,
};

const MODERATION_MESSAGE: Record<ModerationError['code'], string> = {
  report_not_found: 'That report does not exist.',
  sanction_not_found: 'That sanction does not exist or was already lifted.',
  evidence_not_found: 'That evidence hold does not exist (it may have expired).',
  report_closed: 'That report is already closed.',
  no_subject: 'This report has no account to act on (the account may have been deleted).',
  crisis_never_strikes: 'A crisis report can never add a strike (PRD REQ-SAFE-08).',
  invalid_duration: 'That duration is not allowed for this action.',
  invalid_input: 'Invalid input.',
};

/** ModerationService errors → HTTP (the internal service throws typed codes). */
export function moderationHttpError(err: ModerationError): ApiError {
  return new ApiError(MODERATION_STATUS[err.code] ?? HttpStatus.BAD_REQUEST, err.code, MODERATION_MESSAGE[err.code] ?? err.code);
}
