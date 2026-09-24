import { importPKCS8, SignJWT, type KeyLike } from 'jose';
import type { AppleStatusItem } from './apple-types';

/**
 * App Store Server API (the store-side confirmation: "never granted from a client receipt alone", REQ-PAY-10).
 *   - `transaction(id)`:     GET /inApps/v1/transactions/{transactionId} → `signedTransactionInfo`;
 *   - `statuses(id)`:        GET /inApps/v1/subscriptions/{transactionId} → per group `lastTransactions[]`
 *                            (status + signed transaction + signed renewal info).
 * Production first, then the sandbox when production answers 404 (TestFlight and App Review buy in the sandbox).
 * Authenticated with an ES256 JWT signed by the In-App Purchase key (APPLE_IAP_ISSUER_ID / _KEY_ID / _PRIVATE_KEY,
 * bundle id `bid`). Every response is still App Store JWS, verified by the caller like a notification. Bodies, tokens
 * and ids are never logged.
 */
export interface AppStoreServerApi {
  readonly configured: boolean;
  /** Signed transaction info, or null when neither environment knows the id. Throws StoreUnavailableError. */
  transaction(transactionId: string): Promise<string | null>;
  /** The subscription's latest status items, or null when unknown. Throws StoreUnavailableError. */
  statuses(transactionId: string): Promise<AppleStatusItem[] | null>;
}

/** The store's server API can't be used right now (not configured, unreachable, 5xx, 429, auth refused). */
export class StoreUnavailableError extends Error {
  constructor(readonly reason: string) {
    super(`store API unavailable: ${reason}`);
    this.name = 'StoreUnavailableError';
  }
}

export interface AppStoreApiConfig {
  issuerId: string;
  keyId: string;
  /** The `.p8` key: PEM (real or `\n`-escaped newlines) or the bare base64 body. */
  privateKey: string;
  bundleId: string;
}

export const APPLE_PRODUCTION_URL = 'https://api.storekit.itunes.apple.com';
export const APPLE_SANDBOX_URL = 'https://api.storekit-sandbox.itunes.apple.com';
const TIMEOUT_MS = 10_000;

export function normalizeP8(key: string): string {
  const k = key.replace(/\\n/g, '\n').trim();
  if (k.includes('BEGIN PRIVATE KEY')) return k;
  return `-----BEGIN PRIVATE KEY-----\n${k.replace(/\s+/g, '')}\n-----END PRIVATE KEY-----`;
}

export class HttpAppStoreServerApi implements AppStoreServerApi {
  readonly configured: boolean;
  private key: KeyLike | null = null;

  constructor(
    private readonly config: AppStoreApiConfig | null,
    private readonly opts: { fetch?: typeof fetch; productionUrl?: string; sandboxUrl?: string; acceptSandbox?: boolean } = {},
  ) {
    this.configured = config !== null;
  }

  private async token(): Promise<string> {
    const c = this.config;
    if (!c) throw new StoreUnavailableError('not_configured');
    try {
      this.key ??= await importPKCS8(normalizeP8(c.privateKey), 'ES256');
    } catch {
      throw new StoreUnavailableError('bad_key');
    }
    const now = Math.floor(Date.now() / 1000);
    return new SignJWT({ bid: c.bundleId })
      .setProtectedHeader({ alg: 'ES256', kid: c.keyId, typ: 'JWT' })
      .setIssuer(c.issuerId)
      .setIssuedAt(now)
      .setExpirationTime(now + 20 * 60)
      .setAudience('appstoreconnect-v1')
      .sign(this.key);
  }

  private async get(path: string): Promise<unknown | null> {
    const bases = [this.opts.productionUrl ?? APPLE_PRODUCTION_URL];
    if (this.opts.acceptSandbox !== false) bases.push(this.opts.sandboxUrl ?? APPLE_SANDBOX_URL);
    const f = this.opts.fetch ?? fetch;
    for (const base of bases) {
      let res: Response;
      try {
        res = await f(`${base}${path}`, {
          headers: { Authorization: `Bearer ${await this.token()}` },
          signal: AbortSignal.timeout(TIMEOUT_MS),
        });
      } catch (err) {
        if (err instanceof StoreUnavailableError) throw err;
        throw new StoreUnavailableError('network');
      }
      if (res.status === 404) {
        await res.arrayBuffer().catch(() => undefined);
        continue; // not in this environment: try the sandbox
      }
      if (!res.ok) {
        await res.arrayBuffer().catch(() => undefined);
        throw new StoreUnavailableError(`http_${res.status}`);
      }
      return (await res.json()) as unknown;
    }
    return null;
  }

  async transaction(transactionId: string): Promise<string | null> {
    const body = (await this.get(`/inApps/v1/transactions/${encodeURIComponent(transactionId)}`)) as {
      signedTransactionInfo?: unknown;
    } | null;
    return typeof body?.signedTransactionInfo === 'string' ? body.signedTransactionInfo : null;
  }

  async statuses(transactionId: string): Promise<AppleStatusItem[] | null> {
    const body = (await this.get(`/inApps/v1/subscriptions/${encodeURIComponent(transactionId)}`)) as {
      data?: { lastTransactions?: AppleStatusItem[] }[];
    } | null;
    if (!body) return null;
    return (body.data ?? []).flatMap((g) => g.lastTransactions ?? []).filter((x) => typeof x?.signedTransactionInfo === 'string');
  }
}
