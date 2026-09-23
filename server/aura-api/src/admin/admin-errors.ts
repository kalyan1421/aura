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
  ssoRequired: (): ApiError =>
    ApiError.forbidden('sso_required', 'Staff sign in with the organisation’s single sign-on (Google Workspace), then TOTP.'),
  queueSessionCap: (breakUntil: string): ApiError =>
    new ApiError(
      HttpStatus.LOCKED,
      'queue_session_cap',
      `Queue session limit reached (PRD: 2 h). Take a break; non-urgent items open again at ${breakUntil}. Paging items stay open.`,
    ),
  sessionExpired: (): ApiError => ApiError.unauthorized('This console session has ended. Sign in again.', 'session_expired'),
  routeNotConfigured: (): ApiError => ApiError.forbidden('forbidden_role', 'This route has no console role configured.'),
  notFound: (what = 'Not found.'): ApiError => new ApiError(HttpStatus.NOT_FOUND, 'not_found', what),
  conflict: (code: string, message: string): ApiError => ApiError.conflict(code, message),
  badRequest: (message: string, code = 'invalid_request'): ApiError => ApiError.badRequest(code, message),
  rateLimited: (): ApiError =>
    new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'rate_limited', 'Too many requests. Please try again in an hour.'),
  unavailable: (code: string, message: string): ApiError => new ApiError(HttpStatus.SERVICE_UNAVAILABLE, code, message),
  notImplemented: (message: string): ApiError => new ApiError(HttpStatus.NOT_IMPLEMENTED, 'not_implemented', message),
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

/**
 * Refusals from the console's SECURITY DEFINER functions (migration 20261005000016: SQLSTATE AR040, message = code) →
 * HTTP. Anything else passes through unchanged.
 */
const CONSOLE_REFUSALS: Readonly<Record<string, [HttpStatus, string]>> = {
  forbidden_role: [HttpStatus.FORBIDDEN, 'Your console role cannot do this.'],
  invalid_input: [HttpStatus.BAD_REQUEST, 'Invalid input.'],
  no_account: [HttpStatus.NOT_FOUND, 'No Aura account signs in with that email address.'],
  ambiguous_account: [HttpStatus.CONFLICT, 'More than one account uses that email address; resolve it in Supabase first.'],
  app_account: [HttpStatus.CONFLICT, 'That is an Aura app account. Staff accounts must be separate from app accounts.'],
  already_staff: [HttpStatus.CONFLICT, 'That account is already on the staff list.'],
  staff_not_found: [HttpStatus.NOT_FOUND, 'That staff member does not exist.'],
  cannot_change_self: [HttpStatus.CONFLICT, 'You cannot demote or disable yourself; ask another Owner.'],
  last_owner: [HttpStatus.CONFLICT, 'The console must keep at least one enabled Owner.'],
  open_case_exists: [HttpStatus.CONFLICT, 'That account already has an open deletion case.'],
  case_not_found: [HttpStatus.NOT_FOUND, 'That deletion case does not exist.'],
  case_not_awaiting: [HttpStatus.CONFLICT, 'That case is no longer waiting for the account holder to confirm.'],
  case_not_verified: [HttpStatus.CONFLICT, 'The account holder has not confirmed this request yet; nothing can be deleted before that.'],
  case_not_closable: [HttpStatus.CONFLICT, 'That case cannot be closed in its current state.'],
  staff_account: [HttpStatus.CONFLICT, 'Staff accounts are never deleted through a deletion case.'],
};

export function consoleRefusal(err: unknown): unknown {
  if ((err as { code?: unknown })?.code !== 'AR040') return err;
  const code = (err as Error).message;
  const known = CONSOLE_REFUSALS[code];
  return known ? new ApiError(known[0], code, known[1]) : new ApiError(HttpStatus.BAD_REQUEST, 'invalid_request', 'Invalid request.');
}
