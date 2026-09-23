import { createHmac, hkdfSync } from 'node:crypto';
import type { Request } from 'express';
import type { Platform } from './devices.schema';

/**
 * The app's install identifier (PRD 19 REQ-ADM-14 "bans account and device"; contracts/api/v1.md "Device bans").
 *
 * The app makes 32 random bytes once per install, keeps them in the Keychain / Keystore (on iOS the Keychain item
 * survives deleting and reinstalling the app; on Android it goes with the app — see docs/setup/lexicon-and-flags.md)
 * and sends them, base64url, as `X-Aura-Install` (+ `X-Aura-Platform: ios|android`) on the calls that decide whether
 * this phone may use Aura: `POST /v1/profile` (sign-in / onboarding), `PUT /v1/devices`, `POST /v1/rooms/match`.
 *
 * The value is opaque and random — no hardware id, no fingerprinting, never linked in analytics. The server never
 * stores it: only `installHash` = HMAC-SHA256 under a key derived from AURA_MASTER_KEY, so a database copy can't be
 * matched against a phone without the master key. A missing or malformed header is simply "unknown install" — never an
 * error (attestation with DeviceCheck / Play Integrity is the later hardening).
 */
export const INSTALL_HEADER = 'x-aura-install';
export const PLATFORM_HEADER = 'x-aura-platform';

/** base64url of 16–64 random bytes (the app sends 32 → 43 characters). */
const INSTALL_RE = /^[A-Za-z0-9_-]{22,86}$/;

export interface InstallInfo {
  id: string;
  platform: Platform | null;
}

function header(req: Pick<Request, 'headers'>, name: string): string | null {
  const v = req.headers[name];
  const s = Array.isArray(v) ? v[0] : v;
  return typeof s === 'string' ? s.trim() : null;
}

/** The request's install id, or null when absent or not in the expected shape. */
export function readInstall(req: Pick<Request, 'headers'>): InstallInfo | null {
  const id = header(req, INSTALL_HEADER);
  if (!id || !INSTALL_RE.test(id)) return null;
  const p = header(req, PLATFORM_HEADER);
  return { id, platform: p === 'ios' || p === 'android' ? p : null };
}

const installKeys = new WeakMap<Buffer, Buffer>();

function installKey(masterKey: Buffer): Buffer {
  let k = installKeys.get(masterKey);
  if (!k) {
    k = Buffer.from(hkdfSync('sha256', masterKey, Buffer.alloc(0), 'aura/device-install/v1', 32));
    installKeys.set(masterKey, k);
  }
  return k;
}

/** What the database keeps for an install: 64 hex characters, not reversible without AURA_MASTER_KEY. */
export function installHash(masterKey: Buffer, installId: string): string {
  return createHmac('sha256', installKey(masterKey)).update(installId, 'utf8').digest('hex');
}

export const INSTALL_HASH_RE = /^[0-9a-f]{64}$/;
