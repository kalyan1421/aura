import { Controller, Get, HttpCode, Param, Post, Query, UseGuards, UseInterceptors } from '@nestjs/common';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor, uuidParam } from './admin-http';
import type { StaffUser } from './admin-types';
import { PagingConsoleService, type PageView } from './paging-console.service';

/** On-call pages: status, delivery log, acknowledge, manual drill (Owner — the on-call person). */
@Controller('admin')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class PagingController {
  constructor(private readonly pages: PagingConsoleService) {}

  @Get('paging/status')
  status(): Promise<Record<string, unknown>> {
    return this.pages.status();
  }

  @Get('pages')
  async list(@Query() query: unknown): Promise<{ pages: PageView[] }> {
    return { pages: await this.pages.list(query) };
  }

  @Post('pages/test')
  @HttpCode(201)
  test(@CurrentStaff() staff: StaffUser): Promise<PageView> {
    return this.pages.test(staff);
  }

  @Get('pages/:id')
  get(@Param('id') id: string): Promise<unknown> {
    return this.pages.get(uuidParam(id));
  }

  @Post('pages/:id/ack')
  @HttpCode(200)
  ack(@CurrentStaff() staff: StaffUser, @Param('id') id: string): Promise<PageView> {
    return this.pages.acknowledge(staff, uuidParam(id));
  }
}
