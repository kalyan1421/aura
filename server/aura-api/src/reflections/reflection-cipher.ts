import { createCipheriv, createDecipheriv, createHmac, hkdfSync, randomBytes } from 'node:crypto';
import { generateDataKey, unwrapDataKey, wrapDataKey } from '../keys/envelope';
import { normalizeForFilter } from './filter/reflection-filter';

/**
 * DS-1 envelope encryption for reflection text (contracts/api/v1-reflections.md §0). Reuses the key service's
 * envelope (src/keys/envelope.ts): a fresh 256-bit data key per reflection, wrapped with AURA_MASTER_KEY
 * (AES-256-GCM, bound to `reflection:<id>`), and the text sealed under that data key (AES-256-GCM, associated data
 * `aura:reflection:v1:<id>`). A per-reflection key rather than the author's user key: the text must stay readable for
 * the evidence store (180 days, [LEGAL]) after the author's own key is shredded by the account purge, and a copy moved
 * onto another reflection id fails to open. Only NestJS holds the master key; the console never decrypts.
 */
const IV = 12;
const TAG = 16;

const keyContext = (id: string): string => `reflection:${id.toLowerCase()}`;
const aad = (id: string): Buffer => Buffer.from(`aura:reflection:v1:${id.toLowerCase()}`, 'utf8');

export interface SealedText {
  bodyCt: string;
  bodyKey: string;
}

export function sealReflection(masterKey: Buffer, reflectionId: string, text: string): SealedText {
  const dek = generateDataKey();
  const iv = randomBytes(IV);
  const c = createCipheriv('aes-256-gcm', dek, iv);
  c.setAAD(aad(reflectionId));
  const ct = Buffer.concat([c.update(Buffer.from(text, 'utf8')), c.final()]);
  const bodyCt = Buffer.concat([iv, ct, c.getAuthTag()]).toString('base64');
  const bodyKey = wrapDataKey(masterKey, dek, keyContext(reflectionId));
  dek.fill(0);
  return { bodyCt, bodyKey };
}

/** Throws on tamper, a wrong key or a ciphertext moved to another id. */
export function openReflection(masterKey: Buffer, reflectionId: string, sealed: SealedText): string {
  const dek = unwrapDataKey(masterKey, sealed.bodyKey, keyContext(reflectionId));
  try {
    const buf = Buffer.from(sealed.bodyCt, 'base64');
    if (buf.length < IV + TAG) throw new Error('ciphertext too short');
    const d = createDecipheriv('aes-256-gcm', dek, buf.subarray(0, IV));
    d.setAAD(aad(reflectionId));
    d.setAuthTag(buf.subarray(buf.length - TAG));
    return Buffer.concat([d.update(buf.subarray(IV, buf.length - TAG)), d.final()]).toString('utf8');
  } finally {
    dek.fill(0);
  }
}

/** Null-safe open for views: a scrubbed or unreadable body → null (never throws into a response, never logs). */
export function tryOpen(masterKey: Buffer, reflectionId: string, bodyCt: string | null, bodyKey: string | null): string | null {
  if (!bodyCt || !bodyKey) return null;
  try {
    return openReflection(masterKey, reflectionId, { bodyCt, bodyKey });
  } catch {
    return null;
  }
}

const dupKeys = new WeakMap<Buffer, Buffer>();

/**
 * Near-duplicate key (PRD F6 step 5): HMAC of the text reduced to letters and digits after the filter's
 * normalization, under a key derived from the master key. Lets the server see "the same words in a third room"
 * without storing anything readable.
 */
export function textHash(masterKey: Buffer, text: string): string {
  let k = dupKeys.get(masterKey);
  if (!k) {
    k = Buffer.from(hkdfSync('sha256', masterKey, Buffer.alloc(0), 'aura/reflection-dup/v1', 32));
    dupKeys.set(masterKey, k);
  }
  const reduced = normalizeForFilter(text).replace(/[^\p{L}\p{M}\p{N}]+/gu, '');
  return createHmac('sha256', k).update(reduced, 'utf8').digest('hex');
}
