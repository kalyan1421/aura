/**
 * PRD 19 "Audit log … exported nightly": each run exports every row after the last export (no gaps, no repeats) as NDJSON
 * + a manifest (range, SHA-256, last row hash, chain check, link to the previous export) to the configured directory
 * and/or mailboxes (a multipart attachment), and audits itself; a run that reaches no destination is audited as failed
 * and does not advance. Nothing is exported when nothing is configured.
 */
import { createHash } from 'node:crypto';
import { mkdtemp, readFile, readdir, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseAdminConfig } from '../../src/admin/admin-config';
import type { AdminDb } from '../../src/admin/admin-db';
import { AuditExportService, buildAuditExport, type AuditExportRow } from '../../src/admin/audit-export';
import { DisabledMailer, type Mailer, type MailMessage } from '../../src/admin/mail/mailer';
import { buildMessage } from '../../src/admin/mail/smtp';

const row = (id: number, prev: string | null): AuditExportRow => ({
  id,
  createdAt: new Date(Date.UTC(2026, 9, 12, 0, id)).toISOString(),
  actor: id % 2 ? 'staff:0192f0c2-7a4e-7c1a-9b3d-000000000001' : 'system:pager',
  action: 'strike',
  reportId: null,
  subjectHash: 'a'.repeat(64),
  reasonCode: 'harassment',
  detail: { lane: 'harassment' },
  prevHash: prev,
  rowHash: String(id).padStart(64, '0'),
});

describe('buildAuditExport (pure)', () => {
  it('NDJSON + manifest: range, count, SHA-256 of the exact bytes, last hash, link to the previous export', () => {
    const rows = [row(11, '0'.repeat(62) + '10'), row(12, row(11, null).rowHash)];
    const at = new Date('2026-10-12T21:00:00.000Z');
    const { ndjson, manifest } = buildAuditExport(rows, { exportedAt: at, trigger: 'nightly', previous: { toId: 10, lastRowHash: '0'.repeat(62) + '10' }, chainVerified: true });
    expect(ndjson.toString('utf8').trim().split('\n').map((l) => JSON.parse(l))).toEqual(rows);
    expect(manifest).toMatchObject({
      format: 'aura-audit-export/v1',
      fromId: 11,
      toId: 12,
      rows: 2,
      previousToId: 10,
      linksToPrevious: true,
      chainVerified: true,
      lastRowHash: rows[1].rowHash,
      ndjsonSha256: createHash('sha256').update(ndjson).digest('hex'),
      filename: 'aura-audit-20261012T210000Z-11-12.ndjson',
    });
    expect(buildAuditExport(rows, { exportedAt: at, trigger: 'manual', previous: { toId: 10, lastRowHash: 'f'.repeat(64) }, chainVerified: true }).manifest.linksToPrevious).toBe(false);
    expect(buildAuditExport(rows, { exportedAt: at, trigger: 'manual', previous: null, chainVerified: false }).manifest).toMatchObject({ linksToPrevious: null, chainVerified: false });
  });
});

describe('SMTP attachments', () => {
  it('multipart/mixed with the text first and base64 attachments with safe file names', () => {
    const msg = buildMessage({
      from: 'Aura <no-reply@aura.test>',
      to: ['ak@akvega.test'],
      subject: 'Audit export',
      text: 'see attached',
      attachments: [{ filename: 'aura audit"\r\n.ndjson', contentType: 'application/x-ndjson', content: Buffer.from('{"id":1}\n') }],
    });
    const boundary = /boundary="([^"]+)"/.exec(msg)?.[1] as string;
    expect(boundary).toMatch(/^aura-[0-9a-f]{24}$/);
    expect(msg).toContain('Content-Type: multipart/mixed;');
    expect(msg).toContain('Content-Disposition: attachment; filename="aura_audit___.ndjson"');
    expect(msg).toContain(Buffer.from('{"id":1}\n').toString('base64'));
    expect(msg.trimEnd().endsWith(`--${boundary}--`)).toBe(true);
    expect(msg.indexOf('text/plain')).toBeLessThan(msg.indexOf('application/x-ndjson'));
  });
});

describe('AuditExportService', () => {
  function adminDb(state: { previous: { to_id: string; last_hash: string } | null; rows: AuditExportRow[] }) {
    const audits: Array<{ actor: string; action: string; reasonCode: unknown; detail: Record<string, unknown> }> = [];
    const answer = async (text: string, params: unknown[] = []) => {
      if (/insert into public\.moderation_actions/.test(text)) {
        audits.push({ actor: params[0] as string, action: params[1] as string, reasonCode: params[4], detail: JSON.parse(params[5] as string) });
        return { rows: [{ id: '99' }], rowCount: 1 };
      }
      if (/detail->>'toId' as to_id/.test(text)) return { rows: state.previous ? [state.previous] : [], rowCount: state.previous ? 1 : 0 };
      if (/from public\.moderation_actions where id > \$1/.test(text)) {
        const rows = state.rows
          .filter((r) => r.id > (params[0] as number))
          .map((r) => ({ id: String(r.id), created_at: new Date(r.createdAt), actor: r.actor, action: r.action, report_id: r.reportId, subject_hash: r.subjectHash, reason_code: r.reasonCode, detail: r.detail, prev_hash: r.prevHash, row_hash: r.rowHash }));
        return { rows, rowCount: rows.length };
      }
      if (/with before as/.test(text)) return { rows: [{ ok: true }], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    };
    const db = { withTx: async <T>(fn: (tx: { query: typeof answer }) => Promise<T>) => fn({ query: answer }), query: answer } as unknown as AdminDb;
    return { db, audits };
  }

  it('does nothing when no destination is configured', async () => {
    const { db, audits } = adminDb({ previous: null, rows: [row(1, null)] });
    const svc = new AuditExportService(db, parseAdminConfig({}), new DisabledMailer());
    expect(svc.configured).toBe(false);
    expect(await svc.run('nightly')).toEqual({ status: 'skipped', reason: 'not_configured' });
    expect(audits).toEqual([]);
  });

  it('writes NDJSON + manifest (owner-only files) and emails them; audits the export with its hash; next run starts after it', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'aura-audit-export-'));
    try {
      const state = { previous: null as { to_id: string; last_hash: string } | null, rows: [row(1, null), row(2, row(1, null).rowHash)] };
      const { db, audits } = adminDb(state);
      const sent: MailMessage[] = [];
      const mailer: Mailer = { enabled: true, send: async (m) => void sent.push(m) };
      const svc = new AuditExportService(db, parseAdminConfig({ ADMIN_AUDIT_EXPORT_DIR: dir, ADMIN_AUDIT_EXPORT_EMAIL: 'archive@akvega.test' }), mailer);
      const out = await svc.run('nightly');
      expect(out).toMatchObject({ status: 'exported', destinations: ['file', 'email'], failed: [], manifest: { fromId: 1, toId: 2, rows: 2, chainVerified: true } });
      const files = (await readdir(dir)).sort();
      expect(files).toHaveLength(2);
      const nd = await readFile(join(dir, files.find((f) => f.endsWith('.ndjson')) as string));
      const manifest = JSON.parse(await readFile(join(dir, files.find((f) => f.endsWith('.manifest.json')) as string), 'utf8'));
      expect(manifest.ndjsonSha256).toBe(createHash('sha256').update(nd).digest('hex'));
      expect((await stat(join(dir, files[0]))).mode & 0o777).toBe(0o600);
      expect(sent[0]).toMatchObject({ to: ['archive@akvega.test'], autoSubmitted: true });
      expect(sent[0].attachments?.map((a) => a.contentType)).toEqual(['application/x-ndjson', 'application/json']);
      expect(audits).toEqual([
        expect.objectContaining({ actor: 'system:audit_export', action: 'audit_export', reasonCode: 'nightly', detail: expect.objectContaining({ fromId: 1, toId: 2, sha256: manifest.ndjsonSha256, destinations: ['file', 'email'] }) }),
      ]);
      // The next run exports only what came after (here: nothing new).
      state.previous = { to_id: '2', last_hash: row(2, null).rowHash };
      expect(await svc.run('nightly')).toEqual({ status: 'skipped', reason: 'nothing_new' });
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it('a run that reaches no destination is audited as failed and does not advance', async () => {
    const { db, audits } = adminDb({ previous: null, rows: [row(1, null)] });
    const mailer: Mailer = { enabled: true, send: () => Promise.reject(Object.assign(new Error('x'), { name: 'SmtpError', code: 'smtp_550' })) };
    const svc = new AuditExportService(db, parseAdminConfig({ ADMIN_AUDIT_EXPORT_EMAIL: 'archive@akvega.test' }), mailer);
    const out = await svc.run('manual', 'staff:0192f0c2-7a4e-7c1a-9b3d-000000000001');
    expect(out.status).toBe('failed');
    expect(audits.map((a) => [a.actor, a.action])).toEqual([['staff:0192f0c2-7a4e-7c1a-9b3d-000000000001', 'audit_export_failed']]);
  });
});
