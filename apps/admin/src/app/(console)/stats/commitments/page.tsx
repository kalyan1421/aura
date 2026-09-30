import type { Metadata } from 'next';
import { PageHead, When } from '@/components/ui';
import { apiGet } from '@/lib/api';
import type { CommitmentOutcomes } from '@/lib/types';

export const metadata: Metadata = { title: 'Commitments' };

const LABEL: Record<string, string> = {
  recovery_7d: 'Logged again within 7 days of a rest episode',
  lapse_14d: 'No activity at all for 14 days after a rest episode (guardrail)',
  logs_14d_change: 'Habit logs in the 14 days after vs before committing',
  ended_30d: 'Commitments ended within 30 days',
};

const pct = new Set(['recovery_7d', 'lapse_14d', 'ended_30d']);

function show(measure: string, value: number | null): string {
  if (value === null) return 'hidden (fewer than 20 people)';
  return pct.has(measure) ? `${(value * 100).toFixed(1)}%` : value.toFixed(2);
}

/**
 * Do habit commitments help? Aggregates only, adults only, within-person comparisons; a cell under 20 people is
 * hidden by the database. How to read it, and what would make us pause or keep the feature:
 * docs/measurement/commitments.md.
 */
export default async function CommitmentStatsPage() {
  const s = await apiGet<CommitmentOutcomes>('/admin/stats/commitments');
  return (
    <>
      <PageHead title="Commitments">
        <span className="muted small">
          Updated <When iso={s.generatedAt} />
        </span>
      </PageHead>
      <p className="muted small">
        Committed habits compared with the same person&apos;s other habits over the same days. Adults only; cells under 20
        people are hidden. Numbers are descriptive: read them with the decision rules in the measurement note before acting.
      </p>
      {s.rows.length === 0 ? (
        <p>No commitments have been observed long enough yet.</p>
      ) : (
        <div className="table-wrap">
          <table>
            <caption className="caption">Outcomes</caption>
            <thead>
              <tr>
                <th scope="col">Measure</th>
                <th scope="col">Group</th>
                <th scope="col">People</th>
                <th scope="col">Counted</th>
                <th scope="col">Result</th>
              </tr>
            </thead>
            <tbody>
              {s.rows.map((r) => (
                <tr key={`${r.measure}-${r.cohort}`}>
                  <td>{LABEL[r.measure] ?? r.measure}</td>
                  <td>{r.cohort}</td>
                  <td>{r.users}</td>
                  <td>{r.units}</td>
                  <td>{show(r.measure, r.value)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
