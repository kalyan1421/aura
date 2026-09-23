import { createHash, createPrivateKey, createPublicKey, sign, verify, type KeyObject } from 'node:crypto';

/**
 * Signed bundles (PRD 19 REQ-ADM-12 "lexicon versions are signed and reversible"; contracts/safety/README.md
 * "Signed versions"). NestJS signs with an Ed25519 key it alone holds (`LEXICON_SIGNING_KEY`); the app embeds the
 * public key(s) and never uses a bundle whose signature, key or kind doesn't check out.
 *
 * Wire shape (`GET /v1/lexicon/crisis`):
 *   { "format": "aura.signed-bundle.v1", "keyId": "<16 hex>", "payload": "<base64>", "signature": "<base64>" }
 * `payload` is the exact UTF-8 bytes of a canonical JSON object (sorted keys, no whitespace):
 *   { "kind", "seq", "issuedAt", "version", "content", "vectors" }
 * and `signature` = Ed25519(private key, "aura.signed-bundle.v1\n" ‖ payload bytes). The prefix keeps these signatures
 * from ever being valid for anything else signed with the same key. `seq` only grows (a rollback is a NEW signature
 * with a higher seq), so the app can refuse a replayed older bundle. `keyId` = first 8 bytes of SHA-256 of the raw
 * 32-byte public key, hex.
 */
export const BUNDLE_FORMAT = 'aura.signed-bundle.v1';
const SIGNING_PREFIX = Buffer.from(`${BUNDLE_FORMAT}\n`, 'utf8');

/** RFC 8410 DER prefixes around a raw 32-byte Ed25519 seed (PKCS#8) / public key (SPKI). */
const PKCS8_ED25519_PREFIX = Buffer.from('302e020100300506032b657004220420', 'hex');

/**
 * The development key. Its seed is derived from this public string, so it is NOT a secret and must never sign anything
 * a production app trusts: the API refuses it when NODE_ENV=production and release builds of the app don't trust it
 * unless told to (docs/setup/lexicon-and-flags.md).
 */
export const DEV_KEY_LABEL = 'aura/dev-bundle-signing-key/v1 -- PUBLIC, DEVELOPMENT ONLY, NEVER PRODUCTION';
export const devSeed = (): Buffer => createHash('sha256').update(DEV_KEY_LABEL, 'utf8').digest();

export interface SignedBundle {
  format: typeof BUNDLE_FORMAT;
  keyId: string;
  payload: string;
  signature: string;
}

export interface BundlePayload {
  kind: string;
  seq: number;
  issuedAt: string;
  version: number;
  content: unknown;
  vectors: unknown[];
}

export class BundleKeyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BundleKeyError';
  }
}

export class BundleVerifyError extends Error {
  constructor(readonly reason: 'malformed' | 'unknown_key' | 'bad_signature' | 'wrong_kind' | 'bad_payload') {
    super(`signed bundle rejected: ${reason}`);
    this.name = 'BundleVerifyError';
  }
}

/** JSON with object keys sorted (recursively) and no whitespace: the exact bytes that get signed and hashed. */
export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') {
    if (typeof value === 'number' && !Number.isFinite(value)) throw new TypeError('canonicalJson: non-finite number');
    return JSON.stringify(value) ?? 'null';
  }
  if (Array.isArray(value)) return `[${value.map((v) => canonicalJson(v === undefined ? null : v)).join(',')}]`;
  const obj = value as Record<string, unknown>;
  const keys = Object.keys(obj)
    .filter((k) => obj[k] !== undefined)
    .sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalJson(obj[k])}`).join(',')}}`;
}

export const sha256Hex = (data: string | Buffer): string => createHash('sha256').update(data).digest('hex');

export function keyIdOf(rawPublicKey: Buffer): string {
  if (rawPublicKey.length !== 32) throw new BundleKeyError('an Ed25519 public key is 32 bytes');
  return createHash('sha256').update(rawPublicKey).digest().subarray(0, 8).toString('hex');
}

function rawPublicKeyOf(key: KeyObject): Buffer {
  const jwk = createPublicKey(key).export({ format: 'jwk' }) as { x?: string };
  if (!jwk.x) throw new BundleKeyError('not an Ed25519 key');
  return Buffer.from(jwk.x, 'base64url');
}

/** An Ed25519 signing key. Holds the private key; never logs or returns it. */
export class BundleSigner {
  readonly keyId: string;
  /** Raw 32-byte public key, base64 — what the app embeds (`AURA_BUNDLE_PUBLIC_KEYS`). */
  readonly publicKeyBase64: string;

  private constructor(
    private readonly key: KeyObject,
    readonly isDevKey: boolean,
  ) {
    if (key.asymmetricKeyType !== 'ed25519') throw new BundleKeyError('the signing key must be Ed25519');
    const raw = rawPublicKeyOf(key);
    this.keyId = keyIdOf(raw);
    this.publicKeyBase64 = raw.toString('base64');
  }

  static fromSeed(seed: Buffer): BundleSigner {
    if (seed.length !== 32) throw new BundleKeyError('an Ed25519 seed is 32 bytes');
    const key = createPrivateKey({ key: Buffer.concat([PKCS8_ED25519_PREFIX, seed]), format: 'der', type: 'pkcs8' });
    return new BundleSigner(key, seed.equals(devSeed()));
  }

  static dev(): BundleSigner {
    return BundleSigner.fromSeed(devSeed());
  }

  /**
   * `LEXICON_SIGNING_KEY`: base64 of the 32-byte seed (what `pnpm bundle keygen` prints), or a PKCS#8 PEM
   * (`openssl genpkey -algorithm ed25519`). Errors never contain the value.
   */
  static fromEnvValue(value: string): BundleSigner {
    const v = value.trim();
    if (v.includes('BEGIN')) {
      let key: KeyObject;
      try {
        key = createPrivateKey({ key: v.replace(/\\n/g, '\n'), format: 'pem' });
      } catch {
        throw new BundleKeyError('LEXICON_SIGNING_KEY is not a readable PEM private key');
      }
      const signer = new BundleSigner(key, false);
      return signer.keyId === BundleSigner.dev().keyId ? BundleSigner.dev() : signer;
    }
    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(v)) throw new BundleKeyError('LEXICON_SIGNING_KEY must be base64 of a 32-byte seed or a PEM key');
    const seed = Buffer.from(v, 'base64');
    if (seed.length !== 32) throw new BundleKeyError('LEXICON_SIGNING_KEY must be base64 of exactly 32 bytes');
    return BundleSigner.fromSeed(seed);
  }

  sign(payload: BundlePayload): SignedBundle {
    const bytes = Buffer.from(canonicalJson(payload), 'utf8');
    const signature = sign(null, Buffer.concat([SIGNING_PREFIX, bytes]), this.key);
    return { format: BUNDLE_FORMAT, keyId: this.keyId, payload: bytes.toString('base64'), signature: signature.toString('base64') };
  }
}

/** Trusted public keys by key id (raw 32 bytes each). */
export type TrustedKeys = ReadonlyMap<string, Buffer>;

export function trustedKeys(publicKeysBase64: readonly string[]): TrustedKeys {
  const out = new Map<string, Buffer>();
  for (const b64 of publicKeysBase64) {
    const raw = Buffer.from(b64.trim(), 'base64');
    out.set(keyIdOf(raw), raw);
  }
  return out;
}

const SPKI_ED25519_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

/**
 * Checks a bundle the way the app does (format, known key, signature over the exact bytes, then kind) and returns the
 * decoded payload. The CLI's `verify` and the tests use it; the API itself only ever serves bundles it signed.
 */
export function verifyBundle(bundle: unknown, keys: TrustedKeys, expectedKind: string): BundlePayload {
  if (typeof bundle !== 'object' || bundle === null) throw new BundleVerifyError('malformed');
  const b = bundle as Record<string, unknown>;
  if (b.format !== BUNDLE_FORMAT || typeof b.keyId !== 'string' || typeof b.payload !== 'string' || typeof b.signature !== 'string') {
    throw new BundleVerifyError('malformed');
  }
  const raw = keys.get(b.keyId);
  if (!raw) throw new BundleVerifyError('unknown_key');
  const bytes = Buffer.from(b.payload, 'base64');
  const signature = Buffer.from(b.signature, 'base64');
  const publicKey = createPublicKey({ key: Buffer.concat([SPKI_ED25519_PREFIX, raw]), format: 'der', type: 'spki' });
  if (signature.length !== 64 || !verify(null, Buffer.concat([SIGNING_PREFIX, bytes]), publicKey, signature)) {
    throw new BundleVerifyError('bad_signature');
  }
  let payload: unknown;
  try {
    payload = JSON.parse(bytes.toString('utf8'));
  } catch {
    throw new BundleVerifyError('bad_payload');
  }
  const p = payload as Partial<BundlePayload>;
  if (typeof p !== 'object' || p === null || typeof p.seq !== 'number' || typeof p.version !== 'number' || !Array.isArray(p.vectors)) {
    throw new BundleVerifyError('bad_payload');
  }
  if (p.kind !== expectedKind) throw new BundleVerifyError('wrong_kind');
  return p as BundlePayload;
}
