import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { Badge, Empty, Forbidden, PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import { label } from '@/lib/format';
import {
  INTENTION_LOCALES,
  INTENTION_POOLS,
  INTENTION_ACTION_LABEL,
  LOCALE_LABEL,
  POOL_LABEL,
  historySubject,
  nightLabel,
  textField,
  type IntentionTexts,
  type IntentionsOverview,
} from '@/lib/intentions';
import { isForbidden, load } from '@/lib/load';
import type { SessionInfo } from '@/lib/types';
import { addPreset, editWords, movePreset, setEnabled } from './actions';

export const metadata: Metadata = { title: 'Tonight’s intention' };

function Words({ texts }: { texts: IntentionTexts | undefined }) {
  if (!texts) return <span className="muted">no words</span>;
  return (
    <dl className="small intention-words">
      {INTENTION_LOCALES.map((l) => (
        <div key={l} className="row">
          <dt className="muted">{l}</dt>
          <dd lang={l}>{texts[l]}</dd>
        </div>
      ))}
    </dl>
  );
}

function ReasonInput({ id, placeholder }: { id: string; placeholder: string }) {
  return (
    <>
      <label htmlFor={id} className="hint">
        Reason code
      </label>
      <input id={id} name="reasonCode" type="text" required pattern="[a-z0-9_]{1,40}" placeholder={placeholder} />
    </>
  );
}

function WordFields({ idPrefix, texts, maxChars, required }: { idPrefix: string; texts?: IntentionTexts; maxChars: number; required: boolean }) {
  return (
    <>
      {INTENTION_LOCALES.map((l) => (
        <div key={l}>
          <label htmlFor={`${idPrefix}-${l}`}>{LOCALE_LABEL[l]}</label>
          <input
            id={`${idPrefix}-${l}`}
            name={textField(l)}
            type="text"
            lang={l}
            maxLength={maxChars}
            required={required}
            defaultValue={texts?.[l] ?? ''}
            autoComplete="off"
          />
        </div>
      ))}
    </>
  );
}

/**
 * Tonight's intention list per language pool (PRD 19 "Configuration"; PRD 06b "Tonight's intention";
 * contracts/api/v1-rooms.md §1.9–1.10). Owner: add, reword, move, retire, restore — each audited with a reason code,
 * every word checked (no guilt, clinical or scoring words, no treatment claims, one line in the right script).
 * Moderator: read. Nothing is ever deleted: a retired preset leaves the rotation for rooms whose Lantern Hour starts
 * after the change, and a room already showing it tonight keeps it.
 */
export default async function IntentionsPage() {
  const data = await load<IntentionsOverview>('/admin/intentions');
  if (isForbidden(data)) return <Forbidden what="The Tonight’s intention list" />;
  const me = await apiGet<SessionInfo>('/admin/session');
  const owner = me.staff.role === 'owner';
  const words = new Map(data.words.map((w) => [w.key, w]));

  return (
    <>
      <PageHead title="Tonight’s intention" />
      <p className="muted small">
        At the start of Lantern Hour each room pins one preset for the night, rotated from its language pool’s list in the order below (position, then
        key). Holding it is one tap and the room sees only the total. A change applies to rooms whose Lantern Hour starts after it; a room already
        showing a preset keeps it until the room closes. Each key has one line in all five app languages ({data.maxChars} characters at most); phones
        load the words from the server and fall back to the ones they bundle. Non-English lines need a native reviewer. The kill switch{' '}
        <code>room_intention_enabled</code> (Kill switches) turns intentions off everywhere.
      </p>

      {data.pools.map((p) => {
        const inRotation = p.presets.filter((x) => x.enabled).length;
        return (
          <section key={p.pool} className="panel" aria-labelledby={`h-pool-${p.pool}`}>
            <h2 id={`h-pool-${p.pool}`}>
              {POOL_LABEL[p.pool]} <span className="hint">({inRotation} in rotation)</span>
            </h2>
            {p.presets.length === 0 ? (
              <Empty>No presets in this pool: rooms show no intention.</Empty>
            ) : (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th scope="col">Position</th>
                      <th scope="col">Preset</th>
                      <th scope="col">State</th>
                      <th scope="col">Tonight</th>
                      {owner ? <th scope="col">Change</th> : null}
                    </tr>
                  </thead>
                  <tbody>
                    {p.presets.map((x) => (
                      <tr key={x.key}>
                        <td>{x.position}</td>
                        <td>
                          <code>{x.key}</code>
                          <div lang="en">{words.get(x.key)?.texts.en ?? ''}</div>
                          <div className="small muted">
                            changed <When iso={x.updatedAt} />
                          </div>
                        </td>
                        <td>{x.enabled ? <Badge>in rotation</Badge> : <Badge tone="legal">retired</Badge>}</td>
                        <td className="small">{x.inUseTonight > 0 ? `${x.inUseTonight} room${x.inUseTonight === 1 ? '' : 's'}` : '—'}</td>
                        {owner ? (
                          <td>
                            <ActionForm
                              action={setEnabled.bind(null, p.pool, x.key, !x.enabled)}
                              submitLabel={x.enabled ? 'Retire' : 'Restore'}
                              confirm={
                                x.enabled
                                  ? `Retire ${x.key} from the ${p.pool} rotation? Rooms showing it tonight keep it.`
                                  : `Put ${x.key} back in the ${p.pool} rotation?`
                              }
                              danger={x.enabled}
                              className="stack small"
                            >
                              <ReasonInput id={`reason-${p.pool}-${x.key}`} placeholder={x.enabled ? 'e.g. seasonal_rest' : 'e.g. back_in_rotation'} />
                            </ActionForm>
                            <ActionForm action={movePreset.bind(null, p.pool, x.key)} submitLabel="Move" className="stack small">
                              <label htmlFor={`pos-${p.pool}-${x.key}`} className="hint">
                                Position
                              </label>
                              <input
                                id={`pos-${p.pool}-${x.key}`}
                                name="position"
                                type="number"
                                min={0}
                                max={100000}
                                step={1}
                                required
                                defaultValue={x.position}
                              />
                              <ReasonInput id={`reason-move-${p.pool}-${x.key}`} placeholder="e.g. reorder" />
                            </ActionForm>
                          </td>
                        ) : null}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <h3>Next 14 nights</h3>
            <p className="small muted">
              What rooms in this pool will show if the list stays as it is (region-local nights; {data.previewTimezone} calendar).
            </p>
            <ol className="small rotation">
              {p.rotation.map((n) => (
                <li key={n.date}>
                  <strong>{nightLabel(n.date)}</strong> — {n.key ? <code>{n.key}</code> : <span className="muted">no intention</span>}
                  {n.key && words.get(n.key) ? <span lang="en"> · {words.get(n.key)?.texts.en}</span> : null}
                </li>
              ))}
            </ol>
          </section>
        );
      })}

      <section aria-labelledby="h-words">
        <h2 id="h-words">Words</h2>
        <p className="small muted">A key has the same words in every pool that uses it. Rewording applies to rooms showing it tonight too.</p>
        {data.words.map((w) => (
          <details key={w.key} className="panel">
            <summary>
              <code>{w.key}</code> <span lang="en">{w.texts.en}</span>{' '}
              <span className="hint">({w.pools.length ? w.pools.join(', ') : 'in no pool'})</span>
            </summary>
            <Words texts={w.texts} />
            {owner ? (
              <ActionForm action={editWords.bind(null, w.key)} submitLabel="Save words" className="stack small">
                <WordFields idPrefix={`w-${w.key}`} texts={w.texts} maxChars={data.maxChars} required />
                <ReasonInput id={`reason-words-${w.key}`} placeholder="e.g. native_review" />
              </ActionForm>
            ) : null}
          </details>
        ))}
      </section>

      <section aria-labelledby="h-history">
        <h2 id="h-history">Recent changes</h2>
        {data.history.length === 0 ? (
          <Empty>No changes yet.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th scope="col">When</th>
                  <th scope="col">Who</th>
                  <th scope="col">What</th>
                  <th scope="col">Reason</th>
                </tr>
              </thead>
              <tbody>
                {data.history.map((h) => (
                  <tr key={h.id}>
                    <td className="small">
                      <When iso={h.createdAt} />
                    </td>
                    <td className="small">{h.actor}</td>
                    <td className="small">
                      {label(INTENTION_ACTION_LABEL, h.action)} <code>{historySubject(h.detail)}</code>
                    </td>
                    <td className="small">{h.reasonCode ? <code>{h.reasonCode}</code> : '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {owner ? (
        <section className="panel" aria-labelledby="h-add">
          <h2 id="h-add">Add a preset</h2>
          <p className="small muted">
            A new key needs its line in all five languages. To add a key another pool already uses, leave the lines empty (its words are reused).
            Leave “in rotation” unticked to check the words and the preview first, then restore it.
          </p>
          <ActionForm action={addPreset} submitLabel="Add preset">
            <div className="row">
              <div>
                <label htmlFor="add-pool">Pool</label>
                <select id="add-pool" name="pool" required defaultValue="en">
                  {INTENTION_POOLS.map((p) => (
                    <option key={p} value={p}>
                      {POOL_LABEL[p]}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label htmlFor="add-key">
                  Key <span className="hint">(a–z, 0–9, _)</span>
                </label>
                <input id="add-key" name="key" type="text" required pattern="[a-z][a-z0-9_]{1,47}" placeholder="e.g. lights_low" autoComplete="off" />
              </div>
              <div>
                <label htmlFor="add-position">
                  Position <span className="hint">(optional: end of the list)</span>
                </label>
                <input id="add-position" name="position" type="number" min={0} max={100000} step={1} />
              </div>
            </div>
            <WordFields idPrefix="add" maxChars={data.maxChars} required={false} />
            <label className="choice">
              <input type="checkbox" name="enabled" value="yes" />
              <span>In rotation from the next Lantern Hour that starts</span>
            </label>
            <ReasonInput id="reason-add" placeholder="e.g. new_intention" />
          </ActionForm>
        </section>
      ) : null}
    </>
  );
}
