import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm, AutoRefresh, SlaTimer } from '@/components/client';
import { DeliveryLog } from '@/components/deliveries';
import { Badge, Forbidden, PageHead, When } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { LegalOrderDetail } from '@/lib/types';
import { acknowledgeOrder, closeOrder } from '../actions';

export const metadata: Metadata = { title: 'Legal order' };

export default async function LegalOrderPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const o = await load<LegalOrderDetail>(`/admin/legal-orders/${encodeURIComponent(id)}`);
  if (isForbidden(o)) return <Forbidden what="Legal orders" />;
  const closed = o.status === 'actioned' || o.status === 'rejected';
  return (
    <>
      <PageHead title={`Legal order ${o.ticket}`}>
        {o.isTest ? <Badge>TEST</Badge> : null}
        <Badge tone="legal">L0 · 3-hour clock</Badge>
        <Badge>{o.status}</Badge>
      </PageHead>
      {!closed ? <AutoRefresh seconds={30} /> : null}
      <div className="grid">
        <section className="panel" aria-labelledby="h-clock">
          <h2 id="h-clock">Clock</h2>
          <dl className="facts">
            <dt>Received</dt>
            <dd>
              <When iso={o.receivedAt} />
            </dd>
            <dt>Deadline</dt>
            <dd>
              <SlaTimer dueAt={o.dueAt} closed={closed} /> <span className="small muted">(<When iso={o.dueAt} />)</span>
            </dd>
            <dt>Acknowledged</dt>
            <dd>{o.acknowledgedAt ? <When iso={o.acknowledgedAt} /> : <strong className="sla-overdue">not yet: paging</strong>}</dd>
            {closed ? (
              <>
                <dt>Closed</dt>
                <dd>
                  <When iso={o.closedAt} /> · {o.status}
                </dd>
              </>
            ) : null}
          </dl>
        </section>
        <section className="panel" aria-labelledby="h-from">
          <h2 id="h-from">Order</h2>
          <dl className="facts">
            <dt>Authority</dt>
            <dd>
              {o.authority} ({o.source.replace('_', ' ')})
            </dd>
            <dt>Reference</dt>
            <dd>{o.reference ?? '—'}</dd>
            <dt>Recorded via</dt>
            <dd>{o.intakeChannel === 'intake_api' ? 'email relay (intake API)' : 'console'}</dd>
          </dl>
        </section>
      </div>
      <section className="panel" aria-labelledby="h-summary">
        <h2 id="h-summary">What it requires</h2>
        <p className="note-text">{o.summary}</p>
        {o.targets ? (
          <>
            <h3>Content or accounts named</h3>
            <p className="note-text">{o.targets}</p>
          </>
        ) : null}
        {o.resolutionNote ? (
          <>
            <h3>Outcome</h3>
            <p className="note-text">{o.resolutionNote}</p>
          </>
        ) : null}
      </section>
      {!closed ? (
        <section className="panel" aria-labelledby="h-act">
          <h2 id="h-act">Act</h2>
          {o.status === 'open' ? <ActionForm action={acknowledgeOrder.bind(null, o.legalOrderId)} submitLabel="Acknowledge (stops paging)" /> : null}
          <h3>Close</h3>
          <ActionForm action={closeOrder.bind(null, o.legalOrderId)} submitLabel="Close the order" confirm="Close this legal order?">
            <fieldset>
              <legend>Outcome</legend>
              <label className="choice">
                <input type="radio" name="status" value="actioned" defaultChecked /> Actioned (content removed / access disabled)
              </label>
              <label className="choice">
                <input type="radio" name="status" value="rejected" /> Rejected (with counsel’s reason)
              </label>
            </fieldset>
            <div>
              <label htmlFor="note">What was done, when</label>
              <textarea id="note" name="note" required minLength={3} maxLength={5000} />
            </div>
          </ActionForm>
        </section>
      ) : null}
      <section className="panel" aria-labelledby="h-page">
        <h2 id="h-page">Paging</h2>
        {o.page ? (
          <>
            <p className="small">
              Page {o.page.status} · round {o.page.round} · {o.page.escalationLevel > 0 ? 'escalated to the call channel' : 'not escalated'} · last delivered{' '}
              <When iso={o.page.lastDeliveredAt} />{' '}
              <Link href={`/paging/${o.page.pageId}`} prefetch={false}>
                open the page
              </Link>
            </p>
            <DeliveryLog deliveries={o.page.deliveries} />
          </>
        ) : (
          <p className="muted">No page yet (the worker raises it within 30 seconds if the API could not).</p>
        )}
      </section>
    </>
  );
}
