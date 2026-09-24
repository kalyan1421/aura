import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound, unstable_rethrow } from 'next/navigation';
import { ActionForm, SlaTimer } from '@/components/client';
import { Badge, Empty, Hash, LaneBadge, PageHead, When, YesNo } from '@/components/ui';
import { ApiFailure } from '@/lib/api';
import { LANE_LABEL, REASON_LABEL, SANCTION_LABEL, durationText, label } from '@/lib/format';
import { isForbidden, load, type Forbidden } from '@/lib/load';
import {
  HOLD_REASON_LABEL,
  POOL_LABEL,
  REFLECTION_REASON_CODES,
  REJECT_REASONS,
  REJECT_REASON_LABEL,
  SCORE_HIGHLIGHT,
  STAGE_LABEL,
  STATUS_LABEL,
  decisionLabel,
  defaultReasonCode,
  formatScore,
  isCrisis,
  isUuid,
  scoreRows,
  supportSheetShown,
  type ReflectionDecision,
  type ReviewView,
} from '@/lib/reflections';
import { decideReflection } from '../actions';

export const metadata: Metadata = { title: 'Reflection' };

const DECISION_HELP: Record<ReflectionDecision, { normal: string; crisis: string }> = {
  approve: {
    normal: 'Publishes it to the room. Its open reports close as “reviewed, no action” and an automatic shadow-mute from them is lifted.',
    crisis: 'The crisis flag was wrong: the reflection publishes to the room and its reports close as reviewed, no action.',
  },
  remove: {
    normal: 'Held or pending → rejected (the author sees the reason below). Published → taken down. Open reports close as actioned.',
    crisis: 'It stays unpublished; nothing else reaches the author. Never a strike.',
  },
  escalate: {
    normal: 'Moves its open report to a higher lane, recomputes the SLA and pages the Owner when the new lane pages.',
    crisis: 'Moves its open report to a higher lane (e.g. grooming alongside the crisis signal) and pages the Owner when that lane pages.',
  },
};

/**
 * One reflection for review (contracts/api/v1-reflections.md §4 `ReviewView`; PRD 19 "Item view and the privacy
 * boundary"; US-42 for crisis-flagged items). The author appears only as pseudonym, hashed id, account age, an
 * Under-18 flag and strike history — never DOB, email or account id (the API has no route to them).
 */
export default async function ReflectionPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isUuid(id)) notFound();
  let data: ReviewView | Forbidden;
  try {
    data = await load<ReviewView>(`/admin/reflections/${encodeURIComponent(id)}`);
  } catch (e) {
    unstable_rethrow(e);
    // PRD 19 "Queue sessions capped at 2 h": non-urgent items wait for a break; crisis and paging items stay open.
    if (e instanceof ApiFailure && e.code === 'queue_session_cap') {
      return (
        <section className="panel" aria-labelledby="h-break">
          <h1 id="h-break">Time for a break</h1>
          <p>{e.message}</p>
          <p className="muted small">
            Crisis and paging items stay open to you. The{' '}
            <Link href="/now" prefetch={false}>
              Now
            </Link>{' '}
            list and the queue keep showing deadlines.
          </p>
        </section>
      );
    }
    throw e;
  }
  if (isForbidden(data)) return <Empty>Your role cannot open reflections.</Empty>;
  const v = data;
  const crisis = isCrisis(v);
  const sheet = supportSheetShown(v);
  // The crisis wording of the help texts fits an unpublished crisis item; a published one reads like any other.
  const crisisHelp = crisis && v.status !== 'published';
  const scores = scoreRows(v.scores);
  const openReports = v.reports.filter((r) => r.status === 'open');
  const reason = v.holdReason ? label(HOLD_REASON_LABEL, v.holdReason) : v.rejectReason ? label(REJECT_REASON_LABEL, v.rejectReason) : null;

  return (
    <>
      <p className="small">
        <Link href="/reflections" prefetch={false}>
          ← Reflections
        </Link>
      </p>
      <PageHead title={crisis ? 'Crisis-flagged reflection' : 'Reflection'}>
        <Badge tone={v.status === 'crisis_diverted' ? 'alert' : 'quiet'}>{label(STATUS_LABEL, v.status)}</Badge>
        {v.hidden ? <Badge>hidden by reports</Badge> : null}
        {v.involvesMinor ? <Badge tone="alert">Under 18 involved</Badge> : null}
        {v.report ? <LaneBadge lane={v.report.lane} /> : null}
        {v.report?.pages ? <Badge>Pages 24×7</Badge> : null}
      </PageHead>

      {crisis ? (
        <div className="callout danger" role="note" aria-labelledby="h-playbook">
          <strong id="h-playbook">Crisis playbook.</strong>{' '}
          {v.status === 'crisis_diverted' ? 'This reflection was never published. ' : ''}
          {sheet ? 'The support sheet opened on the author’s phone the moment it was sent. ' : ''}
          Decide within 15 minutes at Lantern Hour:
          <ol className="small">
            <li>
              <strong>{v.status === 'published' ? 'Take down' : 'Keep unpublished'}</strong> if the text expresses distress or self-harm — the default.
            </li>
            <li>
              <strong>{v.status === 'published' ? 'Keep published' : 'Release as a false positive'}</strong> only when it clearly is not (e.g. “this exam is killing me”).
            </li>
            <li>
              <strong>Escalate</strong> when there is also grooming or a minor at risk.
            </li>
          </ol>
          <p className="small">
            Never a strike for a crisis flag. You never counsel, message or contact the person; the app’s support sheet and helplines do that.
          </p>
        </div>
      ) : null}

      <section className="panel" aria-labelledby="h-text">
        <h2 id="h-text">The reflection</h2>
        {v.text === null ? (
          <p className="muted">The text has been scrubbed (the author deleted it, or it expired when the room became a memory).</p>
        ) : (
          <p className="note-text" style={{ fontSize: '1.15rem' }}>
            {v.text}
          </p>
        )}
        <dl className="facts">
          <dt>Status</dt>
          <dd>
            {label(STATUS_LABEL, v.status)}
            {v.hidden ? ' · hidden by reports (waits for a human)' : ''}
          </dd>
          {reason ? (
            <>
              <dt>{v.holdReason ? 'Held because' : 'Reason the author sees'}</dt>
              <dd>{reason}</dd>
            </>
          ) : null}
          <dt>Decided by</dt>
          <dd>
            {v.stage ? label(STAGE_LABEL, v.stage) : '—'}
            {v.decidedBy ? ` (${v.decidedBy})` : ''}
            {v.decidedAt ? (
              <>
                {' · '}
                <When iso={v.decidedAt} />
              </>
            ) : null}
          </dd>
          <dt>Written</dt>
          <dd>
            <When iso={v.createdAt} /> · {v.charCount} characters · {label(POOL_LABEL, v.languagePool)} pool
          </dd>
          {v.publishedAt ? (
            <>
              <dt>Published</dt>
              <dd>
                <When iso={v.publishedAt} /> · {v.gestureCount} gesture{v.gestureCount === 1 ? '' : 's'} on it
              </dd>
            </>
          ) : null}
          {v.hiddenAt ? (
            <>
              <dt>Hidden</dt>
              <dd>
                <When iso={v.hiddenAt} />
              </dd>
            </>
          ) : null}
          {v.removedAt ? (
            <>
              <dt>Removed</dt>
              <dd>
                <When iso={v.removedAt} />
              </dd>
            </>
          ) : null}
          {crisis ? (
            <>
              <dt>Support sheet</dt>
              <dd>
                <YesNo value={sheet} yes="shown to the author" no="not shown (flagged by a report)" />
              </dd>
            </>
          ) : null}
        </dl>
      </section>

      {v.allowedDecisions.length > 0 ? (
        <section className="panel" aria-labelledby="h-decide">
          <h2 id="h-decide">Decide</h2>
          <ActionForm
            action={decideReflection.bind(null, v.reflectionId, { allowed: v.allowedDecisions, canStrike: v.canStrike, crisis })}
            submitLabel="Apply"
          >
            <fieldset>
              <legend>Decision</legend>
              {v.allowedDecisions.map((d, i) => (
                <label key={d} className="choice">
                  <input type="radio" name="decision" value={d} defaultChecked={i === 0} required />
                  <span>
                    <strong>{decisionLabel(d, { status: v.status, crisis })}</strong>
                    <span className="hint"> — {crisisHelp ? DECISION_HELP[d].crisis : DECISION_HELP[d].normal}</span>
                  </span>
                </label>
              ))}
            </fieldset>
            <div className="grid">
              <div>
                <label htmlFor="reasonCode">Reason code (goes to the audit log)</label>
                <select id="reasonCode" name="reasonCode" defaultValue={defaultReasonCode(v)}>
                  {REFLECTION_REASON_CODES.map((c) => (
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
              {v.allowedDecisions.includes('remove') && v.status !== 'crisis_diverted' ? (
                <div>
                  <label htmlFor="rejectReason">
                    If removing: reason the author sees <span className="hint">(default: other)</span>
                  </label>
                  <select id="rejectReason" name="rejectReason" defaultValue={v.rejectReason ?? 'other'}>
                    {REJECT_REASONS.map((r) => (
                      <option key={r} value={r}>
                        {REJECT_REASON_LABEL[r]}
                      </option>
                    ))}
                  </select>
                </div>
              ) : null}
              {v.allowedDecisions.includes('escalate') ? (
                <div>
                  <label htmlFor="lane">If escalating: lane</label>
                  <select id="lane" name="lane" defaultValue="minors_grooming">
                    <option value="minors_grooming">{LANE_LABEL.minors_grooming}</option>
                    <option value="crisis">{LANE_LABEL.crisis}</option>
                  </select>
                </div>
              ) : null}
            </div>
            {v.allowedDecisions.includes('remove') && v.canStrike && !crisis ? (
              <label className="choice">
                <input type="checkbox" name="strike" value="yes" />
                <span>
                  If removing: also add a strike through the ladder{' '}
                  <span className="hint">(warning → 24 h mute → 7-day room suspension → the 4th active strike bans; only harassment, hate, sexual and spam)</span>
                </span>
              </label>
            ) : null}
          </ActionForm>
        </section>
      ) : (
        <p className="callout ok">No decisions are open to you on this reflection ({label(STATUS_LABEL, v.status).toLowerCase()}).</p>
      )}

      <div className="grid">
        <section className="panel" aria-labelledby="h-mod">
          <h2 id="h-mod">Automatic checks</h2>
          <dl className="facts">
            <dt>Stricter thresholds</dt>
            <dd>
              <YesNo value={v.strict} yes="applied" no="no" />
              {v.strict ? <span className="small muted"> (under 18 involved, or the te / hi pool)</span> : null}
            </dd>
            <dt>Overnight window</dt>
            <dd>
              <YesNo value={v.overnight} yes="yes" no="no" />
              {v.overnight ? <span className="small muted"> (only clean-with-high-confidence text publishes overnight)</span> : null}
            </dd>
            <dt>Rule hits</dt>
            <dd>
              {v.ruleHits.length === 0 ? (
                <span className="muted">none</span>
              ) : (
                v.ruleHits.map((h, i) => (
                  <span key={h}>
                    {i ? ', ' : ''}
                    <code>{h}</code>
                  </span>
                ))
              )}
            </dd>
          </dl>
          <h3>Omni-moderation scores</h3>
          {scores.length === 0 ? (
            <Empty>{v.scores === null ? 'Never classified (rules decided, or the provider was unavailable).' : 'No scores.'}</Empty>
          ) : (
            <div className="table-wrap">
              <table>
                <caption className="caption">Highest first; {formatScore(SCORE_HIGHLIGHT)} and above are marked.</caption>
                <thead>
                  <tr>
                    <th scope="col">Category</th>
                    <th scope="col">Score</th>
                  </tr>
                </thead>
                <tbody>
                  {scores.map((s) => (
                    <tr key={s.category}>
                      <td>
                        <code>{s.category}</code>
                      </td>
                      <td>{s.high ? <strong className="sla-overdue">{s.text} · high</strong> : <span className="muted">{s.text}</span>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <section className="panel" aria-labelledby="h-author">
          <h2 id="h-author">Author</h2>
          <dl className="facts">
            <dt>Pseudonym</dt>
            <dd>{v.author.pseudonym}</dd>
            <dt>Hashed id</dt>
            <dd>
              <Hash value={v.author.hash} />
            </dd>
            <dt>Account age</dt>
            <dd>{v.author.accountAgeDays === null ? '—' : durationText(v.author.accountAgeDays * 1440)}</dd>
            <dt>Under 18</dt>
            <dd>
              <YesNo value={v.author.under18} />
            </dd>
            <dt>Active strikes</dt>
            <dd>{v.author.activeStrikes}</dd>
          </dl>
          <h3>Strikes</h3>
          {v.author.strikes.length === 0 ? (
            <Empty>No strikes.</Empty>
          ) : (
            <ul className="small">
              {v.author.strikes.map((s) => (
                <li key={s.strikeId}>
                  <code>{s.reasonCode}</code> · <When iso={s.createdAt} /> · {s.active ? 'counts until ' : 'expired '}
                  <When iso={s.expiresAt} />
                </li>
              ))}
            </ul>
          )}
          <h3>Sanctions</h3>
          {v.author.sanctions.length === 0 ? (
            <Empty>No sanctions.</Empty>
          ) : (
            <ul className="small">
              {v.author.sanctions.map((s) => (
                <li key={s.sanctionId}>
                  {label(SANCTION_LABEL, s.kind)} ({s.active ? 'active' : 'ended'}) · <code>{s.reasonCode}</code> · {s.source} · <When iso={s.startsAt} />
                  {' → '}
                  {s.endsAt ? <When iso={s.endsAt} /> : <span className="muted">until lifted</span>}
                </li>
              ))}
            </ul>
          )}
          <p className="small muted">Lift sanctions from the linked report or Sanctions.</p>
          <h3>Other reports about this account</h3>
          {(v.author.otherReports ?? []).length === 0 ? (
            <Empty>None.</Empty>
          ) : (
            <ul className="small">
              {(v.author.otherReports ?? []).map((o) => (
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
      </div>

      <section className="panel" aria-labelledby="h-room">
        <h2 id="h-room">Room context</h2>
        {v.roomContext ? (
          <>
            <dl className="facts">
              <dt>Room</dt>
              <dd>
                {v.roomContext.quadrant} · {label(POOL_LABEL, v.roomContext.languagePool)} pool · {v.roomContext.tzRegion} · {v.roomContext.ageHours} h old ·{' '}
                {v.roomContext.state}
              </dd>
              <dt>Becomes a memory</dt>
              <dd>
                <When iso={v.roomContext.memoryAt} />
              </dd>
              <dt>Purged</dt>
              <dd>
                <When iso={v.roomContext.purgeAt} />
              </dd>
            </dl>
            <h3>Other published reflections in the room</h3>
            {v.roomContext.others.length === 0 ? (
              <Empty>None.</Empty>
            ) : (
              <ul className="stack">
                {v.roomContext.others.map((o) => (
                  <li key={o.reflectionId}>
                    <span className="small">
                      <strong>{o.pseudonym}</strong> · <When iso={o.publishedAt} /> ·{' '}
                      <Link href={`/reflections/${o.reflectionId}`} prefetch={false}>
                        open
                      </Link>
                    </span>
                    {o.text === null ? <p className="muted small">(scrubbed)</p> : <p className="note-text">{o.text}</p>}
                  </li>
                ))}
              </ul>
            )}
          </>
        ) : (
          <p className="muted">The room has been purged.</p>
        )}
      </section>

      <section className="panel" aria-labelledby="h-reports">
        <h2 id="h-reports">Reports on this reflection</h2>
        {v.reports.length === 0 ? (
          <Empty>No reports.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <caption className="caption">
                {openReports.length} open of {v.reports.length}
              </caption>
              <thead>
                <tr>
                  <th scope="col">Lane</th>
                  <th scope="col">Reason</th>
                  <th scope="col">Status</th>
                  <th scope="col">Arrived</th>
                  <th scope="col">SLA</th>
                </tr>
              </thead>
              <tbody>
                {v.reports.map((r) => (
                  <tr key={r.reportId}>
                    <td className="nowrap">
                      <LaneBadge lane={r.lane} /> {r.pages ? <Badge>Pages</Badge> : null}
                    </td>
                    <td>
                      <Link href={`/reports/${r.reportId}`} prefetch={false}>
                        {label(REASON_LABEL, r.reasonKey)}
                      </Link>
                      <div className="small muted">{r.source === 'auto' ? `automatic (${r.autoSignal ?? 'signal'})` : 'from a person in the room'}</div>
                    </td>
                    <td>{r.status}</td>
                    <td className="nowrap small">
                      <When iso={r.createdAt} />
                    </td>
                    <td className="nowrap">{r.status === 'open' ? <SlaTimer dueAt={r.slaDueAt} /> : <span className="sla sla-closed">closed</span>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="panel" aria-labelledby="h-audit">
        <h2 id="h-audit">Audit trail</h2>
        {v.audit.length === 0 ? (
          <Empty>Nothing yet.</Empty>
        ) : (
          <ol className="small">
            {v.audit.map((a) => (
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
