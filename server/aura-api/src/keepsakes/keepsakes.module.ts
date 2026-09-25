import { Module } from '@nestjs/common';
import { KeepsakesController } from './keepsakes.controller';
import { KeepsakesService } from './keepsakes.service';

/**
 * F13 Keepsakes (contracts/api/v1-keepsakes.md; rules RULES.md §11; migration 20261005000026). Self-contained so the
 * feature can be cut (PRD 20-timeline lever 8): nothing else imports it. The worker tick is keepsakes.worker.ts.
 */
@Module({
  controllers: [KeepsakesController],
  providers: [KeepsakesService],
})
export class KeepsakesModule {}
