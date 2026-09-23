import { Body, Controller, Delete, Get, Header, HttpCode, Post } from '@nestjs/common';
import { AllowAccountClosed } from '../auth/account-closed.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { AllowPendingDeletion } from '../auth/pending-deletion.guard';
import type { AccountStatus } from './account.schema';
import { AccountService } from './account.service';

/**
 * F8 REQ-ACC-11 (contracts/api/v1.md "Account deletion"). Usable during the grace period, and by an account closed
 * for breaking the rules (it can still see its status and delete itself).
 */
@AllowPendingDeletion()
@AllowAccountClosed()
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

  /** Native Sign in with Apple: keep the refresh token so the deletion can revoke it (App Review 5.1.1(v)) → 204. */
  @Post('apple-auth')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async appleAuth(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<void> {
    await this.account.linkApple(user.id, body);
  }
}
