import { Module } from '@nestjs/common';
import { SafetyModule } from '../safety/safety.module';
import { AdminCoreModule } from './admin-core.module';
import { AdminGuard } from './admin.guard';
import { ConfigController } from './config.controller';
import { ConsoleConfigService } from './console-config.service';
import { GrievancesAdminController, GrievancesPublicController } from './grievances.controller';
import { GrievancesService } from './grievances.service';
import { LegalOrdersAdminController, LegalOrdersIntakeController } from './legal-orders.controller';
import { LegalOrdersService } from './legal-orders.service';
import { ModerationConsoleService } from './moderation-console.service';
import { ModerationController } from './moderation.controller';
import { PagingConsoleService } from './paging-console.service';
import { PagingController } from './paging.controller';
import { SessionController } from './session.controller';

/**
 * Admin console v0, API side (PRD 19; docs/setup/admin-console.md):
 * - `/admin/*` — staff only (AdminGuard: allowlist + AAL2/TOTP + short sessions + roles), no-store, audited;
 * - `POST /v1/grievances`, `GET /v1/grievances/officer` — the public grievance form (no login, rate-limited);
 * - `POST /v1/intake/legal-orders` — machine intake for emailed orders (shared secret; off unless configured).
 * Console reads and console-owned writes run under the `aura_admin` Postgres role; moderation actions go through
 * the internal ModerationService (src/safety). The worker side (paging ticks, weekly drill) is AdminWorkerModule.
 */
@Module({
  imports: [AdminCoreModule, SafetyModule],
  controllers: [
    SessionController,
    ModerationController,
    GrievancesPublicController,
    GrievancesAdminController,
    LegalOrdersAdminController,
    LegalOrdersIntakeController,
    PagingController,
    ConfigController,
  ],
  providers: [AdminGuard, ModerationConsoleService, GrievancesService, LegalOrdersService, PagingConsoleService, ConsoleConfigService],
})
export class AdminModule {}
