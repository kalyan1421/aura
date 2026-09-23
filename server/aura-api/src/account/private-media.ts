import type { Queryable } from '../db/db';

/** The one private bucket (supabase/migrations/20261005000002). Objects live under `<user_id>/…`. */
export const PRIVATE_MEDIA_BUCKET = 'private-media';

/** Names per Storage API delete call (the API caps `prefixes`; keep requests small). */
const DELETE_BATCH = 100;
const TIMEOUT_MS = 15_000;

/** No service key is configured: purges defer the account, /v1/media answers 503, sync skips cleanup. */
export class MediaStoreUnavailableError extends Error {
  constructor() {
    super('SUPABASE_SERVICE_ROLE_KEY is not configured: the private-media bucket cannot be used');
    this.name = 'MediaStoreUnavailableError';
  }
}

export type MediaStoreOp = 'delete' | 'sign upload' | 'sign download';

export class MediaStoreError extends Error {
  constructor(
    readonly httpStatus: number,
    op: MediaStoreOp = 'delete',
  ) {
    // Never include the response body: it echoes object paths, which start with the user id.
    super(`storage ${op} failed: HTTP ${httpStatus}`);
    this.name = 'MediaStoreError';
  }
}

/** A Storage-signed URL (absolute) and when it stops working. */
export interface SignedMediaUrl {
  url: string;
  expiresAt: Date;
}

export interface PrivateMediaStoreOptions {
  supabaseUrl: string;
  /** service_role key (legacy JWT or `sb_secret_…`). The API (media URLs, sync cleanup) and the worker (purge) need it. */
  serviceKey?: string;
  fetch?: typeof fetch;
  timeoutMs?: number;
}

/**
 * Encodes an object name for a Storage API URL, one segment at a time. Callers only pass names they
 * validated (`<user_id>/voice/<uuid>`), so this is defence in depth: `.`/`..` segments are refused
 * because the URL parser would resolve them (even percent-encoded) and escape the caller's prefix.
 */
export function encodeObjectPath(name: string): string {
  const segments = name.split('/');
  if (segments.some((s) => s === '' || /^(\.|%2e)+$/i.test(s))) throw new TypeError('invalid object name');
  return segments.map(encodeURIComponent).join('/');
}

/** `exp` of the token in a Storage-signed URL (`…?token=<jwt>`), or null if it cannot be read. */
export function signedUrlExpiry(url: string): Date | null {
  try {
    const token = new URL(url, 'http://x').searchParams.get('token');
    const payload = token?.split('.')[1];
    if (!payload) return null;
    const exp = (JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as { exp?: unknown }).exp;
    return typeof exp === 'number' && Number.isFinite(exp) ? new Date(exp * 1000) : null;
  } catch {
    return null;
  }
}

/**
 * The `private-media` bucket, **through the Storage API** with the service role key. Clients never touch
 * the bucket directly (no storage.objects policies): NestJS signs short-lived upload/download URLs for one
 * object at a time. Deleting through the API removes the blob from the storage backend *and* its
 * `storage.objects` row; deleting rows with SQL is refused by `storage.protect_delete()` and would orphan
 * the (encrypted) blobs, so it is never done. Listing uses SQL (the API/worker DB role reads
 * `storage.objects`; the API only lists one folder level).
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
  async remove(names: string[], opts: { timeoutMs?: number } = {}): Promise<number> {
    if (names.length === 0) return 0;
    const key = this.key();
    for (let i = 0; i < names.length; i += DELETE_BATCH) {
      const res = await this.doFetch(`${this.base}/storage/v1/object/${PRIVATE_MEDIA_BUCKET}`, {
        method: 'DELETE',
        headers: { ...this.auth(key), 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefixes: names.slice(i, i + DELETE_BATCH) }),
        signal: AbortSignal.timeout(opts.timeoutMs ?? this.opts.timeoutMs ?? TIMEOUT_MS),
      });
      if (!res.ok) {
        await res.body?.cancel().catch(() => undefined);
        throw new MediaStoreError(res.status, 'delete');
      }
      await res.arrayBuffer().catch(() => undefined); // drain; the body lists paths — never logged
    }
    return names.length;
  }

  /**
   * A signed **upsert** upload URL for one object (the client `PUT`s the bytes to it; a retry overwrites).
   * Storage fixes the lifetime project-wide (`SIGNED_UPLOAD_URL_EXPIRATION_TIME`, 2 h by default); the
   * returned `expiresAt` is read from the token so callers can cap it.
   */
  async signUpload(name: string): Promise<SignedMediaUrl> {
    const key = this.key();
    const res = await this.doFetch(`${this.base}/storage/v1/object/upload/sign/${PRIVATE_MEDIA_BUCKET}/${encodeObjectPath(name)}`, {
      method: 'POST',
      headers: { ...this.auth(key), 'x-upsert': 'true' },
      signal: AbortSignal.timeout(this.opts.timeoutMs ?? TIMEOUT_MS),
    });
    const body = await this.json<{ url?: unknown }>(res, 'sign upload');
    if (typeof body.url !== 'string') throw new MediaStoreError(res.status, 'sign upload');
    const url = `${this.base}/storage/v1${body.url}`;
    return { url, expiresAt: signedUrlExpiry(url) ?? new Date(Date.now() + 2 * 3600_000) };
  }

  /** A signed GET URL valid for `expiresIn` seconds, or `null` when the object does not exist. */
  async signDownload(name: string, expiresIn: number): Promise<SignedMediaUrl | null> {
    const key = this.key();
    const requestedAt = Date.now();
    const res = await this.doFetch(`${this.base}/storage/v1/object/sign/${PRIVATE_MEDIA_BUCKET}/${encodeObjectPath(name)}`, {
      method: 'POST',
      headers: { ...this.auth(key), 'Content-Type': 'application/json' },
      body: JSON.stringify({ expiresIn }),
      signal: AbortSignal.timeout(this.opts.timeoutMs ?? TIMEOUT_MS),
    });
    if (res.status === 400 || res.status === 404) {
      // Storage answers a missing object with 400 {statusCode: "404", error: "not_found"} (404 on some versions).
      const err = (await res.json().catch(() => ({}))) as { statusCode?: unknown; error?: unknown };
      if (res.status === 404 || String(err.statusCode) === '404' || err.error === 'not_found') return null;
      throw new MediaStoreError(res.status, 'sign download');
    }
    const body = await this.json<{ signedURL?: unknown }>(res, 'sign download');
    if (typeof body.signedURL !== 'string') throw new MediaStoreError(res.status, 'sign download');
    const url = `${this.base}/storage/v1${body.signedURL}`;
    return { url, expiresAt: signedUrlExpiry(url) ?? new Date(requestedAt + expiresIn * 1000) };
  }

  private key(): string {
    const key = this.opts.serviceKey;
    if (!key) throw new MediaStoreUnavailableError();
    return key;
  }

  private auth(key: string): Record<string, string> {
    return { apikey: key, Authorization: `Bearer ${key}` };
  }

  private doFetch(url: string, init: RequestInit): Promise<Response> {
    return (this.opts.fetch ?? fetch)(url, init);
  }

  private async json<T>(res: Response, op: MediaStoreOp): Promise<T> {
    if (!res.ok) {
      await res.body?.cancel().catch(() => undefined);
      throw new MediaStoreError(res.status, op);
    }
    try {
      return (await res.json()) as T;
    } catch {
      throw new MediaStoreError(res.status, op);
    }
  }
}
