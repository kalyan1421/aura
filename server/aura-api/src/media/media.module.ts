import { Module } from '@nestjs/common';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';

/**
 * `POST /v1/media/upload-url` and `/download-url` — signed URLs for the private-media bucket. The Storage
 * client (PrivateMediaStore, service role key) comes from the global QueuesModule.
 */
@Module({ controllers: [MediaController], providers: [MediaService] })
export class MediaModule {}
