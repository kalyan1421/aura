import { Module } from '@nestjs/common';
import { CapsulesModule } from '../capsules/capsules.module';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';

/**
 * `POST /v1/media/upload-url` and `/download-url` — signed URLs for the private-media bucket (F1 voice notes, F4
 * capsule voice/photos). The Storage client (PrivateMediaStore, service role key) comes from the global
 * QueuesModule; the capsule "sealed means sealed" rules (CapsuleMediaGate) from CapsulesModule.
 */
@Module({ imports: [CapsulesModule], controllers: [MediaController], providers: [MediaService] })
export class MediaModule {}
