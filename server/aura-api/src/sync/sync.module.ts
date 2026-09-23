import { Module } from '@nestjs/common';
import { CapsulesModule } from '../capsules/capsules.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ProfileModule } from '../profile/profile.module';
import { SyncController } from './sync.controller';
import { SyncRepository } from './sync.repository';
import { SyncService } from './sync.service';

@Module({
  imports: [ProfileModule, CapsulesModule, NotificationsModule], // F14: entity `notification_prefs`
  controllers: [SyncController],
  providers: [SyncRepository, SyncService],
})
export class SyncModule {}
