import { ArgumentsHost, Catch, HttpStatus, Injectable, Logger, type ExceptionFilter } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { pgCode, type Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { appendAudit } from '../safety/audit';
import {
  baselineLexicon,
  contractVectors,
  crisisForms,
  failingVectors,
  languagesWithoutCrisis,
  lexiconProblems,
  matcherFor,
  parseLexicon,
  parseVectors,
  type LexiconDocument,
  type LexiconVector,
  type VectorFailure,
} from './lexicon/document';
import type { LexiconVerdict } from './lexicon/matcher';
import {
  findCurrent,
  findVersion,
  insertVersion,
  listVersions,
  lockKind,
  upsertCurrent,
  type BundleKind,
  type CurrentEnvelope,
  type VersionSummary,
} from './bundles.repository';
import { RemoteConfigSettings } from './remote-config.config';
import { RemoteConfigService } from './remote-config.service';
import { BUNDLE_FORMAT, canonicalJson, sha256Hex, type SignedBundle } from './signing';

/**
 * Signed, reversible crisis lexicon versions (PRD 19 REQ-ADM-12 "lexicon versions are signed and reversible";
 * 06c F9 "versioned signed bundle … refreshed on sync"; contracts/api/v1.md "Crisis lexicon versions").
 *
 *  - **Upload** stores an immutable version after the contracts/safety schema check and a vector run: every case in
 *    contracts/safety/crisis_lexicon.vectors.json plus the version's own cases must pass with the TypeScript matcher
 *    (the app's rules, line by line), and each shipped language (en, te, te-Latn) keeps a crisis entry.
 *  - **Publish** moves the live pointer to any stored version — forward, or back (a rollback) — and signs a new
 *    envelope with a higher `seq`. Dropping crisis forms that the live version (or, before any publish, the app's
 *    bundled baseline) has needs `allowCrisisRemovals: true` (Owner only, PRD 19 "Removing a crisis term … is
 *    Owner-only"). Every upload, publish and rollback is written to the append-only, hash-chained audit log in the same
 *    transaction.
 *  - The app downloads the live envelope (`GET /v1/lexicon/crisis`), verifies the signature with the key it embeds,
 *    re-runs the envelope's vectors with its own matcher, and only then uses it; otherwise it keeps its last verified
 *    version, else its bundled v1.
 *
 * Lexicon text and test samples are never logged.
 */
export const LEXICON_KIND: BundleKind = 'crisis_lexicon';

export const LEXICON_ACTIONS = { upload: 'lexicon_upload', publish: 'lexicon_publish', rollback: 'lexicon_rollback' } as const;

const reasonCode = z.string().regex(/^[a-z0-9_]{1,40}$/, 'must be a reason code ([a-z0-9_], at most 40)');

export const uploadSchema = z.object({
  lexicon: z.record(z.string(), z.unknown()),
  vectors: z.array(z.unknown()).max(2000).optional(),
  note: z.string().trim().max(500).optional(),
});

export const testSchema = z
  .object({
    version: z.number().int().min(1).optional(),
    lexicon: z.record(z.string(), z.unknown()).optional(),
    samples: z.array(z.string().max(500)).min(1).max(50),
  })
  .refine((b) => !(b.version !== undefined && b.lexicon !== undefined), 'give a version or a lexicon, not both');

export const publishSchema = z.object({
  version: z.number().int().min(1),
  reasonCode,
  /** Acknowledges that crisis forms of the live version disappear (a rollback past an addition, or a removal). */
  allowCrisisRemovals: z.boolean().optional(),
  /** Sign the live version again (after a key rotation); otherwise publishing the live version is refused. */
  resign: z.boolean().optional(),
});

/** A refusal with machine-readable details (`{ code, message, details }`), written by LexiconErrorFilter. */
export class LexiconRejectedError extends ApiError {
  constructor(status: HttpStatus, code: string, message: string, readonly details: unknown) {
    super(status, code, message);
    this.name = 'LexiconRejectedError';
  }
}

@Catch(LexiconRejectedError)
export class LexiconErrorFilter implements ExceptionFilter {
  catch(e: LexiconRejectedError, host: ArgumentsHost): void {
    const res = host.switchToHttp().getResponse<Response>();
    if (res.headersSent) return;
    res.status(e.status).json({ code: e.code, message: e.message, details: e.details });
  }
}

const invalid = (problems: string[]): LexiconRejectedError =>
  new LexiconRejectedError(HttpStatus.UNPROCESSABLE_ENTITY, 'lexicon_invalid', 'The lexicon does not follow contracts/safety.', problems.slice(0, 50));

export interface LabelledFailure extends VectorFailure {
  source: 'contract' | 'version';
}

export interface LexiconDiff {
  from: number | null;
  added: string[];
  removed: string[];
  changed: string[];
  crisisFormsRemoved: number;
  crisisFormsAdded: number;
}

export interface LexiconOverview {
  kind: BundleKind;
  live: { version: number; seq: number; keyId: string; publishedAt: string; publishedBy: string } | null;
  bundledVersion: number;
  signing: { available: boolean; keyId: string | null; devKey: boolean; offReason: string | null };
  versions: Array<VersionSummary & { live: boolean }>;
  history: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null; detail: Record<string, unknown> }>;
}

@Injectable()
export class LexiconService {
  private readonly logger = new Logger('LexiconService');
  private cached: { envelope: CurrentEnvelope | null; at: number } | null = null;

  constructor(
    private readonly db: DbService,
    private readonly settings: RemoteConfigSettings,
    private readonly config: RemoteConfigService,
  ) {}

  // ------------------------------------------------------------------ public read (GET /v1/lexicon/crisis)

  /** The live signed envelope, or null before the first publish. Cached like the config document. */
  async live(now = Date.now()): Promise<CurrentEnvelope | null> {
    const c = this.cached;
    if (c && now - c.at < this.settings.cacheMs) return c.envelope;
    const envelope = await findCurrent(this.db, LEXICON_KIND);
    this.cached = { envelope, at: Date.now() };
    return envelope;
  }

  static wire(e: CurrentEnvelope): SignedBundle {
    return { format: BUNDLE_FORMAT, keyId: e.keyId, payload: e.payload, signature: e.signature };
  }

  // ------------------------------------------------------------------ console (Owner only, /admin/lexicons/crisis)

  async overview(): Promise<LexiconOverview> {
    return this.db.withTx(async (tx) => {
      const live = await findCurrent(tx, LEXICON_KIND);
      const versions = await listVersions(tx, LEXICON_KIND);
      const history = await tx.query<{
        id: string;
        created_at: Date;
        actor: string;
        action: string;
        reason_code: string | null;
        detail: Record<string, unknown>;
      }>(
        `select id, created_at, actor, action, reason_code, detail from public.moderation_actions
          where action = any($1::text[]) and detail ->> 'kind' = $2 order by id desc limit 50`,
        [Object.values(LEXICON_ACTIONS), LEXICON_KIND],
      );
      const s = this.settings;
      return {
        kind: LEXICON_KIND,
        live: live && { version: live.version, seq: live.seq, keyId: live.keyId, publishedAt: live.publishedAt, publishedBy: live.publishedBy },
        bundledVersion: baselineLexicon().version,
        signing: { available: !!s.signer, keyId: s.signer?.keyId ?? null, devKey: !!s.signer?.isDevKey, offReason: s.signingOffReason },
        versions: versions.map((v) => ({ ...v, live: live?.version === v.version })),
        history: history.rows.map((h) => ({
          id: Number(h.id),
          createdAt: h.created_at.toISOString(),
          actor: h.actor,
          action: h.action,
          reasonCode: h.reason_code,
          detail: h.detail,
        })),
      };
    });
  }

  /** One stored version with its content and own test cases (the console's editor starts from it). */
  async version(version: number): Promise<{ version: number; contentSha256: string; lexicon: unknown; vectors: unknown[]; note: string | null; createdAt: string; createdBy: string }> {
    const v = await findVersion(this.db, LEXICON_KIND, version);
    if (!v) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That lexicon version does not exist.');
    return { version: v.version, contentSha256: v.contentSha256, lexicon: v.content, vectors: v.vectors, note: v.note, createdAt: v.createdAt, createdBy: v.createdBy };
  }

  /** Stores a new version (not live yet). */
  async upload(actor: string, body: unknown): Promise<{ version: number; contentSha256: string; entries: number; diff: LexiconDiff }> {
    const b = parseOrThrow(uploadSchema, body);
    const problems = lexiconProblems(b.lexicon);
    if (problems.length) throw invalid(problems);
    const doc = parseLexicon(b.lexicon);
    const own = this.vectorsOrThrow(b.vectors ?? []);
    this.checkPublishable(doc, own);
    return this.store(actor, doc, own, b.note ?? null, false);
  }

  /** Stores the app's bundled baseline (contracts/safety/crisis_lexicon.v1.json) as version 1, so it can be (re)published. */
  async uploadBaseline(actor: string): Promise<{ version: number; contentSha256: string; entries: number; diff: LexiconDiff }> {
    const doc = baselineLexicon();
    this.checkPublishable(doc, []);
    return this.store(actor, doc, [], 'Bundled baseline (contracts/safety/crisis_lexicon.v1.json)', true);
  }

  private async store(
    actor: string,
    doc: LexiconDocument,
    own: LexiconVector[],
    note: string | null,
    baseline: boolean,
  ): Promise<{ version: number; contentSha256: string; entries: number; diff: LexiconDiff }> {
    const contentSha256 = sha256Hex(canonicalJson(doc));
    try {
      return await this.db.withTx(async (tx) => {
        await lockKind(tx, LEXICON_KIND);
        const newest = (await tx.query<{ v: number | null }>('select max(version) as v from public.signed_bundle_versions where kind = $1', [LEXICON_KIND]))
          .rows[0]?.v;
        if (await findVersion(tx, LEXICON_KIND, doc.version)) {
          throw ApiError.conflict('version_exists', `Lexicon version ${doc.version} is already stored; versions never change. Bump \`version\`.`);
        }
        if (!baseline && newest != null && doc.version <= newest) {
          throw ApiError.conflict('version_not_newer', `A new lexicon version must be greater than ${newest}.`);
        }
        await insertVersion(tx, { kind: LEXICON_KIND, version: doc.version, content: doc, contentSha256, vectors: own, note, createdBy: actor });
        const live = await findCurrent(tx, LEXICON_KIND);
        const from = live ? await this.liveDocument(tx, live) : null;
        const diff = diffLexicons(from ?? baselineLexicon(), doc, from ? from.version : null);
        await appendAudit(tx, {
          actor,
          action: LEXICON_ACTIONS.upload,
          reasonCode: baseline ? 'bundled_baseline' : 'new_version',
          detail: { kind: LEXICON_KIND, version: doc.version, sha256: contentSha256, entries: doc.entries.length, vectors: own.length, ...diffCounts(diff) },
        });
        return { version: doc.version, contentSha256, entries: doc.entries.length, diff };
      });
    } catch (err) {
      if (pgCode(err) === '23505') throw ApiError.conflict('version_exists', `Lexicon version ${doc.version} is already stored.`);
      throw err;
    }
  }

  /** "Test on samples" (PRD 19): verdicts for staff-typed samples against a stored version or a draft. Nothing is kept. */
  async test(body: unknown): Promise<{ version: number | null; results: Array<{ index: number; verdict: LexiconVerdict }> }> {
    const b = parseOrThrow(testSchema, body);
    let doc: LexiconDocument;
    if (b.lexicon) {
      const problems = lexiconProblems(b.lexicon);
      if (problems.length) throw invalid(problems);
      doc = parseLexicon(b.lexicon);
    } else if (b.version !== undefined) {
      const v = await findVersion(this.db, LEXICON_KIND, b.version);
      if (!v) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That lexicon version does not exist.');
      doc = parseLexicon(v.content);
    } else {
      const live = await findCurrent(this.db, LEXICON_KIND);
      doc = live ? await this.liveDocument(this.db, live) : baselineLexicon();
    }
    const matcher = matcherFor(doc);
    return { version: b.lexicon ? null : doc.version, results: b.samples.map((s, index) => ({ index, verdict: matcher.verdict(s) })) };
  }

  /** Makes a stored version live (forward or back): a new signed envelope with a higher seq, audited. */
  async publish(actor: string, body: unknown): Promise<{ version: number; previousVersion: number | null; seq: number; keyId: string; publishedAt: string; action: string }> {
    const b = parseOrThrow(publishSchema, body);
    const signer = this.settings.signer;
    if (!signer) {
      throw new ApiError(HttpStatus.SERVICE_UNAVAILABLE, 'signing_unavailable', 'Lexicon signing is off on this server (set LEXICON_SIGNING_KEY).');
    }
    const out = await this.db.withTx(async (tx) => {
      await lockKind(tx, LEXICON_KIND);
      const target = await findVersion(tx, LEXICON_KIND, b.version);
      if (!target) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That lexicon version does not exist.');
      // Versions are immutable (a DB trigger refuses changes); still, never sign content that doesn't hash to its record.
      if (sha256Hex(canonicalJson(target.content)) !== target.contentSha256) {
        throw ApiError.conflict('version_tampered', 'This version no longer matches its recorded hash; it cannot be published.');
      }
      const problems = lexiconProblems(target.content);
      if (problems.length) throw invalid(problems);
      const doc = parseLexicon(target.content);
      const own = this.vectorsOrThrow(target.vectors);
      this.checkPublishable(doc, own);

      const live = await findCurrent(tx, LEXICON_KIND);
      if (live && live.version === doc.version && !b.resign) {
        throw ApiError.conflict('already_live', `Version ${doc.version} is already live (pass resign: true to sign it again).`);
      }
      const from = live ? await this.liveDocument(tx, live) : baselineLexicon();
      const diff = diffLexicons(from, doc, live ? live.version : null);
      if (diff.crisisFormsRemoved > 0 && !b.allowCrisisRemovals) {
        throw new LexiconRejectedError(
          HttpStatus.CONFLICT,
          'crisis_terms_removed',
          `Version ${doc.version} drops ${diff.crisisFormsRemoved} crisis form(s) that phones use now. Confirm with allowCrisisRemovals: true (Owner only).`,
          { crisisFormsRemoved: diff.crisisFormsRemoved, removedEntries: diff.removed },
        );
      }
      const seq = Math.max((live?.seq ?? 0) + 1, Date.now());
      const issuedAt = new Date().toISOString();
      const signed = signer.sign({ kind: LEXICON_KIND, seq, issuedAt, version: doc.version, content: doc, vectors: [...contractVectors(), ...own] });
      const saved = await upsertCurrent(tx, { kind: LEXICON_KIND, version: doc.version, seq, keyId: signed.keyId, payload: signed.payload, signature: signed.signature, publishedBy: actor });
      const action = live && doc.version < live.version ? LEXICON_ACTIONS.rollback : LEXICON_ACTIONS.publish;
      await appendAudit(tx, {
        actor,
        action,
        reasonCode: b.reasonCode,
        detail: { kind: LEXICON_KIND, version: doc.version, previousVersion: live?.version ?? null, seq, keyId: signed.keyId, resign: !!b.resign, ...diffCounts(diff) },
      });
      return { version: doc.version, previousVersion: live?.version ?? null, seq, keyId: saved.keyId, publishedAt: saved.publishedAt, action };
    });
    this.cached = null;
    this.config.invalidate();
    this.logger.log(`crisis lexicon v${out.version} is live (${out.action}, seq ${out.seq}, key ${out.keyId})`);
    return out;
  }

  // ------------------------------------------------------------------ helpers

  private async liveDocument(q: Queryable, live: CurrentEnvelope): Promise<LexiconDocument> {
    const v = await findVersion(q, LEXICON_KIND, live.version);
    return v ? parseLexicon(v.content) : baselineLexicon();
  }

  private vectorsOrThrow(raw: unknown[]): LexiconVector[] {
    try {
      return parseVectors(raw);
    } catch (err) {
      const problems = (err as { problems?: string[] }).problems ?? ['vectors are invalid'];
      throw new LexiconRejectedError(HttpStatus.UNPROCESSABLE_ENTITY, 'lexicon_vectors_invalid', 'The test cases are not in the contract shape.', problems);
    }
  }

  /** Contract + own vectors must pass, and each shipped language keeps a crisis entry. */
  private checkPublishable(doc: LexiconDocument, own: readonly LexiconVector[]): void {
    const missing = languagesWithoutCrisis(doc);
    if (missing.length) {
      throw new LexiconRejectedError(
        HttpStatus.UNPROCESSABLE_ENTITY,
        'lexicon_missing_language',
        `Every shipped language needs at least one crisis entry (missing: ${missing.join(', ')}).`,
        missing,
      );
    }
    const matcher = matcherFor(doc);
    const failures: LabelledFailure[] = [
      ...failingVectors(matcher, contractVectors()).map((f) => ({ ...f, source: 'contract' as const })),
      ...failingVectors(matcher, own).map((f) => ({ ...f, source: 'version' as const })),
    ];
    if (failures.length) {
      throw new LexiconRejectedError(
        HttpStatus.UNPROCESSABLE_ENTITY,
        'lexicon_vectors_failed',
        `${failures.length} test case(s) fail with this lexicon (contracts/safety/crisis_lexicon.vectors.json and the version's own cases).`,
        failures.slice(0, 100),
      );
    }
  }
}

function entryKey(e: LexiconDocument['entries'][number]): string {
  return canonicalJson({ language: e.language, kind: e.kind, stem: e.stem === true, forms: [e.phrase, ...(e.variants ?? [])] });
}

export function diffLexicons(from: LexiconDocument, to: LexiconDocument, fromVersion: number | null): LexiconDiff {
  const before = new Map(from.entries.map((e) => [e.id, entryKey(e)]));
  const after = new Map(to.entries.map((e) => [e.id, entryKey(e)]));
  const added = [...after.keys()].filter((id) => !before.has(id));
  const removed = [...before.keys()].filter((id) => !after.has(id));
  const changed = [...after.keys()].filter((id) => before.has(id) && before.get(id) !== after.get(id));
  const crisisBefore = crisisForms(from);
  const crisisAfter = crisisForms(to);
  return {
    from: fromVersion,
    added,
    removed,
    changed,
    crisisFormsRemoved: [...crisisBefore].filter((f) => !crisisAfter.has(f)).length,
    crisisFormsAdded: [...crisisAfter].filter((f) => !crisisBefore.has(f)).length,
  };
}

/** Counts only, for the audit row (ids and forms stay out of the log). */
function diffCounts(d: LexiconDiff): Record<string, number> {
  return {
    entriesAdded: d.added.length,
    entriesRemoved: d.removed.length,
    entriesChanged: d.changed.length,
    crisisFormsRemoved: d.crisisFormsRemoved,
    crisisFormsAdded: d.crisisFormsAdded,
  };
}
