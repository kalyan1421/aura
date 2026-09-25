import { Body, Controller, Get, HttpCode, Param, Post, UseGuards, UseInterceptors } from '@nestjs/common';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor } from './admin-http';
import type { StaffUser } from './admin-types';
import { RegionPauseService, type RegionFlagState, type RegionPauses } from './region-pause.service';

/**
 * Per-region pauses of Quiet Together (`quiet_enabled`) and the Lantern Hour wind-down (`lantern_wind_down_enabled`)
 * — PRD 19 "Configuration". Reading is Owner + Moderator (a Moderator should know why a region has no Quiet Together
 * tonight); changing is Owner only (PRD 19 Roles: a Moderator cannot "change config"). Refusals by role are audited by
 * AdminGuard, changes by the service.
 */
@Controller('admin/config/regions')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
export class RegionPauseController {
  constructor(private readonly regions: RegionPauseService) {}

  @Get()
  @AdminRoles('owner', 'moderator')
  get(): Promise<RegionPauses> {
    return this.regions.get();
  }

  @Post(':key/:region/pause')
  @HttpCode(200)
  @AdminRoles('owner')
  pause(@CurrentStaff() staff: StaffUser, @Param('key') key: string, @Param('region') region: string, @Body() body: unknown): Promise<RegionFlagState> {
    return this.regions.setPaused(staff, key, region, true, body);
  }

  @Post(':key/:region/resume')
  @HttpCode(200)
  @AdminRoles('owner')
  resume(@CurrentStaff() staff: StaffUser, @Param('key') key: string, @Param('region') region: string, @Body() body: unknown): Promise<RegionFlagState> {
    return this.regions.setPaused(staff, key, region, false, body);
  }
}
