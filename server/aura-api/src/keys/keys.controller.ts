import { Controller, Get, Header } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { KeysService, type DataKeyResponse } from './keys.service';

@Controller('v1/keys')
export class KeysController {
  constructor(private readonly keys: KeysService) {}

  @Get('data-key')
  @Header('Cache-Control', 'no-store')
  dataKey(@CurrentUser() user: AuthUser): Promise<DataKeyResponse> {
    return this.keys.getOrCreate(user.id);
  }
}
