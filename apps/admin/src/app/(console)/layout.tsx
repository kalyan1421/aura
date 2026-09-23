import { redirect } from 'next/navigation';
import type { ReactNode } from 'react';
import { NavLinks } from '@/components/client';
import { apiGet } from '@/lib/api';
import { ROLE_LABEL, ist, queueSessionText } from '@/lib/format';
import { requireSession } from '@/lib/session';
import type { SessionInfo, StaffRole } from '@/lib/types';
import { signOutAction } from './session-actions';

/** PRD 19 roles: the Owner sees everything; a Moderator works the queue; an analyst sees aggregates only. */
function navFor(role: StaffRole): Array<{ href: string; label: string }> {
  if (role === 'analyst') return [{ href: '/stats', label: 'Stats' }];
  const common = [
    { href: '/now', label: 'Now' },
    { href: '/queue', label: 'Queue' },
    { href: '/sanctions', label: 'Sanctions' },
  ];
  if (role === 'moderator') return [...common, { href: '/lexicons', label: 'Lexicon' }, { href: '/stats', label: 'Stats' }];
  return [
    ...common,
    { href: '/mandatory', label: 'Mandatory reports' },
    { href: '/grievances', label: 'Grievances' },
    { href: '/deletion-cases', label: 'Deletion cases' },
    { href: '/legal-orders', label: 'Legal orders' },
    { href: '/paging', label: 'Paging' },
    { href: '/audit', label: 'Audit log' },
    { href: '/config', label: 'Kill switches' },
    { href: '/lexicons', label: 'Lexicon' },
    { href: '/devices', label: 'Device bans' },
    { href: '/staff', label: 'Staff' },
    { href: '/stats', label: 'Stats' },
  ];
}

export default async function ConsoleLayout({ children }: { children: ReactNode }) {
  await requireSession();
  const me = await apiGet<SessionInfo>('/admin/session');
  if (me.mfa !== 'verified') redirect('/mfa');
  const queue = queueSessionText(me.queueSession);
  return (
    <>
      <header className="top">
        <div className="brand">
          Aura console<small>internal</small>
        </div>
        <NavLinks items={navFor(me.staff.role)} />
        <div className="me">
          <span>
            {me.staff.displayName} · {ROLE_LABEL[me.staff.role]} · {me.firstFactor === 'sso' ? 'Google Workspace + TOTP' : 'development sign-in + TOTP'} ·
            session ends {ist(me.sessionExpiresAt)}
            {queue ? <span className={me.queueSession?.capped ? 'sla-overdue' : 'muted'}> · {queue}</span> : null}
          </span>
          <form action={signOutAction}>
            <button type="submit" className="btn btn-quiet">
              Sign out
            </button>
          </form>
        </div>
      </header>
      <main id="main" tabIndex={-1}>
        {children}
      </main>
    </>
  );
}
