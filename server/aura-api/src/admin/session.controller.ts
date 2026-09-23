import { Controller, Get, HttpCode, Post, UseGuards, UseInterceptors } from '@nestjs/common';
import { auditConsole } from './admin-audit';
import { AdminDb } from './admin-db';
import { AdminGuard, AdminRoles, AllowBeforeMfa, CurrentStaff } from './admin.guard';
import { NoStoreInterceptor } from './admin-http';
import type { FirstFactor, MfaState, StaffRole, StaffUser } from './admin-types';
import { QueueSessionService, type QueueSessionView } from './queue-session';
import { RateLimiter } from './rate-limit';

/**
 * Console session bookkeeping. `GET /admin/session` is the only route an allow-listed staff account may call before
 * finishing TOTP (it says whether to enroll or answer a challenge); sign-in and sign-out are audited (PRD 19 "Audit
 * log … and login").
 */
@Controller('admin/session')
@UseGuards(AdminGuard)
@UseInterceptors(NoStoreInterceptor)
export class SessionController {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly limiter: RateLimiter,
    private readonly queueSessions: QueueSessionService,
  ) {}

  @Get()
  @AdminRoles('owner', 'moderator', 'analyst')
  @AllowBeforeMfa()
  async me(@CurrentStaff() staff: StaffUser): Promise<{
    staff: { id: string; displayName: string; role: StaffRole; email: string | null };
    mfa: MfaState;
    /** REQ-ADM-01: `sso` (Google Workspace) or `dev` (the email sign-in; development only). */
    firstFactor: FirstFactor;
    sessionStartedAt: string;
    sessionExpiresAt: string;
    /** PRD 19 "Queue sessions capped at 2 h" (review work); null for analysts and before TOTP. */
    queueSession: QueueSessionView | null;
  }> {
    const reviews = staff.role !== 'analyst' && staff.mfa === 'verified';
    return {
      staff: { id: staff.id, displayName: staff.displayName, role: staff.role, email: staff.email },
      mfa: staff.mfa,
      firstFactor: staff.firstFactor ?? 'dev',
      sessionStartedAt: staff.sessionStartedAt,
      sessionExpiresAt: staff.sessionExpiresAt,
      queueSession: reviews ? await this.queueSessions.peek(staff) : null,
    };
  }

  /** Called by the console right after TOTP succeeds; one audit row per Supabase session. */
  @Post('started')
  @HttpCode(204)
  @AdminRoles('owner', 'moderator', 'analyst')
  async started(@CurrentStaff() staff: StaffUser): Promise<void> {
    if (!(await this.limiter.once(`admin-login:${this.limiter.bucket(staff.sessionId)}`, 24 * 3600))) return;
    await auditConsole(this.adminDb, staff.actor, {
      action: 'staff_login',
      reasonCode: 'totp',
      detail: { role: staff.role, firstFactor: staff.firstFactor ?? 'dev' },
    });
  }

  @Post('ended')
  @HttpCode(204)
  @AdminRoles('owner', 'moderator', 'analyst')
  async ended(@CurrentStaff() staff: StaffUser): Promise<void> {
    await auditConsole(this.adminDb, staff.actor, { action: 'staff_logout', detail: { role: staff.role } });
  }
}
