import { Module } from '@nestjs/common';
import { AdminCoreModule } from '../admin/admin-core.module';
import { QuietGesturesService } from './quiet-gestures.service';
import { QuietSafetyService } from './quiet-safety.service';
import { QuietController } from './quiet.controller';
import { QuietService } from './quiet.service';

/**
 * F16 Quiet Together (contracts/api/v1-quiet.md). AdminCoreModule provides the URGENT_PAGER that paging reports go to
 * (REQ-ADM-05). Safety checks are the plain functions of src/safety; gesture limits come from src/rooms. The worker
 * tick (counts every 30 s, stale memberships, retention) is src/quiet/quiet.worker.ts. The Lantern Hour wind-down
 * lives with the rooms (src/rooms/wind-down*.ts).
 */
@Module({
  imports: [AdminCoreModule],
  controllers: [QuietController],
  providers: [QuietService, QuietGesturesService, QuietSafetyService],
})
export class QuietModule {}
