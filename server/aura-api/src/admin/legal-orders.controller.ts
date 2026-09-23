import { timingSafeEqual } from 'node:crypto';
import { Body, Controller, Get, HttpCode, Param, Post, Req, UseGuards, UseInterceptors } from '@nestjs/common';
import type { Request } from 'express';
import { Public } from '../auth/public.decorator';
import { ApiError } from '../common/api-error';
import { AdminConfig } from './admin-config';
import { AdminErrors } from './admin-errors';
import { AdminGuard, AdminRoles, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor, clientAddress, uuidParam } from './admin-http';
import type { StaffUser } from './admin-types';
import { LegalOrdersService, type LegalOrderDetail, type LegalOrderView } from './legal-orders.service';
import { RateLimiter } from './rate-limit';

/** Court / government orders in the console (Owner only; PRD 19). */
@Controller('admin/legal-orders')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
@AdminRoles('owner')
export class LegalOrdersAdminController {
  constructor(private readonly orders: LegalOrdersService) {}

  @Get()
  async list(): Promise<{ legalOrders: LegalOrderView[] }> {
    return { legalOrders: await this.orders.list() };
  }

  /** Record an order (or a drill with `isTest: true`); it pages the Owner at once. */
  @Post()
  @HttpCode(201)
  create(@CurrentStaff() staff: StaffUser, @Body() body: unknown): Promise<LegalOrderDetail> {
    return this.orders.create(body, { staff });
  }

  @Get(':id')
  get(@Param('id') id: string): Promise<LegalOrderDetail> {
    return this.orders.get(uuidParam(id));
  }

  @Post(':id/acknowledge')
  @HttpCode(200)
  acknowledge(@CurrentStaff() staff: StaffUser, @Param('id') id: string): Promise<LegalOrderDetail> {
    return this.orders.acknowledge(staff, uuidParam(id));
  }

  @Post(':id/close')
  @HttpCode(200)
  close(@CurrentStaff() staff: StaffUser, @Param('id') id: string, @Body() body: unknown): Promise<LegalOrderDetail> {
    return this.orders.close(staff, uuidParam(id), body);
  }
}

/**
 * Machine intake for orders that arrive by email (REQ-SAFE-10: "test government-order email pages AK"): a relay that
 * receives the Grievance Officer's mail (e.g. an email-to-webhook service) posts here with
 * `Authorization: Bearer <LEGAL_INTAKE_TOKEN>`. Off (404) unless the token is configured. The order pages at once.
 */
@Controller('v1/intake/legal-orders')
@Public()
@UseInterceptors(NoStoreInterceptor)
export class LegalOrdersIntakeController {
  constructor(
    private readonly orders: LegalOrdersService,
    private readonly config: AdminConfig,
    private readonly limiter: RateLimiter,
  ) {}

  @Post()
  @HttpCode(201)
  async intake(@Body() body: unknown, @Req() req: Request): Promise<{ legalOrderId: string; ticket: string; dueAt: string }> {
    const expected = this.config.legalIntakeToken;
    if (!expected) throw AdminErrors.notFound();
    if (!(await this.limiter.hit(`legal-intake:${this.limiter.bucket(clientAddress(req) ?? 'unknown')}`, 60, 3600))) throw AdminErrors.rateLimited();
    const m = /^Bearer\s+(\S+)\s*$/i.exec(req.headers.authorization ?? '');
    const given = Buffer.from(m?.[1] ?? '', 'utf8');
    const want = Buffer.from(expected, 'utf8');
    if (given.length !== want.length || !timingSafeEqual(given, want)) throw ApiError.unauthorized('A valid intake token is required.');
    const o = await this.orders.create(body, { intake: true });
    return { legalOrderId: o.legalOrderId, ticket: o.ticket, dueAt: o.dueAt };
  }
}
