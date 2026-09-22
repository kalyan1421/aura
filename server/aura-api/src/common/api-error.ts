import { HttpStatus } from '@nestjs/common';

/** Every API error leaves as `{ code, message }` with a proper HTTP status (contracts/api/v1.md). */
export class ApiError extends Error {
  constructor(
    readonly status: HttpStatus,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  static badRequest(code: string, message: string): ApiError {
    return new ApiError(HttpStatus.BAD_REQUEST, code, message);
  }
  static unauthorized(message = 'A valid Supabase access token is required.', code = 'unauthorized'): ApiError {
    return new ApiError(HttpStatus.UNAUTHORIZED, code, message);
  }
  static forbidden(code: string, message: string): ApiError {
    return new ApiError(HttpStatus.FORBIDDEN, code, message);
  }
  static conflict(code: string, message: string): ApiError {
    return new ApiError(HttpStatus.CONFLICT, code, message);
  }
}

export const profileRequired = (): ApiError =>
  ApiError.conflict('profile_required', 'Complete onboarding (POST /v1/profile) first.');
