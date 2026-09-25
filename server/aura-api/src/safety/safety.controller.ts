import { Body, Controller, Delete, Get, Header, HttpCode, Param, Post, Put, Res, UseFilters } from '@nestjs/common';
import type { Response } from 'express';
import { AllowAccountClosed } from '../auth/account-closed.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { BlocksService, type BlockView } from './blocks.service';
import { GuidelinesRequiredFilter, GuidelinesService, type GuidelinesStatus } from './guidelines';
import { ReportsService, type MyReport } from './reports.service';
import { SafetyService, type SafetyStanding } from './safety.service';

/**
 * F9 core safety for app users — contracts/api/v1-rooms.md §2. Reporting and blocking keep working for suspended
 * accounts ("help is never locked"); a closed account gets `403 account_closed`. Responses are `no-store` and never
 * reveal lanes, ages, reason codes or anything about the other person.
 */
@Controller('v1/safety')
export class SafetyController {
  constructor(
    private readonly reports: ReportsService,
    private readonly blocks: BlocksService,
    private readonly safety: SafetyService,
    private readonly guidelines: GuidelinesService,
  ) {}

  /** REQ-SAFE-04: records that the caller accepted community guidelines `version` (§2.4). */
  @Post('guidelines/accept')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @UseFilters(GuidelinesRequiredFilter)
  acceptGuidelines(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<GuidelinesStatus> {
    return this.guidelines.accept(user.id, body);
  }

  /** `201` new report, `200` when the same open report already existed. */
  @Post('reports')
  @Header('Cache-Control', 'no-store')
  async report(
    @CurrentUser() user: AuthUser,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ reportId: string; showHelplines: boolean }> {
    const r = await this.reports.create(user.id, body);
    res.status(r.created ? 201 : 200);
    return { reportId: r.reportId, showHelplines: r.showHelplines };
  }

  @Get('reports')
  @AllowAccountClosed() // a closed account can still read its standing, reports and blocks (v1-rooms.md §0)
  @Header('Cache-Control', 'no-store')
  myReports(@CurrentUser() user: AuthUser): Promise<{ reports: MyReport[] }> {
    return this.reports.listMine(user.id);
  }

  /** `201` new block, `200` when you already block that person. */
  @Post('blocks')
  @Header('Cache-Control', 'no-store')
  async block(@CurrentUser() user: AuthUser, @Body() body: unknown, @Res({ passthrough: true }) res: Response): Promise<{ blockId: string }> {
    const r = await this.blocks.create(user.id, body);
    res.status(r.created ? 201 : 200);
    return { blockId: r.blockId };
  }

  @Get('blocks')
  @AllowAccountClosed() // a closed account can still read its standing, reports and blocks (v1-rooms.md §0)
  @Header('Cache-Control', 'no-store')
  myBlocks(@CurrentUser() user: AuthUser): Promise<{ blocks: BlockView[] }> {
    return this.blocks.list(user.id);
  }

  @Delete('blocks/:blockId')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async unblock(@CurrentUser() user: AuthUser, @Param('blockId') blockId: string): Promise<void> {
    await this.blocks.remove(user.id, blockId);
  }

  @Get('me')
  @AllowAccountClosed() // a closed account can still read its standing, reports and blocks (v1-rooms.md §0)
  @Header('Cache-Control', 'no-store')
  me(@CurrentUser() user: AuthUser): Promise<SafetyStanding> {
    return this.safety.me(user.id);
  }

  /** REQ-SAFE-16: the moderation-corpus opt-out (v1-reflections.md §7). A privacy choice: never locked. */
  @Get('corpus-consent')
  @AllowAccountClosed()
  @Header('Cache-Control', 'no-store')
  corpusConsent(@CurrentUser() user: AuthUser): Promise<{ enabled: boolean }> {
    return this.safety.corpusConsent(user.id);
  }

  @Put('corpus-consent')
  @AllowAccountClosed()
  @Header('Cache-Control', 'no-store')
  setCorpusConsent(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<{ enabled: boolean }> {
    return this.safety.setCorpusConsent(user.id, body);
  }
}
