import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { Forbidden, PageHead, When, YesNo } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { ConsoleConfig } from '@/lib/types';
import { setFlag } from './actions';

export const metadata: Metadata = { title: 'Kill switches' };

/** What each switch does today (the database description, when present, wins). */
const FLAG_HELP: Record<string, string> = {
  rooms_pool_hi: 'Hindi + Hinglish rooms (off until moderation is ready; those users join English rooms meanwhile).',
  rooms_enabled: 'Mood rooms. Off: no new room joins; rooms already joined keep working until they close.',
  reduced_mode:
    'Reduced mode — turn on before you are unreachable (PRD 19). Pauses reflections and throttles sign-ups; check-ins, gestures and crisis support keep working. Today: recorded and sent to the app; reflections arrive with F6 (Milestone B) and the sign-up throttle is not wired yet (see the setup doc).',
  hold_all:
    'Hold-all — every new reflection waits for a human (06c F9, before planned absences); gestures are unaffected. Takes effect with reflections (F6, Milestone B).',
};

/** PRD 19 "Configuration" kill switches that belong to features not built yet. */
const LATER: Array<[string, string]> = [
  ['Reflections per language pool', 'F6 reflections, Milestone B'],
  ['Breath Ripples', 'F7, Milestone B'],
  ['Echoes', 'F7, Milestone B'],
  ['Gifts', 'F12, Milestone B'],
  ['Room lanterns and Tonight’s intention', 'F5 additions, Milestone B'],
  ['Quiet Together and the Lantern Hour wind-down (per region)', 'F16, Milestone C'],
];

/**
 * Kill switches (PRD 19 "Configuration"): the feature flags the app reads, Owner only, each change audited with its
 * reason. Flags reach the app through GET /v1/config (REQ-ADM-12).
 */
export default async function ConfigPage() {
  const data = await load<ConsoleConfig>('/admin/config');
  if (isForbidden(data)) return <Forbidden what="Configuration" />;
  return (
    <>
      <PageHead title="Kill switches" />
      <p className="muted small">Clients pick up flag changes on their next config fetch, without a release. Every change is audited with its reason.</p>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th scope="col">Switch</th>
              <th scope="col">State</th>
              <th scope="col">Change</th>
            </tr>
          </thead>
          <tbody>
            {data.flags.map((f) => (
              <tr key={f.key}>
                <td>
                  <code>{f.key}</code>
                  <div className="small muted">{FLAG_HELP[f.key] ?? f.description ?? ''}</div>
                  {f.updatedAt ? (
                    <div className="small muted">
                      changed <When iso={f.updatedAt} />
                    </div>
                  ) : null}
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
                    <input id={`reason-${f.key}`} name="reasonCode" type="text" required pattern="[a-z0-9_]{1,40}" placeholder="e.g. owner_travelling" />
                  </ActionForm>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <section className="panel spaced" aria-labelledby="h-later">
        <h2 id="h-later">Arrive with their features</h2>
        <ul className="small">
          {LATER.map(([what, when]) => (
            <li key={what}>
              {what} — <span className="muted">{when}</span>
            </li>
          ))}
        </ul>
      </section>
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
