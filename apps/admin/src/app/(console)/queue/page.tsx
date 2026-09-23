import type { Metadata } from 'next';
import Link from 'next/link';
import { AutoRefresh, ListKeys, SlaTimer } from '@/components/client';
import { Badge, Empty, Hash, LaneBadge, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { LANE_LABEL, REASON_LABEL, label, queueSessionText } from '@/lib/format';
import type { Lane, LaneSummary, QueueItem, QueueSessionView } from '@/lib/types';

export const metadata: Metadata = { title: 'Queue' };

const LANES: Lane[] = ['crisis', 'minors_grooming', 'harassment', 'spam'];

/** Reports by lane (L0 → L3), oldest first inside a lane, each with its SLA timer (PRD 19 "Queues and priority lanes"). */
export default async function QueuePage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const lane = typeof sp.lane === 'string' && (LANES as string[]).includes(sp.lane) ? (sp.lane as Lane) : undefined;
  const q = await apiGet<{ items: QueueItem[]; lanes: LaneSummary[]; generatedAt: string; queueSession?: QueueSessionView }>(
    `/admin/queue?limit=300${lane ? `&lane=${lane}` : ''}`,
  );
  const total = q.lanes.reduce((n, l) => n + l.open, 0);
  const session = queueSessionText(q.queueSession);

  return (
    <>
      <PageHead title={lane ? `Queue: ${LANE_LABEL[lane]}` : 'Queue'}>
        <span className="muted small">
          Updated <When iso={q.generatedAt} /> · j / k to move, Enter to open
        </span>
      </PageHead>
      {session ? (
        <p className={q.queueSession?.capped ? 'callout danger' : 'callout'} role="status">
          {session}
          {q.queueSession?.capped ? ' Crisis and paging items (marked “Pages”) stay open to you.' : ' (PRD: queue sessions are capped at 2 h; a 15-minute break resets it.)'}
        </p>
      ) : null}
      <AutoRefresh seconds={60} />
      <ListKeys />
      <nav aria-label="Lanes" className="row tabs">
        <Link href="/queue" prefetch={false} aria-current={lane ? undefined : 'page'} className="btn btn-quiet">
          All ({total})
        </Link>
        {q.lanes.map((l) => (
          <Link key={l.lane} href={`/queue?lane=${l.lane}`} prefetch={false} aria-current={lane === l.lane ? 'page' : undefined} className="btn btn-quiet">
            {LANE_LABEL[l.lane]} ({l.open}
            {l.overdue ? `, ${l.overdue} overdue` : ''})
          </Link>
        ))}
      </nav>
      <div className="table-wrap">
        {q.items.length === 0 ? (
          <Empty>No open reports{lane ? ' in this lane' : ''}.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">Lane</th>
                <th scope="col">Report</th>
                <th scope="col">Subject</th>
                <th scope="col">Room</th>
                <th scope="col">Reporters</th>
                <th scope="col">Arrived</th>
                <th scope="col">SLA</th>
              </tr>
            </thead>
            <tbody>
              {q.items.map((r) => (
                <tr key={r.reportId}>
                  <td className="nowrap">
                    <LaneBadge lane={r.lane} />
                    {r.involvesMinor ? (
                      <>
                        {' '}
                        <Badge tone="alert">Under 18</Badge>
                      </>
                    ) : null}
                    {r.pages ? (
                      <>
                        {' '}
                        <Badge>Pages</Badge>
                      </>
                    ) : null}
                  </td>
                  <td>
                    <Link href={`/reports/${r.reportId}`} prefetch={false} data-row="">
                      {label(REASON_LABEL, r.reasonKey)}
                    </Link>
                    <div className="small muted">
                      {r.targetKind}
                      {r.source === 'auto' ? ` · automatic (${r.autoSignal ?? 'signal'})` : ''}
                      {r.note ? ' · has note' : ''}
                    </div>
                  </td>
                  <td>
                    {r.subject ? (
                      <>
                        {r.subject.pseudonym ?? <span className="muted">(no pseudonym)</span>} <Hash value={r.subject.hash} />
                        <div className="small muted">
                          {r.subject.accountAgeDays ?? '?'} d old · {r.subject.activeStrikes} active strike{r.subject.activeStrikes === 1 ? '' : 's'}
                          {r.subject.activeSanctions.length ? ` · ${r.subject.activeSanctions.join(', ')}` : ''}
                        </div>
                      </>
                    ) : (
                      <span className="muted">room / no account</span>
                    )}
                  </td>
                  <td className="small">
                    {r.room ? (
                      <>
                        {r.room.quadrant} · {r.room.languagePool} · {r.room.tzRegion}
                        <div className="muted">{r.room.ageHours} h old</div>
                      </>
                    ) : (
                      <span className="muted">purged</span>
                    )}
                  </td>
                  <td>{r.reporterCount}</td>
                  <td className="nowrap small">
                    <When iso={r.createdAt} />
                  </td>
                  <td className="nowrap">
                    <SlaTimer dueAt={r.slaDueAt} />
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
