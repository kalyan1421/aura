import { StoreUnavailableError } from '../apple/app-store-api';
import type { GoogleProductPurchase, GoogleSubscriptionV2, GoogleVoidedPurchase } from './play-types';
import { ANDROID_PUBLISHER_SCOPE, GoogleAccessTokens, type ServiceAccount } from './service-account';

/**
 * Google Play Developer API v3 (androidpublisher) — the store-side confirmation for Android purchases and RTDN
 * (an RTDN message is only a hint: Aura always re-reads the purchase here). Behind an interface so tests use a fake.
 * `null` = Google doesn't know the token (404/410). Throws StoreUnavailableError when Google can't be used right now.
 */
export interface PlayDeveloperApi {
  readonly configured: boolean;
  subscription(purchaseToken: string): Promise<GoogleSubscriptionV2 | null>;
  acknowledgeSubscription(productId: string, purchaseToken: string): Promise<void>;
  product(productId: string, purchaseToken: string): Promise<GoogleProductPurchase | null>;
  acknowledgeProduct(productId: string, purchaseToken: string): Promise<void>;
  consumeProduct(productId: string, purchaseToken: string): Promise<void>;
  /** Voided purchases (refunds, chargebacks, revocations) since `startTimeMs`, one-time and subscriptions. */
  voided(startTimeMs: number): Promise<GoogleVoidedPurchase[]>;
}

export const PLAY_API_URL = 'https://androidpublisher.googleapis.com/androidpublisher/v3';

export class HttpPlayDeveloperApi implements PlayDeveloperApi {
  readonly configured: boolean;
  private readonly tokens: GoogleAccessTokens | null;

  constructor(
    account: ServiceAccount | null,
    private readonly packageName: string,
    private readonly opts: { fetch?: typeof fetch; baseUrl?: string } = {},
  ) {
    this.configured = account !== null;
    this.tokens = account ? new GoogleAccessTokens(account, ANDROID_PUBLISHER_SCOPE, opts.fetch ?? fetch) : null;
  }

  private url(path: string): string {
    return `${this.opts.baseUrl ?? PLAY_API_URL}/applications/${encodeURIComponent(this.packageName)}${path}`;
  }

  private async call(method: 'GET' | 'POST', path: string): Promise<unknown | null> {
    if (!this.tokens) throw new StoreUnavailableError('not_configured');
    const token = await this.tokens.get();
    let res: Response;
    try {
      res = await (this.opts.fetch ?? fetch)(this.url(path), {
        method,
        headers: { Authorization: `Bearer ${token}`, ...(method === 'POST' ? { 'Content-Type': 'application/json' } : {}) },
        body: method === 'POST' ? '{}' : undefined,
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      throw new StoreUnavailableError('network');
    }
    if (res.status === 404 || res.status === 410) {
      await res.arrayBuffer().catch(() => undefined);
      return null;
    }
    if (!res.ok) {
      await res.arrayBuffer().catch(() => undefined);
      throw new StoreUnavailableError(`http_${res.status}`);
    }
    const text = await res.text();
    return text ? (JSON.parse(text) as unknown) : {};
  }

  private static t(token: string): string {
    return encodeURIComponent(token);
  }

  async subscription(purchaseToken: string): Promise<GoogleSubscriptionV2 | null> {
    return (await this.call('GET', `/purchases/subscriptionsv2/tokens/${HttpPlayDeveloperApi.t(purchaseToken)}`)) as GoogleSubscriptionV2 | null;
  }

  async acknowledgeSubscription(productId: string, purchaseToken: string): Promise<void> {
    await this.call(
      'POST',
      `/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${HttpPlayDeveloperApi.t(purchaseToken)}:acknowledge`,
    );
  }

  async product(productId: string, purchaseToken: string): Promise<GoogleProductPurchase | null> {
    return (await this.call(
      'GET',
      `/purchases/products/${encodeURIComponent(productId)}/tokens/${HttpPlayDeveloperApi.t(purchaseToken)}`,
    )) as GoogleProductPurchase | null;
  }

  async acknowledgeProduct(productId: string, purchaseToken: string): Promise<void> {
    await this.call('POST', `/purchases/products/${encodeURIComponent(productId)}/tokens/${HttpPlayDeveloperApi.t(purchaseToken)}:acknowledge`);
  }

  async consumeProduct(productId: string, purchaseToken: string): Promise<void> {
    await this.call('POST', `/purchases/products/${encodeURIComponent(productId)}/tokens/${HttpPlayDeveloperApi.t(purchaseToken)}:consume`);
  }

  async voided(startTimeMs: number): Promise<GoogleVoidedPurchase[]> {
    const out: GoogleVoidedPurchase[] = [];
    let page: string | undefined;
    for (let i = 0; i < 20; i++) {
      const q = new URLSearchParams({ startTime: String(startTimeMs), type: '1', maxResults: '1000' });
      if (page) q.set('token', page);
      const body = (await this.call('GET', `/purchases/voidedpurchases?${q.toString()}`)) as {
        voidedPurchases?: GoogleVoidedPurchase[];
        tokenPagination?: { nextPageToken?: string };
      } | null;
      out.push(...(body?.voidedPurchases ?? []));
      page = body?.tokenPagination?.nextPageToken;
      if (!page) break;
    }
    return out;
  }
}
