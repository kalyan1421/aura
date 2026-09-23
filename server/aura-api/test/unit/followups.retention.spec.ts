/**
 * Retention job (worker `maintenance` queue, job `retention`, daily): the moderation audit log past its retention
 * (3 years [LEGAL], only through prune_moderation_actions()), and closed reports only once a retention is configured
 * (NULL by default = keep; decision for AK / the lawyer). The SQL itself is tested in
 * supabase/tests/14_account_followups.test.sql.
 */
import { RETENTION_CRON, RETENTION_JOB } from '../../src/queues/queue-names';
import { runRetention } from '../../src/queues/retention';

/** Scripted answers per statement kind; records every call. */
function fakeDb(opts: { prune: number[]; days: number | null; deletes?: number[] }) {
  const calls: { text: string; params: unknown[] }[] = [];
  const prune = [...opts.prune];
  const deletes = [...(opts.deletes ?? [])];
  const q = {
    query: async (text: string, params: unknown[] = []) => {
      calls.push({ text, params });
      if (text.includes('prune_moderation_actions')) return { rows: [{ n: String(prune.shift() ?? 0) }], rowCount: 1 };
      if (text.includes('closed_report_retention_days')) return { rows: [{ days: opts.days }], rowCount: 1 };
      if (text.startsWith('delete from public.reports')) return { rows: [], rowCount: deletes.shift() ?? 0 };
      throw new Error(`unexpected query: ${text}`);
    },
  };
  return { q, calls };
}

describe('runRetention', () => {
  it('prunes the audit log in batches until a short batch, through the prune function only', async () => {
    const { q, calls } = fakeDb({ prune: [10_000, 10_000, 7], days: null });
    const r = await runRetention(q as never);
    expect(r.auditPruned).toBe(20_007);
    const prunes = calls.filter((c) => c.text.includes('prune_moderation_actions'));
    expect(prunes).toHaveLength(3);
    expect(prunes[0].params).toEqual([10_000]);
    expect(calls.some((c) => /delete from public\.moderation_actions/.test(c.text))).toBe(false);
  });

  it('closed reports: no retention configured (the default) → nothing is deleted', async () => {
    const { q, calls } = fakeDb({ prune: [0], days: null });
    await expect(runRetention(q as never)).resolves.toEqual({ auditPruned: 0, reportsPruned: 0, closedReportRetentionDays: null });
    expect(calls.some((c) => c.text.startsWith('delete from public.reports'))).toBe(false);
  });

  it('closed reports: once configured, only closed reports resolved that long ago, never under a running evidence hold', async () => {
    const { q, calls } = fakeDb({ prune: [0], days: 400, deletes: [5_000, 12] });
    const r = await runRetention(q as never);
    expect(r).toEqual({ auditPruned: 0, reportsPruned: 5_012, closedReportRetentionDays: 400 });
    const del = calls.filter((c) => c.text.startsWith('delete from public.reports'));
    expect(del).toHaveLength(2);
    expect(del[0].params).toEqual([400, 5_000]);
    expect(del[0].text).toMatch(/r\.status <> 'open'/);
    expect(del[0].text).toMatch(/r\.resolved_at < now\(\) - make_interval\(days => \$1\)/);
    expect(del[0].text).toMatch(/not exists \(select 1 from public\.evidence_holds e where e\.id = r\.evidence_hold_id and e\.hold_until > now\(\)\)/);
  });

  it('is scheduled daily on the maintenance queue', () => {
    expect(RETENTION_JOB).toBe('retention');
    expect(RETENTION_CRON).toMatch(/^\d+ \d+ \* \* \*$/);
  });
});
