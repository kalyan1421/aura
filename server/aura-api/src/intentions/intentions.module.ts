import { Module } from '@nestjs/common';
import { AdminCoreModule } from '../admin/admin-core.module';
import { AdminGuard } from '../admin/admin.guard';
import { IntentionsAdminController, IntentionsPublicController } from './intentions.controller';
import { IntentionsService } from './intentions.service';

/**
 * Tonight's intention list (F5 Milestone B; PRD 19 "the Tonight's intention list per language"; migration
 * 20261005000025):
 * - `/admin/intentions*` — list, add, reword, retire / restore / move (Owner; Moderator reads), audited, words linted;
 * - `GET /v1/intentions` — every key's words for the app (public, ETag).
 * The nightly pick itself stays in src/rooms (lanterns.ts `ensureLanternNight`, rotated from the enabled presets).
 */
@Module({
  imports: [AdminCoreModule],
  controllers: [IntentionsAdminController, IntentionsPublicController],
  providers: [IntentionsService, AdminGuard],
})
export class IntentionsModule {}
