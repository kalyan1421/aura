import { createRemoteJWKSet, decodeProtectedHeader, jwtVerify, type JWTPayload, type JWTVerifyGetKey } from 'jose';
import { isUuid } from '../common/uuid';

export interface AuthUser {
  /** `sub` — the Supabase auth user id; used as `user_id` everywhere. */
  id: string;
  role: string;
  isAnonymous: boolean;
}

export interface JwtVerifierOptions {
  /** HS256 shared secret (legacy Supabase JWT secret). */
  secret?: string;
  /** JWKS endpoint for asymmetric keys (ES256/RS256), e.g. `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`. */
  jwksUrl?: string;
  /** Pre-built key resolver (tests). Wins over `jwksUrl`. */
  jwks?: JWTVerifyGetKey;
  issuer?: string;
  audience?: string;
  clockToleranceSec?: number;
}

export class InvalidTokenError extends Error {}

/** Supabase asymmetric signing keys are ES256 (default) or RS256; the JWK picked by `kid` pins the alg. */
const ASYMMETRIC = ['ES256', 'RS256'];

/**
 * Verifies Supabase access tokens (aud `authenticated`, iss `${SUPABASE_URL}/auth/v1`, role `authenticated`).
 * Default path: ES256/RS256 against the project JWKS, key chosen by `kid` (jose caches + refetches on
 * unknown kid, so CLI/key rotations just work). HS256 is accepted only when a legacy JWT secret is
 * configured — an optional fallback for projects that still sign user sessions with the shared secret.
 */
export class JwtVerifier {
  private readonly secret?: Uint8Array;
  private readonly jwks?: JWTVerifyGetKey;

  constructor(private readonly opts: JwtVerifierOptions) {
    if (opts.secret) this.secret = new TextEncoder().encode(opts.secret);
    this.jwks =
      opts.jwks ??
      (opts.jwksUrl
        ? createRemoteJWKSet(new URL(opts.jwksUrl), { cooldownDuration: 30_000, cacheMaxAge: 10 * 60_000 })
        : undefined);
    if (!this.secret && !this.jwks) throw new Error('JwtVerifier needs a secret or a JWKS source');
  }

  async verify(token: string): Promise<AuthUser> {
    let alg: string | undefined;
    try {
      alg = decodeProtectedHeader(token).alg;
    } catch {
      throw new InvalidTokenError('malformed token');
    }
    const common = {
      audience: this.opts.audience ?? 'authenticated',
      issuer: this.opts.issuer,
      clockTolerance: this.opts.clockToleranceSec ?? 30,
      requiredClaims: ['sub', 'exp'],
    };
    let payload: JWTPayload;
    try {
      if (alg === 'HS256') {
        if (!this.secret) throw new InvalidTokenError('HS256 tokens are not accepted');
        ({ payload } = await jwtVerify(token, this.secret, { ...common, algorithms: ['HS256'] }));
      } else if (alg && ASYMMETRIC.includes(alg)) {
        if (!this.jwks) throw new InvalidTokenError(`${alg} tokens are not accepted`);
        ({ payload } = await jwtVerify(token, this.jwks, { ...common, algorithms: ASYMMETRIC }));
      } else {
        throw new InvalidTokenError(`unsupported alg ${alg ?? '(none)'}`);
      }
    } catch (err) {
      if (err instanceof InvalidTokenError) throw err;
      throw new InvalidTokenError((err as Error).message ?? 'invalid token');
    }
    const role = typeof payload.role === 'string' ? payload.role : '';
    if (role !== 'authenticated') throw new InvalidTokenError('token is not a user session');
    if (!isUuid(payload.sub)) throw new InvalidTokenError('token has no user id');
    return { id: payload.sub.toLowerCase(), role, isAnonymous: payload.is_anonymous === true };
  }
}
