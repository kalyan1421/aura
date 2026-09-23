import { Body, Controller, Get, HttpCode, Param, Post, Query, UseGuards, UseInterceptors } from '@nestjs/common';
import { z } from 'zod';
import { AdminGuard, AdminRoles, CurrentStaff } from '../admin/admin.guard';
import { NoStoreInterceptor } from '../admin/admin-http';
import type { StaffUser } from '../admin/admin-types';
import { parseOrThrow } from '../common/zod';
import type { AccountBanResult, BanView, DeviceView } from './device-bans';
import { DeviceBansService } from './device-bans.service';

const reasonCode = z.string().regex(/^[a-z0-9_]{1,40}$/, 'must be a reason code ([a-z0-9_], at most 40)');
const uuid = z.uuid();

const devicesQuery = z.object({ reportId: uuid });
const banAccountBody = z.object({ reportId: uuid, reasonCode });
const banDeviceBody = z.object({ reasonCode, reportId: uuid.optional() });
const liftBody = z.object({ reasonCode });
const bansQuery = z.object({ status: z.enum(['active', 'lifted', 'all']).optional() });

/**
 * Device bans in the admin console — Owner only (PRD 19 Roles: "Owner … device bans"; REQ-ADM-02: a Moderator calling
 * `POST /admin/devices/{id}/ban` gets 403 and the attempt is audited by AdminGuard). Accounts are reached through a
 * report (the console never sees account ids); devices are their install hashes. Every ban and lift is written to the
 * hash-chained audit log in the same transaction. contracts/api/v1.md "Device bans".
 */
@Controller('admin/devices')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class DevicesAdminController {
  constructor(private readonly bans: DeviceBansService) {}

  /** `GET /admin/devices?reportId=` — the devices of the account a report is about. */
  @Get()
  devices(@Query() query: unknown): Promise<{ reportId: string; subjectHash: string; devices: DeviceView[] }> {
    return this.bans.devicesForReport(parseOrThrow(devicesQuery, query).reportId.toLowerCase());
  }

  /** `POST /admin/devices/ban-account` — ban every device of the account a report is about. */
  @Post('ban-account')
  @HttpCode(200)
  banAccount(@CurrentStaff() staff: StaffUser, @Body() body: unknown): Promise<AccountBanResult> {
    const b = parseOrThrow(banAccountBody, body);
    return this.bans.banForReport(b.reportId.toLowerCase(), b.reasonCode, staff.actor);
  }

  /** `GET /admin/devices/bans?status=active|lifted|all` (default active). */
  @Get('bans')
  async list(@Query() query: unknown): Promise<{ bans: BanView[] }> {
    return { bans: await this.bans.listBans(parseOrThrow(bansQuery, query).status ?? 'active') };
  }

  /** `POST /admin/devices/bans/:banId/lift` — reverse a ban (appeal upheld). */
  @Post('bans/:banId/lift')
  @HttpCode(200)
  lift(@CurrentStaff() staff: StaffUser, @Param('banId') banId: string, @Body() body: unknown): Promise<{ banId: string; liftedAt: string }> {
    return this.bans.liftBan(banId, parseOrThrow(liftBody, body).reasonCode, staff.actor);
  }

  /** `POST /admin/devices/:deviceId/ban` — ban one device (its install hash, from the list above). */
  @Post(':deviceId/ban')
  @HttpCode(200)
  banDevice(
    @CurrentStaff() staff: StaffUser,
    @Param('deviceId') deviceId: string,
    @Body() body: unknown,
  ): Promise<{ banId: string; deviceId: string; alreadyBanned: boolean }> {
    const b = parseOrThrow(banDeviceBody, body);
    return this.bans.banDevice(deviceId.toLowerCase(), b.reasonCode, staff.actor, b.reportId?.toLowerCase());
  }
}
