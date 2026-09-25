import { Body, Controller, Header, HttpCode, Param, Post, Res, UseFilters } from '@nestjs/common';
import type { Response } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { GuidelinesRequiredFilter } from '../safety/guidelines';
import { QuietGesturesService, type GestureAccepted } from './quiet-gestures.service';
import { QuietSafetyService } from './quiet-safety.service';
import { QuietService, type SessionResponse } from './quiet.service';

/**
 * F16 Quiet Together — contracts/api/v1-quiet.md. Every route: Supabase JWT (global guard), `403
 * account_deletion_pending` (global guard), `Cache-Control: no-store`. Counts only: no member list in any payload
 * (REQ-QUIET-01). The kill switch `quiet_enabled` is per region, so the service decides it (`503 quiet_paused`).
 */
@Controller('v1/quiet')
export class QuietController {
  constructor(
    private readonly quiet: QuietService,
    private readonly gestures: QuietGesturesService,
    private readonly safety: QuietSafetyService,
  ) {}

  /** §1.1 */
  @Post('join')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @UseFilters(GuidelinesRequiredFilter)
  join(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<SessionResponse> {
    return this.quiet.join(user.id, body);
  }

  /** §1.2 */
  @Post('sessions/:sessionId/heartbeat')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  heartbeat(@CurrentUser() user: AuthUser, @Param('sessionId') sessionId: string): Promise<SessionResponse> {
    return this.quiet.heartbeat(user.id, sessionId);
  }

  /** §1.3 — leaving costs nothing. */
  @Post('sessions/:sessionId/leave')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async leave(@CurrentUser() user: AuthUser, @Param('sessionId') sessionId: string): Promise<void> {
    await this.quiet.leave(user.id, sessionId);
  }

  /** §1.4 */
  @Post('sessions/:sessionId/gestures')
  @HttpCode(202)
  @Header('Cache-Control', 'no-store')
  gesture(@CurrentUser() user: AuthUser, @Param('sessionId') sessionId: string, @Body() body: unknown): Promise<GestureAccepted> {
    return this.gestures.send(user.id, sessionId, body);
  }

  /** §1.5 — `201` new, `200` when the same open report already existed. */
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
}
