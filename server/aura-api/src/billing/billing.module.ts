import { Logger, Module } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { HttpAppStoreServerApi, type AppStoreServerApi } from './apple/app-store-api';
import { AppleJwsVerifier } from './apple/jws';
import { loadBillingConfig, type BillingConfig } from './billing.config';
import { BillingController, BillingWebhooksController } from './billing.controller';
import { BillingService } from './billing.service';
import { APP_STORE_API, APPLE_JWS_VERIFIER, BILLING_CONFIG, PLAY_API, PUBSUB_VERIFIER } from './billing.tokens';
import { HttpPlayDeveloperApi, type PlayDeveloperApi } from './google/play-api';
import { PubSubPushVerifier } from './google/pubsub-auth';
import { StoreSync } from './store-sync.service';

/**
 * F12 core, shared by the API and the worker: configuration (env, read after AppConfig merged `.env`), the App Store
 * JWS verifier (Apple roots), the App Store Server API and Play Developer API clients, and StoreSync.
 */
@Module({
  providers: [
    {
      provide: BILLING_CONFIG,
      useFactory: (_app: AppConfig): BillingConfig => {
        const c = loadBillingConfig();
        const log = new Logger('Billing');
        if (!c.appleApi) log.warn('APPLE_IAP_ISSUER_ID / _KEY_ID / _PRIVATE_KEY not set: App Store purchases stay "confirming" until a notification arrives');
        if (!c.googleServiceAccount) log.warn(`Play Developer API not configured${c.googleServiceAccountProblem ? ` (${c.googleServiceAccountProblem})` : ''}: Google purchases stay "confirming"`);
        return c;
      },
      inject: [AppConfig],
    },
    { provide: APPLE_JWS_VERIFIER, useFactory: (): AppleJwsVerifier => new AppleJwsVerifier() },
    {
      provide: APP_STORE_API,
      useFactory: (c: BillingConfig): AppStoreServerApi => new HttpAppStoreServerApi(c.appleApi, { acceptSandbox: c.acceptSandbox }),
      inject: [BILLING_CONFIG],
    },
    {
      provide: PLAY_API,
      useFactory: (c: BillingConfig): PlayDeveloperApi => new HttpPlayDeveloperApi(c.googleServiceAccount, c.googlePackageName),
      inject: [BILLING_CONFIG],
    },
    StoreSync,
  ],
  exports: [BILLING_CONFIG, APPLE_JWS_VERIFIER, APP_STORE_API, PLAY_API, StoreSync],
})
export class BillingCoreModule {}

/** HTTP API: /v1/billing/* (contracts/api/v1-billing.md) and the two store webhooks. */
@Module({
  imports: [BillingCoreModule],
  controllers: [BillingController, BillingWebhooksController],
  providers: [
    BillingService,
    {
      provide: PUBSUB_VERIFIER,
      useFactory: (c: BillingConfig): PubSubPushVerifier =>
        new PubSubPushVerifier({ audience: c.rtdnAudience, serviceAccountEmail: c.rtdnServiceAccount }),
      inject: [BILLING_CONFIG],
    },
  ],
})
export class BillingModule {}
