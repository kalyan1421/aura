import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';
import type { Platform } from './devices.schema';

/** `public.device_tokens` (token is unique; one row per device install). Never logs tokens. */
@Injectable()
export class DevicesRepository {
  /** Insert, or take the token over: a token that moves to another account is reassigned to it. */
  async upsert(q: Queryable, userId: string, token: string, platform: Platform): Promise<void> {
    await q.query(
      `insert into public.device_tokens (user_id, platform, token) values ($1, $2, $3)
       on conflict (token) do update set
         user_id = excluded.user_id, platform = excluded.platform, updated_at = now()`,
      [userId, platform, token],
    );
  }

  /** Deletes only the caller's own row; someone else's token is left alone. */
  async delete(q: Queryable, userId: string, token: string): Promise<number> {
    const r = await q.query('delete from public.device_tokens where token = $1 and user_id = $2', [token, userId]);
    return r.rowCount ?? 0;
  }
}
