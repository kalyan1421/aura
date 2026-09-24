import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { deriveAccountToken, loadBillingConfig } from '../../src/billing/billing.config';
import { ALL_PRODUCT_IDS, GIFT_PRODUCTS, PLUS_PRODUCTS, productInfo, SKY_THEMES, SOUNDSCAPES } from '../../src/billing/catalogue';
import { standingFromRefunds } from '../../src/billing/gifts';

describe('F12 catalogue invariants (checked on every catalogue change)', () => {
  it('REQ-PAY-03: no product below ₹10; cosmetics ₹10–₹99; gifts ₹10 / ₹29 / ₹49', () => {
    for (const s of SKY_THEMES.filter((t) => t.tier === 'cosmetic')) expect([10, 29, 49, 99]).toContain(s.inr);
    expect(GIFT_PRODUCTS.map((g) => g.inr)).toEqual([10, 29, 49]);
  });
  it('gifts give the recipient 10 / 30 / 50 Stardust', () => {
    expect(GIFT_PRODUCTS.map((g) => [g.kind, g.stardust])).toEqual([
      ['warm_tea', 10],
      ['comfort_lantern', 30],
      ['encouragement_bouquet', 50],
    ]);
  });
  it('REQ-AVA-03 / REQ-STK-04 / REQ-SHR-05: nothing sold grants Starlight, a rest day or a keepsake', () => {
    const kinds = new Set(ALL_PRODUCT_IDS.map((id) => productInfo(id)?.kind));
    expect([...kinds].sort()).toEqual(['cosmetic', 'gift', 'plus']);
    for (const id of ALL_PRODUCT_IDS) expect(id).not.toMatch(/starlight|rest|streak|keepsake/);
  });
  it('Plus is monthly + annual; every product id is store-safe and unique', () => {
    expect(PLUS_PRODUCTS).toEqual(['aura_plus_monthly', 'aura_plus_annual']);
    expect(new Set(ALL_PRODUCT_IDS).size).toBe(ALL_PRODUCT_IDS.length);
    for (const id of ALL_PRODUCT_IDS) expect(id).toMatch(/^[a-z0-9_.]{1,64}$/);
  });
  it('sky soundscape pairings use base (free) stems only, so a pairing never needs Plus', () => {
    const manifest = readFileSync(join(__dirname, '../../../../apps/mobile/lib/src/features/sanctuary/sounds/stem_manifest_bundled.dart'), 'utf8');
    const tiers = new Map([...manifest.matchAll(/"id": "([a-z_]+)"[\s\S]*?"tier": "(free|plus)"/g)].map((m) => [m[1], m[2]]));
    expect(tiers.get('rain')).toBe('free');
    expect(tiers.get('pink_noise')).toBe('plus');
    for (const stems of Object.values(SOUNDSCAPES)) for (const s of stems) expect(tiers.get(s)).toBe('free');
    for (const t of SKY_THEMES) expect(Object.keys(SOUNDSCAPES)).toContain(t.soundscape);
  });
  it('one free sky, Plus skies have no store product, cosmetic skies have one and a Stardust price', () => {
    expect(SKY_THEMES.filter((t) => t.tier === 'free').map((t) => t.id)).toEqual(['night']);
    for (const t of SKY_THEMES.filter((x) => x.tier === 'plus')) expect(t.productId).toBeNull();
    for (const t of SKY_THEMES.filter((x) => x.tier === 'cosmetic')) {
      expect(t.productId).toBe(`sky_${t.id}`);
      expect(t.stardust).not.toBeNull();
    }
  });
});

describe('gift refund standing (PRD: 2 in 90 days pause 90 days, a 3rd disables)', () => {
  const NOW = new Date('2026-10-20T00:00:00Z');
  const d = (days: number): Date => new Date(NOW.getTime() - days * 86_400_000);
  it('one refund: fine', () => expect(standingFromRefunds([d(1)], NOW)).toEqual({ state: 'ok' }));
  it('two within 90 days: paused 90 days from the second', () => {
    const s = standingFromRefunds([d(40), d(10)], NOW);
    expect(s.state).toBe('paused');
    if (s.state === 'paused') expect(s.until.getTime()).toBe(d(10).getTime() + 90 * 86_400_000);
  });
  it('two more than 90 days apart: fine; pause over: fine', () => {
    expect(standingFromRefunds([d(200), d(5)], NOW)).toEqual({ state: 'ok' });
    expect(standingFromRefunds([d(130), d(100)], NOW)).toEqual({ state: 'ok' });
  });
  it('a third: disabled for good', () => expect(standingFromRefunds([d(400), d(300), d(1)], NOW)).toEqual({ state: 'disabled' }));
});

describe('billing config and the account token', () => {
  const key = Buffer.alloc(32, 7);
  it('the store token is a stable UUID derived from the user id, never the id itself', () => {
    const u = '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b';
    const t = deriveAccountToken(key, u);
    expect(t).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(deriveAccountToken(key, u.toUpperCase())).toBe(t);
    expect(t).not.toBe(u);
    expect(deriveAccountToken(Buffer.alloc(32, 8), u)).not.toBe(t);
    expect(deriveAccountToken(key, '0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5c')).not.toBe(t);
  });
  it('defaults: bundle / package com.akvega.aura, sandbox accepted, nothing configured', () => {
    const c = loadBillingConfig({});
    expect(c).toMatchObject({ appleBundleId: 'com.akvega.aura', googlePackageName: 'com.akvega.aura', acceptSandbox: true, appleApi: null, googleServiceAccount: null });
    expect(loadBillingConfig({ BILLING_ACCEPT_SANDBOX: 'false' }).acceptSandbox).toBe(false);
    expect(loadBillingConfig({ APPLE_IAP_ISSUER_ID: 'i', APPLE_IAP_KEY_ID: 'k', APPLE_IAP_PRIVATE_KEY: 'p', APPLE_IAP_APP_APPLE_ID: '123' })).toMatchObject({
      appleAppAppleId: 123,
      appleApi: { issuerId: 'i', keyId: 'k', bundleId: 'com.akvega.aura' },
    });
    expect(loadBillingConfig({ GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: 'not json' }).googleServiceAccountProblem).toMatch(/JSON/);
  });
});
