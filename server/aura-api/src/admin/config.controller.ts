import { Body, Controller, Get, HttpCode, Param, Post, Query, UseGuards, UseInterceptors } from '@nestjs/common';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor } from './admin-http';
import type { StaffUser } from './admin-types';
import { AuditExportService, type AuditExportResult, type AuditExportStatus } from './audit-export';
import { ConsoleConfigService, type AuditView } from './console-config.service';

/** Kill switches (feature flags), the audit log and its export — Owner only (PRD 19 Roles: config, flags). */
@Controller('admin')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class ConfigController {
  constructor(
    private readonly config: ConsoleConfigService,
    private readonly exports: AuditExportService,
  ) {}

  @Get('config')
  get(): ReturnType<ConsoleConfigService['get']> {
    return this.config.get();
  }

  @Post('config/flags/:key')
  @HttpCode(200)
  setFlag(@CurrentStaff() staff: StaffUser, @Param('key') key: string, @Body() body: unknown): Promise<{ key: string; enabled: boolean }> {
    return this.config.setFlag(staff, key, body);
  }

  @Get('audit')
  async audit(@Query() query: unknown): Promise<{ entries: AuditView[] }> {
    return { entries: await this.config.audit(query) };
  }

  @Get('audit/verify')
  verify(): Promise<{ ok: boolean; checkedAt: string }> {
    return this.config.verifyChain();
  }

  /** The nightly export's configuration and its latest runs (PRD 19 "exported nightly"). */
  @Get('audit/exports')
  exportStatus(): Promise<AuditExportStatus> {
    return this.exports.status();
  }

  /** Export now (everything since the last export) to the configured destinations; audited like the nightly run. */
  @Post('audit/exports')
  @HttpCode(200)
  exportNow(@CurrentStaff() staff: StaffUser): Promise<AuditExportResult> {
    return this.exports.run('manual', staff.actor);
  }
}
