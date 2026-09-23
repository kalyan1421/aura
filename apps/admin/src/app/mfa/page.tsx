import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { ActionForm } from '@/components/client';
import { apiGet } from '@/lib/api';
import { readSession } from '@/lib/session';
import type { SessionInfo } from '@/lib/types';
import { startOver } from '../login/actions';
import { confirmTotp, startEnroll } from './actions';
import { Enroll } from './enroll';

export const metadata: Metadata = { title: 'Two-factor verification' };

export default async function MfaPage() {
  const s = await readSession();
  if (!s?.at) redirect('/login');
  if (s.stage === 'aal2') redirect('/now');
  let info: SessionInfo | null = null;
  try {
    info = await apiGet<SessionInfo>('/admin/session', s.at);
  } catch {
    info = null;
  }
  if (!info) redirect('/login?reason=session_expired');

  return (
    <main id="main" className="auth">
      <div className="panel stack">
        <h1>Two-factor verification</h1>
        <p className="muted">
          Signed in as {info.staff.displayName} ({info.staff.role}){info.firstFactor === 'sso' ? ' with Google Workspace' : ' with the development sign-in'}. The
          console needs a code from your authenticator app every sign-in.
        </p>
        {info.mfa === 'enroll' ? (
          <Enroll start={startEnroll} confirm={confirmTotp} />
        ) : (
          <ActionForm action={confirmTotp} submitLabel="Verify">
            <div>
              <label htmlFor="code">Code from your authenticator app</label>
              <input id="code" name="code" className="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,7}" required autoFocus />
            </div>
          </ActionForm>
        )}
        <form action={startOver}>
          <button type="submit" className="btn btn-quiet">
            Cancel and sign out
          </button>
        </form>
      </div>
    </main>
  );
}
