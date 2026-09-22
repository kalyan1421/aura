import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

/**
 * DS-1 envelope: a per-user 256-bit data key wrapped with AURA_MASTER_KEY using AES-256-GCM.
 * Stored form: base64( iv[12] ‖ ciphertext[32] ‖ tag[16] ). The user id is bound as AAD, so a
 * wrapped key copied onto another user's row fails to unwrap.
 */
const IV_BYTES = 12;
const TAG_BYTES = 16;
export const DATA_KEY_BYTES = 32;

const aadFor = (userId: string): Buffer => Buffer.from(`aura:data-key:v1:${userId}`, 'utf8');

export function generateDataKey(): Buffer {
  return randomBytes(DATA_KEY_BYTES);
}

export function wrapDataKey(masterKey: Buffer, dataKey: Buffer, userId: string): string {
  if (masterKey.length !== 32) throw new Error('master key must be 32 bytes');
  if (dataKey.length !== DATA_KEY_BYTES) throw new Error('data key must be 32 bytes');
  const iv = randomBytes(IV_BYTES);
  const c = createCipheriv('aes-256-gcm', masterKey, iv);
  c.setAAD(aadFor(userId));
  const ct = Buffer.concat([c.update(dataKey), c.final()]);
  return Buffer.concat([iv, ct, c.getAuthTag()]).toString('base64');
}

export function unwrapDataKey(masterKey: Buffer, wrapped: string, userId: string): Buffer {
  const buf = Buffer.from(wrapped, 'base64');
  if (buf.length !== IV_BYTES + DATA_KEY_BYTES + TAG_BYTES) throw new Error('wrapped key has the wrong length');
  const iv = buf.subarray(0, IV_BYTES);
  const tag = buf.subarray(buf.length - TAG_BYTES);
  const ct = buf.subarray(IV_BYTES, buf.length - TAG_BYTES);
  const d = createDecipheriv('aes-256-gcm', masterKey, iv);
  d.setAAD(aadFor(userId));
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]); // throws on tamper / wrong key / wrong user
}
