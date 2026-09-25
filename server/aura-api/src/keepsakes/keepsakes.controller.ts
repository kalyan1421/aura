import { Controller, Get, Header } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import type { OwnKeepsake } from './award';
import { KeepsakesService } from './keepsakes.service';

/**
 * F13 keepsakes (contracts/api/v1-keepsakes.md). One route, and it only ever answers about the caller: no path or
 * query parameter selects a person, so no endpoint can return someone else's keepsakes (DS-10, CI-8).
 */
@Controller('v1/keepsakes')
export class KeepsakesController {
  constructor(private readonly keepsakes: KeepsakesService) {}

  /** `200 { keepsakes: [{ key, earnedOn }] }` — the caller's own, after awarding anything newly reached. */
  @Get()
  @Header('Cache-Control', 'no-store')
  mine(@CurrentUser() user: AuthUser): Promise<{ keepsakes: OwnKeepsake[] }> {
    return this.keepsakes.mine(user.id);
  }
}
