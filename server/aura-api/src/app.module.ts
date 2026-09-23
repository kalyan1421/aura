import { Module } from '@nestjs/common';
import { AccountModule } from './account/account.module';
import { AuthModule } from './auth/auth.module';
import { CatalogueModule } from './catalogue/catalogue.module';
import { ConfigModule } from './config/config.module';
import { DbModule } from './db/db.module';
import { DevicesModule } from './devices/devices.module';
import { HealthModule } from './health/health.module';
import { KeysModule } from './keys/keys.module';
import { MediaModule } from './media/media.module';
import { ProfileModule } from './profile/profile.module';
import { ProgressionModule } from './progression/progression.module';
import { QueuesModule } from './queues/queues.module';
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
  ],
})
export class AppModule {}
