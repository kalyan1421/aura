import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { RemoteConfigSettings } from './remote-config.config';
import { canonicalJson, sha256Hex } from './signing';

/**
 * `GET /v1/config` (contracts/api/v1.md "Remote config"; PRD 19 REQ-ADM-12): the server-authoritative feature flags and
 * kill switches plus a pointer to each signed bundle, as one small document with a strong ETag. The app fetches it at
 * start, on resume and every `pollSeconds` while in the foreground (If-None-Match → 304), keeps the last copy for
 * offline use, and falls back to its bundled safe defaults. A flag flipped in the console therefore reaches every open
 * app within `pollSeconds` + `REMOTE_CONFIG_CACHE_MS` (≤ 250 s by default) without a release.
 *
 * Flags are not secret (`public.feature_flags` is anon-readable) and the document carries nothing about the caller, so
 * the route is public: it also serves the signed-out app (sign-up kill switch, the lexicon pointer).
 */
export interface FlagValue {
  enabled: boolean;
  /** Only when the flag has one (e.g. a per-partition list). */
  payload?: Record<string, unknown>;
}

export interface BundlePointer {
  version: number;
  seq: number;
}

export interface ConfigDocument {
  /** Changes whenever anything below changes; the ETag is this value in quotes. */
  configVersion: string;
  pollSeconds: number;
  flags: Record<string, FlagValue>;
  /** Published signed bundles by kind (`crisis_lexicon`); absent = none published (the app uses its bundled copy). */
  bundles: Record<string, BundlePointer>;
}

@Injectable()
export class RemoteConfigService {
  private cached: { doc: ConfigDocument; at: number } | null = null;
  private inflight: Promise<ConfigDocument> | null = null;

  constructor(
    private readonly db: DbService,
    private readonly settings: RemoteConfigSettings,
  ) {}

  /** The current document, rebuilt at most every `REMOTE_CONFIG_CACHE_MS` per API instance. */
  async current(now = Date.now()): Promise<ConfigDocument> {
    const c = this.cached;
    if (c && now - c.at < this.settings.cacheMs) return c.doc;
    // One rebuild at a time: a burst of polls after a deploy shares one pair of queries.
    this.inflight ??= buildConfigDocument(this.db, this.settings.pollSeconds)
      .then((doc) => {
        this.cached = { doc, at: Date.now() };
        return doc;
      })
      .finally(() => {
        this.inflight = null;
      });
    return this.inflight;
  }

  /** After a change made through this instance (a publish): the next read rebuilds. */
  invalidate(): void {
    this.cached = null;
  }

  /** A flag's `enabled` from the cached document; `fallback` when the flag doesn't exist. */
  async flagEnabled(key: string, fallback: boolean): Promise<boolean> {
    const f = (await this.current()).flags[key];
    return f ? f.enabled : fallback;
  }
}

export async function buildConfigDocument(q: Queryable, pollSeconds: number): Promise<ConfigDocument> {
  const [flags, bundles] = await Promise.all([
    q.query<{ key: string; enabled: boolean; payload: Record<string, unknown> | null }>(
      'select key, enabled, payload from public.feature_flags order by key',
    ),
    q.query<{ kind: string; version: number; seq: string }>('select kind, version, seq from public.signed_bundle_current order by kind'),
  ]);
  const out: Omit<ConfigDocument, 'configVersion'> = { pollSeconds, flags: {}, bundles: {} };
  for (const f of flags.rows) {
    const payload = f.payload && typeof f.payload === 'object' && Object.keys(f.payload).length > 0 ? f.payload : undefined;
    out.flags[f.key] = payload ? { enabled: f.enabled, payload } : { enabled: f.enabled };
  }
  for (const b of bundles.rows) out.bundles[b.kind] = { version: b.version, seq: Number(b.seq) };
  return { configVersion: `c1-${sha256Hex(canonicalJson(out)).slice(0, 20)}`, ...out };
}

/** `If-None-Match` holds this ETag (a list, `*`, weak or strong). */
export function etagMatches(ifNoneMatch: string | string[] | undefined, etag: string): boolean {
  if (!ifNoneMatch) return false;
  const header = Array.isArray(ifNoneMatch) ? ifNoneMatch.join(',') : ifNoneMatch;
  const bare = etag.replace(/^W\//, '');
  return header
    .split(',')
    .map((t) => t.trim())
    .some((t) => t === '*' || t.replace(/^W\//, '') === bare);
}
