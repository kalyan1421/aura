import { Module } from '@nestjs/common';
import { RoomsRepository } from '../rooms/rooms.repository';
import { BlocksService } from './blocks.service';
import { ModerationService } from './moderation.service';
import { ReportsService } from './reports.service';
import { SafetyController } from './safety.controller';
import { SafetyService } from './safety.service';

/**
 * F9 core safety: reports → lanes, blocks, the caller's standing (HTTP, contracts/api/v1-rooms.md §2) and the internal
 * `ModerationService` (queue by lane, act, audit log) that the admin console stage will wrap with staff auth.
 * Shared SQL helpers (sanctions, blocks, evidence, audit) are plain functions used by rooms and the worker too.
 */
@Module({
  controllers: [SafetyController],
  providers: [ReportsService, BlocksService, SafetyService, ModerationService, RoomsRepository],
  exports: [ModerationService],
})
export class SafetyModule {}
