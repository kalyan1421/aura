import { Body, Controller, Get, HttpCode, Param, Post, Query, Res, UseGuards, UseInterceptors } from '@nestjs/common';
import type { Response } from 'express';
import type { QueueItem } from '../safety/moderation.service';
import { AdminDb } from './admin-db';
import { auditConsole } from './admin-audit';
import { AdminErrors } from './admin-errors';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor, uuidParam } from './admin-http';
import { parse, queueQuerySchema, sanctionsQuerySchema } from './admin.schemas';
import type { StaffUser } from './admin-types';
import { ModerationConsoleService, type ItemView, type LaneSummary, type SanctionView, type WorkEntry } from './moderation-console.service';

/**
 * Moderation routes of the console (Owner + Moderator; the analyst gets `/admin/stats` only). Actions are role-checked
 * again per action inside the service (a Moderator can't ban or unban), and every refusal is audited.
 */
@Controller('admin')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
export class ModerationController {
  constructor(
    private readonly console: ModerationConsoleService,
    private readonly adminDb: AdminDb,
  ) {}

  @Get('work')
  @AdminRoles('owner', 'moderator')
  async work(@CurrentStaff() staff: StaffUser): Promise<{ items: WorkEntry[]; generatedAt: string }> {
    return { items: await this.console.work(staff), generatedAt: new Date().toISOString() };
  }

  @Get('stats')
  @AdminRoles('owner', 'moderator', 'analyst')
  stats(): Promise<Record<string, unknown>> {
    return this.console.stats();
  }

  @Get('queue')
  @AdminRoles('owner', 'moderator')
  queue(@Query() query: unknown): Promise<{ items: QueueItem[]; lanes: LaneSummary[]; generatedAt: string }> {
    const q = parse(queueQuerySchema, query);
    return this.console.queue({ lane: q.lane, limit: q.limit });
  }

  @Get('reports/:reportId')
  @AdminRoles('owner', 'moderator')
  item(@CurrentStaff() staff: StaffUser, @Param('reportId') reportId: string): Promise<ItemView> {
    return this.console.item(staff, uuidParam(reportId));
  }

  @Post('reports/:reportId/actions')
  @HttpCode(200)
  @AdminRoles('owner', 'moderator')
  act(@CurrentStaff() staff: StaffUser, @Param('reportId') reportId: string, @Body() body: unknown): Promise<unknown> {
    return this.console.act(staff, uuidParam(reportId), body);
  }

  @Get('sanctions')
  @AdminRoles('owner', 'moderator')
  async sanctions(@Query() query: unknown): Promise<{ sanctions: SanctionView[] }> {
    const q = parse(sanctionsQuerySchema, query);
    return { sanctions: await this.console.sanctions({ active: q.active === undefined ? undefined : q.active === 'true', subject: q.subject }) };
  }

  @Post('sanctions/:sanctionId/lift')
  @HttpCode(204)
  @AdminRoles('owner', 'moderator')
  async lift(@CurrentStaff() staff: StaffUser, @Param('sanctionId') sanctionId: string, @Body() body: unknown): Promise<void> {
    await this.console.lift(staff, uuidParam(sanctionId), body);
  }

  @Get('mandatory-reports')
  @AdminRoles('owner')
  async mandatory(): Promise<{ items: Awaited<ReturnType<ModerationConsoleService['mandatoryReports']>> }> {
    return { items: await this.console.mandatoryReports() };
  }

  @Post('mandatory-reports/:holdId/checklist')
  @HttpCode(204)
  @AdminRoles('owner')
  async checklist(@CurrentStaff() staff: StaffUser, @Param('holdId') holdId: string, @Body() body: unknown): Promise<void> {
    await this.console.setChecklistItem(staff, uuidParam(holdId), body);
  }

  @Post('mandatory-reports/:holdId/record')
  @HttpCode(204)
  @AdminRoles('owner')
  async record(@CurrentStaff() staff: StaffUser, @Param('holdId') holdId: string, @Body() body: unknown): Promise<void> {
    await this.console.recordMandatoryReport(staff, uuidParam(holdId), body);
  }

  /** Break-glass evidence export (Owner, audited): a JSON download. */
  @Post('evidence/:holdId/export')
  @HttpCode(200)
  @AdminRoles('owner')
  async export(
    @CurrentStaff() staff: StaffUser,
    @Param('holdId') holdId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<unknown> {
    const out = await this.console.exportEvidence(staff, uuidParam(holdId), body);
    res.setHeader('Content-Disposition', `attachment; filename="${out.filename}"`);
    return out.bundle;
  }

  /**
   * Device bans (Owner only in the PRD) need Apple DeviceCheck / Play Integrity, which v0 does not have yet. The route
   * exists so the role boundary is real (REQ-ADM-02: a Moderator gets 403 and the attempt is audited); the Owner
   * gets 501 until device attestation lands.
   */
  @Post('devices/:deviceId/ban')
  @AdminRoles('owner')
  async banDevice(@CurrentStaff() staff: StaffUser, @Param('deviceId') deviceId: string): Promise<never> {
    await auditConsole(this.adminDb, staff.actor, { action: 'device_ban_unavailable', detail: { hasDeviceId: deviceId.length > 0 } });
    throw AdminErrors.notImplemented('Device bans need DeviceCheck / Play Integrity, which are not built yet.');
  }
}
