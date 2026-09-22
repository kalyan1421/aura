import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { pgCode } from '../db/db';
import { DbService } from '../db/db.service';
import { DevicesRepository } from './devices.repository';
import { registerDeviceSchema, unregisterDeviceSchema } from './devices.schema';

/**
 * FCM registration only; sending is F14 (worker `notifications` queue). Push payloads carry
 * `{ type, id? }` and never content (PRD Notifications, global rule 3).
 */
@Injectable()
export class DevicesService {
  constructor(
    private readonly db: DbService,
    private readonly devices: DevicesRepository,
  ) {}

  async register(userId: string, body: unknown): Promise<void> {
    const { token, platform } = parseOrThrow(registerDeviceSchema, body);
    try {
      await this.devices.upsert(this.db, userId, token, platform);
    } catch (err) {
      // The auth user was deleted after the token was issued.
      if (pgCode(err) === '23503') throw ApiError.unauthorized('This account no longer exists.', 'unknown_user');
      throw err;
    }
  }

  /** Idempotent: an unknown token, or one owned by another account, is a no-op. */
  async unregister(userId: string, body: unknown): Promise<void> {
    const { token } = parseOrThrow(unregisterDeviceSchema, body);
    await this.devices.delete(this.db, userId, token);
  }
}
