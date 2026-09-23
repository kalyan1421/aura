import type { ReactNode } from 'react';
import { LANE_LABEL, ist, shortHash } from '@/lib/format';

/** Small presentational pieces (server components). Colour is never the only signal: badges carry text. */
export function LaneBadge({ lane }: { lane: string | null | undefined }) {
  if (!lane) return null;
  return <span className={`badge lane-${lane}`}>{LANE_LABEL[lane] ?? lane}</span>;
}

export function Badge({ children, tone = 'quiet' }: { children: ReactNode; tone?: 'quiet' | 'alert' | 'legal' }) {
  const cls = tone === 'alert' ? 'badge badge-alert' : tone === 'legal' ? 'badge lane-legal' : 'badge badge-quiet';
  return <span className={cls}>{children}</span>;
}

export function When({ iso }: { iso: string | null | undefined }) {
  if (!iso) return <span className="muted">—</span>;
  return <time dateTime={iso}>{ist(iso)}</time>;
}

export function Hash({ value }: { value: string | null | undefined }) {
  if (!value) return <span className="muted">—</span>;
  return (
    <code title={value} aria-label={`Hashed account id starting ${shortHash(value)}`}>
      {shortHash(value)}
    </code>
  );
}

export function YesNo({ value, yes = 'Yes', no = 'No' }: { value: boolean; yes?: string; no?: string }) {
  return <span className={value ? 'yes' : 'no'}>{value ? yes : no}</span>;
}

export function Forbidden({ what }: { what: string }) {
  return (
    <div className="panel">
      <h1>Not available for your role</h1>
      <p className="muted">{what} is Owner-only in the console (PRD roles). Nothing was shown.</p>
    </div>
  );
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="empty">{children}</p>;
}

export function PageHead({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="page-head">
      <h1>{title}</h1>
      <span className="spacer" />
      {children}
    </div>
  );
}
