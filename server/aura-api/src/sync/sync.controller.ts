import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { SyncService, type PushResponse } from './sync.service';

@Controller('v1/sync')
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  /** The only write path for personal data (contracts/api/v1.md). */
  @Post('push')
  @HttpCode(200)
  push(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<PushResponse> {
    return this.sync.push(user.id, body);
  }
}
