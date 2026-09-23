import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm } from '@/components/client';
import { Badge, Forbidden, Hash, PageHead, When } from '@/components/ui';
import { CLOSE_OUTCOME_LABEL, DELETION_STATUS_LABEL, IMMEDIATE_REASON_LABEL, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { DeletionCase } from '@/lib/types';
import { closeCase, resendLink, startDeletion } from '../actions';

export const metadata: Metadata = { title: 'Deletion case' };

const CLOSE_OUTCOMES = ['withdrawn', 'unverified', 'duplicate', 'declined_by_holder', 'restored_by_holder', 'other'] as const;

/**
 * One deletion case (REQ-ADM-11): where the verification stands, then the app's own deletion — deactivated at once,
 * deleted by the hourly purge after the 7-day grace (or immediately, with an audited reason). The completed case shows
 * how many evidence records about the account the legal hold keeps, and until when.
 */
export default async function DeletionCasePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const c = await load<DeletionCase>(`/admin/deletion-cases/${encodeURIComponent(id)}`);
  if (isForbidden(c)) return <Forbidden what="Deletion cases" />;
  const restored = c.status === 'deletion_scheduled' && c.deletion && !c.deletion.pending;
  return (
    <>
      <PageHead title={`Deletion case ${c.ticket}`}>
        <Badge tone={c.status === 'declined' ? 'alert' : 'quiet'}>{label(DELETION_STATUS_LABEL, c.status)}</Badge>
      </PageHead>
      {c.status === 'declined' ? (
        <p className="callout danger" role="note">
          The account holder pressed “This wasn’t me”. Nothing will be deleted. Consider whether the request was an attempt to delete someone
          else’s account, then close the case.
        </p>
      ) : null}
      {restored ? (
        <p className="callout ok" role="note">
          The account holder signed in and kept the account during the grace period. Close the case (“Account holder kept the account”).
        </p>
      ) : null}
      <div className="grid">
        <section className="panel" aria-labelledby="h-req">
          <h2 id="h-req">Request</h2>
          <dl className="facts">
            <dt>Received</dt>
            <dd>
              <When iso={c.receivedAt} /> via {c.channel}
            </dd>
            {c.grievanceId ? (
              <>
                <dt>Grievance</dt>
                <dd>
                  <Link href={`/grievances/${c.grievanceId}`} prefetch={false}>
                    {c.grievanceTicket ?? 'open'}
                  </Link>
                </dd>
              </>
            ) : null}
            <dt>Account</dt>
            <dd>{c.accountEmailMasked ?? <span className="muted">{c.status === 'completed' ? 'deleted' : '—'}</span>}</dd>
            <dt>Hashed id</dt>
            <dd>
              <Hash value={c.subjectHash} />
            </dd>
            <dt>Opened</dt>
            <dd>
              <When iso={c.createdAt} /> by {c.createdBy}
            </dd>
          </dl>
        </section>
        <section className="panel" aria-labelledby="h-verify">
          <h2 id="h-verify">Verification (link to the account’s own email)</h2>
          <dl className="facts">
            <dt>Link sent</dt>
            <dd>
              {c.verification.sentAt ? <When iso={c.verification.sentAt} /> : <span className="muted">not sent{c.verification.attempts ? ' (mail failed)' : ''}</span>}
            </dd>
            <dt>Link expires</dt>
            <dd>
              <When iso={c.verification.expiresAt} />
            </dd>
            <dt>Confirmed</dt>
            <dd>
              <When iso={c.verification.verifiedAt} />
            </dd>
            {c.verification.declinedAt ? (
              <>
                <dt>Declined</dt>
                <dd>
                  <When iso={c.verification.declinedAt} />
                </dd>
              </>
            ) : null}
          </dl>
          {c.allowed.resend ? <ActionForm action={resendLink.bind(null, c.caseId)} submitLabel="Send a new link" className="stack spaced" /> : null}
        </section>
      </div>

      <section className="panel" aria-labelledby="h-del">
        <h2 id="h-del">Deletion</h2>
        {c.deletion ? (
          <dl className="facts">
            <dt>Started</dt>
            <dd>
              <When iso={c.deletion.requestedAt} /> by {c.deletion.requestedBy}
            </dd>
            <dt>Mode</dt>
            <dd>{c.deletion.mode === 'immediate' ? `immediate — ${label(IMMEDIATE_REASON_LABEL, c.deletion.reasonCode)}` : '7-day grace (restorable by signing in)'}</dd>
            <dt>Purge due</dt>
            <dd>
              <When iso={c.deletion.scheduledFor} /> {c.deletion.pending ? '' : <span className="muted">(no longer pending)</span>}
            </dd>
            {c.completedAt ? (
              <>
                <dt>Deleted</dt>
                <dd>
                  <When iso={c.completedAt} />
                </dd>
              </>
            ) : null}
          </dl>
        ) : c.allowed.startDeletion ? (
          <ActionForm action={startDeletion.bind(null, c.caseId)} submitLabel="Start the deletion" danger confirm="Start deleting this account?">
            <fieldset>
              <legend>How</legend>
              <label className="choice">
                <input type="radio" name="mode" value="grace" defaultChecked /> The app’s deletion: deactivated now, deleted after 7 days (signing in
                before then keeps it)
              </label>
              <label className="choice">
                <input type="radio" name="mode" value="immediate" /> Immediately (the next hourly purge) — only with a reason:
              </label>
              <label htmlFor="reasonCode" className="sr-only">
                Reason for an immediate deletion
              </label>
              <select id="reasonCode" name="reasonCode" defaultValue="requester_asked_immediate">
                {Object.entries(IMMEDIATE_REASON_LABEL).map(([k, v]) => (
                  <option key={k} value={k}>
                    {v}
                  </option>
                ))}
              </select>
              <label className="choice">
                <input type="checkbox" name="confirmImmediate" value="yes" /> If immediate: I understand it cannot be undone.
              </label>
            </fieldset>
          </ActionForm>
        ) : (
          <p className="muted">
            {c.status === 'awaiting_verification'
              ? 'Waiting for the account holder to confirm through the link. Nothing can be deleted before that.'
              : 'No deletion for this case.'}
          </p>
        )}
      </section>

      <section className="panel" aria-labelledby="h-hold">
        <h2 id="h-hold">Legal hold</h2>
        <p>
          {c.legalHold.records
            ? `${c.legalHold.records} evidence record(s) about this account are kept past the deletion until `
            : 'No evidence records about this account are under legal hold.'}
          {c.legalHold.records ? <When iso={c.legalHold.until} /> : null}
          {c.legalHold.records ? ' (reported content; PRD: removed content preserved 180 days).' : null}
        </p>
      </section>

      {c.allowed.close ? (
        <section className="panel" aria-labelledby="h-close">
          <h2 id="h-close">Close without deleting</h2>
          <ActionForm action={closeCase.bind(null, c.caseId)} submitLabel="Close the case">
            <label htmlFor="outcome">Outcome</label>
            <select id="outcome" name="outcome" defaultValue={c.status === 'declined' ? 'declined_by_holder' : restored ? 'restored_by_holder' : 'unverified'}>
              {CLOSE_OUTCOMES.map((o) => (
                <option key={o} value={o}>
                  {CLOSE_OUTCOME_LABEL[o]}
                </option>
              ))}
            </select>
          </ActionForm>
        </section>
      ) : null}
      {c.closedAt ? (
        <p className="muted small">
          Closed <When iso={c.closedAt} /> by {c.closedBy} — {label(CLOSE_OUTCOME_LABEL, c.closeOutcome)}
        </p>
      ) : null}
    </>
  );
}
