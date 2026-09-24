import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';

/**
 * Authenticated Pub/Sub push (Play RTDN): the push subscription is configured with "Enable authentication" and a
 * service account, so every request carries `Authorization: Bearer <Google-signed OIDC ID token>`. Accepted only when:
 *   - the token verifies against Google's keys (RS256, https://www.googleapis.com/oauth2/v3/certs);
 *   - `iss` is accounts.google.com, `aud` is GOOGLE_RTDN_AUDIENCE (the push endpoint URL set on the subscription);
 *   - `email` is GOOGLE_RTDN_SERVICE_ACCOUNT and `email_verified` is true.
 * Without an audience + service account configured, every push is refused (fail closed).
 */
export const GOOGLE_OIDC_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
export const GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];

export type PushAuthFailure = 'not_configured' | 'missing_token' | 'invalid_token' | 'wrong_sender';

export class PushAuthError extends Error {
  constructor(readonly reason: PushAuthFailure) {
    super(`Pub/Sub push refused: ${reason}`);
    this.name = 'PushAuthError';
  }
}

export interface PubSubPushAuthConfig {
  audience: string | null;
  serviceAccountEmail: string | null;
}

export class PubSubPushVerifier {
  private readonly keys: JWTVerifyGetKey;

  constructor(
    private readonly config: PubSubPushAuthConfig,
    keys?: JWTVerifyGetKey,
  ) {
    this.keys = keys ?? createRemoteJWKSet(new URL(GOOGLE_OIDC_JWKS_URL));
  }

  get configured(): boolean {
    return !!this.config.audience && !!this.config.serviceAccountEmail;
  }

  async verify(authorization: string | undefined): Promise<void> {
    if (!this.configured) throw new PushAuthError('not_configured');
    const m = /^Bearer\s+(\S+)$/i.exec(authorization ?? '');
    if (!m) throw new PushAuthError('missing_token');
    let payload: Record<string, unknown>;
    try {
      ({ payload } = await jwtVerify(m[1], this.keys, {
        issuer: GOOGLE_ISSUERS,
        audience: this.config.audience as string,
        algorithms: ['RS256'],
        clockTolerance: 60,
      }));
    } catch {
      throw new PushAuthError('invalid_token');
    }
    if (payload.email !== this.config.serviceAccountEmail || payload.email_verified !== true) {
      throw new PushAuthError('wrong_sender');
    }
  }
}
