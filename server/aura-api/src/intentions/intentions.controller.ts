import {
  Body,
  Catch,
  Controller,
  Get,
  HttpCode,
  Param,
  Post,
  Req,
  Res,
  UseFilters,
  UseGuards,
  UseInterceptors,
  type ArgumentsHost,
  type ExceptionFilter,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { AdminGuard, AdminRoles, CurrentStaff } from '../admin/admin.guard';
import { NoStoreInterceptor } from '../admin/admin-http';
import type { StaffUser } from '../admin/admin-types';
import { Public } from '../auth/public.decorator';
import { etagMatches } from '../remote-config/remote-config.service';
import { IntentionRejectedError, IntentionsService, type IntentionsOverview } from './intentions.service';

/** Lint refusals leave as `422 { code, message, details: string[] }` (the console lists the lines). */
@Catch(IntentionRejectedError)
export class IntentionRejectedFilter implements ExceptionFilter {
  catch(e: IntentionRejectedError, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    if (res.headersSent) return;
    res.status(e.status).json({ code: e.code, message: e.message, details: e.details });
  }
}

/**
 * The Tonight's intention list in the admin console (PRD 19 "Configuration"). Changing it is Owner only; a Moderator
 * may read (like the helpline directory). contracts/api/v1-rooms.md §1.10.
 */
@Controller('admin/intentions')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@UseFilters(IntentionRejectedFilter)
export class IntentionsAdminController {
  constructor(private readonly intentions: IntentionsService) {}

  /** Every pool's list (enabled and retired, in rotation order), each key's words, the next 14 nights, rooms tonight. */
  @Get()
  @AdminRoles('owner', 'moderator')
  overview(): Promise<IntentionsOverview> {
    return this.intentions.overview();
  }

  /** Add a preset to a pool (a new key comes with its words in all five languages). */
  @Post('presets')
  @AdminRoles('owner')
  create(@CurrentStaff() staff: StaffUser, @Body() body: unknown): ReturnType<IntentionsService['create']> {
    return this.intentions.create(staff.actor, body);
  }

  /** Retire / restore / move one preset of a pool. */
  @Post('presets/:pool/:key')
  @HttpCode(200)
  @AdminRoles('owner')
  update(
    @CurrentStaff() staff: StaffUser,
    @Param('pool') pool: string,
    @Param('key') key: string,
    @Body() body: unknown,
  ): ReturnType<IntentionsService['update']> {
    return this.intentions.update(staff.actor, pool, key, body);
  }

  /** Reword a key (all five languages at once). */
  @Post('words/:key')
  @HttpCode(200)
  @AdminRoles('owner')
  editWords(@CurrentStaff() staff: StaffUser, @Param('key') key: string, @Body() body: unknown): ReturnType<IntentionsService['editWords']> {
    return this.intentions.editWords(staff.actor, key, body);
  }
}

/**
 * `GET /v1/intentions` — public (nothing about the caller goes in or out): every preset key's words in the five app
 * languages, retired keys included, with an ETag (`If-None-Match` → 304). The app shows these words for tonight's
 * intention and falls back to its bundled strings (contracts/api/v1-rooms.md §1.9).
 */
@Controller('v1/intentions')
export class IntentionsPublicController {
  constructor(private readonly intentions: IntentionsService) {}

  @Public()
  @Get()
  async copy(@Req() req: Request, @Res() res: Response): Promise<void> {
    const doc = await this.intentions.appCopy();
    const etag = `"in-${doc.version}"`;
    res.setHeader('ETag', etag);
    res.setHeader('Cache-Control', 'no-cache');
    if (etagMatches(req.headers['if-none-match'], etag)) {
      res.status(304).end();
      return;
    }
    res.status(200).json(doc);
  }
}
