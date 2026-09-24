import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { CompactSign, importPKCS8 } from 'jose';
import { AppleJwsVerifier } from '../../../src/billing/apple/jws';

/**
 * TEST-ONLY App Store JWS signing with the committed test CA (make-test-ca.sh). The server never trusts this CA; tests
 * build an AppleJwsVerifier with `testRoots()` instead of Apple's.
 */
const DIR = join(__dirname, 'test-ca');
const der = (name: string): Buffer => readFileSync(join(DIR, `${name}.der`));
const pem = (name: string): string => readFileSync(join(DIR, `${name}.key`), 'utf8');

export const testRoots = (): Buffer[] => [der('root')];
export const testVerifier = (now?: () => Date): AppleJwsVerifier => new AppleJwsVerifier({ roots: testRoots(), now });

export type Chain = 'good' | 'dev' | 'rogue';

const CHAINS: Record<Chain, { leaf: string; x5c: string[] }> = {
  good: { leaf: 'leaf', x5c: ['leaf', 'intermediate', 'root'] },
  dev: { leaf: 'dev-leaf', x5c: ['dev-leaf', 'intermediate', 'root'] },
  rogue: { leaf: 'rogue-leaf', x5c: ['rogue-leaf', 'rogue-intermediate', 'rogue-root'] },
};

export async function signApple(payload: object, chain: Chain = 'good', opts: { alg?: string; x5c?: string[] } = {}): Promise<string> {
  const c = CHAINS[chain];
  const key = await importPKCS8(pem(c.leaf), 'ES256');
  return new CompactSign(new TextEncoder().encode(JSON.stringify(payload)))
    .setProtectedHeader({ alg: (opts.alg ?? 'ES256') as 'ES256', x5c: opts.x5c ?? c.x5c.map((n) => der(n).toString('base64')) })
    .sign(key);
}

export const BUNDLE = 'com.akvega.aura';

let seq = 0;
/** A unique numeric-looking Apple transaction id. */
export const txId = (): string => `${Date.now()}${String(++seq).padStart(4, '0')}${Math.floor(Math.random() * 1000)}`;

export function appleTx(over: Record<string, unknown> = {}): Record<string, unknown> {
  const id = txId();
  const now = Date.now();
  return {
    transactionId: id,
    originalTransactionId: id,
    bundleId: BUNDLE,
    productId: 'aura_plus_monthly',
    purchaseDate: now,
    originalPurchaseDate: now,
    expiresDate: now + 30 * 86_400_000,
    type: 'Auto-Renewable Subscription',
    inAppOwnershipType: 'PURCHASED',
    signedDate: now,
    environment: 'Sandbox',
    offerType: 1,
    offerDiscountType: 'FREE_TRIAL',
    price: 0,
    currency: 'INR',
    ...over,
  };
}

export function appleRenewal(originalTransactionId: string, over: Record<string, unknown> = {}): Record<string, unknown> {
  return { originalTransactionId, productId: 'aura_plus_monthly', autoRenewStatus: 1, signedDate: Date.now(), environment: 'Sandbox', ...over };
}
