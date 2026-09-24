import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm, AutoRefresh, ListKeys, SlaTimer } from '@/components/client';
import { Badge, Empty, LaneBadge, PageHead, When, YesNo } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { REASON_LABEL, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import {
  HOLD_REASON_LABEL,
  POOL_LABEL,
  REJECT_REASON_LABEL,
  STATUS_LABEL,
  STATUS_TABS,
  STATUS_TAB_LABEL,
  listHref,
  statusTab,
  type ReflectionList,
  type ReviewItem,
} from '@/lib/reflections';
import type { SessionInfo } from '@/lib/types';
import { setPoolPaused } from './actions';

export const metadata: Metadata = { title: 'Reflections' };

/** A language pool's composer pauses itself above this many held reflections (contract §3). */
const AUTO_PAUSE_AT = 50;

/**
 * F6 reflections for review (PRD 19; contracts/api/v1-reflections.md §4). Held first (oldest first): the text is what
 * the reviewer judges, so it is shown in full. Pool kill switches below; pausing and resuming is Owner-only.
 */
export default async function ReflectionsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const tab = statusTab(sp.status);
  const data = await load<ReflectionList>(`/admin/reflections?status=${tab}&limit=200`);
  if (isForbidden(data)) return <Empty>Your role cannot open reflections.</Empty>;
  const me = await apiGet<SessionInfo>('/admin/session');
  const owner = me.staff.role === 'owner';
  const heldTotal = data.pools.reduce((n, p) => n + p.held, 0);

  return (
    <>
      <PageHead title={tab === 'held' ? 'Reflections: held for review' : `Reflections: ${STATUS_LABEL[tab].toLowerCase()}`}>
        <span className="muted small">
          {heldTotal} held across pools · j / k to move, Enter to open
        </span>
      </PageHead>
      <p className="muted small">
        Held, crisis-diverted and reported reflections are also items in the{' '}
        <Link href="/queue" prefetch={false}>
          queue
        </Link>
        . Nothing publishes without a server or moderator decision. Never copy reflection text out of the console.
      </p>
      <AutoRefresh seconds={60} />
      <ListKeys />
      <nav aria-label="Reflection status" className="row tabs">
        {STATUS_TABS.map((t) => (
          <Link key={t} href={listHref(t)} prefetch={false} aria-current={tab === t ? 'page' : undefined} className="btn btn-quiet">
            {STATUS_TAB_LABEL[t]}
            {t === 'held' ? ` (${heldTotal})` : ''}
          </Link>
        ))}
      </nav>

      <div className="table-wrap">
        {data.items.length === 0 ? (
          <Empty>No {tab === 'all' ? '' : `${STATUS_TAB_LABEL[tab].toLowerCase()} `}reflections.</Empty>
        ) : (
          <table>
            <caption className="caption">
              {data.items.length} shown · {tab === 'held' || tab === 'pending' ? 'oldest first' : 'newest first'}
            </caption>
            <thead>
              <tr>
                <th scope="col">Status</th>
                <th scope="col">Reflection</th>
                <th scope="col">Pool</th>
                <th scope="col">Room</th>
                <th scope="col">Report</th>
                <th scope="col">Written</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((r) => (
                <Row key={r.reflectionId} r={r} />
              ))}
            </tbody>
          </table>
        )}
      </div>

      <section className="panel spaced" aria-labelledby="h-pools">
        <h2 id="h-pools">Language pools</h2>
        <p className="small muted">
          A pool’s composer pauses itself when more than {AUTO_PAUSE_AT} reflections are held in it; gestures keep working. The app says “Reflections are
          resting for a bit”. {owner ? 'Resume once the held list is under control.' : 'Only the Owner can pause or resume a pool.'}
        </p>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th scope="col">Pool</th>
                <th scope="col">Held</th>
                <th scope="col">Composer</th>
                {owner ? <th scope="col">Change</th> : null}
              </tr>
            </thead>
            <tbody>
              {data.pools.map((p) => (
                <tr key={p.pool}>
                  <td>
                    {POOL_LABEL[p.pool] ?? p.pool} <code className="muted">{p.pool}</code>
                  </td>
                  <td>
                    {p.held}
                    {p.held > AUTO_PAUSE_AT ? <span className="sla-overdue small"> · over {AUTO_PAUSE_AT}</span> : null}
                  </td>
                  <td>
                    <YesNo value={!p.paused} yes="open" no="paused" />
                  </td>
                  {owner ? (
                    <td>
                      <ActionForm
                        action={setPoolPaused.bind(null, p.pool, !p.paused)}
                        submitLabel={p.paused ? 'Resume' : 'Pause'}
                        confirm={`${p.paused ? 'Resume' : 'Pause'} new reflections in the ${POOL_LABEL[p.pool] ?? p.pool} pool?`}
                        danger={!p.paused}
                        className="stack small"
                      >
                        <label htmlFor={`pool-${p.pool}`} className="hint">
                          Reason code
                        </label>
                        <input
                          id={`pool-${p.pool}`}
                          name="reasonCode"
                          type="text"
                          required
                          pattern="[a-z0-9_]{1,40}"
                          defaultValue={p.paused ? 'held_cleared' : 'held_backlog'}
                        />
                      </ActionForm>
                    </td>
                  ) : null}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}

function Row({ r }: { r: ReviewItem }) {
  const reason = r.holdReason ? label(HOLD_REASON_LABEL, r.holdReason) : r.rejectReason ? label(REJECT_REASON_LABEL, r.rejectReason) : null;
  return (
    <tr>
      <td>
        <Badge tone={r.status === 'crisis_diverted' ? 'alert' : 'quiet'}>{label(STATUS_LABEL, r.status)}</Badge>
        {r.hidden ? (
          <>
            {' '}
            <Badge>hidden</Badge>
          </>
        ) : null}
        {reason ? <div className="small muted">{reason}</div> : null}
      </td>
      <td>
        <Link href={`/reflections/${r.reflectionId}`} prefetch={false} data-row="" aria-label={`Open reflection (${label(STATUS_LABEL, r.status)})`}>
          Open
        </Link>
        {r.text === null ? (
          <p className="muted small">(text scrubbed — deleted or expired)</p>
        ) : (
          <p className="note-text">
            {r.text}
          </p>
        )}
        <div className="small">
          {r.involvesMinor ? <Badge tone="alert">Under 18</Badge> : null} {r.strict ? <Badge>stricter thresholds</Badge> : null}{' '}
          {r.overnight ? <Badge>overnight</Badge> : null} <span className="muted">{r.charCount} characters</span>
        </div>
      </td>
      <td className="small">{POOL_LABEL[r.languagePool] ?? r.languagePool}</td>
      <td className="small">
        {r.room ? (
          <>
            {r.room.quadrant} · {r.room.tzRegion}
            <div className="muted">{r.room.state}</div>
          </>
        ) : (
          <span className="muted">purged</span>
        )}
      </td>
      <td>
        {r.report ? (
          <>
            <LaneBadge lane={r.report.lane} /> {r.report.pages ? <Badge>Pages</Badge> : null}
            <div className="small">
              <Link href={`/reports/${r.report.reportId}`} prefetch={false}>
                {label(REASON_LABEL, r.report.reasonKey)}
              </Link>
              {r.report.source === 'auto' ? <span className="muted"> · automatic ({r.report.autoSignal ?? 'signal'})</span> : null}
            </div>
            <SlaTimer dueAt={r.report.slaDueAt} />
          </>
        ) : (
          <span className="muted small">no open report</span>
        )}
      </td>
      <td className="nowrap small">
        <When iso={r.createdAt} />
        {r.decidedAt ? (
          <div className="muted">
            decided <When iso={r.decidedAt} />
            {r.decidedBy ? ` by ${r.decidedBy}` : ''}
          </div>
        ) : null}
      </td>
    </tr>
  );
}
