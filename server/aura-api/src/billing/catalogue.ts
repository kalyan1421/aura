/**
 * F12 catalogue (PRD 06c "Catalogue"; contracts/api/v1-billing.md §1). Product ids are the same in App Store Connect
 * and Play Console. Prices live in the stores (India tiers GST-inclusive: ₹49 / ₹399, cosmetics ₹10–₹99, gifts
 * ₹10 / ₹29 / ₹49); the app always shows the store's localized price string, never these numbers. The INR tiers here
 * are documentation and a guard (REQ-PAY-03: nothing below ₹10).
 *
 * Invariants checked by test/unit/billing.catalogue.spec.ts on every catalogue change:
 *  - REQ-AVA-03 / REQ-STK-04 / REQ-SHR-05: no product, Plus perk, gift or Stardust path grants Starlight, a rest day
 *    or a keepsake — the catalogue simply has no such item kind;
 *  - cosmetics are personal sky themes only (never shown to strangers);
 *  - gift Stardust is 10 / 30 / 50.
 */

export const PLUS_PRODUCTS = ['aura_plus_monthly', 'aura_plus_annual'] as const;
export type PlusProductId = (typeof PLUS_PRODUCTS)[number];

/** Base plan / period per Plus product (Google: one base plan each, with the `first-month-free` offer). */
export const PLUS_PERIOD: Readonly<Record<PlusProductId, 'month' | 'year'>> = {
  aura_plus_monthly: 'month',
  aura_plus_annual: 'year',
};

/** Google Play offer id of the introductory free month (tag `free-month` too). Apple: an introductory offer. */
export const GOOGLE_TRIAL_OFFER_ID = 'first-month-free';

export type GiftKind = 'warm_tea' | 'comfort_lantern' | 'encouragement_bouquet';

export interface GiftProduct {
  productId: string;
  kind: GiftKind;
  inr: 10 | 29 | 49;
  /** Stardust the recipient gets (PRD: 10 / 30 / 50). */
  stardust: 10 | 30 | 50;
}

export const GIFT_PRODUCTS: readonly GiftProduct[] = [
  { productId: 'gift_warm_tea', kind: 'warm_tea', inr: 10, stardust: 10 },
  { productId: 'gift_comfort_lantern', kind: 'comfort_lantern', inr: 29, stardust: 30 },
  { productId: 'gift_encouragement_bouquet', kind: 'encouragement_bouquet', inr: 49, stardust: 50 },
];

export type SkyTier = 'free' | 'plus' | 'cosmetic';

/**
 * Personal sky themes for the user's own Home, Sanctuary and Insights (PRD 06c "Cosmetics"; competitor plan #20:
 * "personal only"). `free`: everyone; `plus`: included while Plus is on ("more of"); `cosmetic`: bought once in the
 * store (non-consumable, restorable) or with Stardust. Each has a suggested soundscape made of base stems only, so a
 * pairing never needs Plus (base Sounds are never paywalled).
 */
export interface SkyTheme {
  id: string;
  tier: SkyTier;
  /** Store product id (cosmetics only). */
  productId: string | null;
  inr: 10 | 29 | 49 | 99 | null;
  /** Stardust price (cosmetics only) `[ASSUMPTION]`: 1 Stardust ≈ ₹1 of the gift that earned it. */
  stardust: 10 | 30 | 50 | 100 | null;
  /** Suggested soundscape preset (SOUNDSCAPES). */
  soundscape: string;
}

export const SKY_THEMES: readonly SkyTheme[] = [
  { id: 'night', tier: 'free', productId: null, inr: null, stardust: null, soundscape: 'night_air' },
  { id: 'aurora', tier: 'plus', productId: null, inr: null, stardust: null, soundscape: 'high_wind' },
  { id: 'monsoon_dusk', tier: 'plus', productId: null, inr: null, stardust: null, soundscape: 'monsoon' },
  { id: 'first_light', tier: 'cosmetic', productId: 'sky_first_light', inr: 10, stardust: 10, soundscape: 'bells' },
  { id: 'lantern_festival', tier: 'cosmetic', productId: 'sky_lantern_festival', inr: 29, stardust: 30, soundscape: 'night_air' },
  { id: 'deep_ocean', tier: 'cosmetic', productId: 'sky_deep_ocean', inr: 49, stardust: 50, soundscape: 'shore' },
  { id: 'meteor_shower', tier: 'cosmetic', productId: 'sky_meteor_shower', inr: 99, stardust: 100, soundscape: 'high_wind' },
];

/**
 * Soundscape presets a sky can be paired with: base stems only (apps/mobile sounds manifest; never Plus stems, so the
 * pairing plays on Free too). `none` = no pairing.
 */
export const SOUNDSCAPES: Readonly<Record<string, readonly string[]>> = {
  night_air: ['night_insects', 'wind'],
  high_wind: ['wind', 'chimes'],
  monsoon: ['rain', 'brown_noise'],
  bells: ['singing_bowl', 'chimes'],
  shore: ['ocean', 'wind'],
};

export const DEFAULT_SKY = 'night';

export type ProductKind = 'plus' | 'cosmetic' | 'gift';

export interface ProductInfo {
  productId: string;
  kind: ProductKind;
}

export function productInfo(productId: string): ProductInfo | null {
  if ((PLUS_PRODUCTS as readonly string[]).includes(productId)) return { productId, kind: 'plus' };
  if (GIFT_PRODUCTS.some((g) => g.productId === productId)) return { productId, kind: 'gift' };
  if (SKY_THEMES.some((s) => s.productId === productId)) return { productId, kind: 'cosmetic' };
  return null;
}

export const giftByProduct = (productId: string): GiftProduct | null => GIFT_PRODUCTS.find((g) => g.productId === productId) ?? null;
export const giftByKind = (kind: string): GiftProduct | null => GIFT_PRODUCTS.find((g) => g.kind === kind) ?? null;
export const skyById = (id: string): SkyTheme | null => SKY_THEMES.find((s) => s.id === id) ?? null;
export const skyByProduct = (productId: string): SkyTheme | null => SKY_THEMES.find((s) => s.productId === productId) ?? null;

/** Every store product id (App Store Connect + Play Console setup list, docs in contracts/api/v1-billing.md). */
export const ALL_PRODUCT_IDS: readonly string[] = [
  ...PLUS_PRODUCTS,
  ...SKY_THEMES.filter((s) => s.productId).map((s) => s.productId as string),
  ...GIFT_PRODUCTS.map((g) => g.productId),
];

/** Gifting limits (PRD F12 "Gifts" / "Refunds"). */
export const GIFT_RULES = {
  /** ≤ 5 gifts per sender per Aura day. */
  perDay: 5,
  /** A pre-checked gift waits this long for the store (Ask to Buy / UPI mandate approval can take days). */
  reservationDays: 7,
  /** 2 refunded gifts within 90 days pause gifting for 90 days `[ASSUMPTION]`. */
  pauseAfterRefunds: 2,
  refundWindowDays: 90,
  pauseDays: 90,
  /** A 3rd refunded gift disables gifting `[ASSUMPTION]`. */
  disableAfterRefunds: 3,
  /** 3+ gifts in 7 days from one adult to the same under-18 account → minors-lane review `[ASSUMPTION]`. */
  minorPatternCount: 3,
  minorPatternDays: 7,
} as const;
