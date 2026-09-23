import { Module } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { AdminConfig, parseAdminConfig } from './admin-config';
import { AdminDb } from './admin-db';
import { GrievanceMail } from './grievance-mail';
import { DisabledMailer, MAILER, SmtpMailer, type Mailer } from './mail/mailer';
import { PAGE_CHANNELS, buildChannels } from './paging/channels';
import { PagingService } from './paging/paging.service';
import { RateLimiter } from './rate-limit';

/**
 * What the API (AdminModule) and the worker (AdminWorkerModule) share: admin config, the aura_admin database wrapper,
 * mail, the pager and its channels, the rate limiter. DbService, QueuesService and AppConfig come from global modules.
 */
@Module({
  providers: [
    // AppConfig first: its factory merges `.env` into process.env before the admin variables are read.
    { provide: AdminConfig, useFactory: (_app: AppConfig): AdminConfig => parseAdminConfig(process.env), inject: [AppConfig] },
    {
      provide: MAILER,
      useFactory: (c: AdminConfig): Mailer => (c.smtpUrl ? SmtpMailer.fromUrl(c.smtpUrl, c.mailFrom) : new DisabledMailer()),
      inject: [AdminConfig],
    },
    { provide: PAGE_CHANNELS, useFactory: (c: AdminConfig, m: Mailer) => buildChannels(c, m), inject: [AdminConfig, MAILER] },
    AdminDb,
    PagingService,
    GrievanceMail,
    RateLimiter,
  ],
  exports: [AdminConfig, MAILER, PAGE_CHANNELS, AdminDb, PagingService, GrievanceMail, RateLimiter],
})
export class AdminCoreModule {}
