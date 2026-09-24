/**
 * App Store decoded payloads (the fields Aura reads). All times are Unix milliseconds. Field names follow Apple's
 * App Store Server API / App Store Server Notifications V2 documentation.
 */
export type AppleEnvironment = 'Production' | 'Sandbox' | 'Xcode' | 'LocalTesting';

/** JWSTransactionDecodedPayload */
export interface AppleTransaction {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate?: number;
  originalPurchaseDate?: number;
  expiresDate?: number;
  quantity?: number;
  type: 'Auto-Renewable Subscription' | 'Non-Consumable' | 'Consumable' | 'Non-Renewing Subscription';
  appAccountToken?: string;
  inAppOwnershipType?: 'PURCHASED' | 'FAMILY_SHARED';
  signedDate?: number;
  revocationReason?: number;
  revocationDate?: number;
  isUpgraded?: boolean;
  /** 1 introductory, 2 promotional, 3 offer code, 4 win-back. */
  offerType?: number;
  offerIdentifier?: string;
  offerDiscountType?: 'FREE_TRIAL' | 'PAY_AS_YOU_GO' | 'PAY_UP_FRONT' | string;
  environment?: AppleEnvironment;
  storefront?: string;
  transactionReason?: 'PURCHASE' | 'RENEWAL';
  /** Milli-units of `currency`. */
  price?: number;
  currency?: string;
}

/** JWSRenewalInfoDecodedPayload */
export interface AppleRenewalInfo {
  originalTransactionId: string;
  productId?: string;
  autoRenewProductId?: string;
  /** 0 off, 1 on. */
  autoRenewStatus?: number;
  expirationIntent?: number;
  isInBillingRetryPeriod?: boolean;
  gracePeriodExpiresDate?: number;
  signedDate?: number;
  environment?: AppleEnvironment;
  renewalDate?: number;
  renewalPrice?: number;
  currency?: string;
  appAccountToken?: string;
}

/** ResponseBodyV2DecodedPayload */
export interface AppleNotification {
  notificationType: string;
  subtype?: string;
  notificationUUID: string;
  version?: string;
  signedDate?: number;
  data?: {
    appAppleId?: number;
    bundleId?: string;
    bundleVersion?: string;
    environment?: AppleEnvironment;
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
    /** 1 active, 2 expired, 3 billing retry, 4 grace period, 5 revoked. */
    status?: number;
    consumptionRequestReason?: string;
  };
  summary?: { bundleId?: string; environment?: AppleEnvironment };
}

/** One `lastTransactions` item of GET /inApps/v1/subscriptions/{transactionId}. */
export interface AppleStatusItem {
  originalTransactionId: string;
  /** 1 active, 2 expired, 3 billing retry, 4 grace period, 5 revoked. */
  status: number;
  signedTransactionInfo: string;
  signedRenewalInfo?: string;
}

export const isAppleSubscription = (t: Pick<AppleTransaction, 'type'>): boolean => t.type === 'Auto-Renewable Subscription';
