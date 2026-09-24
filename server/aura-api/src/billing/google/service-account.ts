import { readFileSync } from 'node:fs';
import { importPKCS8, SignJWT, type KeyLike } from 'jose';
import { StoreUnavailableError } from '../apple/app-store-api';

/**
 * A Google service account (OAuth 2.0 JWT bearer, signed with `jose`; no googleapis dependency) for the Play Developer
 * API (`androidpublisher` scope). Configured from GOOGLE_PLAY_SERVICE_ACCOUNT_JSON (JSON or base64 of it) or
 * GOOGLE_PLAY_SERVICE_ACCOUNT_FILE. The key and tokens are never logged.
 */
export const ANDROID_PUBLISHER_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
export const GOOGLE_TOKEN_URI = 'https://oauth2.googleapis.com/token';

export interface ServiceAccount {
  clientEmail: string;
  privateKey: string;
  tokenUri: string;
}

const nonEmpty = (v: string | undefined): string | undefined => (v && v.trim() !== '' ? v.trim() : undefined);

/** Never throws: an unusable account is `{ account: null, problem }` (problem never contains values). */
export function loadServiceAccount(
  inline: string | undefined,
  path: string | undefined,
  readFile: (p: string) => string = (p) => readFileSync(p, 'utf8'),
): { account: ServiceAccount | null; problem: string | null } {
  const i = nonEmpty(inline);
  const p = nonEmpty(path);
  if (!i && !p) return { account: null, problem: null };
  let raw: string;
  if (i) raw = i.startsWith('{') ? i : Buffer.from(i, 'base64').toString('utf8');
  else {
    try {
      raw = readFile(p as string);
    } catch {
      return { account: null, problem: 'the service-account file cannot be read' };
    }
  }
  let json: Record<string, unknown>;
  try {
    json = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { account: null, problem: 'the service account is not valid JSON' };
  }
  const str = (k: string): string | undefined => (typeof json[k] === 'string' && json[k] !== '' ? (json[k] as string) : undefined);
  const clientEmail = str('client_email');
  const privateKey = str('private_key')?.replace(/\\n/g, '\n');
  if (!clientEmail || !privateKey || !privateKey.includes('BEGIN PRIVATE KEY')) {
    return { account: null, problem: 'client_email and a PKCS#8 private_key are required' };
  }
  return { account: { clientEmail, privateKey, tokenUri: str('token_uri') ?? GOOGLE_TOKEN_URI }, problem: null };
}

/** Access tokens for one scope, cached until 5 minutes before expiry. */
export class GoogleAccessTokens {
  private cached: { token: string; expiresAt: number } | null = null;
  private key: KeyLike | null = null;

  constructor(
    private readonly account: ServiceAccount,
    private readonly scope: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async get(): Promise<string> {
    if (this.cached && this.cached.expiresAt > Date.now() + 5 * 60_000) return this.cached.token;
    try {
      this.key ??= await importPKCS8(this.account.privateKey, 'RS256');
    } catch {
      throw new StoreUnavailableError('bad_key');
    }
    const now = Math.floor(Date.now() / 1000);
    const assertion = await new SignJWT({ scope: this.scope })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuer(this.account.clientEmail)
      .setAudience(this.account.tokenUri)
      .setIssuedAt(now)
      .setExpirationTime(now + 3600)
      .sign(this.key);
    let res: Response;
    try {
      res = await this.fetchFn(this.account.tokenUri, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }).toString(),
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      throw new StoreUnavailableError('network');
    }
    if (!res.ok) {
      await res.arrayBuffer().catch(() => undefined);
      throw new StoreUnavailableError(`oauth_${res.status}`);
    }
    const body = (await res.json()) as { access_token?: string; expires_in?: number };
    if (!body.access_token) throw new StoreUnavailableError('oauth_no_token');
    this.cached = { token: body.access_token, expiresAt: Date.now() + (body.expires_in ?? 3600) * 1000 };
    return body.access_token;
  }
}
