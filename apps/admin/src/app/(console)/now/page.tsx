import type { Metadata } from 'next';
import Link from 'next/link';
import { AutoRefresh, ListKeys, SlaTimer } from '@/components/client';
import { Badge, Empty, LaneBadge, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import type { LaneSummary, QueueItem, WorkEntry } from '@/lib/types';

export const metadata: Metadata = { title: 'Now' };

const KIND: Record<WorkEntry['kind'], string> = { legal_order: 'Legal order', report: 'Report', grievance: 'Grievance' };

/**
 * One list for one person: legal orders (L0), crisis (L0), minors & grooming and 2-hour grievances (L1), harassment
 * and unlawful-content grievances (L2), spam and 7-day grievances (L3) — then the earliest deadline, then the oldest.
 */
export default async function NowPage() {
  const [work, queue] = await Promise.all([
    apiGet<{ items: WorkEntry[]; generatedAt: string }>('/admin/work'),
    apiGet<{ items: QueueItem[]; lanes: LaneSummary[] }>('/admin/queue?limit=1'),
  ]);
  return (
    <>
      <PageHead title="Now">
        <span className="muted small">
          Updated <When iso={work.generatedAt} /> · j / k to move, Enter to open
        </span>
      </PageHead>
      <AutoRefresh seconds={60} />
      <ListKeys />
      <div className="cards" aria-label="Queue by lane">
        {queue.lanes.map((l) => (
          <Link key={l.lane} href={`/queue?lane=${l.lane}`} prefetch={false} className="card">
            <LaneBadge lane={l.lane} />
            <div className="num">{l.open}</div>
            <div className="small">
              {l.overdue > 0 ? <strong className="sla-overdue">{l.overdue} overdue</strong> : <span className="muted">none overdue</span>}
              {l.paging > 0 ? <span> · {l.paging} paging</span> : null}
            </div>
          </Link>
        ))}
      </div>
      <div className="table-wrap">
        {work.items.length === 0 ? (
          <Empty>Nothing waiting. Pages still reach you 24×7 for legal orders, 2-hour grievances and minors’ cases.</Empty>
        ) : (
          <table>
            <caption className="caption">
              Everything open, most urgent first
            </caption>
            <thead>
              <tr>
                <th scope="col">Priority</th>
                <th scope="col">Item</th>
                <th scope="col">Due</th>
                <th scope="col">Flags</th>
                <th scope="col">Arrived</th>
              </tr>
            </thead>
            <tbody>
              {work.items.map((w) => (
                <tr key={`${w.kind}:${w.id}`}>
                  <td className="nowrap">{w.lane ? <LaneBadge lane={w.lane} /> : <Badge tone={w.kind === 'legal_order' ? 'legal' : 'quiet'}>{`L${w.priority} ${KIND[w.kind]}`}</Badge>}</td>
                  <td>
                    <Link href={w.href} prefetch={false} data-row="">
                      {w.ticket ? `${w.ticket} · ` : ''}
                      {w.title}
                    </Link>
                  </td>
                  <td className="nowrap">
                    <SlaTimer dueAt={w.dueAt} />
                  </td>
                  <td className="nowrap">
                    {w.minorInvolved ? <Badge tone="alert">Under 18</Badge> : null} {w.pages ? <Badge>Pages 24×7</Badge> : null}
                  </td>
                  <td className="nowrap small">
                    <When iso={w.createdAt} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
