import type { Metadata } from 'next';
import Link from 'next/link';
import { Empty, Forbidden, Hash, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { isForbidden, load } from '@/lib/load';
import type { AuditEntry } from '@/lib/types';

export const metadata: Metadata = { title: 'Audit log' };

const PAGE = 100;

/** The append-only, hash-chained audit log (PRD 19 "Audit log"): every staff action, config change, export and login. */
export default async function AuditPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const before = typeof sp.before === 'string' && /^\d+$/.test(sp.before) ? sp.before : null;
  const data = await load<{ entries: AuditEntry[] }>(`/admin/audit?limit=${PAGE}${before ? `&beforeId=${before}` : ''}`);
  if (isForbidden(data)) return <Forbidden what="The audit log" />;
  const chain = await apiGet<{ ok: boolean; checkedAt: string }>('/admin/audit/verify');
  const last = data.entries[data.entries.length - 1];
  return (
    <>
      <PageHead title="Audit log">
        <span className={chain.ok ? 'yes' : 'sla-overdue'}>
          {chain.ok ? 'Hash chain verified' : 'Hash chain BROKEN'} · <When iso={chain.checkedAt} />
        </span>
      </PageHead>
      <p className="muted small">Rows never hold content, emails or raw app account ids; people appear as a hashed id.</p>
      <div className="table-wrap">
        {data.entries.length === 0 ? (
          <Empty>No entries.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col">When</th>
                <th scope="col">Who</th>
                <th scope="col">Action</th>
                <th scope="col">Reason</th>
                <th scope="col">Subject</th>
                <th scope="col">Detail</th>
              </tr>
            </thead>
            <tbody>
              {data.entries.map((e) => (
                <tr key={e.id}>
                  <td className="small">{e.id}</td>
                  <td className="small nowrap">
                    <When iso={e.createdAt} />
                  </td>
                  <td className="small">{e.actorLabel}</td>
                  <td>
                    <strong>{e.action}</strong>
                    {e.reportId ? (
                      <div className="small">
                        <Link href={`/reports/${e.reportId}`} prefetch={false}>
                          report
                        </Link>
                      </div>
                    ) : null}
                  </td>
                  <td>{e.reasonCode ? <code>{e.reasonCode}</code> : '—'}</td>
                  <td>
                    <Hash value={e.subjectHash} />
                  </td>
                  <td className="small">
                    <code>{JSON.stringify(e.detail)}</code>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      {last && data.entries.length === PAGE ? (
        <p>
          <Link href={`/audit?before=${last.id}`} prefetch={false}>
            Older entries
          </Link>
        </p>
      ) : null}
    </>
  );
}
