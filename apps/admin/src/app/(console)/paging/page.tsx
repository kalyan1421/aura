import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm, AutoRefresh, ListKeys } from '@/components/client';
import { Badge, Empty, Forbidden, LaneBadge, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { PAGE_KIND_LABEL, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { PageView, PagingStatus } from '@/lib/types';
import { ackPage, testPage } from './actions';

export const metadata: Metadata = { title: 'Paging' };

const CHANNEL: Record<string, string> = { webhook: 'Push webhook', email: 'Email', escalation_webhook: 'Escalation (call) webhook' };

/**
 * 24×7 on-call (PRD 19 REQ-ADM-15): legal orders, 2-hour grievances and urgent minors cases (plus crisis near its SLA)
 * page at once, escalate at 5 minutes and repeat every 5 minutes until acknowledged. Channels come from the server's
 * environment only: there is no switch here to mute them.
 */
export default async function PagingPage() {
  const data = await load<{ pages: PageView[] }>('/admin/pages');
  if (isForbidden(data)) return <Forbidden what="Paging" />;
  const status = await apiGet<PagingStatus>('/admin/paging/status');
  const open = data.pages.filter((p) => p.status === 'open');
  return (
    <>
      <PageHead title="Paging">
        <ActionForm action={testPage} submitLabel="Send a test page" className="row" />
      </PageHead>
      <AutoRefresh seconds={30} />
      <ListKeys />
      {status.warnings.map((w) => (
        <p key={w} className="callout danger">
          {w}
        </p>
      ))}
      <section className="panel" aria-labelledby="h-status">
        <h2 id="h-status">Channels</h2>
        {status.channels.length === 0 ? (
          <p className="sla-overdue">No channel is configured: pages are logged but reach nobody.</p>
        ) : (
          <ul>
            {status.channels.map((c) => (
              <li key={c.name}>
                {CHANNEL[c.name] ?? c.name} {c.level > 0 ? `(from ${status.escalateAfterMinutes} min unacknowledged)` : '(immediately)'}
                {c.name === 'webhook' && status.configured.webhook ? <span className="hint"> · {status.configured.webhook}</span> : null}
                {c.name === 'escalation_webhook' && status.configured.escalationWebhook ? (
                  <span className="hint"> · {status.configured.escalationWebhook}</span>
                ) : null}
              </li>
            ))}
          </ul>
        )}
        <p className="small">
          Repeats every {status.repeatMinutes} min until acknowledged ·{' '}
          {status.weeklyTest ? `weekly drill: ${status.weeklyTest.cron} (${status.weeklyTest.timezone})` : 'weekly drill off'}
        </p>
        <p className="small">
          Last test:{' '}
          {status.lastTest ? (
            <>
              <When iso={status.lastTest.createdAt} /> · {status.lastTest.status}
              {status.lastTest.acknowledgedAt ? (
                <>
                  {' '}
                  (acknowledged <When iso={status.lastTest.acknowledgedAt} />)
                </>
              ) : null}
            </>
          ) : (
            'never'
          )}
        </p>
      </section>
      <h2>{open.length ? `${open.length} open page${open.length === 1 ? '' : 's'}` : 'Pages'}</h2>
      <div className="table-wrap">
        {data.pages.length === 0 ? (
          <Empty>No pages yet.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">Page</th>
                <th scope="col">Raised</th>
                <th scope="col">Status</th>
                <th scope="col">Deliveries</th>
                <th scope="col">Acknowledge</th>
              </tr>
            </thead>
            <tbody>
              {data.pages.map((p) => (
                <tr key={p.pageId}>
                  <td>
                    <Link href={`/paging/${p.pageId}`} prefetch={false} data-row="">
                      {label(PAGE_KIND_LABEL, p.kind)}
                      {p.ticket ? ` ${p.ticket}` : ''}
                    </Link>{' '}
                    {p.isTest ? <Badge>TEST</Badge> : null} {p.lane ? <LaneBadge lane={p.lane} /> : null}{' '}
                    {p.minorInvolved ? <Badge tone="alert">Under 18</Badge> : null}
                    <div className="small muted">{p.reason.replace(/_/g, ' ')}</div>
                  </td>
                  <td className="small nowrap">
                    <When iso={p.createdAt} />
                  </td>
                  <td>
                    {p.status}
                    <div className="small muted">
                      round {p.round}
                      {p.escalationLevel > 0 ? ' · escalated' : ''}
                      {p.nextAttemptAt ? (
                        <>
                          {' · next '}
                          <When iso={p.nextAttemptAt} />
                        </>
                      ) : null}
                    </div>
                  </td>
                  <td className="small">
                    {p.deliveries.ok}/{p.deliveries.total} delivered
                    {p.deliveries.lastError ? (
                      <div className="muted">
                        last error <code>{p.deliveries.lastError}</code>
                      </div>
                    ) : null}
                  </td>
                  <td>{p.status === 'open' ? <ActionForm action={ackPage.bind(null, p.pageId)} submitLabel="Acknowledge" className="inline-form" /> : <When iso={p.acknowledgedAt} />}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
