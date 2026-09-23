/**
 * Remote config + signed bundles (src/remote-config): the envelope the app verifies (sign/verify round trip, tampered
 * payload / signature, unknown key, wrong kind, the committed dev-signed fixture), key parsing and the production
 * rules, the config document and its ETag, the kill-switch guard, and the lexicon diff that gates crisis removals.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { generateKeyPairSync } from 'node:crypto';
import type { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ApiError } from '../../src/common/api-error';
import { KILL_SWITCH, KillSwitchGuard, ROOMS_KILL_SWITCH } from '../../src/remote-config/kill-switch';
import { baselineLexicon, contractVectors, type LexiconDocument } from '../../src/remote-config/lexicon/document';
import { diffLexicons } from '../../src/remote-config/lexicon.service';
import { parseRemoteConfigSettings } from '../../src/remote-config/remote-config.config';
import { buildConfigDocument, etagMatches, RemoteConfigService } from '../../src/remote-config/remote-config.service';
import {
  BundleSigner,
  BundleVerifyError,
  canonicalJson,
  keyIdOf,
  trustedKeys,
  verifyBundle,
  type BundlePayload,
  type SignedBundle,
} from '../../src/remote-config/signing';

const FIXTURE = resolve(__dirname, '..', '..', '..', '..', 'contracts', 'safety', 'fixtures', 'crisis_lexicon.v1.dev-signed.json');
const DEV_PUBLIC = 'c8HcqQhqAfZ/Q0f+tf7I7n7meei0mzldCIbFYLYSfko=';

const payload = (over: Partial<BundlePayload> = {}): BundlePayload => ({
  kind: 'crisis_lexicon',
  seq: 42,
  issuedAt: '2026-09-24T00:00:00.000Z',
  version: 1,
  content: baselineLexicon(),
  vectors: contractVectors(),
  ...over,
});

function reencode(bundle: SignedBundle, edit: (json: Record<string, unknown>) => void): SignedBundle {
  const json = JSON.parse(Buffer.from(bundle.payload, 'base64').toString('utf8')) as Record<string, unknown>;
  edit(json);
  return { ...bundle, payload: Buffer.from(canonicalJson(json), 'utf8').toString('base64') };
}

describe('signed bundles', () => {
  const dev = BundleSigner.dev();
  const keys = trustedKeys([dev.publicKeyBase64]);

  it('the development key is the documented one', () => {
    expect(dev.publicKeyBase64).toBe(DEV_PUBLIC);
    expect(dev.keyId).toBe('ba9afcf9c1f7ab25');
    expect(keyIdOf(Buffer.from(DEV_PUBLIC, 'base64'))).toBe(dev.keyId);
    expect(dev.isDevKey).toBe(true);
  });

  it('round-trips: sign → verify → the same payload', () => {
    const b = dev.sign(payload());
    expect(b.format).toBe('aura.signed-bundle.v1');
    expect(b.keyId).toBe(dev.keyId);
    expect(Buffer.from(b.signature, 'base64')).toHaveLength(64);
    expect(verifyBundle(b, keys, 'crisis_lexicon')).toEqual(JSON.parse(canonicalJson(payload())));
  });

  it('signing is deterministic (canonical JSON, Ed25519)', () => {
    expect(dev.sign(payload())).toEqual(dev.sign(payload()));
  });

  it('a tampered payload (one crisis form removed) is refused', () => {
    const b = dev.sign(payload());
    const tampered = reencode(b, (j) => {
      const content = j.content as LexiconDocument;
      content.entries = content.entries.filter((e) => e.id !== 'en.kill_myself');
    });
    expect(() => verifyBundle(tampered, keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('bad_signature'));
  });

  it('a replayed payload with a bumped seq is refused (seq is signed)', () => {
    const b = dev.sign(payload({ seq: 1 }));
    expect(() => verifyBundle(reencode(b, (j) => (j.seq = 999)), keys, 'crisis_lexicon')).toThrow(BundleVerifyError);
  });

  it('a flipped signature bit, a wrong-length signature, another key, another kind are refused', () => {
    const b = dev.sign(payload());
    const sig = Buffer.from(b.signature, 'base64');
    sig[0] ^= 1;
    expect(() => verifyBundle({ ...b, signature: sig.toString('base64') }, keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('bad_signature'));
    expect(() => verifyBundle({ ...b, signature: 'AAAA' }, keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('bad_signature'));
    const other = BundleSigner.fromSeed(Buffer.alloc(32, 7)).sign(payload());
    expect(() => verifyBundle(other, keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('unknown_key'));
    // Same key id, different key: still a bad signature.
    expect(() => verifyBundle({ ...other, keyId: dev.keyId }, keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('bad_signature'));
    expect(() => verifyBundle(dev.sign(payload({ kind: 'helplines' })), keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('wrong_kind'));
    expect(() => verifyBundle({ ...b, format: 'x' }, keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('malformed'));
    expect(() => verifyBundle(null, keys, 'crisis_lexicon')).toThrow(new BundleVerifyError('malformed'));
  });

  it('the committed fixture (contracts/safety/fixtures) verifies with the dev key and carries the contract v1', () => {
    const fixture = JSON.parse(readFileSync(FIXTURE, 'utf8')) as SignedBundle;
    const p = verifyBundle(fixture, keys, 'crisis_lexicon');
    expect(p).toMatchObject({ kind: 'crisis_lexicon', version: 1, seq: 1 });
    expect(p.content).toEqual(JSON.parse(canonicalJson(baselineLexicon())));
    expect(p.vectors).toEqual(JSON.parse(canonicalJson(contractVectors())));
  });

  it('canonicalJson sorts keys at every level and drops undefined', () => {
    expect(canonicalJson({ b: 1, a: { d: [3, { z: 1, y: 2 }], c: 'x' }, u: undefined })).toBe('{"a":{"c":"x","d":[3,{"y":2,"z":1}]},"b":1}');
    expect(canonicalJson('ఆ')).toBe('"ఆ"');
    expect(() => canonicalJson(Number.NaN)).toThrow();
  });
});

describe('LEXICON_SIGNING_KEY', () => {
  const seed = Buffer.alloc(32, 9).toString('base64');

  it('base64 seed or PEM; the same key either way', () => {
    const fromSeed = BundleSigner.fromEnvValue(seed);
    const { privateKey } = generateKeyPairSync('ed25519');
    const pem = privateKey.export({ format: 'pem', type: 'pkcs8' }).toString();
    const fromPem = BundleSigner.fromEnvValue(pem);
    expect(fromSeed.keyId).toMatch(/^[0-9a-f]{16}$/);
    expect(fromPem.keyId).toMatch(/^[0-9a-f]{16}$/);
    expect(BundleSigner.fromEnvValue(pem.replace(/\n/g, '\\n')).keyId).toBe(fromPem.keyId);
  });

  it('refuses malformed values without echoing them', () => {
    for (const bad of ['not-base64!!', Buffer.alloc(31).toString('base64'), '-----BEGIN PRIVATE KEY-----\nsecretstuff\n-----END PRIVATE KEY-----']) {
      expect(() => parseRemoteConfigSettings({ LEXICON_SIGNING_KEY: bad })).toThrow(/LEXICON_SIGNING_KEY/);
      try {
        parseRemoteConfigSettings({ LEXICON_SIGNING_KEY: bad });
      } catch (err) {
        expect((err as Error).message).not.toContain('secretstuff');
      }
    }
  });

  it('development/test without a key → the dev key; production without one → publishing off', () => {
    expect(parseRemoteConfigSettings({}).signer?.isDevKey).toBe(true);
    expect(parseRemoteConfigSettings({ NODE_ENV: 'test' }).signer?.isDevKey).toBe(true);
    const prod = parseRemoteConfigSettings({ NODE_ENV: 'production' });
    expect(prod.signer).toBeNull();
    expect(prod.signingOffReason).toMatch(/not set/);
  });

  it('production refuses the public development key', () => {
    const s = parseRemoteConfigSettings({ NODE_ENV: 'production', LEXICON_SIGNING_KEY: 'BweXFJHSJMphO39iA2V66aL9drmZB8ELKYUTHczrn8s=' });
    expect(s.signer).toBeNull();
    expect(s.signingOffReason).toMatch(/development key/);
    expect(parseRemoteConfigSettings({ NODE_ENV: 'production', LEXICON_SIGNING_KEY: seed }).signer?.isDevKey).toBe(false);
  });

  it('poll interval stays within the 5-minute promise', () => {
    expect(parseRemoteConfigSettings({}).pollSeconds).toBe(240);
    expect(() => parseRemoteConfigSettings({ REMOTE_CONFIG_POLL_SECONDS: '301' })).toThrow(/REMOTE_CONFIG_POLL_SECONDS/);
    expect(() => parseRemoteConfigSettings({ REMOTE_CONFIG_CACHE_MS: '60000' })).toThrow(/REMOTE_CONFIG_CACHE_MS/);
  });
});

describe('config document', () => {
  function fakeDb(flags: Array<{ key: string; enabled: boolean; payload: Record<string, unknown> | null }>, bundles: Array<{ kind: string; version: number; seq: string }> = []) {
    const calls: string[] = [];
    return {
      calls,
      query: jest.fn(async (sql: string) => {
        calls.push(sql);
        return { rows: sql.includes('feature_flags') ? flags : bundles };
      }),
    };
  }

  it('flags, payloads only when present, bundle pointers; ETag follows the content', async () => {
    const db = fakeDb(
      [
        { key: 'rooms_enabled', enabled: true, payload: {} },
        { key: 'rooms_pool_hi', enabled: false, payload: null },
        { key: 'reflections_composer', enabled: true, payload: { pausedPools: ['te'] } },
      ],
      [{ kind: 'crisis_lexicon', version: 3, seq: '1727000000000' }],
    );
    const doc = await buildConfigDocument(db as never, 240);
    expect(doc).toEqual({
      configVersion: expect.stringMatching(/^c1-[0-9a-f]{20}$/),
      pollSeconds: 240,
      flags: {
        rooms_enabled: { enabled: true },
        rooms_pool_hi: { enabled: false },
        reflections_composer: { enabled: true, payload: { pausedPools: ['te'] } },
      },
      bundles: { crisis_lexicon: { version: 3, seq: 1727000000000 } },
    });
    const again = await buildConfigDocument(db as never, 240);
    expect(again.configVersion).toBe(doc.configVersion);
    const flipped = await buildConfigDocument(fakeDb([{ key: 'rooms_enabled', enabled: false, payload: {} }]) as never, 240);
    expect(flipped.configVersion).not.toBe(doc.configVersion);
  });

  it('is cached per instance for REMOTE_CONFIG_CACHE_MS, and a burst shares one rebuild', async () => {
    const db = fakeDb([{ key: 'rooms_enabled', enabled: true, payload: null }]);
    const svc = new RemoteConfigService(db as never, parseRemoteConfigSettings({ REMOTE_CONFIG_CACHE_MS: '10000' }));
    await Promise.all([svc.current(), svc.current(), svc.current()]);
    expect(db.query).toHaveBeenCalledTimes(2); // flags + bundles, once
    await svc.current();
    expect(db.query).toHaveBeenCalledTimes(2);
    svc.invalidate();
    await svc.current();
    expect(db.query).toHaveBeenCalledTimes(4);
    expect(await svc.flagEnabled('rooms_enabled', false)).toBe(true);
    expect(await svc.flagEnabled('missing_flag', true)).toBe(true);
  });

  it.each([
    ['"c1-abc"', '"c1-abc"', true],
    ['W/"c1-abc"', '"c1-abc"', true],
    ['"x", "c1-abc"', '"c1-abc"', true],
    ['*', '"c1-abc"', true],
    ['"c1-abd"', '"c1-abc"', false],
    [undefined, '"c1-abc"', false],
  ])('If-None-Match %j vs %s → %s', (header, etag, match) => {
    expect(etagMatches(header, etag)).toBe(match);
  });
});

describe('KillSwitchGuard', () => {
  const ctx = (spec: unknown): ExecutionContext => {
    const handler = (): void => undefined;
    if (spec) Reflect.defineMetadata(KILL_SWITCH, spec, handler);
    return { getHandler: () => handler, getClass: () => class {} } as unknown as ExecutionContext;
  };
  const guard = (flags: Record<string, boolean>): KillSwitchGuard =>
    new KillSwitchGuard(new Reflector(), { flagEnabled: async (k: string, d: boolean) => flags[k] ?? d } as never);

  it('routes without @KillSwitch are untouched', async () => {
    await expect(guard({ rooms_enabled: false }).canActivate(ctx(undefined))).resolves.toBe(true);
  });

  it('on (or missing) → through; off → 503 rooms_paused', async () => {
    await expect(guard({ rooms_enabled: true }).canActivate(ctx(ROOMS_KILL_SWITCH))).resolves.toBe(true);
    await expect(guard({}).canActivate(ctx(ROOMS_KILL_SWITCH))).resolves.toBe(true);
    const err = await guard({ rooms_enabled: false }).canActivate(ctx(ROOMS_KILL_SWITCH)).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect(err).toMatchObject({ status: 503, code: 'rooms_paused' });
  });
});

describe('lexicon diff (crisis removals need an explicit yes at publish)', () => {
  const base = baselineLexicon();
  const clone = (): LexiconDocument => structuredClone(base);

  it('identical → nothing', () => {
    expect(diffLexicons(base, clone(), 1)).toEqual({ from: 1, added: [], removed: [], changed: [], crisisFormsRemoved: 0, crisisFormsAdded: 0 });
  });

  it('counts crisis forms removed and added, entries added / removed / changed', () => {
    const next = clone();
    next.version = 2;
    next.entries = next.entries.filter((e) => e.id !== 'te-Latn.will_die');
    const kill = next.entries.find((e) => e.id === 'en.kill_myself');
    if (!kill) throw new Error('fixture');
    kill.variants = [...(kill.variants ?? []), 'kill my own self'];
    next.entries.push({ id: 'en.no_way_out', language: 'en', kind: 'crisis', phrase: 'no way out' });
    const d = diffLexicons(base, next, 1);
    expect(d.added).toEqual(['en.no_way_out']);
    expect(d.removed).toEqual(['te-Latn.will_die']);
    expect(d.changed).toEqual(['en.kill_myself']);
    const removedForms = base.entries.find((e) => e.id === 'te-Latn.will_die');
    expect(d.crisisFormsRemoved).toBe(1 + (removedForms?.variants?.length ?? 0));
    expect(d.crisisFormsAdded).toBe(2);
    // Rolling back from `next` to the baseline removes the two added forms.
    expect(diffLexicons(next, base, 2).crisisFormsRemoved).toBe(2);
  });
});
