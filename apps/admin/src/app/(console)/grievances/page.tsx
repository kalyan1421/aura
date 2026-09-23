import type { Metadata } from 'next';
import Link from 'next/link';
import { AutoRefresh, ListKeys, SlaTimer } from '@/components/client';
import { Badge, Empty, Forbidden, PageHead, When, YesNo } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { GrievanceView } from '@/lib/types';

export const metadata: Metadata = { title: 'Grievances' };

const FILTERS = [
  { key: 'active', label: 'Open' },
  { key: 'resolved', label: 'Resolved' },
  { key: 'all', label: 'All' },
];

/**
 * The Grievance Officer's inbox (IT Rules 2021 as amended 20 Feb 2026): acknowledge within 24 h, resolve within 7 days,
 * unlawful content 36 h, nudity / CSAM and intimate images 2 h (those page 24×7). Tickets from the in-app form and the
 * website arrive auto-acknowledged; emailed ones are entered here.
 */
export default async function GrievancesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const status = typeof sp.status === 'string' && FILTERS.some((f) => f.key === sp.status) ? sp.status : 'active';
  const data = await load<{ grievances: GrievanceView[] }>(`/admin/grievances?status=${status}`);
  if (isForbidden(data)) return <Forbidden what="The grievance inbox" />;
  return (
    <>
      <PageHead title="Grievances">
        <Link href="/grievances/new" prefetch={false} className="btn">
          Record an emailed grievance
        </Link>
      </PageHead>
      <AutoRefresh seconds={60} />
      <ListKeys />
      <nav aria-label="Filter" className="row tabs">
        {FILTERS.map((f) => (
          <Link key={f.key} href={`/grievances?status=${f.key}`} prefetch={false} className="btn btn-quiet" aria-current={status === f.key ? 'page' : undefined}>
            {f.label}
          </Link>
        ))}
      </nav>
      <div className="table-wrap">
        {data.grievances.length === 0 ? (
          <Empty>No grievances here.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">Ticket</th>
                <th scope="col">Category</th>
                <th scope="col">Received</th>
                <th scope="col">Acknowledged</th>
                <th scope="col">Resolve by</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {data.grievances.map((g) => (
                <tr key={g.grievanceId}>
                  <td className="nowrap">
                    <Link href={`/grievances/${g.grievanceId}`} prefetch={false} data-row="">
                      {g.ticket}
                    </Link>
                    <div className="small muted">{g.channel.replace('_', ' ')}</div>
                  </td>
                  <td>
                    {g.categoryLabel} {g.pages ? <Badge tone="alert">2 h · pages</Badge> : null}
                  </td>
                  <td className="small nowrap">
                    <When iso={g.receivedAt} />
                  </td>
                  <td className="small">
                    {g.acknowledgedAt ? <When iso={g.acknowledgedAt} /> : <SlaTimer dueAt={g.ackDueAt} />}
                    <div className="muted">
                      email: <YesNo value={!!g.ackEmailSentAt} yes="sent" no="not sent" />
                    </div>
                  </td>
                  <td className="nowrap">
                    <SlaTimer dueAt={g.resolveDueAt} closed={g.status === 'resolved'} />
                  </td>
                  <td>{g.status === 'resolved' ? `resolved (${g.outcome?.replace('_', ' ')})` : g.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
