import type { INestApplication } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { ApiExceptionFilter } from './common/api-exception.filter';
import { AppConfig } from './config/app-config';

/**
 * SR-2: Express `trust proxy` from TRUST_PROXY (config.schema.ts). Without it, behind a load balancer every request's
 * `req.ip` is the balancer's address and the per-client limits of the public routes become one global bucket (five
 * grievances an hour for the whole country). Never `true`: that would trust a client-sent X-Forwarded-For.
 */
export function applyTrustProxy(express: { set(setting: string, value: unknown): unknown }, trustProxy: AppConfig['trustProxy']): void {
  express.set('trust proxy', trustProxy === undefined ? false : typeof trustProxy === 'number' ? trustProxy : [...trustProxy]);
}

/** Shared HTTP setup for main.ts and the e2e suite (same behaviour under test). */
export function configureApp(app: INestApplication): void {
  const express = app as NestExpressApplication;
  express.useBodyParser('json', { limit: '2mb' }); // 200 mutations with ciphertext notes
  express.disable('x-powered-by');
  applyTrustProxy(express, app.get(AppConfig).trustProxy);
  app.useGlobalFilters(new ApiExceptionFilter());
  app.enableShutdownHooks();
}
