/**
 * Sealed cookies: AES-256-GCM via Web Crypto (works in the proxy and in server code), base64url, versioned.
 * The key is SHA-256 over a domain-separated ADMIN_COOKIE_SECRET. Tampered, truncated or foreign values open to null.
 * Each value is bound to its purpose as AES-GCM associated data (v2; docs/security/milestone-b-review.md §5.14): a
 * sealed PKCE cookie can never be presented as a session and the other way round. v1 values (no binding) no longer
 * open, so a console session sealed before this change simply asks for a new sign-in.
 * Pure and dependency-free (unit-tested with node:test).
 */
export type SealPurpose = 'session' | 'pkce';

const aad = (purpose: SealPurpose): Uint8Array<ArrayBuffer> => {
  const bytes = enc.encode(`aura-admin-cookie/v2/${purpose}`);
  const out = new Uint8Array(new ArrayBuffer(bytes.length));
  out.set(bytes);
  return out;
};
const enc = new TextEncoder();
const dec = new TextDecoder();

function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromB64url(s: string): Uint8Array<ArrayBuffer> {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((s.length + 3) % 4);
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

const keys = new Map<string, Promise<CryptoKey>>();

function keyFor(secret: string): Promise<CryptoKey> {
  let k = keys.get(secret);
  if (!k) {
    k = crypto.subtle
      .digest('SHA-256', enc.encode(`aura-admin-cookie/v1\u0000${secret}`))
      .then((raw) => crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt', 'decrypt']));
    keys.set(secret, k);
  }
  return k;
}

export async function seal(value: unknown, secret: string, purpose: SealPurpose): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: aad(purpose) }, await keyFor(secret), enc.encode(JSON.stringify(value))),
  );
  return `v2.${b64url(iv)}.${b64url(ct)}`;
}

export async function unseal<T>(token: string | undefined | null, secret: string, purpose: SealPurpose): Promise<T | null> {
  if (!token) return null;
  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] !== 'v2') return null;
  try {
    const iv = fromB64url(parts[1]);
    const ct = fromB64url(parts[2]);
    if (iv.length !== 12 || ct.length < 17) return null;
    const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv, additionalData: aad(purpose) }, await keyFor(secret), ct);
    return JSON.parse(dec.decode(pt)) as T;
  } catch {
    return null;
  }
}
