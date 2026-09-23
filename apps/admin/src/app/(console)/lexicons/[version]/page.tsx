import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Forbidden, PageHead, When } from '@/components/ui';
import { isForbidden, load } from '@/lib/load';
import type { LexiconVersion } from '@/lib/types';

export const metadata: Metadata = { title: 'Lexicon version' };

/** One stored lexicon version, read-only (versions never change): the starting point for the next one. */
export default async function LexiconVersionPage({ params }: { params: Promise<{ version: string }> }) {
  const { version } = await params;
  if (!/^\d{1,9}$/.test(version)) notFound();
  const v = await load<LexiconVersion>(`/admin/lexicons/crisis/versions/${version}`);
  if (isForbidden(v)) return <Forbidden what="The crisis lexicon" />;
  return (
    <>
      <PageHead title={`Crisis lexicon · version ${v.version}`}>
        <Link href="/lexicons" prefetch={false}>
          All versions
        </Link>
      </PageHead>
      <p className="small">
        Stored <When iso={v.createdAt} /> by {v.createdBy} · SHA-256 <code>{v.contentSha256}</code>
        {v.note ? <> · {v.note}</> : null}
      </p>
      <section className="panel" aria-labelledby="h-lexicon">
        <h2 id="h-lexicon">Lexicon</h2>
        <p className="small muted">Copy this into “Store a new version”, bump the version number and edit.</p>
        <pre className="json">{JSON.stringify(v.lexicon, null, 2)}</pre>
      </section>
      <section className="panel" aria-labelledby="h-vectors">
        <h2 id="h-vectors">This version’s own test cases ({v.vectors.length})</h2>
        <p className="small muted">The contract’s test cases (contracts/safety) always run as well, on the server and in every app.</p>
        <pre className="json">{JSON.stringify(v.vectors, null, 2)}</pre>
      </section>
    </>
  );
}
