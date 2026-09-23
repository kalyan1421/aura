import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm } from '@/components/client';
import { Empty, Forbidden, Hash, PageHead, When } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { MandatoryTask } from '@/lib/types';
import { recordReport, setChecklist } from './actions';

export const metadata: Metadata = { title: 'Mandatory reports' };

const ITEMS: Array<{ key: string; label: string }> = [
  { key: 'evidence_preserved', label: 'Evidence preserved for 180 days (overrides the room purge)' },
  { key: 'account_banned', label: 'Account banned (instant ban, no strikes)' },
  { key: 'bundle_exported', label: 'Evidence bundle exported for the report (audited break-glass)' },
  { key: 'pocso_report_prepared', label: 'POCSO report prepared (police / Special Juvenile Police Unit)' },
  { key: 'ncrp_report_prepared', label: 'IT Rules report prepared (National Cybercrime Reporting Portal)' },
  { key: 'ncmec_assessed', label: 'NCMEC CyberTipline assessed (US users; file if it applies)' },
  { key: 'counsel_consulted', label: 'Counsel consulted per the SOP (lawyer action A3)' },
  { key: 'no_tipping_off_confirmed', label: 'No tipping off: only the generic closure notice; nobody contacted the family' },
];

/**
 * Minors & grooming SOP step 3 (PRD 19, REQ-ADM-14): after an instant ban, prepare the mandatory report. The console
 * tracks the checklist, exports the evidence bundle and records the external reference; the filing itself follows
 * the lawyer's SOP. A task closes only with a report reference or an Owner-recorded legal reason.
 */
export default async function MandatoryPage() {
  const data = await load<{ items: MandatoryTask[] }>('/admin/mandatory-reports');
  if (isForbidden(data)) return <Forbidden what="Mandatory reporting" />;
  return (
    <>
      <PageHead title="Mandatory reports" />
      <p className="callout">
        Target: report within 24 h of the ban. Identifiers leave Aura only through the audited export below. The reporter is never included.
        The filing steps and wording are the lawyer’s SOP; the console does not file anything.
      </p>
      {data.items.length === 0 ? (
        <Empty>No open mandatory-report tasks.</Empty>
      ) : (
        data.items.map((t) => (
          <section key={t.evidenceHoldId} className="panel" aria-labelledby={`h-${t.evidenceHoldId}`}>
            <h2 id={`h-${t.evidenceHoldId}`}>
              Evidence hold <code>{t.evidenceHoldId.slice(0, 8)}</code>
              {t.reportId ? (
                <>
                  {' · '}
                  <Link href={`/reports/${t.reportId}`} prefetch={false}>
                    open the report
                  </Link>
                </>
              ) : null}
            </h2>
            <p className="small muted">
              Opened <When iso={t.createdAt} /> · evidence held until <When iso={t.holdUntil} /> · subject{t.subjectHashes.length === 1 ? '' : 's'}:{' '}
              {t.subjectHashes.map((h) => (
                <Hash key={h} value={h} />
              ))}
            </p>
            <h3>Checklist</h3>
            <ul className="stack" aria-label="SOP checklist">
              {ITEMS.map((i) => {
                const c = t.checklist[i.key] ?? { done: false, auto: false, at: null };
                return (
                  <li key={i.key} className="row">
                    <span className={c.done ? 'yes' : 'no'} aria-hidden="true">
                      {c.done ? '✓' : '○'}
                    </span>
                    <span>
                      {i.label} <span className="sr-only">{c.done ? '(done)' : '(not done)'}</span>
                      {c.auto ? <span className="hint"> · automatic</span> : null}
                    </span>
                    {!c.auto ? (
                      <ActionForm action={setChecklist.bind(null, t.evidenceHoldId, i.key, !c.done)} submitLabel={c.done ? 'Untick' : 'Mark done'} className="inline-form" />
                    ) : null}
                  </li>
                );
              })}
            </ul>
            <h3>Export the evidence bundle</h3>
            <form method="post" action={`/evidence/${t.evidenceHoldId}/export`} className="row">
              <label htmlFor={`purpose-${t.evidenceHoldId}`} className="hint">
                Purpose (audited)
              </label>
              <select id={`purpose-${t.evidenceHoldId}`} name="purpose" defaultValue="mandatory_report">
                <option value="mandatory_report">mandatory_report</option>
                <option value="law_enforcement_request">law_enforcement_request</option>
                <option value="court_order">court_order</option>
                <option value="counsel_review">counsel_review</option>
              </select>
              <button type="submit" className="btn btn-quiet">
                Download JSON bundle
              </button>
            </form>
            <h3>Close the task</h3>
            <ActionForm action={recordReport.bind(null, t.evidenceHoldId)} submitLabel="Record and close" confirm="Close this mandatory-report task?">
              <div className="grid">
                <div>
                  <label htmlFor={`to-${t.evidenceHoldId}`}>Reported to</label>
                  <input id={`to-${t.evidenceHoldId}`} name="reportedTo" type="text" placeholder="e.g. NCRP, SJPU Hyderabad, NCMEC" />
                </div>
                <div>
                  <label htmlFor={`ref-${t.evidenceHoldId}`}>Their reference</label>
                  <input id={`ref-${t.evidenceHoldId}`} name="reportRef" type="text" />
                </div>
              </div>
              <div>
                <label htmlFor={`legal-${t.evidenceHoldId}`}>
                  Or: legal reason for not filing <span className="hint">(Owner, with counsel)</span>
                </label>
                <textarea id={`legal-${t.evidenceHoldId}`} name="legalReason" />
              </div>
            </ActionForm>
          </section>
        ))
      )}
    </>
  );
}
