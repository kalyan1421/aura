import { Body, Controller, Delete, HttpCode, Put } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { DevicesService } from './devices.service';

@Controller('v1/devices')
export class DevicesController {
  constructor(private readonly devices: DevicesService) {}

  /** Register (or re-register) this install's FCM token for the caller → 204. */
  @Put()
  @HttpCode(204)
  register(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<void> {
    return this.devices.register(user.id, body);
  }

  /** Unregister (sign-out) → 204, idempotent, scoped to the caller's own token. */
  @Delete()
  @HttpCode(204)
  unregister(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<void> {
    return this.devices.unregister(user.id, body);
  }
}
