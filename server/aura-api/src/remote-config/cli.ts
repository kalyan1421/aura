/**
 * Signed-bundle tooling (docs/setup/lexicon-and-flags.md "Key management"). Run from server/aura-api:
 *
 *   pnpm lexicon keygen
 *       A new Ed25519 key: LEXICON_SIGNING_KEY (server secret) + AURA_BUNDLE_PUBLIC_KEYS (app build define) + key id.
 *   pnpm lexicon public-key [--dev]
 *       The public key and key id of LEXICON_SIGNING_KEY (from the environment / .env), or of the development key.
 *   pnpm lexicon sign <lexicon.json> [--vectors cases.json] [--seq N] [--out bundle.json] [--dev]
 *       Validate a lexicon (contracts/safety schema), run the contract vectors + extra cases, and sign it locally, the
 *       same envelope the API serves (for fixtures and offline checks). Uses LEXICON_SIGNING_KEY, or the public
 *       development key with --dev. Publishing to phones always goes through the console (POST /admin/lexicons/crisis/*).
 *   pnpm lexicon verify <bundle.json> [--key <base64 public key>]... [--kind crisis_lexicon]
 *       Check a signed bundle the way the app does: format, known key, signature, kind, then its vectors.
 *   pnpm lexicon sign <helplines.json> --kind helplines [--seq N] [--out bundle.json] [--dev]
 *   pnpm lexicon verify <bundle.json> --kind helplines
 *       The same for the helpline directory (contracts/safety/helplines.schema.json): schema + the bundled regions, then
 *       the resolution vectors (region × adult/minor → dials) the app re-derives before it uses a version.
 *
 * Never prints the private key except from `keygen` (which is its job).
 */
import { randomBytes } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { DEFAULT_ENV_FILE, loadEnvFile } from '../config/app-config';
import { helplinesProblems, lineCount, parseHelplines, resolutionVectors } from './helplines/document';
import { contractVectors, failingVectors, lexiconProblems, matcherFor, parseLexicon, parseVectors } from './lexicon/document';
import { BundleSigner, canonicalJson, verifyBundle, trustedKeys, type BundlePayload } from './signing';

const out = (line = ''): void => {
  process.stdout.write(`${line}\n`);
};
const fail = (message: string): never => {
  process.stderr.write(`lexicon: ${message}\n`);
  process.exit(1);
};

function signerFrom(dev: boolean): BundleSigner {
  if (dev) return BundleSigner.dev();
  loadEnvFile(DEFAULT_ENV_FILE);
  const v = process.env.LEXICON_SIGNING_KEY;
  if (!v || v.trim() === '') return fail('LEXICON_SIGNING_KEY is not set (or pass --dev for the public development key)');
  try {
    return BundleSigner.fromEnvValue(v);
  } catch (err) {
    return fail((err as Error).message);
  }
}

function readJson(path: string): unknown {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return fail(`cannot read JSON from ${path}`);
  }
}

function main(argv: string[]): void {
  const [command, ...rest] = argv;
  const { values, positionals } = parseArgs({
    args: rest,
    allowPositionals: true,
    options: {
      dev: { type: 'boolean', default: false },
      vectors: { type: 'string' },
      seq: { type: 'string' },
      out: { type: 'string' },
      key: { type: 'string', multiple: true },
      kind: { type: 'string', default: 'crisis_lexicon' },
    },
  });

  switch (command) {
    case 'keygen': {
      // keygen is the one place a private key is shown.
      const seed = randomBytes(32);
      const signer = BundleSigner.fromSeed(seed);
      out('# Server secret (API env, e.g. the DigitalOcean app secret). Never commit it, never put it in the app.');
      out(`LEXICON_SIGNING_KEY=${seed.toString('base64')}`);
      out('# App build define (public). Keep the previous key listed while phones still hold bundles signed with it.');
      out(`AURA_BUNDLE_PUBLIC_KEYS=${signer.publicKeyBase64}`);
      out(`# key id: ${signer.keyId}`);
      return;
    }
    case 'public-key': {
      const signer = signerFrom(values.dev ?? false);
      out(`AURA_BUNDLE_PUBLIC_KEYS=${signer.publicKeyBase64}`);
      out(`# key id: ${signer.keyId}${signer.isDevKey ? ' (the public DEVELOPMENT key)' : ''}`);
      return;
    }
    case 'sign': {
      const [file] = positionals;
      if (values.kind === 'helplines') return signHelplines(file, values);
      if (!file) return fail('usage: pnpm lexicon sign <lexicon.json> [--vectors cases.json] [--seq N] [--out bundle.json] [--dev]');
      const raw = readJson(file);
      const problems = lexiconProblems(raw);
      if (problems.length) return fail(`invalid lexicon:\n  - ${problems.join('\n  - ')}`);
      const doc = parseLexicon(raw);
      let own: ReturnType<typeof parseVectors> = [];
      if (values.vectors) {
        const v = readJson(values.vectors) as { cases?: unknown } | unknown[];
        own = parseVectors(Array.isArray(v) ? v : v.cases);
      }
      const vectors = [...contractVectors(), ...own];
      const failures = failingVectors(matcherFor(doc), vectors);
      if (failures.length) return fail(`${failures.length} vector(s) fail: ${JSON.stringify(failures.slice(0, 10))}`);
      const seq = values.seq ? Number(values.seq) : Date.now();
      if (!Number.isSafeInteger(seq) || seq < 1) return fail('--seq must be a positive integer');
      const signer = signerFrom(values.dev ?? false);
      const payload: BundlePayload = { kind: 'crisis_lexicon', seq, issuedAt: new Date().toISOString(), version: doc.version, content: doc, vectors };
      const text = `${JSON.stringify(signer.sign(payload), null, 2)}\n`;
      if (values.out) {
        writeFileSync(values.out, text);
        out(`signed v${doc.version} (seq ${seq}, key ${signer.keyId}${signer.isDevKey ? ', DEVELOPMENT key' : ''}) → ${values.out}`);
      } else {
        process.stdout.write(text);
      }
      return;
    }
    case 'verify': {
      const [file] = positionals;
      if (!file) return fail('usage: pnpm lexicon verify <bundle.json> [--key <base64 public key>]...');
      const keys = values.key?.length ? values.key : [BundleSigner.dev().publicKeyBase64];
      let payload: BundlePayload;
      try {
        payload = verifyBundle(readJson(file), trustedKeys(keys), values.kind ?? 'crisis_lexicon');
      } catch (err) {
        return fail((err as Error).message);
      }
      if (payload.kind === 'helplines') {
        const problems = helplinesProblems(payload.content);
        if (problems.length) return fail(`invalid directory:\n  - ${problems.join('\n  - ')}`);
        const directory = parseHelplines(payload.content);
        const same = canonicalJson(resolutionVectors(directory)) === canonicalJson(payload.vectors);
        out(`ok: helplines v${payload.version}, seq ${payload.seq}, issued ${payload.issuedAt}, ${lineCount(directory)} lines`);
        out(same ? `all ${payload.vectors.length} vectors match` : 'but its vectors do not match the directory');
        if (!same) process.exit(1);
        return;
      }
      const doc = parseLexicon(payload.content);
      const failures = failingVectors(matcherFor(doc), parseVectors(payload.vectors));
      out(`ok: ${payload.kind} v${payload.version}, seq ${payload.seq}, issued ${payload.issuedAt}, ${doc.entries.length} entries`);
      out(failures.length ? `but ${failures.length} of its vectors fail` : `all ${payload.vectors.length} vectors pass`);
      if (failures.length) process.exit(1);
      return;
    }
    default:
      fail('commands: keygen | public-key [--dev] | sign <lexicon.json> | verify <bundle.json>');
  }
}

function signHelplines(file: string | undefined, values: { dev?: boolean; seq?: string; out?: string }): void {
  if (!file) return fail('usage: pnpm lexicon sign <helplines.json> --kind helplines [--seq N] [--out bundle.json] [--dev]');
  const raw = readJson(file);
  const problems = helplinesProblems(raw);
  if (problems.length) return fail(`invalid directory:\n  - ${problems.join('\n  - ')}`);
  const doc = parseHelplines(raw);
  const seq = values.seq ? Number(values.seq) : Date.now();
  if (!Number.isSafeInteger(seq) || seq < 1) return fail('--seq must be a positive integer');
  const signer = signerFrom(values.dev ?? false);
  const payload: BundlePayload = {
    kind: 'helplines',
    seq,
    issuedAt: new Date().toISOString(),
    version: doc.version,
    content: doc,
    vectors: resolutionVectors(doc),
  };
  const text = `${JSON.stringify(signer.sign(payload), null, 2)}\n`;
  if (values.out) {
    writeFileSync(values.out, text);
    out(`signed helplines v${doc.version} (seq ${seq}, key ${signer.keyId}${signer.isDevKey ? ', DEVELOPMENT key' : ''}) → ${values.out}`);
  } else {
    process.stdout.write(text);
  }
}

main(process.argv.slice(2));
