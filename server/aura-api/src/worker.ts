import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppConfig } from './config/app-config';
import { WorkerModule } from './worker.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(WorkerModule);
  app.enableShutdownHooks();
  const config = app.get(AppConfig);
  await app.listen(config.workerHealthPort);
  Logger.log(`aura-worker health on :${config.workerHealthPort}`, 'Bootstrap');
}

bootstrap().catch((err: unknown) => {
  Logger.error(err instanceof Error ? err.message : String(err), undefined, 'Bootstrap');
  process.exit(1);
});
