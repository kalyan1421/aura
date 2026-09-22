import { createHash, randomBytes } from 'node:crypto';

/** Canonical 8-4-4-4-12 hex UUID (any version — clients send UUIDv7). */
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isUuid = (v: unknown): v is string => typeof v === 'string' && UUID_RE.test(v);

const hex = (b: Buffer): string =>
  `${b.subarray(0, 4).toString('hex')}-${b.subarray(4, 6).toString('hex')}-${b.subarray(6, 8).toString('hex')}-${b
    .subarray(8, 10)
    .toString('hex')}-${b.subarray(10, 16).toString('hex')}`;

/** RFC 9562 UUIDv5 (SHA-1, name-based) — deterministic ids. */
export function uuidv5(name: string, namespace: string): string {
  if (!isUuid(namespace)) throw new TypeError('namespace must be a UUID');
  const ns = Buffer.from(namespace.replace(/-/g, ''), 'hex');
  const h = createHash('sha1').update(ns).update(name, 'utf8').digest().subarray(0, 16);
  h[6] = (h[6] & 0x0f) | 0x50;
  h[8] = (h[8] & 0x3f) | 0x80;
  return hex(Buffer.from(h));
}

/** RFC 9562 UUIDv7 (ms timestamp + random) — used by tests/tools; the app generates its own. */
export function uuidv7(now = Date.now()): string {
  const b = randomBytes(16);
  b.writeUIntBE(now, 0, 6);
  b[6] = (b[6] & 0x0f) | 0x70;
  b[8] = (b[8] & 0x3f) | 0x80;
  return hex(b);
}
