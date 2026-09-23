import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm } from '@/components/client';
import { Badge, Empty, Forbidden, PageHead, When } from '@/components/ui';
import { DELETION_STATUS_LABEL, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { DeletionCase, GrievanceDetail } from '@/lib/types';
import { openCase } from './actions';

export const metadata: Metadata = { title: 'Deletion cases' };

const FILTERS = ['open', 'closed', 'all'] as const;

/**
 * REQ-ADM-11 (PRD 19 "Grievances and deletion"): account-deletion requests that arrive by email, post or grievance.
 * In-app deletion stays the main route. Here the account holder proves they control the account's own mailbox (a
 * one-time link), then the Owner starts the app's own deletion. The console never shows the email or the account id.
 */
export default async function DeletionCasesPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const filter = typeof sp.status === 'string' && (FILTERS as readonly string[]).includes(sp.status) ? sp.status : 'open';
  const data = await load<{ cases: DeletionCase[] }>(`/admin/deletion-cases?status=${filter}`);
  if (isForbidden(data)) return <Forbidden what="Deletion cases" />;
  // From a "data or account" grievance: prefilled on the server from the ticket (never an email in the URL).
  const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const grievanceId = typeof sp.grievance === 'string' && UUID.test(sp.grievance) ? sp.grievance : '';
  const grievance = grievanceId ? await load<GrievanceDetail>(`/admin/grievances/${grievanceId}`) : null;
  const fromGrievance = grievance && !isForbidden(grievance) ? grievance : null;
  const receivedIst = fromGrievance
    ? new Date(Date.parse(fromGrievance.receivedAt) + 330 * 60_000).toISOString().slice(0, 16) // datetime-local, IST
    : undefined;
  return (
    <>
      <PageHead title="Deletion cases" />
      <p className="muted small">
        Emailed or grievance requests to delete an account. The link goes only to the address on the account; nothing is deleted before the
        account holder confirms. Records the law requires (hashed audit rows, evidence under legal hold) are kept until their date.
      </p>
      <nav aria-label="Filter" className="row tabs">
        {FILTERS.map((f) => (
          <Link key={f} href={`/deletion-cases?status=${f}`} prefetch={false} aria-current={filter === f ? 'page' : undefined} className="btn btn-quiet">
            {f[0].toUpperCase() + f.slice(1)}
          </Link>
        ))}
      </nav>
      <div className="table-wrap">
        {data.cases.length === 0 ? (
          <Empty>No {filter === 'all' ? '' : filter} cases.</Empty>
        ) : (
          <table>
            <thead>
              <tr>
                <th scope="col">Case</th>
                <th scope="col">Status</th>
                <th scope="col">Account</th>
                <th scope="col">Received</th>
                <th scope="col">Legal hold</th>
              </tr>
            </thead>
            <tbody>
              {data.cases.map((c) => (
                <tr key={c.caseId}>
                  <td>
                    <Link href={`/deletion-cases/${c.caseId}`} prefetch={false} data-row="">
                      {c.ticket}
                    </Link>
                    <div className="small muted">
                      {c.channel}
                      {c.grievanceTicket ? ` · ${c.grievanceTicket}` : ''}
                    </div>
                  </td>
                  <td>
                    <Badge tone={c.status === 'declined' ? 'alert' : 'quiet'}>{label(DELETION_STATUS_LABEL, c.status)}</Badge>
                  </td>
                  <td className="small">{c.accountEmailMasked ?? <span className="muted">—</span>}</td>
                  <td className="small nowrap">
                    <When iso={c.receivedAt} />
                  </td>
                  <td className="small">{c.legalHold.records ? `${c.legalHold.records} record(s)` : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      <section className="panel spaced" aria-labelledby="h-open">
        <h2 id="h-open">Open a case</h2>
        <p className="small muted">
          Type the address the request names. It only finds the account: the confirmation link goes to the address stored on that account (for
          Hide My Email accounts, the relay address), never to wherever the request came from.
        </p>
        {fromGrievance ? (
          <p className="callout" role="note">
            From grievance{' '}
            <Link href={`/grievances/${fromGrievance.grievanceId}`} prefetch={false}>
              {fromGrievance.ticket}
            </Link>
            : the complainant’s address is filled in — check the request names that address as the account’s.
          </p>
        ) : null}
        <ActionForm action={openCase} submitLabel="Open the case and send the link">
          <input type="hidden" name="grievanceId" value={fromGrievance ? fromGrievance.grievanceId : ''} />
          <div className="grid">
            <div>
              <label htmlFor="email">Account email named in the request</label>
              <input id="email" name="email" type="email" required defaultValue={fromGrievance?.complainantEmail ?? ''} />
            </div>
            <div>
              <label htmlFor="channel">Arrived by</label>
              <select id="channel" name="channel" defaultValue={fromGrievance ? 'grievance' : 'email'}>
                <option value="email">Email</option>
                <option value="grievance">Grievance</option>
                <option value="post">Post</option>
                <option value="other">Other</option>
              </select>
            </div>
            <div>
              <label htmlFor="receivedAt">
                Received at <span className="hint">(IST)</span>
              </label>
              <input id="receivedAt" name="receivedAt" type="datetime-local" required defaultValue={receivedIst} />
            </div>
          </div>
        </ActionForm>
      </section>
    </>
  );
}
