import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AppConfig } from '../config/app-config';
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
    // Global guards run in registration order: authenticate first, then refuse accounts pending deletion.
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_GUARD, useClass: PendingDeletionGuard },
  ],
  exports: [JwtVerifier],
})
export class AuthModule {}
