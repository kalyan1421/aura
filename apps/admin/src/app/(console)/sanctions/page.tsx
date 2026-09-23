import type { Metadata } from 'next';
import Link from 'next/link';
import { SanctionsTable } from '@/components/sanctions';
import { PageHead } from '@/components/ui';
import { apiGet } from '@/lib/api';
import type { SanctionView, SessionInfo } from '@/lib/types';

export const metadata: Metadata = { title: 'Sanctions' };

/** Active (or all) sanctions, newest first; lift early on appeal. Bans ("unban") are Owner-only. */
export default async function SanctionsPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const sp = await searchParams;
  const all = sp.all === '1';
  const [data, me] = await Promise.all([
    apiGet<{ sanctions: SanctionView[] }>(`/admin/sanctions${all ? '' : '?active=true'}`),
    apiGet<SessionInfo>('/admin/session'),
  ]);
  return (
    <>
      <PageHead title={all ? 'All sanctions' : 'Active sanctions'}>
        <Link href={all ? '/sanctions' : '/sanctions?all=1'} prefetch={false}>
          {all ? 'Show active only' : 'Show all (incl. lifted and ended)'}
        </Link>
      </PageHead>
      <p className="muted small">Subjects appear as a hashed id; open the report for context. Shadow-mutes are never shown to the person.</p>
      <SanctionsTable sanctions={data.sanctions} role={me.staff.role} showSubject />
    </>
  );
}
