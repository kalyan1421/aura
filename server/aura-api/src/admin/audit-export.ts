import { createHash } from 'node:crypto';
import { chmod, mkdir, rename, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { verifyAuditRange } from '../safety/audit';
import { auditConsole } from './admin-audit';
import { AdminConfig } from './admin-config';
import { AdminDb } from './admin-db';
import { MAILER, mailErrorCode, type Mailer } from './mail/mailer';

/**
 * Nightly export of the audit log (PRD 19 "Audit log: … append-only, hash-chained table, exported nightly"). Each run
 * exports every row after the last exported one (so nothing is skipped or exported twice), as NDJSON plus a manifest:
 * id range, row count, SHA-256 of the file, the last row hash, and whether the chain verifies across the range and
 * links to what came before. Destinations come from the environment only: a directory (`ADMIN_AUDIT_EXPORT_DIR`, e.g.
 * a volume synced off the box) and/or mailboxes (`ADMIN_AUDIT_EXPORT_EMAIL`, an attachment). The export itself is
 * audited (`audit_export`, with the hash), which chains every export into the log. Runs as aura_admin: the rows hold
 * hashes, codes and ids only — never content, emails or raw app account ids.
 */
export const AUDIT_EXPORT_FORMAT = 'aura-audit-export/v1';
export const AUDIT_EXPORT_ACTOR = 'system:audit_export';
const BATCH = 50_000;

export interface AuditExportRow {
  id: number;
  createdAt: string;
  actor: string;
  action: string;
  reportId: string | null;
  subjectHash: string | null;
  reasonCode: string | null;
  detail: Record<string, unknown>;
  prevHash: string | null;
  rowHash: string;
}

export interface AuditExportManifest {
  format: typeof AUDIT_EXPORT_FORMAT;
  exportedAt: string;
  trigger: 'nightly' | 'manual';
  fromId: number;
  toId: number;
  rows: number;
  /** The previous export's last id (null for the first export). */
  previousToId: number | null;
  firstPrevHash: string | null;
  lastRowHash: string;
  /** Every row's hash recomputes and each row links to the one before it (incl. the row before the range). */
  chainVerified: boolean;
  /** The first row links to the previous export's last row hash (null when there was no previous export). */
  linksToPrevious: boolean | null;
  ndjsonSha256: string;
  filename: string;
}

export type AuditExportResult =
  | { status: 'exported'; manifest: AuditExportManifest; destinations: string[]; failed: string[] }
  | { status: 'skipped'; reason: 'not_configured' | 'nothing_new' }
  | { status: 'failed'; failed: string[] };

/** Pure (unit-tested): NDJSON lines and the manifest for one batch of rows. */
export function buildAuditExport(
  rows: readonly AuditExportRow[],
  opts: { exportedAt: Date; trigger: 'nightly' | 'manual'; previous: { toId: number; lastRowHash: string } | null; chainVerified: boolean },
): { ndjson: Buffer; manifest: AuditExportManifest } {
  if (rows.length === 0) throw new Error('nothing to export');
  const ndjson = Buffer.from(rows.map((r) => JSON.stringify(r)).join('\n') + '\n', 'utf8');
  const first = rows[0];
  const last = rows[rows.length - 1];
  const stamp = opts.exportedAt.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  return {
    ndjson,
    manifest: {
      format: AUDIT_EXPORT_FORMAT,
      exportedAt: opts.exportedAt.toISOString(),
      trigger: opts.trigger,
      fromId: first.id,
      toId: last.id,
      rows: rows.length,
      previousToId: opts.previous?.toId ?? null,
      firstPrevHash: first.prevHash,
      lastRowHash: last.rowHash,
      chainVerified: opts.chainVerified,
      linksToPrevious: opts.previous ? first.prevHash === opts.previous.lastRowHash : null,
      ndjsonSha256: createHash('sha256').update(ndjson).digest('hex'),
      filename: `aura-audit-${stamp}-${first.id}-${last.id}.ndjson`,
    },
  };
}

export interface AuditExportStatus {
  configured: { dir: boolean; email: boolean; nightly: string | null; timezone: string };
  last: Array<{ id: number; createdAt: string; actor: string; trigger: string | null; fromId: number | null; toId: number | null; rows: number | null; sha256: string | null; destinations: string[]; chainVerified: boolean | null }>;
}

@Injectable()
export class AuditExportService {
  private readonly logger = new Logger('AuditExport');

  constructor(
    private readonly adminDb: AdminDb,
    private readonly config: AdminConfig,
    @Inject(MAILER) private readonly mailer: Mailer,
  ) {}

  get configured(): boolean {
    const x = this.config.auditExport;
    return !!x.dir || (x.emailTo.length > 0 && this.mailer.enabled);
  }

  /** Export everything not exported yet (in batches). `actor` = the staff member for a manual run. */
  async run(trigger: 'nightly' | 'manual', actor: string = AUDIT_EXPORT_ACTOR): Promise<AuditExportResult> {
    if (!this.configured) return { status: 'skipped', reason: 'not_configured' };
    let result: AuditExportResult = { status: 'skipped', reason: 'nothing_new' };
    for (let i = 0; i < 20; i++) {
      const one = await this.exportBatch(trigger, actor);
      if (one.status !== 'exported') return i === 0 ? one : result;
      result = one;
      if (one.manifest.rows < BATCH) break;
    }
    return result;
  }

  private async exportBatch(trigger: 'nightly' | 'manual', actor: string): Promise<AuditExportResult> {
    const { rows, previous, chainVerified } = await this.adminDb.withTx(async (tx) => {
      const prev = (
        await tx.query<{ to_id: string | null; last_hash: string | null }>(
          `select detail->>'toId' as to_id, detail->>'lastRowHash' as last_hash from public.moderation_actions
            where action = 'audit_export' order by id desc limit 1`,
        )
      ).rows[0];
      const previous = prev?.to_id && prev.last_hash ? { toId: Number(prev.to_id), lastRowHash: prev.last_hash } : null;
      const r = await tx.query<{
        id: string;
        created_at: Date;
        actor: string;
        action: string;
        report_id: string | null;
        subject_hash: string | null;
        reason_code: string | null;
        detail: Record<string, unknown>;
        prev_hash: string | null;
        row_hash: string;
      }>(
        `select id, created_at, actor, action, report_id, subject_hash, reason_code, detail, prev_hash, row_hash
           from public.moderation_actions where id > $1 order by id limit $2`,
        [previous?.toId ?? 0, BATCH],
      );
      const rows: AuditExportRow[] = r.rows.map((x) => ({
        id: Number(x.id),
        createdAt: x.created_at.toISOString(),
        actor: x.actor,
        action: x.action,
        reportId: x.report_id,
        subjectHash: x.subject_hash,
        reasonCode: x.reason_code,
        detail: x.detail,
        prevHash: x.prev_hash,
        rowHash: x.row_hash,
      }));
      const chainVerified = rows.length ? await verifyAuditRange(tx, rows[0].id, rows[rows.length - 1].id) : true;
      return { rows, previous, chainVerified };
    });
    if (rows.length === 0) return { status: 'skipped', reason: 'nothing_new' };
    const { ndjson, manifest } = buildAuditExport(rows, { exportedAt: new Date(), trigger, previous, chainVerified });
    const manifestJson = Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

    const destinations: string[] = [];
    const failed: string[] = [];
    const x = this.config.auditExport;
    if (x.dir) {
      try {
        await this.writeFiles(x.dir, manifest.filename, ndjson, manifestJson);
        destinations.push('file');
      } catch (e) {
        failed.push(`file:${(e as NodeJS.ErrnoException).code ?? 'error'}`.toLowerCase().replace(/[^a-z0-9_:]/g, '_'));
      }
    }
    if (x.emailTo.length > 0 && this.mailer.enabled) {
      try {
        await this.mailer.send({
          to: x.emailTo,
          subject: `[Aura] Audit log export #${manifest.fromId}-${manifest.toId} (${manifest.rows} rows)`,
          text: [
            `Aura moderation audit log, rows ${manifest.fromId}–${manifest.toId} (${manifest.rows}), exported ${manifest.exportedAt} (${trigger}).`,
            `Chain verified: ${manifest.chainVerified ? 'yes' : 'NO — investigate'}${manifest.linksToPrevious === false ? ' · does NOT link to the previous export' : ''}`,
            `SHA-256 of ${manifest.filename}: ${manifest.ndjsonSha256}`,
            `Last row hash: ${manifest.lastRowHash}`,
            '',
            'Rows hold hashes, codes and ids only — never content, emails or app account ids. Keep this mail as the off-box copy.',
          ].join('\n'),
          autoSubmitted: true,
          attachments: [
            { filename: manifest.filename, contentType: 'application/x-ndjson', content: ndjson },
            { filename: manifest.filename.replace(/\.ndjson$/, '.manifest.json'), contentType: 'application/json', content: manifestJson },
          ],
        });
        destinations.push('email');
      } catch (e) {
        failed.push(`email:${mailErrorCode(e)}`);
      }
    }

    if (destinations.length === 0) {
      await auditConsole(this.adminDb, actor, {
        action: 'audit_export_failed',
        reasonCode: trigger,
        detail: { fromId: manifest.fromId, toId: manifest.toId, failed },
      });
      this.logger.warn(`audit export ${manifest.fromId}-${manifest.toId} failed (${failed.join(',')})`);
      return { status: 'failed', failed };
    }
    await auditConsole(this.adminDb, actor, {
      action: 'audit_export',
      reasonCode: trigger,
      detail: {
        fromId: manifest.fromId,
        toId: manifest.toId,
        rows: manifest.rows,
        sha256: manifest.ndjsonSha256,
        lastRowHash: manifest.lastRowHash,
        chainVerified: manifest.chainVerified,
        linksToPrevious: manifest.linksToPrevious,
        destinations,
        failed,
      },
    });
    if (!manifest.chainVerified) this.logger.warn(`audit export ${manifest.fromId}-${manifest.toId}: the hash chain does NOT verify`);
    return { status: 'exported', manifest, destinations, failed };
  }

  /** Atomic: write to a temp name, then rename; files are owner-read/write only. */
  private async writeFiles(dir: string, filename: string, ndjson: Buffer, manifest: Buffer): Promise<void> {
    await mkdir(dir, { recursive: true, mode: 0o700 });
    const base = join(dir, filename);
    const manifestPath = base.replace(/\.ndjson$/, '.manifest.json');
    for (const [path, data] of [
      [base, ndjson],
      [manifestPath, manifest],
    ] as const) {
      const tmp = `${path}.tmp-${process.pid}`;
      await writeFile(tmp, data, { mode: 0o600 });
      await chmod(tmp, 0o600);
      await rename(tmp, path);
    }
  }

  /** For the console: what is configured and the latest exports (from the audit log itself). */
  async status(): Promise<AuditExportStatus> {
    const r = await this.adminDb.query<{ id: string; created_at: Date; actor: string; reason_code: string | null; detail: Record<string, unknown> }>(
      `select id, created_at, actor, reason_code, detail from public.moderation_actions
        where action in ('audit_export', 'audit_export_failed') order by id desc limit 20`,
    );
    const x = this.config.auditExport;
    const num = (v: unknown): number | null => (typeof v === 'number' ? v : typeof v === 'string' && /^\d+$/.test(v) ? Number(v) : null);
    return {
      configured: { dir: !!x.dir, email: x.emailTo.length > 0 && this.mailer.enabled, nightly: x.cron, timezone: x.tz },
      last: r.rows.map((e) => ({
        id: Number(e.id),
        createdAt: e.created_at.toISOString(),
        actor: e.actor,
        trigger: e.reason_code,
        fromId: num(e.detail.fromId),
        toId: num(e.detail.toId),
        rows: num(e.detail.rows),
        sha256: typeof e.detail.sha256 === 'string' ? e.detail.sha256 : null,
        destinations: Array.isArray(e.detail.destinations) ? (e.detail.destinations as unknown[]).filter((d): d is string => typeof d === 'string') : [],
        chainVerified: typeof e.detail.chainVerified === 'boolean' ? e.detail.chainVerified : null,
      })),
    };
  }
}
