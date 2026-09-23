import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm, AutoRefresh } from '@/components/client';
import { DeliveryLog } from '@/components/deliveries';
import { Badge, Forbidden, LaneBadge, PageHead, When } from '@/components/ui';
import { PAGE_KIND_LABEL, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { Delivery, PageView } from '@/lib/types';
import { ackPage } from '../actions';

export const metadata: Metadata = { title: 'Page' };

/** The link in every page (push, email, call) lands here: see what it is, acknowledge to stop the repeats. */
export default async function PageDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const p = await load<PageView & { deliveryLog: Delivery[] }>(`/admin/pages/${encodeURIComponent(id)}`);
  if (isForbidden(p)) return <Forbidden what="Paging" />;
  const target =
    p.kind === 'legal_order' && p.refId
      ? `/legal-orders/${p.refId}`
      : p.kind === 'grievance' && p.refId
        ? `/grievances/${p.refId}`
        : p.kind === 'report' && p.refId
          ? `/reports/${p.refId}`
          : null;
  return (
    <>
      <PageHead title={`${label(PAGE_KIND_LABEL, p.kind)}${p.ticket ? ` ${p.ticket}` : ''}`}>
        {p.isTest ? <Badge>TEST</Badge> : null}
        {p.lane ? <LaneBadge lane={p.lane} /> : null}
        {p.minorInvolved ? <Badge tone="alert">Under 18</Badge> : null}
        <Badge>{p.status}</Badge>
      </PageHead>
      {p.status === 'open' ? <AutoRefresh seconds={20} /> : null}
      <section className="panel">
        <dl className="facts">
          <dt>Why</dt>
          <dd>{p.reason.replace(/_/g, ' ')}</dd>
          <dt>Raised</dt>
          <dd>
            <When iso={p.createdAt} />
          </dd>
          <dt>Deadline</dt>
          <dd>
            <When iso={p.dueAt} />
          </dd>
          <dt>Rounds</dt>
          <dd>
            {p.round}
            {p.escalationLevel > 0 ? ' · escalated to the call channel' : ''}
          </dd>
          <dt>Acknowledged</dt>
          <dd>{p.acknowledgedAt ? <When iso={p.acknowledgedAt} /> : 'no'}</dd>
        </dl>
        <div className="row">
          {p.status === 'open' ? <ActionForm action={ackPage.bind(null, p.pageId)} submitLabel="Acknowledge" /> : null}
          {target ? (
            <Link href={target} prefetch={false} className="btn btn-quiet">
              Open the item
            </Link>
          ) : null}
        </div>
      </section>
      <h2>Delivery log</h2>
      <DeliveryLog deliveries={p.deliveryLog} />
    </>
  );
}
