import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { Forbidden, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { isForbidden, load } from '@/lib/load';
import type { PseudonymConfig } from '@/lib/pseudonyms';
import type { SessionInfo } from '@/lib/types';
import { setPseudonymBlocked } from './actions';

export const metadata: Metadata = { title: 'Pseudonyms' };

/**
 * Room pseudonyms (PRD 19 "Configuration: pseudonym word lists … plus an offensive-combination blocklist"). The word
 * lists are curated in code and change by review (like copy); the same names serve every language, never translated.
 * The Owner takes a combination out of use here at once, with a reason; new room seats and Breath Ripples seats never
 * get it. A room already showing it keeps it for its short life. A Moderator sees the lists read-only.
 */
export default async function PseudonymsPage() {
  const me = await apiGet<SessionInfo>('/admin/session');
  const owner = me.staff.role === 'owner';
  const data = await load<PseudonymConfig>('/admin/config/pseudonyms');
  if (isForbidden(data)) return <Forbidden what="Pseudonyms" />;
  return (
    <>
      <PageHead title="Pseudonyms" />
      <p className="muted small">
        {data.available.toLocaleString('en-IN')} names are handed out now. Blocking one takes effect on the next join, everywhere; it never renames
        anyone already in a room. Every change is audited with its reason.{owner ? null : ' Only the Owner can change the blocklist.'}
      </p>
      {owner ? (
        <section className="panel" aria-labelledby="h-block">
          <h2 id="h-block">Block a name</h2>
          <ActionForm action={setPseudonymBlocked.bind(null, true)} submitLabel="Block" danger className="stack small">
            <label htmlFor="block-name">Pseudonym</label>
            <input id="block-name" name="pseudonym" type="text" required autoComplete="off" placeholder="e.g. Quiet Comet" />
            <label htmlFor="block-reason" className="hint">
              Reason code
            </label>
            <input id="block-reason" name="reasonCode" type="text" required pattern="[a-z0-9_]{1,40}" placeholder="e.g. reads_badly_in_te" />
          </ActionForm>
        </section>
      ) : null}
      <section className="panel spaced" aria-labelledby="h-blocked">
        <h2 id="h-blocked">Blocked from the console</h2>
        {data.blocked.length === 0 ? (
          <p className="small muted">None yet.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th scope="col">Pseudonym</th>
                  <th scope="col">Reason</th>
                  <th scope="col">Since</th>
                  {owner ? <th scope="col">Change</th> : null}
                </tr>
              </thead>
              <tbody>
                {data.blocked.map((b) => (
                  <tr key={b.pseudonym}>
                    <td>{b.pseudonym}</td>
                    <td>
                      <code>{b.reasonCode}</code>
                    </td>
                    <td>
                      <When iso={b.createdAt} />
                    </td>
                    {owner ? (
                      <td>
                        <ActionForm action={setPseudonymBlocked.bind(null, false)} submitLabel="Unblock" confirm={`Hand out ${b.pseudonym} again?`} className="stack small">
                          <input type="hidden" name="pseudonym" value={b.pseudonym} />
                          <label htmlFor={`unblock-${b.pseudonym}`} className="hint">
                            Reason code
                          </label>
                          <input id={`unblock-${b.pseudonym}`} name="reasonCode" type="text" required pattern="[a-z0-9_]{1,40}" defaultValue="review_done" />
                        </ActionForm>
                      </td>
                    ) : null}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
      <section className="panel spaced" aria-labelledby="h-lists">
        <h2 id="h-lists">Word lists (read-only, changed by review)</h2>
        <p className="small">
          <strong>Adjectives:</strong> {data.adjectives.join(', ')}
        </p>
        <p className="small">
          <strong>Nouns:</strong> {data.nouns.join(', ')}
        </p>
        <p className="small muted">
          <strong>Never generated (in code):</strong> {data.codeBlocked.join(', ')}
        </p>
      </section>
    </>
  );
}
