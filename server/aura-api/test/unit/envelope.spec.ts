import { randomBytes } from 'node:crypto';
import { DATA_KEY_BYTES, generateDataKey, unwrapDataKey, wrapDataKey } from '../../src/keys/envelope';

describe('DS-1 envelope (AES-256-GCM)', () => {
  const master = randomBytes(32);
  const user = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';

  it('round-trips and never stores the key in the clear', () => {
    const key = generateDataKey();
    expect(key).toHaveLength(DATA_KEY_BYTES);
    const wrapped = wrapDataKey(master, key, user);
    expect(Buffer.from(wrapped, 'base64')).toHaveLength(12 + 32 + 16);
    expect(Buffer.from(wrapped, 'base64').includes(key)).toBe(false);
    expect(unwrapDataKey(master, wrapped, user).equals(key)).toBe(true);
  });

  it('uses a fresh IV per wrap', () => {
    const key = generateDataKey();
    expect(wrapDataKey(master, key, user)).not.toBe(wrapDataKey(master, key, user));
  });

  it('fails closed on tamper, wrong master key, or another user (AAD)', () => {
    const key = generateDataKey();
    const wrapped = wrapDataKey(master, key, user);
    const bytes = Buffer.from(wrapped, 'base64');
    bytes[20] ^= 0x01;
    expect(() => unwrapDataKey(master, bytes.toString('base64'), user)).toThrow();
    expect(() => unwrapDataKey(randomBytes(32), wrapped, user)).toThrow();
    expect(() => unwrapDataKey(master, wrapped, '0192f0c2-7a4e-7c1a-9b3d-000000000000')).toThrow();
    expect(() => unwrapDataKey(master, 'AAAA', user)).toThrow(/length/);
  });

  it('rejects bad key sizes', () => {
    expect(() => wrapDataKey(randomBytes(16), generateDataKey(), user)).toThrow();
    expect(() => wrapDataKey(master, randomBytes(16), user)).toThrow();
  });
});
