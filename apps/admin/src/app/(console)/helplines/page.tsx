import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm } from '@/components/client';
import { Badge, Empty, Forbidden, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { HELPLINES_ACTION_LABEL, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { HelplinesOverview, SessionInfo } from '@/lib/types';
import { publishVersion, storeBaseline, uploadVersion } from './actions';

export const metadata: Metadata = { title: 'Helplines' };

/**
 * The crisis helpline directory, versioned and signed (PRD 18 "Helplines by country"; 06c F9; PRD 19 config "publish
 * signed, roll back"). Owner: store a version, publish it, roll back (publish an older one). Moderator: read.
 * Each app checks the signature, the sequence, the schema and every region's numbers before it switches; a bad or
 * unsigned bundle never replaces the numbers a phone shows.
 */
export default async function HelplinesPage() {
  const data = await load<HelplinesOverview>('/admin/helplines');
  if (isForbidden(data)) return <Forbidden what="The helpline directory" />;
  const me = await apiGet<SessionInfo>('/admin/session');
  const owner = me.staff.role === 'owner';
  const newest = data.versions[0]?.version ?? null;
  const hasBaseline = data.versions.some((v) => v.version === data.bundledVersion);
  return (
    <>
      <PageHead title="Crisis helplines">
        {data.live ? (
          <span>
            Live: <strong>version {data.live.version}</strong> · since <When iso={data.live.publishedAt} />
          </span>
        ) : (
          <span className="muted">Nothing published: apps use their bundled version {data.bundledVersion}.</span>
        )}
      </PageHead>
      <p className="muted small">
        What the support sheet, the Safety Center and the under-13 screen list, by the phone’s region (never IP or GPS). A published version is a new
        signed bundle with a higher sequence number; each app checks it before switching and otherwise keeps the numbers it has. Regions every version must
        keep: <strong>{data.requiredCountries.join(', ')}</strong> (the ones app builds bundle). A region not listed gets “call your local emergency
        number”. A wrong number is a P0 bug: re-verify every number quarterly.
      </p>

      <section className="panel" aria-labelledby="h-signing">
        <h2 id="h-signing">Signing</h2>
        {data.signing.available ? (
          <p className="small">
            Key <code>{data.signing.keyId}</code>
            {data.signing.devKey ? <span className="sla-overdue"> · development key — never publish to production apps with it</span> : null}
          </p>
        ) : (
          <p className="small sla-overdue">Signing is off on this server{data.signing.offReason ? ` (${data.signing.offReason})` : ''}: versions can be stored, not published.</p>
        )}
      </section>

      <section aria-labelledby="h-versions">
        <h2 id="h-versions">Versions</h2>
        {data.versions.length === 0 ? (
          <Empty>No stored versions yet.{owner ? ' Store the bundled directory first, so going back to it is an ordinary rollback.' : ''}</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th scope="col">Version</th>
                  <th scope="col">Lines</th>
                  <th scope="col">Stored</th>
                  <th scope="col">Note</th>
                  {owner ? <th scope="col">Publish</th> : null}
                </tr>
              </thead>
              <tbody>
                {data.versions.map((v) => {
                  const back = data.live !== null && v.version < data.live.version;
                  return (
                    <tr key={v.version}>
                      <td>
                        <Link href={`/helplines/${v.version}`} prefetch={false}>
                          Version {v.version}
                        </Link>{' '}
                        {v.live ? <Badge tone="alert">live</Badge> : null}
                        <div className="small muted">
                          SHA-256 <code title={v.contentSha256}>{v.contentSha256.slice(0, 12)}</code>
                        </div>
                      </td>
                      <td>{v.entries}</td>
                      <td className="small">
                        <When iso={v.createdAt} />
                        <div className="muted">{v.createdBy}</div>
                      </td>
                      <td className="small">{v.note ?? '—'}</td>
                      {owner ? (
                        <td>
                          <ActionForm
                            action={publishVersion.bind(null, v.version)}
                            submitLabel={v.live ? 'Sign again' : back ? 'Roll back to this' : 'Publish'}
                            confirm={
                              v.live
                                ? `Sign version ${v.version} again?`
                                : `${back ? 'Roll back to' : 'Publish'} version ${v.version}? Every app switches its helpline numbers on its next config fetch.`
                            }
                            danger={back}
                            className="stack small"
                          >
                            <label htmlFor={`reason-${v.version}`} className="hint">
                              Reason code
                            </label>
                            <input
                              id={`reason-${v.version}`}
                              name="reasonCode"
                              type="text"
                              required
                              pattern="[a-z0-9_]{1,40}"
                              placeholder={back ? 'e.g. wrong_number' : 'e.g. quarterly_reverify'}
                            />
                            <label className="choice">
                              <input type="checkbox" name="allowRemovals" value="yes" />
                              <span>Allow removing numbers phones show now</span>
                            </label>
                            {v.live ? <input type="hidden" name="resign" value="yes" /> : null}
                          </ActionForm>
                        </td>
                      ) : null}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {owner ? (
        <section className="panel" aria-labelledby="h-new">
          <h2 id="h-new">Store a new version</h2>
          <p className="small muted">
            Start from a stored version (open it and copy its JSON), bump <code>version</code>
            {newest !== null ? ` above ${newest}` : ''}, edit, set <code>verifiedOn</code> to the day you called the numbers, store, check the per-region
            list on the version’s page, then publish. Stored versions never change. The digits of every <code>number</code> must be its{' '}
            <code>dial</code>; te / te-Latn names need a native reviewer (docs/l10n/helplines-and-emails.md).
          </p>
          {!hasBaseline ? (
            <ActionForm action={storeBaseline} submitLabel={`Store the bundled directory (version ${data.bundledVersion})`} className="row" />
          ) : null}
          <ActionForm action={uploadVersion} submitLabel="Store version">
            <div>
              <label htmlFor="helplines">
                Directory JSON <span className="hint">(contracts/safety/helplines.schema.json: name, version, verifiedOn, countries)</span>
              </label>
              <textarea id="helplines" name="helplines" className="json" required spellCheck={false} />
            </div>
            <div>
              <label htmlFor="note">Note</label>
              <input id="note" name="note" type="text" maxLength={500} placeholder="What changed, and who confirmed the numbers" />
            </div>
          </ActionForm>
        </section>
      ) : null}

      <section aria-labelledby="h-history">
        <h2 id="h-history">History</h2>
        {data.history.length === 0 ? (
          <Empty>Nothing yet.</Empty>
        ) : (
          <ul className="small">
            {data.history.map((h) => (
              <li key={h.id}>
                <When iso={h.createdAt} /> · {label(HELPLINES_ACTION_LABEL, h.action)} version {String(h.detail.version ?? '?')}
                {h.detail.previousVersion !== undefined && h.detail.previousVersion !== null ? ` (was ${String(h.detail.previousVersion)})` : ''} · {h.actor}
                {h.reasonCode ? (
                  <>
                    {' '}
                    · <code>{h.reasonCode}</code>
                  </>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
