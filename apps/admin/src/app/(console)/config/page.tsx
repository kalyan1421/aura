import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { Forbidden, PageHead, YesNo } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { ConsoleConfig } from '@/lib/types';
import { setFlag } from './actions';

export const metadata: Metadata = { title: 'Kill switches' };

const FLAG_HELP: Record<string, string> = {
  rooms_pool_hi: 'Hindi + Hinglish rooms (off until moderation is ready; those users join English rooms meanwhile).',
};

/**
 * Kill switches that exist in v0 (PRD 19 "Configuration"): the feature flags the app already reads. Reduced mode,
 * hold-all, per-pool reflections, sign-ups and the Milestone B/C switches arrive with the features they switch off.
 */
export default async function ConfigPage() {
  const data = await load<ConsoleConfig>('/admin/config');
  if (isForbidden(data)) return <Forbidden what="Configuration" />;
  return (
    <>
      <PageHead title="Kill switches" />
      <p className="muted small">Clients pick up flag changes on their next flag fetch, without a release. Every change is audited with its reason.</p>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th scope="col">Flag</th>
              <th scope="col">State</th>
              <th scope="col">Change</th>
            </tr>
          </thead>
          <tbody>
            {data.flags.map((f) => (
              <tr key={f.key}>
                <td>
                  <code>{f.key}</code>
                  <div className="small muted">{FLAG_HELP[f.key] ?? ''}</div>
                </td>
                <td>
                  <YesNo value={f.enabled} yes="on" no="off" />
                </td>
                <td>
                  <ActionForm
                    action={setFlag.bind(null, f.key, !f.enabled)}
                    submitLabel={f.enabled ? 'Turn off' : 'Turn on'}
                    confirm={`Turn ${f.key} ${f.enabled ? 'off' : 'on'}?`}
                    className="stack small"
                  >
                    <label htmlFor={`reason-${f.key}`} className="hint">
                      Reason code
                    </label>
                    <input id={`reason-${f.key}`} name="reasonCode" type="text" required pattern="[a-z0-9_]{1,40}" placeholder="e.g. moderation_ready" />
                  </ActionForm>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="grid">
        <section className="panel">
          <h2>Room matching (read-only)</h2>
          <ConfigTable values={data.matching} />
        </section>
        <section className="panel">
          <h2>Safety (read-only)</h2>
          <ConfigTable values={data.safety} />
        </section>
      </div>
    </>
  );
}

function ConfigTable({ values }: { values: Record<string, unknown> }) {
  return (
    <dl className="facts small">
      {Object.entries(values).map(([k, v]) => (
        <div key={k} className="contents">
          <dt>
            <code>{k}</code>
          </dt>
          <dd>{v === null ? '—' : String(v)}</dd>
        </div>
      ))}
    </dl>
  );
}
