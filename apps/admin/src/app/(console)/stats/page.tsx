import type { Metadata } from 'next';
import Link from 'next/link';
import { AutoRefresh } from '@/components/client';
import { LaneBadge, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import type { Stats } from '@/lib/types';

export const metadata: Metadata = { title: 'Stats' };

/** Aggregates only (the Read-only analyst's view): counts, never ids or content. */
export default async function StatsPage() {
  const s = await apiGet<Stats>('/admin/stats');
  return (
    <>
      <PageHead title="Stats">
        <span className="muted small">
          Updated <When iso={s.generatedAt} />
        </span>
      </PageHead>
      <AutoRefresh seconds={120} />
      <div className="table-wrap">
        <table>
          <caption className="caption">Open reports by lane</caption>
          <thead>
            <tr>
              <th scope="col">Lane</th>
              <th scope="col">Open</th>
              <th scope="col">Overdue</th>
              <th scope="col">Paging</th>
            </tr>
          </thead>
          <tbody>
            {s.lanes.map((l) => (
              <tr key={l.lane}>
                <td>
                  <LaneBadge lane={l.lane} />
                </td>
                <td>{l.open}</td>
                <td>{l.overdue}</td>
                <td>{l.paging}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="cards spaced">
        <div className="card">
          <div className="small muted">Grievances open</div>
          <div className="num">{s.grievances.open}</div>
          <div className="small">
            {s.grievances.overdue} overdue · {s.grievances.paging} on a 2-hour clock
          </div>
        </div>
        <div className="card">
          <div className="small muted">Legal orders open (excl. drills)</div>
          <div className="num">{s.legalOrders.open}</div>
          <div className="small">{s.legalOrders.overdue} past 3 h</div>
        </div>
        <div className="card">
          <div className="small muted">Pages open</div>
          <div className="num">{s.pagesOpen}</div>
        </div>
      </div>
      <p className="small spaced">
        <Link href="/stats/commitments">Habit commitments: do they help?</Link>
      </p>
    </>
  );
}
