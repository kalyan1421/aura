import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm, AutoRefresh, ListKeys, SlaTimer } from '@/components/client';
import { Badge, Empty, Forbidden, PageHead, When } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { LegalOrderView } from '@/lib/types';
import { sendDrill } from './actions';

export const metadata: Metadata = { title: 'Legal orders' };

/** Court and government takedown orders: 3 hours from receipt, Owner only, paging 24×7 until acknowledged. */
export default async function LegalOrdersPage() {
  const data = await load<{ legalOrders: LegalOrderView[] }>('/admin/legal-orders');
  if (isForbidden(data)) return <Forbidden what="Legal orders" />;
  return (
    <>
      <PageHead title="Legal orders">
        <Link href="/legal-orders/new" prefetch={false} className="btn">
          Record an order
        </Link>
      </PageHead>
      <AutoRefresh seconds={60} />
      <ListKeys />
      <section className="panel" aria-labelledby="h-drill">
        <h2 id="h-drill">Drill</h2>
        <p className="small">
          A test takedown order pages you exactly like a real one (webhook → email → the 5-minute escalation), marked TEST. Acknowledge it from the page or here.
        </p>
        <ActionForm action={sendDrill} submitLabel="Send a test takedown order" confirm="Send a test order now? It will page you." />
      </section>
      <div className="table-wrap">
        {data.legalOrders.length === 0 ? (
          <Empty>No orders recorded.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">Ticket</th>
                <th scope="col">From</th>
                <th scope="col">Received</th>
                <th scope="col">3-hour clock</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {data.legalOrders.map((o) => {
                const closed = o.status === 'actioned' || o.status === 'rejected';
                return (
                  <tr key={o.legalOrderId}>
                    <td className="nowrap">
                      <Link href={`/legal-orders/${o.legalOrderId}`} prefetch={false} data-row="">
                        {o.ticket}
                      </Link>{' '}
                      {o.isTest ? <Badge>TEST</Badge> : null}
                    </td>
                    <td>
                      {o.authority}
                      <div className="small muted">
                        {o.source.replace('_', ' ')}
                        {o.reference ? ` · ${o.reference}` : ''} · via {o.intakeChannel === 'intake_api' ? 'email relay' : 'console'}
                      </div>
                    </td>
                    <td className="small nowrap">
                      <When iso={o.receivedAt} />
                    </td>
                    <td className="nowrap">
                      <SlaTimer dueAt={o.dueAt} closed={closed} />
                    </td>
                    <td>{o.status}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
