import { Body, Controller, Delete, Get, Header, HttpCode, Param, Post, Res } from '@nestjs/common';
import type { Response } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import type { ComposerView, ReflectionView, SendOutcome } from './reflection-views';
import { ReflectionsService } from './reflections.service';

/**
 * F6 Reflections — contracts/api/v1-reflections.md §1. Supabase JWT (global guard), the rooms sanctions
 * (`403 rooms_suspended` / `account_closed`), `Cache-Control: no-store`. Gestures on a reflection go through
 * `POST /v1/rooms/:roomId/gestures` (target `reflection`), reports through `POST /v1/safety/reports`
 * (target kind `reflection`). There is no edit route (REQ-REF-05).
 */
@Controller('v1/rooms/:roomId/reflections')
export class ReflectionsController {
  constructor(private readonly reflections: ReflectionsService) {}

  @Get()
  @Header('Cache-Control', 'no-store')
  list(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string): Promise<{ reflections: ReflectionView[]; composer: ComposerView }> {
    return this.reflections.list(user.id, roomId);
  }

  @Get(':reflectionId')
  @Header('Cache-Control', 'no-store')
  one(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string, @Param('reflectionId') reflectionId: string): Promise<ReflectionView> {
    return this.reflections.one(user.id, roomId, reflectionId);
  }

  /** `201` when a reflection was stored, `200` for a replay or a rejection by the text rules (nothing stored). */
  @Post()
  @Header('Cache-Control', 'no-store')
  async send(
    @CurrentUser() user: AuthUser,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<SendOutcome> {
    const out = await this.reflections.send(user.id, roomId, body);
    res.status(out.created ? 201 : 200);
    return out.outcome;
  }

  @Delete(':reflectionId')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async remove(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string, @Param('reflectionId') reflectionId: string): Promise<void> {
    await this.reflections.remove(user.id, roomId, reflectionId);
  }
}
