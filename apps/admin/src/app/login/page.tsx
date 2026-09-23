import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { ActionForm } from '@/components/client';
import { ConsoleConfigError, env } from '@/lib/env';
import { readSession } from '@/lib/session';
import { requestCode, startOver, verifyCode } from './actions';

export const metadata: Metadata = { title: 'Sign in' };

const REASONS: Record<string, string> = {
  session_expired: 'Your console session ended. Sign in again.',
  mfa_required: 'Two-factor verification is needed again.',
  not_staff: 'That account cannot use the console.',
  staff_account_is_app_account: 'Staff accounts must be separate from Aura app accounts.',
  unauthorized: 'Please sign in.',
};

export default async function LoginPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  try {
    env();
  } catch (e) {
    if (e instanceof ConsoleConfigError) {
      return (
        <main id="main" className="auth">
          <div className="panel">
            <h1>Console not configured</h1>
            <p>{e.message}</p>
          </div>
        </main>
      );
    }
    throw e;
  }
  const s = await readSession();
  if (s?.stage === 'aal2') redirect('/now');
  if (s?.stage === 'aal1') redirect('/mfa');
  const reason = (await searchParams).reason;
  const notice = typeof reason === 'string' ? REASONS[reason] : undefined;

  return (
    <main id="main" className="auth">
      <div className="panel stack">
        <h1>Aura console</h1>
        <p className="muted">Staff only. Sign-in takes an email code and your authenticator app.</p>
        {notice ? (
          <p className="callout" role="status">
            {notice}
          </p>
        ) : null}
        {s?.stage === 'otp' ? (
          <>
            <p>
              If <strong>{s.email}</strong> is a staff account, a 6-digit code is on its way. It expires in an hour.
            </p>
            <ActionForm action={verifyCode} submitLabel="Continue">
              <div>
                <label htmlFor="code">Code from the email</label>
                <input id="code" name="code" className="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9 ]{6,7}" required autoFocus />
              </div>
            </ActionForm>
            <form action={startOver}>
              <button type="submit" className="btn btn-quiet">
                Use a different email
              </button>
            </form>
          </>
        ) : (
          <ActionForm action={requestCode} submitLabel="Email me a code">
            <div>
              <label htmlFor="email">Staff email</label>
              <input id="email" name="email" type="email" autoComplete="username" required autoFocus />
            </div>
          </ActionForm>
        )}
      </div>
    </main>
  );
}
