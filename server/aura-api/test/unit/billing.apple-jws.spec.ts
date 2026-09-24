import { createHash, X509Certificate } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { APPLE_ROOT_CERTS_B64 } from '../../src/billing/apple/apple-roots';
import { certificateExtensionOids, decodeOid } from '../../src/billing/apple/der';
import { APPLE_INTERMEDIATE_OID, APPLE_LEAF_OID, AppleJwsError, AppleJwsVerifier } from '../../src/billing/apple/jws';
import { signApple, testVerifier } from '../fixtures/billing/jws';

const fail = async (p: Promise<unknown>): Promise<string> => {
  try {
    await p;
  } catch (err) {
    if (err instanceof AppleJwsError) return err.reason;
    throw err;
  }
  throw new Error('expected a rejection');
};

describe('Apple root certificates (bundled)', () => {
  const FINGERPRINTS: Record<string, string> = {
    'AppleRootCA-G3': '63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179',
    'AppleRootCA-G2': 'c2b9b042dd57830e7d117dac55ac8ae19407d38e41d88f3215bc3a890444a050',
  };
  it.each(Object.keys(FINGERPRINTS))('%s: embedded bytes equal the .cer file and Apple’s published SHA-256', (name) => {
    const file = readFileSync(join(__dirname, '../../src/billing/apple/certs', `${name}.cer`));
    expect(Buffer.from(APPLE_ROOT_CERTS_B64[name], 'base64').equals(file)).toBe(true);
    expect(createHash('sha256').update(file).digest('hex')).toBe(FINGERPRINTS[name]);
    const c = new X509Certificate(file);
    expect(c.ca).toBe(true);
    expect(c.subject).toContain('Apple Root CA');
  });

  it('the default verifier trusts only Apple: a test-CA chain is untrusted', async () => {
    expect(await fail(new AppleJwsVerifier().verify(await signApple({ a: 1, signedDate: Date.now() })))).toBe('untrusted_root');
  });
});

describe('DER extension OIDs', () => {
  it('decodes OIDs', () => {
    expect(decodeOid(Buffer.from('2a864886f7636406 0b01'.replace(/\s/g, ''), 'hex'))).toBe(APPLE_LEAF_OID);
    expect(decodeOid(Buffer.from('2a864886f76364060201', 'hex'))).toBe(APPLE_INTERMEDIATE_OID);
  });
  it('lists a certificate’s extensions (test CA leaf carries the receipt-signing marker)', () => {
    const leaf = readFileSync(join(__dirname, '../fixtures/billing/test-ca/leaf.der'));
    const dev = readFileSync(join(__dirname, '../fixtures/billing/test-ca/dev-leaf.der'));
    expect(certificateExtensionOids(leaf)).toContain(APPLE_LEAF_OID);
    expect(certificateExtensionOids(dev)).not.toContain(APPLE_LEAF_OID);
    expect(certificateExtensionOids(dev)).toContain('2.5.29.19'); // basicConstraints
  });
});

describe('AppleJwsVerifier (test CA shaped like Apple’s chain)', () => {
  const v = testVerifier();

  it('accepts a correctly chained, correctly signed payload', async () => {
    const payload = { notificationType: 'TEST', notificationUUID: 'u-1', signedDate: Date.now() };
    await expect(v.verify(await signApple(payload))).resolves.toEqual(payload);
  });

  it('rejects a tampered payload (forged receipt): bad_signature', async () => {
    const jws = await signApple({ productId: 'aura_plus_monthly', signedDate: Date.now() });
    const [h, , s] = jws.split('.');
    const forged = Buffer.from(JSON.stringify({ productId: 'aura_plus_annual', signedDate: Date.now() })).toString('base64url');
    expect(await fail(v.verify(`${h}.${forged}.${s}`))).toBe('bad_signature');
  });

  it('rejects a developer’s own Apple-issued certificate (no receipt-signing marker): bad_leaf', async () => {
    expect(await fail(v.verify(await signApple({ signedDate: Date.now() }, 'dev')))).toBe('bad_leaf');
  });

  it('rejects a look-alike chain whose root is not trusted, whatever the header claims: untrusted_root', async () => {
    expect(await fail(v.verify(await signApple({ signedDate: Date.now() }, 'rogue')))).toBe('untrusted_root');
  });

  it('rejects a chain that is not [leaf, intermediate, root]: bad_chain', async () => {
    const good = await signApple({ signedDate: Date.now() });
    const x5c = (JSON.parse(Buffer.from(good.split('.')[0], 'base64url').toString()) as { x5c: string[] }).x5c;
    expect(await fail(v.verify(await signApple({ signedDate: Date.now() }, 'good', { x5c: x5c.slice(0, 2) })))).toBe('bad_chain');
    // Leaf and intermediate swapped: the "intermediate" (a leaf) is not issued by a trusted root.
    expect(await fail(v.verify(await signApple({ signedDate: Date.now() }, 'good', { x5c: [x5c[1], x5c[0], x5c[2]] })))).toBe('untrusted_root');
  });

  it('rejects anything but ES256 and malformed input', async () => {
    expect(await fail(v.verify('not.a.jws'))).toBe('malformed');
    expect(await fail(v.verify('abc'))).toBe('malformed');
    const unsigned = `${Buffer.from(JSON.stringify({ alg: 'none' })).toString('base64url')}.${Buffer.from('{}').toString('base64url')}.`;
    expect(await fail(v.verify(unsigned))).toBe('bad_algorithm');
  });

  it('checks certificate validity at the payload’s signedDate: expired_certificate', async () => {
    const future = Date.now() + 30 * 365 * 86_400_000; // after the test certificates expire
    expect(await fail(v.verify(await signApple({ signedDate: future })))).toBe('expired_certificate');
    const past = Date.UTC(2000, 0, 1); // before they were issued
    expect(await fail(v.verify(await signApple({ signedDate: past })))).toBe('expired_certificate');
  });
});
