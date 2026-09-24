import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import { ApiError } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { pgCode, type Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { appendAudit } from '../safety/audit';
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
import {
  baselineHelplines,
  diffHelplines,
  helplinesProblems,
  lineCount,
  parseHelplines,
  resolutionVectors,
  type HelplinesDiff,
  type HelplinesDocument,
} from './helplines/document';
import { LexiconRejectedError } from './lexicon.service';
import { RemoteConfigSettings } from './remote-config.config';
import { RemoteConfigService } from './remote-config.service';
import { BUNDLE_FORMAT, canonicalJson, sha256Hex, type SignedBundle } from './signing';

/**
 * Signed, reversible versions of the crisis helpline directory (PRD 18 "Helplines by country": remote config keyed by
 * country, localized, cached on device; 06c F9 / REQ-SAFE-02; PRD 19 "config … publish signed, roll back"). The same
 * machinery as the crisis lexicon (lexicon.service.ts, docs/setup/lexicon-and-flags.md):
 *
 *  - **Upload** stores an immutable version after the contracts/safety/helplines.schema.json check (what is shown is
 *    what is dialled, every region keeps a line for everyone, the bundled regions India + US stay listed).
 *  - **Publish** moves the live pointer to any stored version — forward, or back (a rollback) — and signs a new
 *    envelope with a higher `seq`: `{kind: "helplines", seq, issuedAt, version, content, vectors}` where `vectors` is
 *    every region × {adult, minor} → the dial list. Dropping a number phones list now (or a whole region) needs
 *    `allowRemovals: true` (Owner). Every upload, publish and rollback is in the hash-chained audit log, same transaction.
 *  - The app (`GET /v1/helplines`) verifies the signature with the key it embeds, refuses an older seq, re-checks the
 *    schema and re-derives every vector with its own resolver before the numbers replace the ones it shows; otherwise
 *    it keeps its last verified directory, else the bundled one — a bad or unsigned bundle never replaces working
 *    numbers.
 */
export const HELPLINES_KIND: BundleKind = 'helplines';

export const HELPLINES_ACTIONS = { upload: 'helplines_upload', publish: 'helplines_publish', rollback: 'helplines_rollback' } as const;

const reasonCode = z.string().regex(/^[a-z0-9_]{1,40}$/, 'must be a reason code ([a-z0-9_], at most 40)');

export const helplinesUploadSchema = z.object({
  helplines: z.record(z.string(), z.unknown()),
  note: z.string().trim().max(500).optional(),
});

export const helplinesPublishSchema = z.object({
  version: z.number().int().min(1),
  reasonCode,
  /** Acknowledges that numbers (or regions) phones list now disappear. */
  allowRemovals: z.boolean().optional(),
  /** Sign the live version again (after a key rotation). */
  resign: z.boolean().optional(),
});

const invalid = (problems: string[]): LexiconRejectedError =>
  new LexiconRejectedError(
    HttpStatus.UNPROCESSABLE_ENTITY,
    'helplines_invalid',
    'The helpline directory does not follow contracts/safety/helplines.schema.json.',
    problems.slice(0, 50),
  );

export interface HelplinesOverview {
  kind: BundleKind;
  live: { version: number; seq: number; keyId: string; publishedAt: string; publishedBy: string } | null;
  bundledVersion: number;
  requiredCountries: string[];
  signing: { available: boolean; keyId: string | null; devKey: boolean; offReason: string | null };
  versions: Array<VersionSummary & { live: boolean }>;
  history: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null; detail: Record<string, unknown> }>;
}

@Injectable()
export class HelplinesService {
  private readonly logger = new Logger('HelplinesService');
  private cached: { envelope: CurrentEnvelope | null; at: number } | null = null;

  constructor(
    private readonly db: DbService,
    private readonly settings: RemoteConfigSettings,
    private readonly config: RemoteConfigService,
  ) {}

  // ------------------------------------------------------------------ public read (GET /v1/helplines)

  async live(now = Date.now()): Promise<CurrentEnvelope | null> {
    const c = this.cached;
    if (c && now - c.at < this.settings.cacheMs) return c.envelope;
    const envelope = await findCurrent(this.db, HELPLINES_KIND);
    this.cached = { envelope, at: Date.now() };
    return envelope;
  }

  static wire(e: CurrentEnvelope): SignedBundle {
    return { format: BUNDLE_FORMAT, keyId: e.keyId, payload: e.payload, signature: e.signature };
  }

  // ------------------------------------------------------------------ console (/admin/helplines)

  async overview(): Promise<HelplinesOverview> {
    return this.db.withTx(async (tx) => {
      const live = await findCurrent(tx, HELPLINES_KIND);
      const versions = await listVersions(tx, HELPLINES_KIND);
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
        [Object.values(HELPLINES_ACTIONS), HELPLINES_KIND],
      );
      const s = this.settings;
      const base = baselineHelplines();
      return {
        kind: HELPLINES_KIND,
        live: live && { version: live.version, seq: live.seq, keyId: live.keyId, publishedAt: live.publishedAt, publishedBy: live.publishedBy },
        bundledVersion: base.version,
        requiredCountries: Object.keys(base.countries),
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

  /** One stored version: the directory and what the app would list per region (the console renders both). */
  async version(version: number): Promise<{
    version: number;
    contentSha256: string;
    helplines: unknown;
    vectors: ReturnType<typeof resolutionVectors>;
    note: string | null;
    createdAt: string;
    createdBy: string;
  }> {
    const v = await findVersion(this.db, HELPLINES_KIND, version);
    if (!v) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That helpline directory version does not exist.');
    const doc = parseHelplines(v.content);
    return {
      version: v.version,
      contentSha256: v.contentSha256,
      helplines: v.content,
      vectors: resolutionVectors(doc),
      note: v.note,
      createdAt: v.createdAt,
      createdBy: v.createdBy,
    };
  }

  /** Stores a new version (not live yet). */
  async upload(actor: string, body: unknown): Promise<{ version: number; contentSha256: string; lines: number; diff: HelplinesDiff }> {
    const b = parseOrThrow(helplinesUploadSchema, body);
    const problems = helplinesProblems(b.helplines);
    if (problems.length) throw invalid(problems);
    return this.store(actor, parseHelplines(b.helplines), b.note ?? null, false);
  }

  /** Stores the app's bundled directory (contracts/safety/helplines.v1.json) as its version, so it can be (re)published. */
  async uploadBaseline(actor: string): Promise<{ version: number; contentSha256: string; lines: number; diff: HelplinesDiff }> {
    return this.store(actor, baselineHelplines(), 'Bundled baseline (contracts/safety/helplines.v1.json)', true);
  }

  private async store(
    actor: string,
    doc: HelplinesDocument,
    note: string | null,
    baseline: boolean,
  ): Promise<{ version: number; contentSha256: string; lines: number; diff: HelplinesDiff }> {
    const contentSha256 = sha256Hex(canonicalJson(doc));
    try {
      return await this.db.withTx(async (tx) => {
        await lockKind(tx, HELPLINES_KIND);
        const newest = (
          await tx.query<{ v: number | null }>('select max(version) as v from public.signed_bundle_versions where kind = $1', [HELPLINES_KIND])
        ).rows[0]?.v;
        if (await findVersion(tx, HELPLINES_KIND, doc.version)) {
          throw ApiError.conflict('version_exists', `Helpline directory version ${doc.version} is already stored; versions never change. Bump \`version\`.`);
        }
        if (!baseline && newest != null && doc.version <= newest) {
          throw ApiError.conflict('version_not_newer', `A new helpline directory version must be greater than ${newest}.`);
        }
        await insertVersion(tx, { kind: HELPLINES_KIND, version: doc.version, content: doc, contentSha256, vectors: [], note, createdBy: actor });
        const live = await findCurrent(tx, HELPLINES_KIND);
        const from = live ? await this.liveDocument(tx, live) : null;
        const diff = diffHelplines(from ?? baselineHelplines(), doc, from ? from.version : null);
        await appendAudit(tx, {
          actor,
          action: HELPLINES_ACTIONS.upload,
          reasonCode: baseline ? 'bundled_baseline' : 'new_version',
          detail: { kind: HELPLINES_KIND, version: doc.version, sha256: contentSha256, lines: lineCount(doc), ...diffCounts(diff) },
        });
        return { version: doc.version, contentSha256, lines: lineCount(doc), diff };
      });
    } catch (err) {
      if (pgCode(err) === '23505') throw ApiError.conflict('version_exists', `Helpline directory version ${doc.version} is already stored.`);
      throw err;
    }
  }

  /** Makes a stored version live (forward or back): a new signed envelope with a higher seq, audited. */
  async publish(
    actor: string,
    body: unknown,
  ): Promise<{ version: number; previousVersion: number | null; seq: number; keyId: string; publishedAt: string; action: string }> {
    const b = parseOrThrow(helplinesPublishSchema, body);
    const signer = this.settings.signer;
    if (!signer) {
      throw new ApiError(HttpStatus.SERVICE_UNAVAILABLE, 'signing_unavailable', 'Bundle signing is off on this server (set LEXICON_SIGNING_KEY).');
    }
    const out = await this.db.withTx(async (tx) => {
      await lockKind(tx, HELPLINES_KIND);
      const target = await findVersion(tx, HELPLINES_KIND, b.version);
      if (!target) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That helpline directory version does not exist.');
      if (sha256Hex(canonicalJson(target.content)) !== target.contentSha256) {
        throw ApiError.conflict('version_tampered', 'This version no longer matches its recorded hash; it cannot be published.');
      }
      // Checked again at publish: the rules (e.g. the regions the app bundles) are the ones phones apply today.
      const problems = helplinesProblems(target.content);
      if (problems.length) throw invalid(problems);
      const doc = parseHelplines(target.content);

      const live = await findCurrent(tx, HELPLINES_KIND);
      if (live && live.version === doc.version && !b.resign) {
        throw ApiError.conflict('already_live', `Version ${doc.version} is already live (pass resign: true to sign it again).`);
      }
      const from = live ? await this.liveDocument(tx, live) : baselineHelplines();
      const diff = diffHelplines(from, doc, live ? live.version : null);
      if ((diff.numbersRemoved > 0 || diff.countriesRemoved.length > 0) && !b.allowRemovals) {
        throw new LexiconRejectedError(
          HttpStatus.CONFLICT,
          'helplines_removed',
          `Version ${doc.version} stops listing ${diff.numbersRemoved} number(s) phones show now. Confirm with allowRemovals: true (Owner only).`,
          { numbersRemoved: diff.numbersRemoved, countriesRemoved: diff.countriesRemoved, removedLines: diff.removed },
        );
      }
      const seq = Math.max((live?.seq ?? 0) + 1, Date.now());
      const issuedAt = new Date().toISOString();
      const signed = signer.sign({ kind: HELPLINES_KIND, seq, issuedAt, version: doc.version, content: doc, vectors: resolutionVectors(doc) });
      const saved = await upsertCurrent(tx, {
        kind: HELPLINES_KIND,
        version: doc.version,
        seq,
        keyId: signed.keyId,
        payload: signed.payload,
        signature: signed.signature,
        publishedBy: actor,
      });
      const action = live && doc.version < live.version ? HELPLINES_ACTIONS.rollback : HELPLINES_ACTIONS.publish;
      await appendAudit(tx, {
        actor,
        action,
        reasonCode: b.reasonCode,
        detail: { kind: HELPLINES_KIND, version: doc.version, previousVersion: live?.version ?? null, seq, keyId: signed.keyId, resign: !!b.resign, ...diffCounts(diff) },
      });
      return { version: doc.version, previousVersion: live?.version ?? null, seq, keyId: saved.keyId, publishedAt: saved.publishedAt, action };
    });
    this.cached = null;
    this.config.invalidate();
    this.logger.log(`helpline directory v${out.version} is live (${out.action}, seq ${out.seq}, key ${out.keyId})`);
    return out;
  }

  private async liveDocument(q: Queryable, live: CurrentEnvelope): Promise<HelplinesDocument> {
    const v = await findVersion(q, HELPLINES_KIND, live.version);
    return v ? parseHelplines(v.content) : baselineHelplines();
  }
}

/** Counts only, for the audit row. */
function diffCounts(d: HelplinesDiff): Record<string, number> {
  return {
    linesAdded: d.added.length,
    linesRemoved: d.removed.length,
    linesChanged: d.changed.length,
    numbersRemoved: d.numbersRemoved,
    countriesRemoved: d.countriesRemoved.length,
  };
}
