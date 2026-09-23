import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AppConfig } from '../config/app-config';
import { AccountClosedGuard } from './account-closed.guard';
import { AuthGuard } from './auth.guard';
import { JwtVerifier } from './jwt-verifier';
import { PendingDeletionGuard } from './pending-deletion.guard';

@Global()
@Module({
  providers: [
    {
      provide: JwtVerifier,
      useFactory: (c: AppConfig): JwtVerifier =>
        new JwtVerifier({ secret: c.jwtSecret, jwksUrl: c.jwksUrl, issuer: c.jwtIssuer }),
      inject: [AppConfig],
    },
    // Global guards run in registration order: authenticate first, then refuse accounts pending deletion, then
    // accounts closed for breaking the rules (403 account_closed everywhere but /v1/account* and GET /v1/safety*).
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: PendingDeletionGuard },
    { provide: APP_GUARD, useClass: AccountClosedGuard },
  ],
  exports: [JwtVerifier],
})
export class AuthModule {}
