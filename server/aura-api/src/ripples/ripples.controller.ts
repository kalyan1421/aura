import { Body, Controller, Delete, Get, Header, HttpCode, Param, Post, Put, Res, UseFilters } from '@nestjs/common';
import type { Response } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { KillSwitch, type KillSwitchSpec } from '../remote-config/kill-switch';
import { GuidelinesRequiredFilter } from '../safety/guidelines';
import { RippleSafetyService } from './ripple-safety.service';
import { RIPPLES_FLAG } from './ripple-types';
import type { InviteView, SessionView } from './ripple-views';
import { RipplesService, type MatchResponse } from './ripples.service';

/** Breath Ripples kill switch: off → no new sessions; sessions already playing finish (contracts §0). */
export const RIPPLES_KILL_SWITCH: KillSwitchSpec = {
  flag: RIPPLES_FLAG,
  code: 'ripples_paused',
  message: 'Breath Ripples is resting for a bit. You can still breathe on your own in the Sanctuary.',
};

/**
 * F7 Breath Ripples — contracts/api/v1-ripples.md. Every route: Supabase JWT (global guard), `403
 * account_deletion_pending` (global guard), `Cache-Control: no-store`. Seat numbers and pseudonyms only (DS-10).
 */
@Controller('v1/ripples')
export class RipplesController {
  constructor(
    private readonly ripples: RipplesService,
    private readonly safety: RippleSafetyService,
  ) {}

  /** §1.1 — enqueue (first call) or poll (same ticket id). */
  @Post('match')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @UseFilters(GuidelinesRequiredFilter)
  @KillSwitch(RIPPLES_KILL_SWITCH)
  match(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<MatchResponse> {
    return this.ripples.match(user.id, body);
  }

  /** §1.2 — leave the lobby. */
  @Delete('match/:ticketId')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async cancel(@CurrentUser() user: AuthUser, @Param('ticketId') ticketId: string): Promise<void> {
    await this.ripples.cancel(user.id, ticketId);
  }

  /** §1.3 — the room's "Breathe together" banner. */
  @Get('rooms/:roomId/invite')
  @Header('Cache-Control', 'no-store')
  invite(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<{ invite: InviteView | null }> {
    return this.ripples.roomInvite(user.id, roomId);
  }

  /** §2.7 */
  @Get('echo-consent')
  @Header('Cache-Control', 'no-store')
  echoConsent(@CurrentUser() user: AuthUser): Promise<{ enabled: boolean }> {
    return this.ripples.getEchoConsent(user.id);
  }

  @Put('echo-consent')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  setEchoConsent(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<{ enabled: boolean }> {
    return this.ripples.setEchoConsent(user.id, body);
  }

  /** §2.1 */
  @Get('sessions/:sessionId')
  @Header('Cache-Control', 'no-store')
  session(@CurrentUser() user: AuthUser, @Param('sessionId') sessionId: string): Promise<SessionView> {
    return this.ripples.session(user.id, sessionId);
  }

  /** §2.2 */
  @Post('sessions/:sessionId/leave')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async leave(@CurrentUser() user: AuthUser, @Param('sessionId') sessionId: string): Promise<void> {
    await this.ripples.leave(user.id, sessionId);
  }

  /** §2.3 */
  @Post('sessions/:sessionId/complete')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async complete(@CurrentUser() user: AuthUser, @Param('sessionId') sessionId: string, @Body() body: unknown): Promise<void> {
    await this.ripples.complete(user.id, sessionId, body);
  }

  /** §2.4 — `201` new, `200` when the same open report already existed. */
  @Post('sessions/:sessionId/reports')
  @Header('Cache-Control', 'no-store')
  async report(
    @CurrentUser() user: AuthUser,
    @Param('sessionId') sessionId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ reportId: string; showHelplines: boolean }> {
    const r = await this.safety.report(user.id, sessionId, body);
    res.status(r.created ? 201 : 200);
    return { reportId: r.reportId, showHelplines: r.showHelplines };
  }

  /** §2.5 — `201` new block, `200` existing. */
  @Post('sessions/:sessionId/blocks')
  @Header('Cache-Control', 'no-store')
  async block(
    @CurrentUser() user: AuthUser,
    @Param('sessionId') sessionId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ blockId: string }> {
    const r = await this.safety.block(user.id, sessionId, body);
    res.status(r.created ? 201 : 200);
    return { blockId: r.blockId };
  }

  /** §2.6 — a receiver saw a seat go over 10 events/s. */
  @Post('sessions/:sessionId/flood')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async flood(@CurrentUser() user: AuthUser, @Param('sessionId') sessionId: string, @Body() body: unknown): Promise<void> {
    await this.safety.flood(user.id, sessionId, body);
  }
}
