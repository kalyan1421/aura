import { Body, Controller, Get, HttpCode, Param, Post, Query, UseGuards, UseInterceptors } from '@nestjs/common';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor } from './admin-http';
import type { StaffUser } from './admin-types';
import { ConsoleConfigService, type AuditView } from './console-config.service';

/** Kill switches (feature flags) and the audit log — Owner only (PRD 19 Roles: config, flags). */
@Controller('admin')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class ConfigController {
  constructor(private readonly config: ConsoleConfigService) {}

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
}
