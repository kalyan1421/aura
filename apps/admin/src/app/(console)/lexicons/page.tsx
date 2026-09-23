import type { Metadata } from 'next';
import Link from 'next/link';
import { ActionForm } from '@/components/client';
import { Badge, Empty, Forbidden, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { LEXICON_ACTION_LABEL, label } from '@/lib/format';
import { isForbidden, load } from '@/lib/load';
import type { LexiconOverview, SessionInfo } from '@/lib/types';
import { publishVersion, storeBaseline, testSamples, uploadVersion } from './actions';

export const metadata: Metadata = { title: 'Crisis lexicon' };

/**
 * The crisis lexicon, versioned and signed (PRD 19 "Configuration"; REQ-ADM-12 "signed and reversible"; 06c F9).
 * Owner: store a version, test it on samples, publish it, roll back (publish an older one). Moderator: read and test.
 * The app checks the signature, the sequence and every test case before it uses a new version.
 */
export default async function LexiconsPage() {
  const data = await load<LexiconOverview>('/admin/lexicons/crisis');
  if (isForbidden(data)) return <Forbidden what="The crisis lexicon" />;
  const me = await apiGet<SessionInfo>('/admin/session');
  const owner = me.staff.role === 'owner';
  const newest = data.versions[0]?.version ?? null;
  const hasBaseline = data.versions.some((v) => v.version === data.bundledVersion);
  return (
    <>
      <PageHead title="Crisis lexicon">
        {data.live ? (
          <span>
            Live: <strong>version {data.live.version}</strong> · since <When iso={data.live.publishedAt} />
          </span>
        ) : (
          <span className="muted">Nothing published: apps use their bundled version {data.bundledVersion}.</span>
        )}
      </PageHead>
      <p className="muted small">
        The app matches notes, reflections and capsule text on the phone; text is never sent here. A published version is a new signed bundle with a
        higher sequence number; each app checks the signature and every test case before switching. Removing crisis phrases needs the Owner’s explicit
        “allow crisis removals”.
      </p>

      <section className="panel" aria-labelledby="h-signing">
        <h2 id="h-signing">Signing</h2>
        {data.signing.available ? (
          <p className="small">
            Key <code>{data.signing.keyId}</code>
            {data.signing.devKey ? <span className="sla-overdue"> · development key — never publish to production apps with it</span> : null}
          </p>
        ) : (
          <p className="small sla-overdue">Signing is off on this server{data.signing.offReason ? ` (${data.signing.offReason})` : ''}: versions can be stored and tested, not published.</p>
        )}
      </section>

      <section className="panel" aria-labelledby="h-test">
        <h2 id="h-test">Test on samples</h2>
        <ActionForm action={testSamples} submitLabel="Test">
          <div className="grid">
            <div>
              <label htmlFor="version">Version</label>
              <select id="version" name="version" defaultValue="">
                <option value="">{data.live ? `Live (version ${data.live.version})` : `Bundled baseline (version ${data.bundledVersion})`}</option>
                {data.versions.map((v) => (
                  <option key={v.version} value={String(v.version)}>
                    Version {v.version}
                    {v.live ? ' (live)' : ''}
                  </option>
                ))}
              </select>
            </div>
          </div>
          <div>
            <label htmlFor="samples">
              Samples <span className="hint">(one per line, up to 50; not stored or logged)</span>
            </label>
            <textarea id="samples" name="samples" rows={6} required placeholder={'I want to kill myself\nthis exam is killing me'} />
          </div>
        </ActionForm>
      </section>

      <section aria-labelledby="h-versions">
        <h2 id="h-versions">Versions</h2>
        {data.versions.length === 0 ? (
          <Empty>No stored versions yet.{owner ? ' Store the bundled baseline first, so going back to it is an ordinary rollback.' : ''}</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th scope="col">Version</th>
                  <th scope="col">Entries</th>
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
                        <Link href={`/lexicons/${v.version}`} prefetch={false}>
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
                            confirm={v.live ? `Sign version ${v.version} again?` : `${back ? 'Roll back to' : 'Publish'} version ${v.version}? Every app switches on its next config fetch.`}
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
                              placeholder={back ? 'e.g. false_positives' : 'e.g. new_te_phrases'}
                            />
                            <label className="choice">
                              <input type="checkbox" name="allowCrisisRemovals" value="yes" />
                              <span>Allow crisis removals</span>
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
            {newest !== null ? ` above ${newest}` : ''}, edit, add test cases for what you changed, store, test, then publish. Stored versions never
            change.
          </p>
          {!hasBaseline ? (
            <ActionForm action={storeBaseline} submitLabel={`Store the bundled baseline (version ${data.bundledVersion})`} className="row" />
          ) : null}
          <ActionForm action={uploadVersion} submitLabel="Store version">
            <div>
              <label htmlFor="lexicon">
                Lexicon JSON <span className="hint">(contracts/safety schema: name, version, languages, kinds, entries)</span>
              </label>
              <textarea id="lexicon" name="lexicon" className="json" required spellCheck={false} />
            </div>
            <div>
              <label htmlFor="vectors">
                Test cases <span className="hint">(optional JSON array of {'{ "text", "verdict": "crisis" | "soft" | "none", "why"? }'})</span>
              </label>
              <textarea id="vectors" name="vectors" className="json" spellCheck={false} style={{ minHeight: '6rem' }} />
            </div>
            <div>
              <label htmlFor="note">Note</label>
              <input id="note" name="note" type="text" maxLength={500} placeholder="What changed and why" />
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
                <When iso={h.createdAt} /> · {label(LEXICON_ACTION_LABEL, h.action)} version {String(h.detail.version ?? '?')}
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
