import { createHmac, hkdfSync } from 'node:crypto';
import type { AppStoreApiConfig } from './apple/app-store-api';
import { loadServiceAccount, type ServiceAccount } from './google/service-account';

/**
 * F12 billing configuration (server env; `.env.example` lists every variable, contracts/api/v1-billing.md §7 the
 * store-console setup). Nothing here is required to boot: without store credentials the API still verifies App Store
 * JWS and records purchases as `confirming`, and webhooks still work (Apple's are self-verifying); the store-side
 * confirmation waits until the credentials exist. Values are never logged.
 */
export interface BillingConfig {
  appleBundleId: string;
  /** App Store numeric app id: production notifications must carry it (`data.appAppleId`). Null = not checked. */
  appleAppAppleId: number | null;
  appleApi: AppStoreApiConfig | null;
  googlePackageName: string;
  googleServiceAccount: ServiceAccount | null;
  googleServiceAccountProblem: string | null;
  /** Pub/Sub push authentication (the push subscription's audience + service account). */
  rtdnAudience: string | null;
  rtdnServiceAccount: string | null;
  /** Accept sandbox purchases (TestFlight / App Review / Play licence testers). Default true. */
  acceptSandbox: boolean;
}

const val = (env: NodeJS.ProcessEnv, k: string): string | undefined => {
  const v = env[k];
  return v && v.trim() !== '' ? v.trim() : undefined;
};

export function loadBillingConfig(env: NodeJS.ProcessEnv = process.env): BillingConfig {
  const bundleId = val(env, 'APPLE_IAP_BUNDLE_ID') ?? 'com.akvega.aura';
  const issuerId = val(env, 'APPLE_IAP_ISSUER_ID');
  const keyId = val(env, 'APPLE_IAP_KEY_ID');
  const privateKey = val(env, 'APPLE_IAP_PRIVATE_KEY');
  const appId = val(env, 'APPLE_IAP_APP_APPLE_ID');
  const sa = loadServiceAccount(val(env, 'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'), val(env, 'GOOGLE_PLAY_SERVICE_ACCOUNT_FILE'));
  return {
    appleBundleId: bundleId,
    appleAppAppleId: appId && /^\d+$/.test(appId) ? Number(appId) : null,
    appleApi: issuerId && keyId && privateKey ? { issuerId, keyId, privateKey, bundleId } : null,
    googlePackageName: val(env, 'GOOGLE_PLAY_PACKAGE_NAME') ?? 'com.akvega.aura',
    googleServiceAccount: sa.account,
    googleServiceAccountProblem: sa.problem,
    rtdnAudience: val(env, 'GOOGLE_RTDN_AUDIENCE') ?? null,
    rtdnServiceAccount: val(env, 'GOOGLE_RTDN_SERVICE_ACCOUNT') ?? null,
    acceptSandbox: (val(env, 'BILLING_ACCEPT_SANDBOX') ?? 'true').toLowerCase() !== 'false',
  };
}

/** Nest injection token for BillingConfig. */
export const BILLING_CONFIG = Symbol('BILLING_CONFIG');

/**
 * The account's store token (`appAccountToken` on Apple — must be a UUID — and `obfuscatedAccountId` on Google):
 * HMAC-SHA256 under a key derived from AURA_MASTER_KEY (HKDF, info `aura/billing-account-token/v1`) over the user id,
 * shaped as an RFC 4122 v4-layout UUID. Deterministic, never the user id itself, and meaningless once the account's
 * `billing_accounts` row is purged. PRD 06c: "Purchases carry a user_id-derived token".
 */
export function deriveAccountToken(masterKey: Buffer, userId: string): string {
  const key = Buffer.from(hkdfSync('sha256', masterKey, Buffer.alloc(0), 'aura/billing-account-token/v1', 32));
  const h = createHmac('sha256', key).update(userId.toLowerCase()).digest().subarray(0, 16);
  h[6] = (h[6] & 0x0f) | 0x40;
  h[8] = (h[8] & 0x3f) | 0x80;
  const x = h.toString('hex');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20)}`;
}
