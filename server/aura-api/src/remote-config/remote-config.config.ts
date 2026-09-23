import { z } from 'zod';
import { BundleKeyError, BundleSigner } from './signing';

/**
 * Remote config + signed lexicon settings (docs/setup/lexicon-and-flags.md). All optional so the API boots without
 * them; a malformed value fails fast at boot naming the variable, never its value.
 *
 * - `LEXICON_SIGNING_KEY` — the Ed25519 private key that signs lexicon versions (base64 of the 32-byte seed, or a
 *   PKCS#8 PEM). Unset → the public development key in development/test; in production publishing is off
 *   (`503 signing_unavailable`) and bundles already published keep being served. The development key is refused in
 *   production.
 * - `REMOTE_CONFIG_POLL_SECONDS` — how often a foregrounded app re-fetches `GET /v1/config` (60–300, default 240) —
 *   keeps "a flag change reaches clients within 5 minutes" (REQ-ADM-12) with room for the cache below.
 * - `REMOTE_CONFIG_CACHE_MS` — how long one API instance reuses a built config document (0–30000, default 10000).
 */
export class RemoteConfigSettings {
  constructor(
    /** Null when publishing is off (production without a key). */
    readonly signer: BundleSigner | null,
    readonly pollSeconds: number,
    readonly cacheMs: number,
    /** Why signing is off, for logs and the console (never a key). */
    readonly signingOffReason: string | null,
  ) {
    Object.freeze(this);
  }
}

export class RemoteConfigSettingsError extends Error {}

const blankToUndefined = (v: unknown): unknown => (typeof v === 'string' && v.trim() === '' ? undefined : v);

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LEXICON_SIGNING_KEY: z.preprocess(blankToUndefined, z.string().optional()),
  REMOTE_CONFIG_POLL_SECONDS: z.preprocess(blankToUndefined, z.coerce.number().int().min(60).max(300).default(240)),
  REMOTE_CONFIG_CACHE_MS: z.preprocess(blankToUndefined, z.coerce.number().int().min(0).max(30_000).default(10_000)),
});

export function parseRemoteConfigSettings(env: Record<string, string | undefined>): RemoteConfigSettings {
  const r = schema.safeParse(env);
  if (!r.success) {
    const lines = r.error.issues.map((i) => `  - ${i.path.join('.') || '(env)'}: ${i.message}`);
    throw new RemoteConfigSettingsError(`Invalid remote config environment:\n${lines.join('\n')}`);
  }
  const e = r.data;
  let signer: BundleSigner | null = null;
  let off: string | null = null;
  if (e.LEXICON_SIGNING_KEY) {
    try {
      signer = BundleSigner.fromEnvValue(e.LEXICON_SIGNING_KEY);
    } catch (err) {
      const why = err instanceof BundleKeyError ? err.message : 'LEXICON_SIGNING_KEY could not be read';
      throw new RemoteConfigSettingsError(`Invalid remote config environment:\n  - LEXICON_SIGNING_KEY: ${why}`);
    }
    if (signer.isDevKey && e.NODE_ENV === 'production') {
      signer = null;
      off = 'LEXICON_SIGNING_KEY is the public development key, which production refuses';
    }
  } else if (e.NODE_ENV === 'production') {
    off = 'LEXICON_SIGNING_KEY is not set';
  } else {
    signer = BundleSigner.dev();
  }
  return new RemoteConfigSettings(signer, e.REMOTE_CONFIG_POLL_SECONDS, e.REMOTE_CONFIG_CACHE_MS, off);
}
