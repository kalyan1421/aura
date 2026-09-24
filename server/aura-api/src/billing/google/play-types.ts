/** Google Play Developer API v3 shapes (the fields Aura reads). Times are RFC 3339 strings or epoch-millis strings. */

export type GoogleSubscriptionState =
  | 'SUBSCRIPTION_STATE_UNSPECIFIED'
  | 'SUBSCRIPTION_STATE_PENDING'
  | 'SUBSCRIPTION_STATE_ACTIVE'
  | 'SUBSCRIPTION_STATE_PAUSED'
  | 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'
  | 'SUBSCRIPTION_STATE_ON_HOLD'
  | 'SUBSCRIPTION_STATE_CANCELED'
  | 'SUBSCRIPTION_STATE_EXPIRED'
  | 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED';

/** purchases.subscriptionsv2.get → SubscriptionPurchaseV2 */
export interface GoogleSubscriptionV2 {
  kind?: string;
  startTime?: string;
  subscriptionState: GoogleSubscriptionState;
  latestOrderId?: string;
  linkedPurchaseToken?: string;
  acknowledgementState?: 'ACKNOWLEDGEMENT_STATE_UNSPECIFIED' | 'ACKNOWLEDGEMENT_STATE_PENDING' | 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string; obfuscatedExternalProfileId?: string };
  testPurchase?: Record<string, never>;
  canceledStateContext?: Record<string, unknown>;
  lineItems?: GoogleSubscriptionLineItem[];
}

export interface GoogleSubscriptionLineItem {
  productId: string;
  expiryTime?: string;
  autoRenewingPlan?: { autoRenewEnabled?: boolean; recurringPrice?: { currencyCode?: string; units?: string; nanos?: number } };
  offerDetails?: { basePlanId?: string; offerId?: string; offerTags?: string[] };
  /** Newer API field: which pricing phase the current period is in. */
  offerPhase?: { freeTrial?: Record<string, never>; introductoryPrice?: Record<string, never>; basePrice?: Record<string, never> };
  latestSuccessfulOrderId?: string;
}

/** purchases.products.get → ProductPurchase */
export interface GoogleProductPurchase {
  purchaseTimeMillis?: string;
  /** 0 purchased, 1 canceled, 2 pending. */
  purchaseState?: number;
  /** 0 yet to be consumed, 1 consumed. */
  consumptionState?: number;
  /** 0 yet to be acknowledged, 1 acknowledged. */
  acknowledgementState?: number;
  orderId?: string;
  productId?: string;
  /** 0 test (licensed tester), 1 promo, 2 rewarded; absent = real. */
  purchaseType?: number;
  obfuscatedExternalAccountId?: string;
  obfuscatedExternalProfileId?: string;
  quantity?: number;
}

/** purchases.voidedpurchases.list item */
export interface GoogleVoidedPurchase {
  purchaseToken: string;
  orderId?: string;
  voidedTimeMillis?: string;
  /** 0 user, 1 developer, 2 google. */
  voidedSource?: number;
  voidedReason?: number;
}

/** RTDN DeveloperNotification (Pub/Sub message `data`, base64 JSON). */
export interface DeveloperNotification {
  version?: string;
  packageName?: string;
  eventTimeMillis?: string;
  subscriptionNotification?: { version?: string; notificationType: number; purchaseToken: string; subscriptionId?: string };
  oneTimeProductNotification?: { version?: string; notificationType: number; purchaseToken: string; sku: string };
  voidedPurchaseNotification?: { purchaseToken: string; orderId?: string; productType?: number; refundType?: number };
  testNotification?: { version?: string };
}

/** RTDN subscription notification types. */
export const SUB_NOTIFICATION = {
  RECOVERED: 1,
  RENEWED: 2,
  CANCELED: 3,
  PURCHASED: 4,
  ON_HOLD: 5,
  IN_GRACE_PERIOD: 6,
  RESTARTED: 7,
  PRICE_CHANGE_CONFIRMED: 8,
  DEFERRED: 9,
  PAUSED: 10,
  PAUSE_SCHEDULE_CHANGED: 11,
  REVOKED: 12,
  EXPIRED: 13,
  PRICE_CHANGE_UPDATED: 19,
  PENDING_PURCHASE_CANCELED: 20,
} as const;
