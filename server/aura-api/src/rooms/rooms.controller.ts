import { Body, Controller, Delete, Get, Header, HttpCode, Param, Post, UseFilters } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { KillSwitch, ROOMS_KILL_SWITCH, type KillSwitchSpec } from '../remote-config/kill-switch';
import { GuidelinesRequiredFilter } from '../safety/guidelines';
import { GesturesService, type GestureAccepted } from './gestures.service';
import { LanternsService, type HoldResponse } from './lanterns.service';
import type { Counts, RoomDetail, RoomInfo, RoomSummary } from './room-views';
import { RoomsService, type MatchResponse } from './rooms.service';

/** Tonight's intention off → the hold route refuses (the service re-checks the flag in its transaction too). */
const INTENTION_KILL_SWITCH: KillSwitchSpec = {
  flag: 'room_intention_enabled',
  code: 'intention_paused',
  message: "Tonight's intention is resting for a bit.",
};

/**
 * F5 Mood Rooms — contracts/api/v1-rooms.md §1. Every route: Supabase JWT (global guard), `403
 * account_deletion_pending` during a deletion grace period (global guard), `403 rooms_suspended` /
 * `account_closed` for sanctioned accounts, `Cache-Control: no-store`.
 */
@Controller('v1/rooms')
export class RoomsController {
  constructor(
    private readonly rooms: RoomsService,
    private readonly gestures: GesturesService,
    private readonly lanterns: LanternsService,
  ) {}

  /** `409 guidelines_required` carries the guidelines `version` to accept (REQ-SAFE-04, §1.1). */
  @Post('match')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @UseFilters(GuidelinesRequiredFilter)
  @KillSwitch(ROOMS_KILL_SWITCH) // flag `rooms_enabled` off → 503 rooms_paused (src/remote-config/kill-switch.ts)
  match(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<MatchResponse> {
    return this.rooms.match(user.id, body);
  }

  @Get()
  @Header('Cache-Control', 'no-store')
  list(@CurrentUser() user: AuthUser): Promise<{ rooms: RoomSummary[] }> {
    return this.rooms.list(user.id);
  }

  @Get(':roomId')
  @Header('Cache-Control', 'no-store')
  detail(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<RoomDetail> {
    return this.rooms.detail(user.id, roomId);
  }

  @Post(':roomId/heartbeat')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  heartbeat(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<{ room: RoomInfo; counts: Counts }> {
    return this.rooms.heartbeat(user.id, roomId);
  }

  @Post(':roomId/gestures')
  @HttpCode(202)
  @Header('Cache-Control', 'no-store')
  gesture(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string, @Body() body: unknown): Promise<GestureAccepted> {
    return this.gestures.send(user.id, roomId, body);
  }

  /** Tonight's intention (Milestone B, §1.9): one tap, idempotent; only the room total is ever shown. */
  @Post(':roomId/intention/hold')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @KillSwitch(INTENTION_KILL_SWITCH) // flag `room_intention_enabled` off → 503 intention_paused
  holdIntention(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<HoldResponse> {
    return this.lanterns.hold(user.id, roomId);
  }

  @Post(':roomId/leave')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  leave(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<{ surveyEligible: boolean }> {
    return this.rooms.leave(user.id, roomId);
  }

  @Post(':roomId/survey')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async survey(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string, @Body() body: unknown): Promise<void> {
    await this.rooms.survey(user.id, roomId, body);
  }

  @Post(':roomId/mutes')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async mute(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string, @Body() body: unknown): Promise<void> {
    await this.rooms.mute(user.id, roomId, body);
  }

  @Delete(':roomId/mutes/:memberId')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async unmute(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string, @Param('memberId') memberId: string): Promise<void> {
    await this.rooms.unmute(user.id, roomId, memberId);
  }
}
