import type { INestApplication } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { ApiExceptionFilter } from './common/api-exception.filter';

/** Shared HTTP setup for main.ts and the e2e suite (same behaviour under test). */
export function configureApp(app: INestApplication): void {
  const express = app as NestExpressApplication;
  express.useBodyParser('json', { limit: '2mb' }); // 200 mutations with ciphertext notes
  express.disable('x-powered-by');
  app.useGlobalFilters(new ApiExceptionFilter());
  app.enableShutdownHooks();
}
