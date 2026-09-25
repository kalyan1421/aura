import { Body, Controller, Get, HttpCode, Post, UseGuards, UseInterceptors } from '@nestjs/common';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor } from './admin-http';
import type { StaffUser } from './admin-types';
import { PseudonymsService, type PseudonymConfig } from './pseudonyms.service';

/** PRD 19 "Configuration": room pseudonym lists (read) and the Owner's blocklist (change). */
@Controller('admin/config/pseudonyms')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
export class PseudonymsController {
  constructor(private readonly pseudonyms: PseudonymsService) {}

  @Get()
  @AdminRoles('owner', 'moderator')
  get(): Promise<PseudonymConfig> {
    return this.pseudonyms.get();
  }

  @Post('block')
  @HttpCode(200)
  @AdminRoles('owner')
  block(@CurrentStaff() staff: StaffUser, @Body() body: unknown): Promise<PseudonymConfig> {
    return this.pseudonyms.block(staff, body);
  }

  @Post('unblock')
  @HttpCode(200)
  @AdminRoles('owner')
  unblock(@CurrentStaff() staff: StaffUser, @Body() body: unknown): Promise<PseudonymConfig> {
    return this.pseudonyms.unblock(staff, body);
  }
}
