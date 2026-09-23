import { Global, Module } from '@nestjs/common';
import { AppleSignInClient } from '../account/apple-sign-in';
import { AppleTokenVault } from '../account/apple-tokens';
import { PrivateMediaStore } from '../account/private-media';
import { AppConfig } from '../config/app-config';
import { QueuesService } from './queues.service';

@Global()
@Module({
  providers: [
    QueuesService,
    // Storage API client for the account purge (worker). AppConfig first: it merges `.env` into process.env.
    {
      provide: PrivateMediaStore,
      useFactory: (c: AppConfig): PrivateMediaStore => PrivateMediaStore.fromEnv(c.supabaseUrl),
      inject: [AppConfig],
    },
    // Sign in with Apple tokens (APPLE_* env): stored by the API (POST /v1/account/apple-auth), revoked when a
    // deletion is requested and by the worker's account purge. Unconfigured → apple_unavailable / purge waits 72 h.
    {
      provide: AppleTokenVault,
      useFactory: (c: AppConfig): AppleTokenVault => new AppleTokenVault(c.masterKey, AppleSignInClient.fromEnv()),
      inject: [AppConfig],
    },
  ],
  exports: [QueuesService, PrivateMediaStore, AppleTokenVault],
})
export class QueuesModule {}
