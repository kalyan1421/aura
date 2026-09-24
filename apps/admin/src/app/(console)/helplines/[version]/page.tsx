import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Forbidden, PageHead, When } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { HelplinesVersion } from '@/lib/types';

export const metadata: Metadata = { title: 'Helplines version' };

/**
 * One stored helpline directory version, read-only (versions never change): what the app lists per region for an
 * adult and for someone under 18 — the same list each app re-derives before it uses the version — then the JSON to
 * start the next version from.
 */
export default async function HelplinesVersionPage({ params }: { params: Promise<{ version: string }> }) {
  const { version } = await params;
  if (!/^\d{1,9}$/.test(version)) notFound();
  const v = await load<HelplinesVersion>(`/admin/helplines/versions/${version}`);
  if (isForbidden(v)) return <Forbidden what="The helpline directory" />;
  const countries = Object.entries(v.helplines.countries).sort(([a], [b]) => a.localeCompare(b));
  return (
    <>
      <PageHead title={`Crisis helplines · version ${v.version}`}>
        <Link href="/helplines" prefetch={false}>
          All versions
        </Link>
      </PageHead>
      <p className="small">
        Stored <When iso={v.createdAt} /> by {v.createdBy} · SHA-256 <code>{v.contentSha256}</code>
        {v.helplines.verifiedOn ? <> · numbers verified {v.helplines.verifiedOn}</> : null}
        {v.note ? <> · {v.note}</> : null}
      </p>
      <section aria-labelledby="h-regions">
        <h2 id="h-regions">What phones list</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th scope="col">Region</th>
                <th scope="col">Line</th>
                <th scope="col">Shown · dialled</th>
                <th scope="col">For</th>
                <th scope="col">Names</th>
              </tr>
            </thead>
            <tbody>
              {countries.flatMap(([country, lines]) =>
                lines.map((l, i) => (
                  <tr key={l.id}>
                    <td>{i === 0 ? <strong>{country}</strong> : null}</td>
                    <td>
                      <code>{l.id}</code>
                    </td>
                    <td>
                      {l.number} · <code>tel:{l.dial}</code>
                    </td>
                    <td>{l.audience === 'minors' ? 'under 18 only' : 'everyone'}</td>
                    <td className="small">
                      {Object.entries(l.names).map(([locale, name]) => (
                        <div key={locale}>
                          <span className="muted">{locale}</span> {name}
                        </div>
                      ))}
                    </td>
                  </tr>
                )),
              )}
              <tr>
                <td>any other region</td>
                <td colSpan={4} className="muted">
                  “If you’re in danger right now, please call your local emergency number.” — never an empty list
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
      <section className="panel" aria-labelledby="h-json">
        <h2 id="h-json">Directory JSON</h2>
        <p className="small muted">Copy this into “Store a new version”, bump the version number and edit.</p>
        <pre className="json">{JSON.stringify(v.helplines, null, 2)}</pre>
      </section>
    </>
  );
}
