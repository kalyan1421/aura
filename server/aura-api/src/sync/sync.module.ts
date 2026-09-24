import { Module } from '@nestjs/common';
import { CapsulesModule } from '../capsules/capsules.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ProfileModule } from '../profile/profile.module';
import { SanctuaryModule } from '../sanctuary/sanctuary-sessions';
import { SyncController } from './sync.controller';
import { SyncRepository } from './sync.repository';
import { SyncService } from './sync.service';

@Module({
  imports: [ProfileModule, CapsulesModule, NotificationsModule, SanctuaryModule], // F14: `notification_prefs`; F15: `sanctuary_session`
  controllers: [SyncController],
  providers: [SyncRepository, SyncService],
})
export class SyncModule {}
