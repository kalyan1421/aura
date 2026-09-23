import { HttpStatus, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { MediaStoreError, MediaStoreUnavailableError, PrivateMediaStore } from '../account/private-media';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { isOwnMediaPath, voiceObjectPath } from './media-paths';
import {
  DOWNLOAD_URL_TTL_SECONDS,
  downloadUrlRequestSchema,
  MAX_MEDIA_BYTES,
  UPLOAD_URL_TTL_SECONDS,
  uploadUrlRequestSchema,
  type DownloadUrlResponse,
  type UploadUrlResponse,
} from './media.schema';

export const mediaNotFound = (): ApiError => new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'No such media.');

export const mediaUnavailable = (): ApiError =>
  new ApiError(HttpStatus.SERVICE_UNAVAILABLE, 'media_unavailable', 'Media storage is unavailable right now; try again later.');

/** Transport failures talking to Storage (the messages carry no paths or ids). */
const isStorageOutage = (err: unknown): err is Error =>
  err instanceof MediaStoreError ||
  (err instanceof Error && (err.name === 'TimeoutError' || err.name === 'AbortError' || (err instanceof TypeError && err.message === 'fetch failed')));

const earliest = (ms: number, d: Date): string => new Date(Math.min(ms, d.getTime())).toISOString();

/**
 * F1 voice notes (contracts/api/v1.md "Media: voice notes"). Clients never touch the private bucket:
 * this service signs one short-lived URL per object with the service role key. The bytes are
 * client-encrypted (DS-1); nothing here ever sees plaintext, and paths/ids are never logged.
 */
@Injectable()
export class MediaService implements OnModuleInit {
  private readonly logger = new Logger('Media');

  /** Provided globally by QueuesModule (the same Storage client the worker's account purge uses). */
  constructor(private readonly store: PrivateMediaStore) {}

  onModuleInit(): void {
    if (!this.store.configured) {
      this.logger.warn(
        'SUPABASE_SERVICE_ROLE_KEY is not set: /v1/media/* answer 503 media_unavailable and sync skips voice-object cleanup',
      );
    }
  }

  /** `200 { path, uploadUrl, expiresAt }` — an upsert URL for `<user_id>/voice/<recordId>`. */
  async uploadUrl(userId: string, body: unknown, now = new Date()): Promise<UploadUrlResponse> {
    const req = parseOrThrow(uploadUrlRequestSchema, body);
    const max = MAX_MEDIA_BYTES[req.kind];
    if (req.bytes > max) throw ApiError.badRequest('media_too_large', `bytes: at most ${max} for ${req.kind}`);
    if (!Number.isInteger(req.bytes)) throw ApiError.badRequest('invalid_request', 'bytes: must be an integer');

    const path = voiceObjectPath(userId, req.recordId);
    const signed = await this.storage(() => this.store.signUpload(path));
    // Storage's own token lifetime is project-wide (2 h by default); the client is told the shorter one.
    return { path, uploadUrl: signed.url, expiresAt: earliest(now.getTime() + UPLOAD_URL_TTL_SECONDS * 1000, signed.expiresAt) };
  }

  /** `200 { downloadUrl, expiresAt }` for an object under the caller's own prefix, else `404 not_found`. */
  async downloadUrl(userId: string, body: unknown, now = new Date()): Promise<DownloadUrlResponse> {
    const { path } = parseOrThrow(downloadUrlRequestSchema, body);
    if (!isOwnMediaPath(userId, path)) throw mediaNotFound();
    const signed = await this.storage(() => this.store.signDownload(path, DOWNLOAD_URL_TTL_SECONDS));
    if (!signed) throw mediaNotFound();
    return { downloadUrl: signed.url, expiresAt: earliest(now.getTime() + DOWNLOAD_URL_TTL_SECONDS * 1000, signed.expiresAt) };
  }

  /** No service key or Storage down → `503 media_unavailable` (the app retries later); bugs stay 500. */
  private async storage<T>(call: () => Promise<T>): Promise<T> {
    if (!this.store.configured) throw mediaUnavailable();
    try {
      return await call();
    } catch (err) {
      if (err instanceof MediaStoreUnavailableError) throw mediaUnavailable();
      if (isStorageOutage(err)) {
        this.logger.warn(`storage unavailable: ${err.name}: ${err.message}`);
        throw mediaUnavailable();
      }
      throw err;
    }
  }
}
