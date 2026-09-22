import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AppConfig } from '../config/app-config';
import { AuthGuard } from './auth.guard';
import { JwtVerifier } from './jwt-verifier';

@Global()
@Module({
  providers: [
    {
      provide: JwtVerifier,
      useFactory: (c: AppConfig): JwtVerifier =>
        new JwtVerifier({ secret: c.jwtSecret, jwksUrl: c.jwksUrl, issuer: c.jwtIssuer }),
      inject: [AppConfig],
    },
    { provide: APP_GUARD, useClass: AuthGuard },
  ],
  exports: [JwtVerifier],
})
export class AuthModule {}
