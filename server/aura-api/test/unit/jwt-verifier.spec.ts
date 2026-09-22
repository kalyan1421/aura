import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK, type JWTPayload } from 'jose';
import { InvalidTokenError, JwtVerifier } from '../../src/auth/jwt-verifier';

const ISS = 'http://127.0.0.1:55521/auth/v1';
const SECRET = 'super-secret-jwt-token-with-at-least-32-characters-long';
const SUB = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';

describe('JwtVerifier', () => {
  type KeyPair = Awaited<ReturnType<typeof generateKeyPair>>;
  let es: KeyPair;
  let other: KeyPair;
  let jwk: JWK;

  beforeAll(async () => {
    es = await generateKeyPair('ES256', { extractable: true });
    other = await generateKeyPair('ES256', { extractable: true });
    jwk = { ...(await exportJWK(es.publicKey)), kid: 'kid-1', alg: 'ES256', use: 'sig' };
  });

  const claims = (over: JWTPayload = {}): JWTPayload => ({ sub: SUB, role: 'authenticated', aud: 'authenticated', ...over });

  const es256 = (over: JWTPayload = {}, key = es.privateKey, kid = 'kid-1', exp: string | number = '1h'): Promise<string> =>
    new SignJWT(claims(over)).setProtectedHeader({ alg: 'ES256', kid }).setIssuer(ISS).setIssuedAt().setExpirationTime(exp).sign(key);

  const hs256 = (over: JWTPayload = {}, secret = SECRET): Promise<string> =>
    new SignJWT(claims(over))
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuer(ISS)
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(new TextEncoder().encode(secret));

  const verifier = (withSecret = false): JwtVerifier =>
    new JwtVerifier({ jwks: createLocalJWKSet({ keys: [jwk] }), issuer: ISS, secret: withSecret ? SECRET : undefined });

  it('accepts an ES256 user session and returns sub as the user id', async () => {
    await expect(verifier().verify(await es256())).resolves.toEqual({ id: SUB, role: 'authenticated', isAnonymous: false });
  });

  it('flags anonymous sign-ins', async () => {
    expect((await verifier().verify(await es256({ is_anonymous: true }))).isAnonymous).toBe(true);
  });

  it('accepts HS256 only when the legacy secret is configured', async () => {
    const token = await hs256();
    await expect(verifier(false).verify(token)).rejects.toBeInstanceOf(InvalidTokenError);
    await expect(verifier(true).verify(token)).resolves.toMatchObject({ id: SUB });
  });

  it.each<[string, () => Promise<string>]>([
    ['expired', () => es256({}, undefined, 'kid-1', Math.floor(Date.now() / 1000) - 120)],
    ['wrong audience', () => es256({ aud: 'something-else' })],
    ['anon role', () => es256({ role: 'anon' })],
    ['service_role', () => es256({ role: 'service_role' })],
    ['non-uuid sub', () => es256({ sub: 'not-a-uuid' })],
    ['signed by an unknown key', () => es256({}, other.privateKey, 'kid-1')],
    ['unknown kid', () => es256({}, es.privateKey, 'kid-2')],
    ['HS256 with the wrong secret', () => hs256({}, 'x'.repeat(40))],
  ])('rejects %s', async (_, make) => {
    await expect(verifier(true).verify(await make())).rejects.toBeInstanceOf(InvalidTokenError);
  });

  it('rejects the wrong issuer', async () => {
    const t = await new SignJWT(claims())
      .setProtectedHeader({ alg: 'ES256', kid: 'kid-1' })
      .setIssuer('https://evil.example/auth/v1')
      .setExpirationTime('1h')
      .sign(es.privateKey);
    await expect(verifier().verify(t)).rejects.toBeInstanceOf(InvalidTokenError);
  });

  it('rejects alg none and garbage', async () => {
    const none = `${Buffer.from(JSON.stringify({ alg: 'none' })).toString('base64url')}.${Buffer.from(
      JSON.stringify(claims({ iss: ISS, exp: Math.floor(Date.now() / 1000) + 60 })),
    ).toString('base64url')}.`;
    await expect(verifier(true).verify(none)).rejects.toBeInstanceOf(InvalidTokenError);
    await expect(verifier(true).verify('garbage')).rejects.toBeInstanceOf(InvalidTokenError);
  });

  it('rejects the real local anon/service_role keys (HS256, iss supabase-demo)', async () => {
    const anon =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
    await expect(verifier(true).verify(anon)).rejects.toBeInstanceOf(InvalidTokenError);
  });

  it('needs at least one key source', () => {
    expect(() => new JwtVerifier({})).toThrow();
  });
});
