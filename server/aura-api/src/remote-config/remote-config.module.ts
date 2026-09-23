import { Logger, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AdminCoreModule } from '../admin/admin-core.module';
import { AdminGuard } from '../admin/admin.guard';
import { AppConfig } from '../config/app-config';
import { KillSwitchGuard } from './kill-switch';
import { LexiconService } from './lexicon.service';
import { LexiconAdminController, RemoteConfigController } from './remote-config.controller';
import { RemoteConfigSettings, parseRemoteConfigSettings } from './remote-config.config';
import { RemoteConfigService } from './remote-config.service';

/**
 * Remote config (PRD 19 REQ-ADM-12; docs/setup/lexicon-and-flags.md):
 * - `GET /v1/config` — feature flags / kill switches + signed-bundle pointers, ETag, public;
 * - `GET /v1/lexicon/crisis` — the live signed crisis lexicon, ETag, public;
 * - `/admin/lexicons/crisis*` — upload, test on samples, publish, roll back (Owner), audited;
 * - KillSwitchGuard (global) — routes marked @KillSwitch(...) answer 503 while their flag is off.
 * Flags themselves are flipped by the console's `POST /admin/config/flags/:key` (src/admin).
 */
@Module({
  imports: [AdminCoreModule],
  controllers: [RemoteConfigController, LexiconAdminController],
  providers: [
    {
      provide: RemoteConfigSettings,
      // AppConfig first: its factory merges `.env` into process.env before these variables are read.
      useFactory: (_app: AppConfig): RemoteConfigSettings => {
        const s = parseRemoteConfigSettings(process.env);
        const log = new Logger('RemoteConfig');
        if (s.signer?.isDevKey) log.warn(`lexicon signing uses the public DEVELOPMENT key (${s.signer.keyId}); set LEXICON_SIGNING_KEY for real use`);
        else if (s.signer) log.log(`lexicon signing key ${s.signer.keyId}`);
        else log.warn(`lexicon signing is off: ${s.signingOffReason ?? 'no key'}`);
        return s;
      },
      inject: [AppConfig],
    },
    RemoteConfigService,
    LexiconService,
    AdminGuard,
    { provide: APP_GUARD, useClass: KillSwitchGuard },
  ],
  exports: [RemoteConfigService],
})
export class RemoteConfigModule {}
