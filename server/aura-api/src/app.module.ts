import { Module } from '@nestjs/common';
import { AccountModule } from './account/account.module';
import { AdminModule } from './admin/admin.module';
import { AuthModule } from './auth/auth.module';
import { ReviewSignInModule } from './auth/review-sign-in';
import { BillingModule } from './billing/billing.module';
import { CatalogueModule } from './catalogue/catalogue.module';
import { ConfigModule } from './config/config.module';
import { DbModule } from './db/db.module';
import { DevicesModule } from './devices/devices.module';
import { HealthModule } from './health/health.module';
import { IntentionsModule } from './intentions/intentions.module';
import { KeepsakesModule } from './keepsakes/keepsakes.module';
import { KeysModule } from './keys/keys.module';
import { MediaModule } from './media/media.module';
import { ProfileModule } from './profile/profile.module';
import { ProgressionModule } from './progression/progression.module';
import { QueuesModule } from './queues/queues.module';
import { QuietModule } from './quiet/quiet.module';
import { ReflectionsModule } from './reflections/reflections.module';
import { RemoteConfigModule } from './remote-config/remote-config.module';
import { RipplesModule } from './ripples/ripples.module';
import { RoomsModule } from './rooms/rooms.module';
import { SafetyModule } from './safety/safety.module';
import { SyncModule } from './sync/sync.module';

/** HTTP API (src/main.ts). Queues are producer-only here; processors run in src/worker.ts. */
@Module({
  imports: [
    ConfigModule,
    DbModule,
    AuthModule,
    QueuesModule,
    CatalogueModule,
    ProgressionModule,
    HealthModule,
    ProfileModule,
    SyncModule,
    KeysModule,
    DevicesModule,
    AccountModule,
    MediaModule,
    RoomsModule, // F5 Mood Rooms — contracts/api/v1-rooms.md
    SafetyModule, // F9 core safety (reports, blocks, standing; internal ModerationService)
    AdminModule, // admin console v0: /admin/*, public grievance form, legal-order intake (docs/setup/admin-console.md)
    RemoteConfigModule, // REQ-ADM-12: GET /v1/config (flags, kill switches), signed lexicon versions (docs/setup/lexicon-and-flags.md)
    ReflectionsModule, // F6 Reflections + moderation pipeline, /admin/reflections* — contracts/api/v1-reflections.md
    RipplesModule, // F7 Breath Ripples — contracts/api/v1-ripples.md
    QuietModule, // F16 Quiet Together (the Lantern Hour wind-down lives in RoomsModule) — contracts/api/v1-quiet.md
    BillingModule, // F12 Monetization: /v1/billing/*, store webhooks — contracts/api/v1-billing.md
    IntentionsModule, // F5 Tonight's intention list: /admin/intentions*, GET /v1/intentions — contracts/api/v1-rooms.md §1.10
    KeepsakesModule, // F13 Keepsakes: GET /v1/keepsakes (the caller's own only) — contracts/api/v1-keepsakes.md
    ReviewSignInModule, // POST /v1/auth/review-sign-in: the App Review account's fixed code (off unless configured) — docs/setup/app-review.md
  ],
})
export class AppModule {}
