import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { parseOrThrow } from '../common/zod';
import type { Snapshot } from '../progression/snapshot';
import { profileRequestSchema, type ProfileDto } from './profile.schema';
import { ProfileService } from './profile.service';

@Controller('v1')
export class ProfileController {
  constructor(private readonly profiles: ProfileService) {}

  @Post('profile')
  @HttpCode(200)
  upsert(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<{ profile: ProfileDto; snapshot: Snapshot }> {
    return this.profiles.upsert(user.id, parseOrThrow(profileRequestSchema, body));
  }

  @Get('me/snapshot')
  snapshot(@CurrentUser() user: AuthUser): Promise<Snapshot> {
    return this.profiles.snapshot(user.id);
  }
}
