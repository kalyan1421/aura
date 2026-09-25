import { Controller, Delete, Get, Header, HttpCode, Param, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { WindDownService, type WindDownResponse } from './wind-down.service';

/**
 * F16 Lantern Hour wind-down in a room — contracts/api/v1-quiet.md §2. Every route: Supabase JWT (global guard), `403
 * account_deletion_pending` (global guard), `403 rooms_suspended` / `account_closed` for sanctioned accounts,
 * `Cache-Control: no-store`. The kill switch `lantern_wind_down_enabled` is per region, so the service decides it.
 */
@Controller('v1/rooms/:roomId/wind-down')
export class WindDownController {
  constructor(private readonly windDown: WindDownService) {}

  /** §2.1 */
  @Get()
  @Header('Cache-Control', 'no-store')
  get(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<WindDownResponse> {
    return this.windDown.get(user.id, roomId);
  }

  /** §2.2 — opt in. */
  @Post()
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  join(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<WindDownResponse> {
    return this.windDown.join(user.id, roomId);
  }

  /** §2.3 — opt out; costs nothing. */
  @Delete()
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async leave(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<void> {
    await this.windDown.leave(user.id, roomId);
  }
}
