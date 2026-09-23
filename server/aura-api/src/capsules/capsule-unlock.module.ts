import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { CapsuleUnlockService } from './capsule-unlock.service';

/**
 * The date-capsule unlock push: scheduling (API, after a seal commits) and the `capsule-unlock` queue processor +
 * sweep (worker). Imported by CapsulesModule (API) and WorkerModule. DbService / QueuesService are global.
 */
@Module({
  imports: [NotificationsModule],
  providers: [CapsuleUnlockService],
  exports: [CapsuleUnlockService],
})
export class CapsuleUnlockModule {}
