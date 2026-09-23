import { Global, Module } from '@nestjs/common';
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
  ],
  exports: [QueuesService, PrivateMediaStore],
})
export class QueuesModule {}
