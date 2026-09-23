import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm, SlaTimer } from '@/components/client';
import { Badge, Forbidden, PageHead, When, YesNo } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { GrievanceDetail } from '@/lib/types';
import { acknowledgeGrievance, resolveGrievance } from '../actions';

export const metadata: Metadata = { title: 'Grievance' };

const OUTCOMES: Array<{ key: string; label: string }> = [
  { key: 'action_taken', label: 'Action taken' },
  { key: 'no_action', label: 'No breach found' },
  { key: 'referred', label: 'Referred to an authority' },
  { key: 'duplicate', label: 'Duplicate' },
  { key: 'withdrawn', label: 'Withdrawn' },
];

export default async function GrievancePage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { id } = await params;
  const sp = await searchParams;
  const g = await load<GrievanceDetail>(`/admin/grievances/${encodeURIComponent(id)}`);
  if (isForbidden(g)) return <Forbidden what="The grievance inbox" />;
  const resolved = g.status === 'resolved';
  return (
    <>
      <PageHead title={`Grievance ${g.ticket}`}>
        <Badge>{g.categoryLabel}</Badge>
        {g.pages ? <Badge tone="alert">2-hour clock · pages 24×7</Badge> : null}
        <Badge>{g.status}</Badge>
      </PageHead>
      {sp.resolved === 'emailed' ? <p className="callout ok">Resolved. The reply (with the appeal route) was emailed.</p> : null}
      {sp.resolved === 'not-emailed' ? (
        <p className="callout danger">Resolved, but the reply email did not go out. Check SMTP (Paging → status) and reply manually.</p>
      ) : null}
      <div className="grid">
        <section className="panel" aria-labelledby="h-clock">
          <h2 id="h-clock">Clock</h2>
          <dl className="facts">
            <dt>Received</dt>
            <dd>
              <When iso={g.receivedAt} /> via {g.channel.replace('_', ' ')}
            </dd>
            <dt>Acknowledge by</dt>
            <dd>
              {g.acknowledgedAt ? (
                <>
                  done <When iso={g.acknowledgedAt} />
                </>
              ) : (
                <SlaTimer dueAt={g.ackDueAt} />
              )}
            </dd>
            <dt>Acknowledgement email</dt>
            <dd>
              <YesNo value={!!g.ackEmailSentAt} yes="sent" no="not sent" />
            </dd>
            <dt>Resolve by</dt>
            <dd>
              <SlaTimer dueAt={g.resolveDueAt} closed={resolved} /> <span className="small muted">(<When iso={g.resolveDueAt} />)</span>
            </dd>
            {resolved ? (
              <>
                <dt>Resolved</dt>
                <dd>
                  <When iso={g.resolvedAt} /> by {g.resolvedBy} · reply email <YesNo value={!!g.replyEmailSentAt} yes="sent" no="not sent" />
                </dd>
              </>
            ) : null}
          </dl>
        </section>
        <section className="panel" aria-labelledby="h-who">
          <h2 id="h-who">Complainant</h2>
          <dl className="facts">
            <dt>Name</dt>
            <dd>{g.complainantName ?? <span className="muted">not given</span>}</dd>
            <dt>Email</dt>
            <dd>{g.complainantEmail}</dd>
            <dt>Language</dt>
            <dd>{g.locale ?? '—'}</dd>
          </dl>
        </section>
      </div>
      <section className="panel" aria-labelledby="h-text">
        <h2 id="h-text">Grievance</h2>
        <p className="note-text">{g.description}</p>
        {g.contentLocation ? (
          <>
            <h3>Where the content is</h3>
            <p className="note-text">{g.contentLocation}</p>
          </>
        ) : null}
      </section>
      {g.status === 'open' ? (
        <section className="panel">
          <ActionForm action={acknowledgeGrievance.bind(null, g.grievanceId)} submitLabel="Acknowledge (emails the complainant)" />
        </section>
      ) : null}
      {g.category === 'data_request' && !resolved ? (
        <p className="callout" role="note">
          A request about data or an account. To delete an account, open a{' '}
          <Link href={`/deletion-cases?grievance=${g.grievanceId}`} prefetch={false}>
            deletion case from this grievance
          </Link>{' '}
          — the account holder confirms through a link sent to the account’s own email (REQ-ADM-11).
        </p>
      ) : null}
      {resolved ? (
        <section className="panel" aria-labelledby="h-reply">
          <h2 id="h-reply">Reply sent</h2>
          <p>Outcome: {OUTCOMES.find((o) => o.key === g.outcome)?.label ?? g.outcome}</p>
          <p className="note-text">{g.reply}</p>
        </section>
      ) : (
        <section className="panel" aria-labelledby="h-resolve">
          <h2 id="h-resolve">Resolve</h2>
          <ActionForm action={resolveGrievance.bind(null, g.grievanceId)} submitLabel="Resolve and email the reply" confirm="Send this reply and resolve the grievance?">
            <fieldset>
              <legend>Outcome</legend>
              {OUTCOMES.map((o, i) => (
                <label key={o.key} className="choice">
                  <input type="radio" name="outcome" value={o.key} defaultChecked={i === 0} required /> {o.label}
                </label>
              ))}
            </fieldset>
            <div>
              <label htmlFor="reply">
                Reply to the complainant <span className="hint">(the Grievance Appellate Committee appeal route is added automatically)</span>
              </label>
              <textarea id="reply" name="reply" required minLength={10} maxLength={5000} />
            </div>
          </ActionForm>
        </section>
      )}
    </>
  );
}
