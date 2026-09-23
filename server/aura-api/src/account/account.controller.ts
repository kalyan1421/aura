import { Body, Controller, Delete, Get, Header, HttpCode, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { AllowPendingDeletion } from '../auth/pending-deletion.guard';
import type { AccountStatus } from './account.schema';
import { AccountService } from './account.service';

/** F8 REQ-ACC-11 (contracts/api/v1.md "Account deletion"). Usable during the grace period. */
@AllowPendingDeletion()
@Controller('v1/account')
export class AccountController {
  constructor(private readonly account: AccountService) {}

  @Get()
  @Header('Cache-Control', 'no-store')
  status(@CurrentUser() user: AuthUser): Promise<AccountStatus> {
    return this.account.status(user.id);
  }

  /** Schedule the purge 7 days out (idempotent) → 202. */
  @Post('deletion')
  @HttpCode(202)
  requestDeletion(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<{ deletionScheduledFor: string }> {
    return this.account.requestDeletion(user.id, body);
  }

  /** "Keep my account" → 200, idempotent. */
  @Delete('deletion')
  @HttpCode(200)
  cancelDeletion(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<{ deletionScheduledFor: null }> {
    return this.account.cancelDeletion(user.id, body);
  }
}
