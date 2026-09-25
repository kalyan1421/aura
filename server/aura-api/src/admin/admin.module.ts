import { Module } from '@nestjs/common';
import { SafetyModule } from '../safety/safety.module';
import { AdminCoreModule } from './admin-core.module';
import { AdminGuard } from './admin.guard';
import { ConfigController } from './config.controller';
import { ConsoleConfigService } from './console-config.service';
import { DeletionCasesAdminController, DeletionRequestsPublicController } from './deletion-cases.controller';
import { DeletionCasesService } from './deletion-cases.service';
import { GrievancesAdminController, GrievancesPublicController } from './grievances.controller';
import { GrievancesService } from './grievances.service';
import { LegalOrdersAdminController, LegalOrdersIntakeController } from './legal-orders.controller';
import { LegalOrdersService } from './legal-orders.service';
import { ModerationConsoleService } from './moderation-console.service';
import { ModerationController } from './moderation.controller';
import { PagingConsoleService } from './paging-console.service';
import { PagingController } from './paging.controller';
import { QueueSessionService } from './queue-session';
import { RegionPauseController } from './region-pause.controller';
import { RegionPauseService } from './region-pause.service';
import { SessionController } from './session.controller';
import { StaffController, StaffService } from './staff.service';

/**
 * Admin console v0, API side (PRD 19; docs/setup/admin-console.md):
 * - `/admin/*` — staff only (AdminGuard: allowlist + SSO first factor + AAL2/TOTP + short sessions + roles), no-store,
 *   audited;
 * - `POST /v1/grievances`, `GET /v1/grievances/officer` — the public grievance form (no login, rate-limited);
 * - `POST /v1/intake/legal-orders` — machine intake for emailed orders (shared secret; off unless configured);
 * - `/v1/deletion-requests/:token` — the account holder's confirmation link for a deletion case (REQ-ADM-11).
 * Console reads and actions run under the `aura_admin` Postgres role (moderation actions through ModerationService in
 * src/safety; state changes through the SECURITY DEFINER functions of migration 20261005000016). The worker side
 * (paging ticks, weekly drill, nightly audit export) is AdminWorkerModule.
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
    RegionPauseController,
    StaffController,
    DeletionCasesAdminController,
    DeletionRequestsPublicController,
  ],
  providers: [
    AdminGuard,
    ModerationConsoleService,
    GrievancesService,
    LegalOrdersService,
    PagingConsoleService,
    ConsoleConfigService,
    RegionPauseService,
    QueueSessionService,
    StaffService,
    DeletionCasesService,
  ],
})
export class AdminModule {}
