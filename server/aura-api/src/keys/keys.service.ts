import { Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { AppConfig } from '../config/app-config';
import { pgCode } from '../db/db';
import { DbService } from '../db/db.service';
import { generateDataKey, unwrapDataKey, wrapDataKey } from './envelope';

export interface DataKeyResponse {
  keyId: string;
  /** base64 of the raw 32-byte key — only ever sent over TLS, never stored unwrapped. */
  dataKey: string;
}

@Injectable()
export class KeysService {
  constructor(
    private readonly db: DbService,
    private readonly config: AppConfig,
  ) {}

  /** Create-once per user (race-safe), then always return the same key. */
  async getOrCreate(userId: string): Promise<DataKeyResponse> {
    let row = await this.find(userId);
    if (!row) {
      const wrapped = wrapDataKey(this.config.masterKey, generateDataKey(), userId);
      try {
        await this.db.query(
          'insert into public.user_data_keys (user_id, wrapped_key) values ($1, $2) on conflict (user_id) do nothing',
          [userId, wrapped],
        );
      } catch (err) {
        if (pgCode(err) === '23503') throw ApiError.unauthorized('This account no longer exists.', 'unknown_user');
        throw err;
      }
      row = await this.find(userId); // the winner of a concurrent first call
      if (!row) throw new Error('data key vanished after insert');
    }
    const key = unwrapDataKey(this.config.masterKey, row.wrapped_key, userId);
    return { keyId: row.key_id, dataKey: key.toString('base64') };
  }

  private async find(userId: string): Promise<{ key_id: string; wrapped_key: string } | null> {
    const r = await this.db.query<{ key_id: string; wrapped_key: string }>(
      'select key_id, wrapped_key from public.user_data_keys where user_id = $1',
      [userId],
    );
    return r.rows[0] ?? null;
  }
}
