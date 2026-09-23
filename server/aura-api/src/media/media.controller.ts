import { Body, Controller, Header, HttpCode, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import type { DownloadUrlResponse, UploadUrlResponse } from './media.schema';
import { MediaService } from './media.service';

/**
 * F1 voice notes (contracts/api/v1.md "Media: voice notes"). Behind the global AuthGuard and
 * PendingDeletionGuard like every other /v1 route (403 account_deletion_pending during the grace period).
 */
@Controller('v1/media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post('upload-url')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  uploadUrl(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<UploadUrlResponse> {
    return this.media.uploadUrl(user.id, body);
  }

  @Post('download-url')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  downloadUrl(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<DownloadUrlResponse> {
    return this.media.downloadUrl(user.id, body);
  }
}
