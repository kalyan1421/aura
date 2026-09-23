import type { Queryable } from '../db/db';

/** The one private bucket (supabase/migrations/20261005000002). Objects live under `<user_id>/…`. */
export const PRIVATE_MEDIA_BUCKET = 'private-media';

/** Names per Storage API delete call (the API caps `prefixes`; keep requests small). */
const DELETE_BATCH = 100;
const TIMEOUT_MS = 15_000;

/** Objects exist but no service key is configured: the purge defers the account (retried next run). */
export class MediaStoreUnavailableError extends Error {
  constructor() {
    super('SUPABASE_SERVICE_ROLE_KEY is not configured: private-media objects cannot be deleted');
    this.name = 'MediaStoreUnavailableError';
  }
}

export class MediaStoreError extends Error {
  constructor(readonly httpStatus: number) {
    // Never include the response body: it echoes object paths, which start with the user id.
    super(`storage delete failed: HTTP ${httpStatus}`);
    this.name = 'MediaStoreError';
  }
}

export interface PrivateMediaStoreOptions {
  supabaseUrl: string;
  /** service_role key (legacy JWT or `sb_secret_…`). Only the worker's purge needs it. */
  serviceKey?: string;
  fetch?: typeof fetch;
  timeoutMs?: number;
}

/**
 * Deletes a user's private-media objects **through the Storage API** — that removes the blob from the
 * storage backend *and* its `storage.objects` row. Deleting rows with SQL is refused by
 * `storage.protect_delete()` and would orphan the (encrypted) blobs, so it is never done.
 * Listing uses SQL (the API/worker DB role reads `storage.objects`; the API only lists one folder level).
 */
export class PrivateMediaStore {
  private readonly base: string;

  constructor(private readonly opts: PrivateMediaStoreOptions) {
    this.base = opts.supabaseUrl.replace(/\/+$/, '');
  }

  /** Reads `SUPABASE_SERVICE_ROLE_KEY` (call after AppConfig has merged `.env` into the environment). */
  static fromEnv(supabaseUrl: string, env: NodeJS.ProcessEnv = process.env): PrivateMediaStore {
    const key = env.SUPABASE_SERVICE_ROLE_KEY?.trim();
    return new PrivateMediaStore({ supabaseUrl, serviceKey: key ? key : undefined });
  }

  get configured(): boolean {
    return !!this.opts.serviceKey;
  }

  /** Every object of the user in the bucket: their `<user_id>/` prefix plus anything they own elsewhere. */
  async listUserObjects(q: Queryable, userId: string): Promise<string[]> {
    const r = await q.query<{ name: string }>(
      `select name from storage.objects
        where bucket_id = $1 and (name like ($2 || '/%') or owner_id = $2)
        order by name`,
      [PRIVATE_MEDIA_BUCKET, userId],
    );
    return r.rows.map((x) => x.name);
  }

  /** Deletes the named objects (missing ones are ignored by the API). Returns how many names were sent. */
  async remove(names: string[]): Promise<number> {
    if (names.length === 0) return 0;
    const key = this.opts.serviceKey;
    if (!key) throw new MediaStoreUnavailableError();
    const doFetch = this.opts.fetch ?? fetch;
    for (let i = 0; i < names.length; i += DELETE_BATCH) {
      const res = await doFetch(`${this.base}/storage/v1/object/${PRIVATE_MEDIA_BUCKET}`, {
        method: 'DELETE',
        headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefixes: names.slice(i, i + DELETE_BATCH) }),
        signal: AbortSignal.timeout(this.opts.timeoutMs ?? TIMEOUT_MS),
      });
      if (!res.ok) {
        await res.body?.cancel().catch(() => undefined);
        throw new MediaStoreError(res.status);
      }
      await res.arrayBuffer().catch(() => undefined); // drain; the body lists paths — never logged
    }
    return names.length;
  }
}
