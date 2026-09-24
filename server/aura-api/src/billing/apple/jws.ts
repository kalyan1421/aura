import { X509Certificate } from 'node:crypto';
import { compactVerify, decodeProtectedHeader } from 'jose';
import { APPLE_ROOT_CERTS_B64 } from './apple-roots';
import { certificateExtensionOids, DerError } from './der';

/**
 * Verifies App Store signed data (JWS, ES256, `x5c` chain) the way Apple's App Store Server Library does, with no
 * trust in anything the payload says until the chain and the signature check out:
 *   1. header `alg` is ES256 and `x5c` holds exactly [leaf, intermediate, root];
 *   2. the intermediate is issued and signed by one of OUR trusted roots (Apple Root CA G3 / G2 — the root in the
 *      header is never trusted on its own), is a CA, and carries Apple's WWDR intermediate marker
 *      (OID 1.2.840.113635.100.6.2.1);
 *   3. the leaf is issued and signed by that intermediate and carries the App Store receipt-signing marker
 *      (OID 1.2.840.113635.100.6.11.1) — so a developer's own Apple-issued certificate can't sign one;
 *   4. every certificate is valid at the payload's `signedDate` (Apple's rule when online revocation checks are off);
 *   5. the JWS signature verifies with the leaf's key.
 * OCSP revocation checks are not done (Apple's library makes them optional) `[ASSUMPTION]`.
 */
export const APPLE_LEAF_OID = '1.2.840.113635.100.6.11.1';
export const APPLE_INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

export type AppleJwsFailure =
  | 'malformed'
  | 'bad_algorithm'
  | 'bad_chain'
  | 'untrusted_root'
  | 'bad_intermediate'
  | 'bad_leaf'
  | 'expired_certificate'
  | 'bad_signature';

export class AppleJwsError extends Error {
  constructor(readonly reason: AppleJwsFailure) {
    super(`App Store signed data rejected: ${reason}`);
    this.name = 'AppleJwsError';
  }
}

export interface AppleJwsVerifierOptions {
  /** Trusted roots (DER). Default: the bundled Apple roots (apple-roots.ts). Tests pass their own CA. */
  roots?: Buffer[];
  /** Used when a payload carries no `signedDate`. */
  now?: () => Date;
}

const b64urlJson = (part: string): unknown => JSON.parse(Buffer.from(part, 'base64url').toString('utf8'));

export class AppleJwsVerifier {
  private readonly roots: X509Certificate[];
  private readonly now: () => Date;

  constructor(opts: AppleJwsVerifierOptions = {}) {
    const der = opts.roots ?? Object.values(APPLE_ROOT_CERTS_B64).map((b) => Buffer.from(b, 'base64'));
    this.roots = der.map((d) => new X509Certificate(d));
    this.now = opts.now ?? (() => new Date());
  }

  /** The verified payload, or AppleJwsError. Never logs or echoes the input. */
  async verify<T extends object>(jws: string): Promise<T> {
    if (typeof jws !== 'string' || jws.length > 100_000 || jws.split('.').length !== 3) throw new AppleJwsError('malformed');
    let header: { alg?: unknown; x5c?: unknown };
    let claimed: { signedDate?: unknown };
    try {
      header = decodeProtectedHeader(jws) as { alg?: unknown; x5c?: unknown };
      claimed = b64urlJson(jws.split('.')[1]) as { signedDate?: unknown };
    } catch {
      throw new AppleJwsError('malformed');
    }
    if (header.alg !== 'ES256') throw new AppleJwsError('bad_algorithm');
    const x5c = header.x5c;
    if (!Array.isArray(x5c) || x5c.length !== 3 || !x5c.every((c) => typeof c === 'string')) throw new AppleJwsError('bad_chain');
    let leaf: X509Certificate;
    let intermediate: X509Certificate;
    try {
      leaf = new X509Certificate(Buffer.from(x5c[0] as string, 'base64'));
      intermediate = new X509Certificate(Buffer.from(x5c[1] as string, 'base64'));
    } catch {
      throw new AppleJwsError('bad_chain');
    }

    const root = this.roots.find((r) => intermediate.checkIssued(r) && intermediate.verify(r.publicKey));
    if (!root) throw new AppleJwsError('untrusted_root');
    if (!intermediate.ca || !hasOid(intermediate, APPLE_INTERMEDIATE_OID)) throw new AppleJwsError('bad_intermediate');
    if (!leaf.checkIssued(intermediate) || !leaf.verify(intermediate.publicKey)) throw new AppleJwsError('bad_chain');
    if (leaf.ca || !hasOid(leaf, APPLE_LEAF_OID)) throw new AppleJwsError('bad_leaf');

    const at = typeof claimed.signedDate === 'number' && Number.isFinite(claimed.signedDate) ? new Date(claimed.signedDate) : this.now();
    for (const c of [leaf, intermediate, root]) {
      if (at < new Date(c.validFrom) || at > new Date(c.validTo)) throw new AppleJwsError('expired_certificate');
    }

    try {
      const { payload } = await compactVerify(jws, leaf.publicKey, { algorithms: ['ES256'] });
      const parsed = JSON.parse(Buffer.from(payload).toString('utf8')) as unknown;
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new AppleJwsError('malformed');
      return parsed as T;
    } catch (err) {
      if (err instanceof AppleJwsError) throw err;
      throw new AppleJwsError('bad_signature');
    }
  }
}

function hasOid(cert: X509Certificate, oid: string): boolean {
  try {
    return certificateExtensionOids(cert.raw).includes(oid);
  } catch (err) {
    if (err instanceof DerError) return false;
    throw err;
  }
}
