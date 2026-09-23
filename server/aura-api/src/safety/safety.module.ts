import { Module } from '@nestjs/common';
import { AdminCoreModule } from '../admin/admin-core.module';
import { BlocksService } from './blocks.service';
import { GuidelinesService } from './guidelines';
import { ModerationService } from './moderation.service';
import { ReportsService } from './reports.service';
import { SafetyController } from './safety.controller';
import { SafetyService } from './safety.service';

/**
 * F9 core safety: reports → lanes, blocks, the caller's standing, community guidelines acceptance (HTTP,
 * contracts/api/v1-rooms.md §2) and the internal `ModerationService` (queue by lane, act, audit log) that the admin
 * console wraps with staff auth. Shared SQL helpers (sanctions, blocks, evidence, audit, the guidelines gate) are plain
 * functions used by rooms and the worker too.
 *
 * AdminCoreModule provides `AdminDb` (ModerationService runs as the `aura_admin` role) and the URGENT_PAGER that
 * ReportsService hands paging reports to (REQ-ADM-05: the Owner's phone within 60 s).
 */
@Module({
  imports: [AdminCoreModule],
  controllers: [SafetyController],
  providers: [ReportsService, BlocksService, SafetyService, GuidelinesService, ModerationService],
  exports: [ModerationService],
})
export class SafetyModule {}
