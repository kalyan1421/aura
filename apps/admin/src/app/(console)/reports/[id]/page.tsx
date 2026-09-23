import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm, SlaTimer } from '@/components/client';
import { SanctionsTable } from '@/components/sanctions';
import { Badge, Empty, Hash, LaneBadge, PageHead, When, YesNo } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { ACTION_LABEL, REASON_LABEL, durationText, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { ItemView, SessionInfo } from '@/lib/types';
import { actOnReport } from './actions';

export const metadata: Metadata = { title: 'Report' };

const REASON_CODES = [
  'harassment',
  'hate',
  'sexual',
  'contact_info',
  'threat',
  'doxxing',
  'grooming',
  'minor_sexual_content',
  'under_13',
  'targeting_minor',
  'spam',
  'no_violation',
  'duplicate',
  'crisis_support',
  'other',
];

const ACTION_HELP: Record<string, string> = {
  dismiss: 'No violation. The reporter’s inbox shows “reviewed, no action”.',
  warn: 'A visible notice to the person with the reason code.',
  strike: 'The ladder: warning → 24 h shadow-mute → 7-day room suspension → social ban. Strikes stop counting after 90 days. Never for crisis reports.',
  shadow_mute: 'Their gestures silently stop reaching anyone. They are not told.',
  suspend: 'Rooms off for 24 h or 7 days; solo features keep working.',
  pause: 'Rooms paused pending review; the report stays open.',
  ban: 'Permanent account closure. The person sees only “This account was closed for breaking Aura’s rules”.',
};

/** PRD 19 "Item view and the privacy boundary": the item, room context, reporter count and reasons, the subject by
 * pseudonym and hashed id with strike history and an Under-18 flag. Never check-ins, notes, voice, capsules, DOB,
 * email or phone — the API has no route to them. */
export default async function ReportPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const [data, me] = await Promise.all([load<ItemView>(`/admin/reports/${encodeURIComponent(id)}`), apiGet<SessionInfo>('/admin/session')]);
  if (isForbidden(data)) return <Empty>Your role cannot open reports.</Empty>;
  const { report: r, subject, room, evidence } = data;
  const minors = r.lane === 'minors_grooming';

  return (
    <>
      <PageHead title={label(REASON_LABEL, r.reasonKey)}>
        <LaneBadge lane={r.lane} />
        {r.involvesMinor ? <Badge tone="alert">Under 18 involved</Badge> : null}
        {r.pages ? <Badge>Pages 24×7</Badge> : null}
        <Badge>{r.status}</Badge>
      </PageHead>

      <div className="grid">
        <section className="panel" aria-labelledby="h-report">
          <h2 id="h-report">Report</h2>
          <dl className="facts">
            <dt>SLA</dt>
            <dd>{r.status === 'open' ? <SlaTimer dueAt={r.slaDueAt} /> : <span className="sla sla-closed">closed</span>}</dd>
            <dt>Arrived</dt>
            <dd>
              <When iso={r.createdAt} />
            </dd>
            <dt>Target</dt>
            <dd>
              {r.targetKind}
              {r.source === 'auto' ? ` (automatic: ${r.autoSignal ?? 'signal'})` : ''}
            </dd>
            <dt>Reporters</dt>
            <dd>
              {r.reporters.count} on this item · {r.reporters.reasons.map((x) => label(REASON_LABEL, x)).join(', ') || '—'}
              <div className="small muted">Reporters are never identified.</div>
            </dd>
            {r.resolvedAt ? (
              <>
                <dt>Closed</dt>
                <dd>
                  <When iso={r.resolvedAt} /> by {r.resolvedBy}
                </dd>
              </>
            ) : null}
          </dl>
          {r.note ? (
            <>
              <h3>Reporter’s note</h3>
              <p className="note-text">{r.note}</p>
            </>
          ) : null}
        </section>

        <section className="panel" aria-labelledby="h-subject">
          <h2 id="h-subject">Subject</h2>
          {subject ? (
            <dl className="facts">
              <dt>Pseudonym</dt>
              <dd>{subject.pseudonym ?? <span className="muted">—</span>}</dd>
              <dt>Hashed id</dt>
              <dd>
                <Hash value={subject.hash} />
              </dd>
              <dt>Account age</dt>
              <dd>{subject.accountAgeDays === null ? '—' : durationText(subject.accountAgeDays * 1440)}</dd>
              <dt>Under 18</dt>
              <dd>
                <YesNo value={subject.under18} />
              </dd>
              <dt>Active strikes</dt>
              <dd>{subject.activeStrikes}</dd>
            </dl>
          ) : (
            <p className="muted">No single account (a room report, or the account was deleted).</p>
          )}
        </section>
      </div>

      {minors ? (
        <div className="callout danger" role="note">
          <strong>Minors &amp; grooming SOP.</strong> On confirming sexual content involving or aimed at a minor, or grooming: ban (one action,
          no strikes) · evidence kept 180 days · mandatory report (POCSO / National Cybercrime Reporting Portal; NCMEC where US law applies)
          following the lawyer’s SOP · no tipping off · nobody contacts the family.{' '}
          <Link href="/mandatory" prefetch={false}>
            Mandatory reports
          </Link>
        </div>
      ) : null}

      {data.allowedActions.length > 0 ? (
        <section className="panel" aria-labelledby="h-act">
          <h2 id="h-act">Act</h2>
          <ActionForm action={actOnReport.bind(null, r.reportId)} submitLabel="Apply">
            <fieldset>
              <legend>Action</legend>
              {data.allowedActions.map((a, i) => (
                <label key={a} className="choice">
                  <input type="radio" name="action" value={a} defaultChecked={i === 0} required />
                  <span>
                    <strong>{ACTION_LABEL[a] ?? a}</strong>
                    <span className="hint"> — {ACTION_HELP[a]}</span>
                  </span>
                </label>
              ))}
            </fieldset>
            <div className="grid">
              <div>
                <label htmlFor="reasonCode">Reason code (goes to the audit log and the person’s notice)</label>
                <select id="reasonCode" name="reasonCode" defaultValue={REASON_CODES.includes(r.reasonKey) ? r.reasonKey : 'other'}>
                  {REASON_CODES.map((c) => (
                    <option key={c} value={c}>
                      {c}
                    </option>
                  ))}
                  <option value="custom">custom…</option>
                </select>
              </div>
              <div>
                <label htmlFor="customReason">
                  Custom reason code <span className="hint">(if “custom…”: a–z, 0–9, _)</span>
                </label>
                <input id="customReason" name="customReason" type="text" pattern="[a-z0-9_]{1,40}" />
              </div>
              {data.allowedActions.includes('shadow_mute') ? (
                <div>
                  <label htmlFor="muteHours">Shadow-mute length</label>
                  <select id="muteHours" name="muteHours" defaultValue="168">
                    <option value="24">24 hours</option>
                    <option value="72">3 days</option>
                    <option value="168">7 days</option>
                    {me.staff.role === 'owner' ? <option value="720">30 days (Owner)</option> : null}
                  </select>
                </div>
              ) : null}
              {data.allowedActions.includes('suspend') ? (
                <div>
                  <label htmlFor="suspendHours">Suspension length</label>
                  <select id="suspendHours" name="suspendHours" defaultValue="24">
                    <option value="24">24 hours</option>
                    <option value="168">7 days</option>
                  </select>
                </div>
              ) : null}
            </div>
            {data.allowedActions.includes('ban') ? (
              <label className="choice">
                <input type="checkbox" name="confirmBan" value="yes" />
                <span>
                  If banning: I confirm the ban{minors ? ' under the minors & grooming SOP (180-day evidence hold and a mandatory-report task)' : ''}.
                </span>
              </label>
            ) : null}
          </ActionForm>
        </section>
      ) : (
        <p className="callout ok">{r.status === 'open' ? 'Your role has no actions on this report.' : 'This report is closed.'}</p>
      )}

      {subject ? (
        <section aria-labelledby="h-history">
          <h2 id="h-history">History of this account</h2>
          <h3>Sanctions</h3>
          <SanctionsTable sanctions={subject.sanctions} role={me.staff.role} />
          <h3>Strikes</h3>
          {subject.strikes.length === 0 ? (
            <Empty>No strikes.</Empty>
          ) : (
            <ul>
              {subject.strikes.map((s) => (
                <li key={s.strikeId}>
                  <code>{s.reasonCode}</code> · <When iso={s.createdAt} /> · {s.active ? 'counts until ' : 'expired '}
                  <When iso={s.expiresAt} />
                </li>
              ))}
            </ul>
          )}
          <h3>Other reports about this account</h3>
          {subject.otherReports.length === 0 ? (
            <Empty>None.</Empty>
          ) : (
            <ul>
              {subject.otherReports.map((o) => (
                <li key={o.reportId}>
                  <Link href={`/reports/${o.reportId}`} prefetch={false}>
                    {label(REASON_LABEL, o.reasonKey)}
                  </Link>{' '}
                  · <LaneBadge lane={o.lane} /> · {o.status} · <When iso={o.createdAt} />
                </li>
              ))}
            </ul>
          )}
        </section>
      ) : null}

      <section className="panel" aria-labelledby="h-room">
        <h2 id="h-room">Room context</h2>
        {room ? (
          <dl className="facts">
            <dt>Room</dt>
            <dd>
              {room.quadrant} · {room.languagePool} pool · {room.tzRegion} · {room.ageHours} h old · {room.status}
            </dd>
            <dt>Becomes a memory</dt>
            <dd>
              <When iso={room.memoryAt} />
            </dd>
            <dt>Purged</dt>
            <dd>
              <When iso={room.purgeAt} /> <span className="muted">(evidence is kept separately for 180 days)</span>
            </dd>
          </dl>
        ) : (
          <p className="muted">The room has been purged. The evidence snapshot below is what remains.</p>
        )}
      </section>

      <section className="panel" aria-labelledby="h-evidence">
        <h2 id="h-evidence">Evidence</h2>
        {evidence ? (
          <>
            <p className="small muted">
              Snapshot taken <When iso={evidence.capturedAt} /> · held until <When iso={evidence.holdUntil} />
              {evidence.mandatoryReportRequired ? (evidence.mandatoryReportClosed ? ' · mandatory report recorded' : ' · mandatory report pending') : ''}
            </p>
            {evidence.room ? (
              <p className="small">
                Room at capture: {evidence.room.quadrant} · {evidence.room.languagePool} · {evidence.room.tzRegion}
              </p>
            ) : null}
            <h3>People</h3>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th scope="col">Who</th>
                    <th scope="col">Role</th>
                    <th scope="col">Hashed id</th>
                    <th scope="col">Mood at join</th>
                    <th scope="col">Joined</th>
                    <th scope="col">Left</th>
                  </tr>
                </thead>
                <tbody>
                  {evidence.people.map((p, i) => (
                    <tr key={`${p.label}-${i}`}>
                      <td>{p.label}</td>
                      <td>{p.role}</td>
                      <td>
                        <Hash value={p.subjectHash} />
                      </td>
                      <td>{p.moodAtJoin ?? '—'}</td>
                      <td className="small nowrap">
                        <When iso={p.joinedAt} />
                      </td>
                      <td className="small nowrap">
                        <When iso={p.leftAt} />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <h3>Gestures</h3>
            {evidence.gestures.length === 0 ? (
              <Empty>No gestures in the snapshot.</Empty>
            ) : (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th scope="col">Gesture</th>
                      <th scope="col">From</th>
                      <th scope="col">To</th>
                      <th scope="col">Delivered</th>
                      <th scope="col">At</th>
                    </tr>
                  </thead>
                  <tbody>
                    {evidence.gestures.map((g, i) => (
                      <tr key={i}>
                        <td>{g.type ?? '—'}</td>
                        <td>{g.from ?? '—'}</td>
                        <td>{g.to ?? (g.target === 'room' ? 'the room' : '—')}</td>
                        <td>{g.dropped ? `no (${g.dropped})` : 'yes'}</td>
                        <td className="small nowrap">
                          <When iso={g.at} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </>
        ) : (
          <p className="muted">No evidence snapshot on this report.</p>
        )}
      </section>

      <section className="panel" aria-labelledby="h-audit">
        <h2 id="h-audit">Audit trail</h2>
        {data.audit.length === 0 ? (
          <Empty>Nothing yet.</Empty>
        ) : (
          <ol className="small">
            {data.audit.map((a) => (
              <li key={a.id}>
                <When iso={a.createdAt} /> · <strong>{a.action}</strong>
                {a.reasonCode ? (
                  <>
                    {' '}
                    (<code>{a.reasonCode}</code>)
                  </>
                ) : null}{' '}
                · {a.actor}
              </li>
            ))}
          </ol>
        )}
      </section>
    </>
  );
}
