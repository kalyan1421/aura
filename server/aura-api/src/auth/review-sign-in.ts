import { createHash, timingSafeEqual } from 'node:crypto';
import { Body, Controller, Header, HttpCode, HttpStatus, Inject, Injectable, Logger, Module, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import { z } from 'zod';
import { RateLimiter } from '../admin/rate-limit';
import { ApiError } from '../common/api-error';
import { errorText } from '../common/log-scrub';
import { AppConfig } from '../config/app-config';
import { DbService } from '../db/db.service';
import { appendAudit, subjectHash } from '../safety/audit';
import { Public } from './public.decorator';

/**
 * App Review sign-in (docs/setup/app-review.md). Aura is passwordless: accounts sign in with a 6-digit email code
 * (or Apple / Google), and App Review / Play review can't receive that email. This route lets the ONE review account
 * sign in with a fixed code the Owner puts in the review notes:
 *
 *   POST /v1/auth/review-sign-in  { email, code }  (public, ≤ 5 attempts per client address per hour)
 *
 * - Off (404) unless both `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` (exactly 6 digits: the app's code field
 *   takes 6 digits, like Supabase's own codes) are set.
 * - The email must match (case-insensitive) AND the code must match — both compared in constant time. Anything else is
 *   the same generic `401 invalid_code`, never a hint whether the email is the review one.
 * - On a match NestJS mints a normal Supabase session for that account with the GoTrue admin API
 *   (`generate_link` type `magiclink` → its `email_otp` → `verify` type `email`); no email is sent. The account is an
 *   ordinary app account (it onboards like anyone). Needs `SUPABASE_SERVICE_ROLE_KEY`.
 * - Every successful use is audit-logged (hash-chained `moderation_actions`, action `review_sign_in`, the account as a
 *   subject hash only). The code, the email and the tokens are never logged.
 *
 * The app calls this only after Supabase refused a typed code (features/auth), so a person's mistyped code costs one
 * extra request that answers 401 — the app then shows its normal "That code didn't work" message.
 */

export interface ReviewSession {
  userId: string;
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

/** The GoTrue admin boundary (faked in unit tests). */
export interface ReviewSessionMinter {
  /** Null when this server can't mint sessions (no service role key). Throws on a GoTrue failure. */
  mint(email: string): Promise<ReviewSession | null>;
}

export const REVIEW_SESSION_MINTER = Symbol('REVIEW_SESSION_MINTER');

/** Reads the service role key lazily (after AppConfig merged `.env`). */
export class GoTrueReviewSessionMinter implements ReviewSessionMinter {
  constructor(
    private readonly supabaseUrl: string,
    private readonly env: NodeJS.ProcessEnv = process.env,
    private readonly doFetch: typeof fetch = fetch,
  ) {}

  async mint(email: string): Promise<ReviewSession | null> {
    const key = this.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
    if (!key) return null;
    const headers = { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };
    const link = await this.doFetch(`${this.supabaseUrl}/auth/v1/admin/generate_link`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ type: 'magiclink', email }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!link.ok) throw new Error(`generate_link ${link.status}`);
    const l = (await link.json()) as { id?: unknown; email_otp?: unknown };
    if (typeof l.email_otp !== 'string' || typeof l.id !== 'string') throw new Error('generate_link: unexpected shape');
    const verified = await this.doFetch(`${this.supabaseUrl}/auth/v1/verify`, {
      method: 'POST',
      headers: { apikey: key, 'Content-Type': 'application/json' },
      body: JSON.stringify({ type: 'email', email, token: l.email_otp }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!verified.ok) throw new Error(`verify ${verified.status}`);
    const s = (await verified.json()) as { access_token?: unknown; refresh_token?: unknown; expires_in?: unknown };
    if (typeof s.access_token !== 'string' || typeof s.refresh_token !== 'string') throw new Error('verify: unexpected shape');
    return {
      userId: l.id,
      accessToken: s.access_token,
      refreshToken: s.refresh_token,
      expiresIn: typeof s.expires_in === 'number' ? s.expires_in : 3600,
    };
  }
}

/** The review account from the environment, or null (route off). */
export function reviewAccountFromEnv(env: NodeJS.ProcessEnv = process.env): { email: string; code: string } | null {
  const email = env.REVIEW_ACCOUNT_EMAIL?.trim().toLowerCase();
  const code = env.REVIEW_ACCOUNT_CODE?.trim();
  if (!email || !code || !/^\d{6}$/.test(code) || !email.includes('@')) return null;
  return { email, code };
}

/** Constant-time equality of two strings of any length (compares SHA-256 digests). */
export function sameSecret(a: string, b: string): boolean {
  const x = createHash('sha256').update(a, 'utf8').digest();
  const y = createHash('sha256').update(b, 'utf8').digest();
  return timingSafeEqual(x, y);
}

const bodySchema = z.object({
  email: z.string().max(320),
  code: z.string().max(128),
});

/** Attempts per client address per hour. */
export const REVIEW_SIGN_IN_LIMIT = 5;

const invalid = (): ApiError => ApiError.unauthorized("That code didn't work.", 'invalid_code');

@Injectable()
export class ReviewSignInService {
  private readonly logger = new Logger('ReviewSignIn');

  constructor(
    @Inject(REVIEW_SESSION_MINTER) private readonly minter: ReviewSessionMinter,
    private readonly limiter: RateLimiter,
    private readonly db: DbService,
    private readonly config: AppConfig,
  ) {}

  async signIn(
    body: unknown,
    clientAddress: string,
    env: NodeJS.ProcessEnv = process.env,
  ): Promise<{ access_token: string; refresh_token: string; expires_in: number; token_type: 'bearer' }> {
    const account = reviewAccountFromEnv(env);
    if (!account) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'Not found.');
    if (!(await this.limiter.hit(`review-sign-in:${this.limiter.bucket(clientAddress)}`, REVIEW_SIGN_IN_LIMIT, 3600))) {
      throw new ApiError(HttpStatus.TOO_MANY_REQUESTS, 'rate_limited', 'Too many attempts. Please try again in an hour.');
    }
    const parsed = bodySchema.safeParse(body);
    if (!parsed.success) throw invalid();
    // Both comparisons always run (no early exit that would time the email apart from the code).
    const emailOk = sameSecret(parsed.data.email.trim().toLowerCase(), account.email);
    const codeOk = sameSecret(parsed.data.code.trim(), account.code);
    if (!(emailOk && codeOk)) throw invalid();

    let session: ReviewSession | null;
    try {
      session = await this.minter.mint(account.email);
    } catch (e) {
      this.logger.error(`review sign-in: session mint failed (${errorText(e)})`);
      throw new ApiError(HttpStatus.SERVICE_UNAVAILABLE, 'review_sign_in_unavailable', 'Sign-in is unavailable right now.');
    }
    if (!session) {
      this.logger.error('review sign-in: SUPABASE_SERVICE_ROLE_KEY is not set');
      throw new ApiError(HttpStatus.SERVICE_UNAVAILABLE, 'review_sign_in_unavailable', 'Sign-in is unavailable right now.');
    }
    await appendAudit(this.db, {
      actor: 'system',
      action: 'review_sign_in',
      subjectHash: subjectHash(this.config.masterKey, session.userId),
    });
    this.logger.log('review sign-in: session issued for the review account');
    return { access_token: session.accessToken, refresh_token: session.refreshToken, expires_in: session.expiresIn, token_type: 'bearer' };
  }
}

@Controller('v1/auth')
export class ReviewSignInController {
  constructor(private readonly service: ReviewSignInService) {}

  @Public()
  @Post('review-sign-in')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  signIn(@Body() body: unknown, @Req() req: Request): ReturnType<ReviewSignInService['signIn']> {
    return this.service.signIn(body, req.ip ?? req.socket?.remoteAddress ?? 'unknown');
  }
}

@Module({
  controllers: [ReviewSignInController],
  providers: [
    RateLimiter,
    ReviewSignInService,
    {
      provide: REVIEW_SESSION_MINTER,
      useFactory: (c: AppConfig): ReviewSessionMinter => new GoTrueReviewSessionMinter(c.supabaseUrl),
      inject: [AppConfig],
    },
  ],
})
export class ReviewSignInModule {}
