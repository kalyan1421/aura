import type { Metadata } from 'next';
import { ActionForm } from '@/components/client';
import { Forbidden, PageHead, When, YesNo } from '@/components/ui';
import { apiGet } from '@/lib/api';
import {
  REGION_FLAG_LABEL,
  REGION_LABEL,
  REGION_STATE_LABEL,
  prdCoverage,
  regionState,
  type RegionFlagState,
  type RegionPauses,
} from '@/lib/kill-switches';
import { isForbidden, load } from '@/lib/load';
import type { ConsoleConfig, SessionInfo } from '@/lib/types';
import { setFlag, setRegionPaused } from './actions';

export const metadata: Metadata = { title: 'Kill switches' };

/**
 * Kill switches (PRD 19 "Configuration"): the feature flags the app reads, each change audited with its reason. Flags
 * reach the app through GET /v1/config (REQ-ADM-12). What a flag does is its `feature_flags.description` (kept current
 * by migrations). The Owner changes everything here; a Moderator sees the per-region pauses read-only (PRD 19 Roles:
 * a Moderator cannot change config), so the rest is not even requested for them.
 */
export default async function ConfigPage() {
  const me = await apiGet<SessionInfo>('/admin/session');
  const owner = me.staff.role === 'owner';
  const regions = await load<RegionPauses>('/admin/config/regions');
  if (isForbidden(regions)) return <Forbidden what="Configuration" />;
  const data = owner ? await load<ConsoleConfig>('/admin/config') : null;
  if (isForbidden(data)) return <Forbidden what="Configuration" />;

  return (
    <>
      <PageHead title="Kill switches" />
      <p className="muted small">
        Clients pick up flag changes on their next config fetch, without a release; the server refuses on the route either way. Every change is
        audited with its reason.{owner ? null : ' Only the Owner can change them.'}
      </p>
      {data ? <FlagsTable flags={data.flags} /> : null}
      <RegionsPanel data={regions} owner={owner} />
      {data ? (
        <>
          <Coverage keys={data.flags.map((f) => f.key)} />
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
      ) : null}
    </>
  );
}

function FlagsTable({ flags }: { flags: ConsoleConfig['flags'] }) {
  return (
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
          {flags.map((f) => (
            <tr key={f.key}>
              <td>
                <code>{f.key}</code>
                <div className="small muted">{f.description ?? 'No description yet.'}</div>
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
  );
}

/** Quiet Together and the Lantern Hour wind-down, per timezone region (PRD 19; `payload.pausedRegions`). */
function RegionsPanel({ data, owner }: { data: RegionPauses; owner: boolean }) {
  return (
    <section className="panel spaced" aria-labelledby="h-regions">
      <h2 id="h-regions">Per region</h2>
      <p className="small muted">
        Pausing a region stops new Quiet Together joins (the app shows “Quiet Together is resting for a bit”) or takes the “Wind down together” offer
        out of its rooms; sessions already running finish their block. A switch turned off above pauses every region.
      </p>
      {data.flags.length === 0 ? (
        <p className="small">Neither flag exists yet (migration 20261005000027).</p>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th scope="col">Region</th>
                {data.flags.map((f) => (
                  <th scope="col" key={f.key}>
                    {REGION_FLAG_LABEL[f.key] ?? f.key} <code className="muted small">{f.key}</code>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.regions.map((region) => (
                <tr key={region}>
                  <td>
                    {REGION_LABEL[region] ?? region} <code className="muted">{region}</code>
                  </td>
                  {data.flags.map((f) => (
                    <td key={f.key}>
                      <RegionCell flag={f} region={region} owner={owner} />
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function RegionCell({ flag, region, owner }: { flag: RegionFlagState; region: string; owner: boolean }) {
  const state = regionState(flag, region);
  const paused = flag.pausedRegions.includes(region);
  const label = `${REGION_FLAG_LABEL[flag.key] ?? flag.key} in ${REGION_LABEL[region] ?? region}`;
  return (
    <div className="stack small">
      <span className={state === 'open' ? undefined : 'sla-overdue'}>{REGION_STATE_LABEL[state]}</span>
      {owner ? (
        <ActionForm
          action={setRegionPaused.bind(null, flag.key, region, !paused)}
          submitLabel={paused ? 'Resume' : 'Pause'}
          confirm={`${paused ? 'Resume' : 'Pause'} ${label}?`}
          danger={!paused}
          className="stack small"
        >
          <label htmlFor={`region-${flag.key}-${region}`} className="hint">
            Reason code
          </label>
          <input
            id={`region-${flag.key}-${region}`}
            name="reasonCode"
            type="text"
            required
            pattern="[a-z0-9_]{1,40}"
            defaultValue={paused ? 'region_resolved' : 'region_incident'}
          />
        </ActionForm>
      ) : null}
    </div>
  );
}

/** PRD 19's kill switch list against the flags in the database: every one should say "exists". */
function Coverage({ keys }: { keys: string[] }) {
  return (
    <section className="panel spaced" aria-labelledby="h-coverage">
      <h2 id="h-coverage">PRD 19 kill switches</h2>
      <ul className="small">
        {prdCoverage(keys).map((c) => (
          <li key={c.what}>
            {c.what} — <code>{c.key}</code> <span className={c.exists ? 'muted' : 'sla-overdue'}>{c.exists ? `exists; ${c.where}` : 'missing'}</span>
          </li>
        ))}
      </ul>
    </section>
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
