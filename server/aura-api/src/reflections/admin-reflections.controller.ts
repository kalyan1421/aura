import { Body, Controller, Get, HttpCode, Param, Post, Query, UseGuards, UseInterceptors } from '@nestjs/common';
import { AdminGuard, AdminRoles, CurrentStaff } from '../admin/admin.guard';
import { NoStoreInterceptor, uuidParam } from '../admin/admin-http';
import type { StaffUser } from '../admin/admin-types';
import { QueueSessionService } from '../admin/queue-session';
import { AdminReflectionsService, type DecisionResult, type PoolState, type ReviewItem, type ReviewView } from './admin-reflections.service';

/**
 * Reflection review in the admin console (contracts/api/v1-reflections.md §4; PRD 19). Owner + Moderator; the pool
 * kill switch is Owner only (PRD 19 Roles: config). Opening an item and deciding on it is review work that counts
 * toward the 2-hour queue session, except urgent items (crisis lane or paging). Every refusal by role is audited by
 * AdminGuard; every decision by the service.
 */
@Controller('admin/reflections')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
export class AdminReflectionsController {
  constructor(
    private readonly reflections: AdminReflectionsService,
    private readonly queueSessions: QueueSessionService,
  ) {}

  @Get()
  @AdminRoles('owner', 'moderator')
  list(@Query() query: unknown): Promise<{ items: ReviewItem[]; pools: PoolState[]; generatedAt: string }> {
    return this.reflections.list(query);
  }

  @Get('by-report/:reportId')
  @AdminRoles('owner', 'moderator')
  byReport(@Param('reportId') reportId: string): Promise<{ reflectionId: string }> {
    return this.reflections.byReport(uuidParam(reportId));
  }

  @Get(':reflectionId')
  @AdminRoles('owner', 'moderator')
  async view(@CurrentStaff() staff: StaffUser, @Param('reflectionId') reflectionId: string): Promise<ReviewView> {
    const id = uuidParam(reflectionId);
    await this.queueSessions.gate(staff, { urgent: await this.reflections.isUrgent(id) });
    return this.reflections.view(staff, id);
  }

  @Post(':reflectionId/decision')
  @HttpCode(200)
  @AdminRoles('owner', 'moderator')
  async decide(@CurrentStaff() staff: StaffUser, @Param('reflectionId') reflectionId: string, @Body() body: unknown): Promise<DecisionResult> {
    const id = uuidParam(reflectionId);
    await this.queueSessions.gate(staff, { urgent: await this.reflections.isUrgent(id) });
    return this.reflections.decide(staff, id, body);
  }

  @Post('pools/:pool/pause')
  @HttpCode(204)
  @AdminRoles('owner')
  async pause(@CurrentStaff() staff: StaffUser, @Param('pool') pool: string, @Body() body: unknown): Promise<void> {
    await this.reflections.setPoolPaused(staff, pool, true, body);
  }

  @Post('pools/:pool/resume')
  @HttpCode(204)
  @AdminRoles('owner')
  async resume(@CurrentStaff() staff: StaffUser, @Param('pool') pool: string, @Body() body: unknown): Promise<void> {
    await this.reflections.setPoolPaused(staff, pool, false, body);
  }
}
