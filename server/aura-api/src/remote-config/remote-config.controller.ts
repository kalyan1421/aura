import { Body, Controller, Get, HttpCode, Param, ParseIntPipe, Post, Req, Res, UseFilters, UseGuards, UseInterceptors } from '@nestjs/common';
import type { Request, Response } from 'express';
import { AdminGuard, AdminRoles, CurrentStaff } from '../admin/admin.guard';
import { NoStoreInterceptor } from '../admin/admin-http';
import type { StaffUser } from '../admin/admin-types';
import { ApiError } from '../common/api-error';
import { Public } from '../auth/public.decorator';
import { HelplinesService, type HelplinesOverview } from './helplines.service';
import { LexiconErrorFilter, LexiconService, type LexiconOverview } from './lexicon.service';
import { RemoteConfigService, etagMatches } from './remote-config.service';

/**
 * App-facing, public (no sign-in needed; nothing about the caller goes in or out): `GET /v1/config` (flags, kill
 * switches, signed-bundle pointers), `GET /v1/lexicon/crisis` (the live signed crisis lexicon) and `GET /v1/helplines`
 * (the live signed helpline directory). All answer `If-None-Match` with `304`. contracts/api/v1.md "Remote config" /
 * "Crisis lexicon versions" / "Helpline directory versions".
 */
@Controller('v1')
export class RemoteConfigController {
  constructor(
    private readonly config: RemoteConfigService,
    private readonly lexicon: LexiconService,
    private readonly helplines: HelplinesService,
  ) {}

  @Public()
  @Get('config')
  async getConfig(@Req() req: Request, @Res() res: Response): Promise<void> {
    const doc = await this.config.current();
    const etag = `"${doc.configVersion}"`;
    res.setHeader('ETag', etag);
    res.setHeader('Cache-Control', 'no-cache');
    if (etagMatches(req.headers['if-none-match'], etag)) {
      res.status(304).end();
      return;
    }
    res.status(200).json(doc);
  }

  @Public()
  @Get('lexicon/crisis')
  async getLexicon(@Req() req: Request, @Res() res: Response): Promise<void> {
    const live = await this.lexicon.live();
    res.setHeader('Cache-Control', 'no-cache');
    if (!live) throw new ApiError(404, 'not_published', 'No crisis lexicon has been published; use the bundled one.');
    const etag = `"lx-${live.seq}"`;
    res.setHeader('ETag', etag);
    if (etagMatches(req.headers['if-none-match'], etag)) {
      res.status(304).end();
      return;
    }
    res.status(200).json(LexiconService.wire(live));
  }

  /** The live signed helpline directory (PRD 18 "Helplines by country"); 404 → the app keeps its bundled numbers. */
  @Public()
  @Get('helplines')
  async getHelplines(@Req() req: Request, @Res() res: Response): Promise<void> {
    const live = await this.helplines.live();
    res.setHeader('Cache-Control', 'no-cache');
    if (!live) throw new ApiError(404, 'not_published', 'No helpline directory has been published; use the bundled one.');
    const etag = `"hl-${live.seq}"`;
    res.setHeader('ETag', etag);
    if (etagMatches(req.headers['if-none-match'], etag)) {
      res.status(304).end();
      return;
    }
    res.status(200).json(HelplinesService.wire(live));
  }
}

/**
 * Crisis lexicon versions in the admin console (PRD 19 "lexicons … add, test on samples, publish signed, roll back").
 * Changing what phones use (upload, publish, rollback) is Owner only; a Moderator may read and test samples.
 * Refusals carry `details` (problems, failing vector indexes, counts). contracts/api/v1.md "Crisis lexicon versions".
 */
@Controller('admin/lexicons/crisis')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@UseFilters(LexiconErrorFilter)
export class LexiconAdminController {
  constructor(private readonly lexicon: LexiconService) {}

  @Get()
  @AdminRoles('owner', 'moderator')
  overview(): Promise<LexiconOverview> {
    return this.lexicon.overview();
  }

  @Get('versions/:version')
  @AdminRoles('owner', 'moderator')
  version(@Param('version', ParseIntPipe) version: number): ReturnType<LexiconService['version']> {
    return this.lexicon.version(version);
  }

  @Post('versions')
  @AdminRoles('owner')
  upload(@CurrentStaff() staff: StaffUser, @Body() body: unknown): ReturnType<LexiconService['upload']> {
    return this.lexicon.upload(staff.actor, body);
  }

  @Post('versions/baseline')
  @AdminRoles('owner')
  uploadBaseline(@CurrentStaff() staff: StaffUser): ReturnType<LexiconService['uploadBaseline']> {
    return this.lexicon.uploadBaseline(staff.actor);
  }

  @Post('test')
  @HttpCode(200)
  @AdminRoles('owner', 'moderator')
  test(@Body() body: unknown): ReturnType<LexiconService['test']> {
    return this.lexicon.test(body);
  }

  /** Publish a stored version — forward, or back to an older one (a rollback). */
  @Post('publish')
  @HttpCode(200)
  @AdminRoles('owner')
  publish(@CurrentStaff() staff: StaffUser, @Body() body: unknown): ReturnType<LexiconService['publish']> {
    return this.lexicon.publish(staff.actor, body);
  }
}

/**
 * The crisis helpline directory in the admin console (PRD 18 "Helplines by country"; PRD 19 config "publish signed,
 * roll back"). Changing what phones dial (upload, publish, rollback) is Owner only; a Moderator may read.
 * contracts/api/v1.md "Helpline directory versions".
 */
@Controller('admin/helplines')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@UseFilters(LexiconErrorFilter)
export class HelplinesAdminController {
  constructor(private readonly helplines: HelplinesService) {}

  @Get()
  @AdminRoles('owner', 'moderator')
  overview(): Promise<HelplinesOverview> {
    return this.helplines.overview();
  }

  @Get('versions/:version')
  @AdminRoles('owner', 'moderator')
  version(@Param('version', ParseIntPipe) version: number): ReturnType<HelplinesService['version']> {
    return this.helplines.version(version);
  }

  @Post('versions')
  @AdminRoles('owner')
  upload(@CurrentStaff() staff: StaffUser, @Body() body: unknown): ReturnType<HelplinesService['upload']> {
    return this.helplines.upload(staff.actor, body);
  }

  @Post('versions/baseline')
  @AdminRoles('owner')
  uploadBaseline(@CurrentStaff() staff: StaffUser): ReturnType<HelplinesService['uploadBaseline']> {
    return this.helplines.uploadBaseline(staff.actor);
  }

  /** Publish a stored version — forward, or back to an older one (a rollback). */
  @Post('publish')
  @HttpCode(200)
  @AdminRoles('owner')
  publish(@CurrentStaff() staff: StaffUser, @Body() body: unknown): ReturnType<HelplinesService['publish']> {
    return this.helplines.publish(staff.actor, body);
  }
}
