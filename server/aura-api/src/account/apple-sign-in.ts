import { decodeJwt, importPKCS8, SignJWT, type KeyLike } from 'jose';

/**
 * Sign in with Apple REST API client (App Review 5.1.1(v): an app that offers Sign in with Apple revokes the user's
 * Apple tokens when the account is deleted — PRD F8 REQ-ACC-11 "Apple token revoked").
 *
 *  - `exchangeCode`: the one-time `authorizationCode` from the app's native sheet → a refresh token
 *    (`POST https://appleid.apple.com/auth/token`, grant_type=authorization_code).
 *  - `revokeRefreshToken`: `POST https://appleid.apple.com/auth/revoke` (token_type_hint=refresh_token). Revoking any
 *    token of the user ends the user's authorization of the app.
 *
 * Both authenticate with a client secret: an ES256 JWT signed with the team's Sign in with Apple key
 * (iss = team id, sub = client id, aud = https://appleid.apple.com, kid = key id), minted per call and valid 1 h.
 * Configured from env (docs/setup/social-sign-in.md): APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_CLIENT_ID.
 * Tokens, codes and Apple's response bodies are never logged or put in error messages.
 */
export const APPLE_ID_URL = 'https://appleid.apple.com';
const APPLE_AUDIENCE = 'https://appleid.apple.com';
const CLIENT_SECRET_TTL_S = 3600;
const TIMEOUT_MS = 10_000;

export interface AppleSignInConfig {
  /** 10-character Apple Developer team id (e.g. `AQLMTLP6PD`). */
  teamId: string;
  /** 10-character id of the Sign in with Apple key. */
  keyId: string;
  /** The key's `.p8` contents: PEM (real or `\n`-escaped newlines) or the bare base64 body. */
  privateKey: string;
  /** The client the app's codes are issued to: the bundle id for native iOS (`com.akvega.aura`). */
  clientId: string;
}

export interface AppleSignInOptions {
  config?: AppleSignInConfig;
  /** Apple's base URL; tests point it at a fake. */
  baseUrl?: string;
  fetch?: typeof fetch;
  timeoutMs?: number;
  now?: () => Date;
}

export interface AppleGrant {
  refreshToken: string;
  /** `sub` of the returned id_token: the Apple user id (`auth.identities.provider_id` for provider `apple`). */
  subject: string | null;
  /** The client the token was issued to (needed again to revoke it). */
  clientId: string;
}

/** Apple can't be used right now: not configured, unreachable, 5xx, or our client credentials were refused. */
export class AppleUnavailableError extends Error {
  constructor(readonly reason: string) {
    super(`Sign in with Apple unavailable: ${reason}`);
    this.name = 'AppleUnavailableError';
  }
}

/** Apple refused the request itself (e.g. `invalid_grant`: the code expired, was used, or belongs to another client). */
export class AppleRejectedError extends Error {
  constructor(readonly reason: string) {
    super(`Sign in with Apple rejected the request: ${reason}`);
    this.name = 'AppleRejectedError';
  }
}

const ID_RE = /^[A-Z0-9]{10}$/;
const CLIENT_ID_RE = /^[A-Za-z0-9][A-Za-z0-9.-]{0,254}$/;

/** `.p8` contents → PKCS#8 PEM. Accepts real newlines, `\n` escapes (single-line env values) or the bare body. */
export function normalizeP8(raw: string): string {
  const s = raw.trim().replace(/\\n/g, '\n');
  if (s.includes('-----BEGIN')) return s;
  const body = s.replace(/\s+/g, '');
  return `-----BEGIN PRIVATE KEY-----\n${(body.match(/.{1,64}/g) ?? []).join('\n')}\n-----END PRIVATE KEY-----\n`;
}

/** Reads APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY / APPLE_CLIENT_ID; any missing → not configured. */
export function appleConfigFromEnv(env: NodeJS.ProcessEnv = process.env): AppleSignInConfig | undefined {
  const teamId = env.APPLE_TEAM_ID?.trim();
  const keyId = env.APPLE_KEY_ID?.trim();
  const privateKey = env.APPLE_PRIVATE_KEY?.trim();
  const clientId = env.APPLE_CLIENT_ID?.trim();
  if (!teamId || !keyId || !privateKey || !clientId) return undefined;
  return { teamId, keyId, privateKey, clientId };
}

/** Problems with a present configuration (names only, never values). Empty = usable. */
export function appleConfigProblems(c: AppleSignInConfig): string[] {
  const out: string[] = [];
  if (!ID_RE.test(c.teamId)) out.push('APPLE_TEAM_ID must be the 10-character team id');
  if (!ID_RE.test(c.keyId)) out.push('APPLE_KEY_ID must be the 10-character key id');
  if (!CLIENT_ID_RE.test(c.clientId)) out.push('APPLE_CLIENT_ID must be a bundle id or Services id');
  return out;
}

export class AppleSignInClient {
  private readonly base: string;
  private key?: Promise<KeyLike>;

  constructor(private readonly opts: AppleSignInOptions = {}) {
    this.base = (opts.baseUrl ?? APPLE_ID_URL).replace(/\/+$/, '');
  }

  /** From env (call after AppConfig merged `.env` into process.env). A malformed configuration counts as missing. */
  static fromEnv(env: NodeJS.ProcessEnv = process.env): AppleSignInClient {
    const config = appleConfigFromEnv(env);
    return new AppleSignInClient({ config: config && appleConfigProblems(config).length === 0 ? config : undefined });
  }

  get configured(): boolean {
    return !!this.opts.config;
  }

  /** The configured client id (native iOS: the bundle id), or undefined. */
  get clientId(): string | undefined {
    return this.opts.config?.clientId;
  }

  /** ES256 client secret for `clientId` (default: the configured one). Same team key for every client of the team. */
  async clientSecret(clientId = this.config().clientId): Promise<string> {
    const c = this.config();
    const iat = Math.floor((this.opts.now?.() ?? new Date()).getTime() / 1000);
    return new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: c.keyId })
      .setIssuer(c.teamId)
      .setSubject(clientId)
      .setAudience(APPLE_AUDIENCE)
      .setIssuedAt(iat)
      .setExpirationTime(iat + CLIENT_SECRET_TTL_S)
      .sign(await this.signingKey());
  }

  /** One-time authorization code → refresh token (+ the Apple user id from the id_token). */
  async exchangeCode(code: string): Promise<AppleGrant> {
    const clientId = this.config().clientId;
    const body = await this.post('/auth/token', {
      client_id: clientId,
      client_secret: await this.clientSecret(clientId),
      code,
      grant_type: 'authorization_code',
    });
    let parsed: { refresh_token?: unknown; id_token?: unknown };
    try {
      parsed = JSON.parse(body) as typeof parsed;
    } catch {
      throw new AppleUnavailableError('unreadable token response');
    }
    if (typeof parsed.refresh_token !== 'string' || parsed.refresh_token.length === 0) {
      throw new AppleUnavailableError('no refresh token in the response');
    }
    return { refreshToken: parsed.refresh_token, subject: subjectOf(parsed.id_token, clientId), clientId };
  }

  /**
   * Revokes a refresh token issued to `clientId`. Apple answers 200 for a token that is already invalid (RFC 7009);
   * `invalid_grant` is treated the same way (nothing left to revoke).
   */
  async revokeRefreshToken(token: string, clientId = this.config().clientId, opts: { timeoutMs?: number } = {}): Promise<void> {
    try {
      await this.post(
        '/auth/revoke',
        { client_id: clientId, client_secret: await this.clientSecret(clientId), token, token_type_hint: 'refresh_token' },
        opts.timeoutMs,
      );
    } catch (err) {
      if (err instanceof AppleRejectedError && err.reason === 'invalid_grant') return;
      throw err;
    }
  }

  private config(): AppleSignInConfig {
    const c = this.opts.config;
    if (!c) throw new AppleUnavailableError('not configured');
    return c;
  }

  private signingKey(): Promise<KeyLike> {
    if (!this.key) {
      const pending = importPKCS8(normalizeP8(this.config().privateKey), 'ES256');
      this.key = pending;
      // A key that can't be imported stays unusable, but a later call may retry (e.g. after a transient failure).
      pending.catch(() => {
        if (this.key === pending) this.key = undefined;
      });
    }
    return this.key.catch(() => {
      throw new AppleUnavailableError('APPLE_PRIVATE_KEY is not a valid ES256 .p8 key');
    });
  }

  /** Form POST to Apple. Returns the body on 2xx; maps everything else (never echoing bodies or tokens). */
  private async post(path: string, form: Record<string, string>, timeoutMs?: number): Promise<string> {
    let res: Response;
    try {
      res = await (this.opts.fetch ?? fetch)(`${this.base}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
        body: new URLSearchParams(form).toString(),
        signal: AbortSignal.timeout(timeoutMs ?? this.opts.timeoutMs ?? TIMEOUT_MS),
      });
    } catch (err) {
      // DOMException (the abort reason) is not always an Error instance across realms: read the name directly.
      const name = (err as { name?: unknown } | null)?.name;
      throw new AppleUnavailableError(name === 'TimeoutError' || name === 'AbortError' ? 'timeout' : 'unreachable');
    }
    const text = await res.text().catch(() => '');
    if (res.ok) return text;
    if (res.status === 400 || res.status === 401) {
      let error = '';
      try {
        const e = (JSON.parse(text) as { error?: unknown }).error;
        error = typeof e === 'string' && /^[a-z_]{1,40}$/.test(e) ? e : '';
      } catch {
        error = '';
      }
      // Our own credentials (key, team, client id) were refused: a configuration problem, not the user's code.
      if (error === 'invalid_client' || error === 'unauthorized_client' || res.status === 401) {
        throw new AppleUnavailableError(error || `HTTP ${res.status}`);
      }
      throw new AppleRejectedError(error || `HTTP ${res.status}`);
    }
    throw new AppleUnavailableError(`HTTP ${res.status}`);
  }
}

/** `sub` of Apple's id_token when it was issued to `clientId` (the token comes straight from Apple over TLS). */
function subjectOf(idToken: unknown, clientId: string): string | null {
  if (typeof idToken !== 'string') return null;
  try {
    const claims = decodeJwt(idToken);
    const aud = claims.aud;
    const forUs = aud === clientId || (Array.isArray(aud) && aud.includes(clientId));
    return forUs && typeof claims.sub === 'string' && claims.sub.length > 0 ? claims.sub : null;
  } catch {
    return null;
  }
}
