import { Body, Controller, Get, HttpCode, Param, Post, Query, Req, UseGuards, UseInterceptors } from '@nestjs/common';
import type { Request } from 'express';
import { Public } from '../auth/public.decorator';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor, clientAddress, uuidParam } from './admin-http';
import type { StaffUser } from './admin-types';
import { GrievancesService, type GrievanceDetail, type GrievanceReceipt, type GrievanceView } from './grievances.service';

/**
 * The public grievance form (PRD F9 "Grievance Officer … ticketed form, auto-acknowledged", REQ-SAFE-11): no login, so
 * the in-app form works signed out and the website can post to it too. Rate-limited per client and globally.
 */
@Controller('v1/grievances')
@Public()
@UseInterceptors(NoStoreInterceptor)
export class GrievancesPublicController {
  constructor(private readonly grievances: GrievancesService) {}

  /** Grievance Officer contact, timelines and categories for the app's Help & Safety screen and the website. */
  @Get('officer')
  officer(): ReturnType<GrievancesService['officer']> {
    return this.grievances.officer();
  }

  /** `201` with the ticket id: this response is the acknowledgement; an email copy follows. */
  @Post()
  @HttpCode(201)
  submit(@Body() body: unknown, @Req() req: Request): Promise<GrievanceReceipt> {
    return this.grievances.submitPublic(body, clientAddress(req));
  }
}

/** The Grievance Officer's inbox (Owner only: complainant contact details are visible here). */
@Controller('admin/grievances')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class GrievancesAdminController {
  constructor(private readonly grievances: GrievancesService) {}

  @Get()
  async list(@Query() query: unknown): Promise<{ grievances: GrievanceView[] }> {
    return { grievances: await this.grievances.list(query) };
  }

  /** A grievance that arrived by email or post, entered by the Owner (its clock runs from `receivedAt`). */
  @Post()
  @HttpCode(201)
  create(@CurrentStaff() staff: StaffUser, @Body() body: unknown): Promise<GrievanceDetail> {
    return this.grievances.createFromStaff(staff, body);
  }

  @Get(':id')
  get(@Param('id') id: string): Promise<GrievanceDetail> {
    return this.grievances.get(uuidParam(id));
  }

  @Post(':id/acknowledge')
  @HttpCode(200)
  acknowledge(@CurrentStaff() staff: StaffUser, @Param('id') id: string): Promise<GrievanceDetail> {
    return this.grievances.acknowledge(staff, uuidParam(id));
  }

  @Post(':id/resolve')
  @HttpCode(200)
  resolve(@CurrentStaff() staff: StaffUser, @Param('id') id: string, @Body() body: unknown): Promise<GrievanceDetail & { replyEmailed: boolean }> {
    return this.grievances.resolve(staff, uuidParam(id), body);
  }
}
