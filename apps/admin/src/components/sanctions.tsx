import Link from 'next/link';
import { liftSanction } from '@/app/(console)/reports/[id]/actions';
import { ActionForm } from '@/components/client';
import { Hash, When } from '@/components/ui';
import { SANCTION_LABEL, label } from '@/lib/format';
import type { SanctionView, StaffRole } from '@/lib/types';

const BANS = new Set(['account_ban', 'social_ban']);

/** Sanctions with an inline "lift" form; lifting a ban (unban) is offered to the Owner only (NestJS enforces it too). */
export function SanctionsTable({ sanctions, role, showSubject = false }: { sanctions: SanctionView[]; role: StaffRole; showSubject?: boolean }) {
  if (sanctions.length === 0) return <p className="empty">No sanctions.</p>;
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            <th scope="col">Sanction</th>
            {showSubject ? <th scope="col">Subject</th> : null}
            <th scope="col">Reason</th>
            <th scope="col">From</th>
            <th scope="col">Until</th>
            <th scope="col">By</th>
            <th scope="col">Lift</th>
          </tr>
        </thead>
        <tbody>
          {sanctions.map((s) => {
            const canLift = s.active && (!BANS.has(s.kind) || role === 'owner');
            return (
              <tr key={s.sanctionId}>
                <td>
                  {label(SANCTION_LABEL, s.kind)}
                  <div className="small muted">
                    {s.active ? 'active' : s.liftedAt ? 'lifted' : 'ended'}
                    {s.reportId ? (
                      <>
                        {' · '}
                        <Link href={`/reports/${s.reportId}`} prefetch={false}>
                          report
                        </Link>
                      </>
                    ) : null}
                  </div>
                </td>
                {showSubject ? (
                  <td>
                    <Hash value={s.subjectHash} />
                  </td>
                ) : null}
                <td>
                  <code>{s.reasonCode}</code>
                </td>
                <td className="nowrap small">
                  <When iso={s.startsAt} />
                </td>
                <td className="nowrap small">{s.endsAt ? <When iso={s.endsAt} /> : <span className="muted">until lifted</span>}</td>
                <td className="small">{s.createdBy}</td>
                <td>
                  {canLift ? (
                    <ActionForm
                      action={liftSanction.bind(null, s.sanctionId)}
                      submitLabel={BANS.has(s.kind) ? 'Unban' : 'Lift'}
                      confirm={BANS.has(s.kind) ? 'Lift this ban? The account regains access at once.' : undefined}
                      className="stack small"
                    >
                      <label htmlFor={`lift-${s.sanctionId}`} className="hint">
                        Reason code
                      </label>
                      <select id={`lift-${s.sanctionId}`} name="reasonCode" defaultValue="appeal_upheld">
                        <option value="appeal_upheld">appeal_upheld</option>
                        <option value="review_cleared">review_cleared</option>
                        <option value="mistake">mistake</option>
                      </select>
                    </ActionForm>
                  ) : (
                    <span className="muted small">{s.active ? 'Owner only' : '—'}</span>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
