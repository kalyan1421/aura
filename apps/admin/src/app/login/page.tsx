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
  not_staff: 'That account is not on the console’s staff list. Ask the Owner to add it (Staff).',
  staff_account_is_app_account: 'Staff accounts must be separate from Aura app accounts.',
  sso_required: 'Staff sign in with Google Workspace. The email-code sign-in is for development only.',
  sso_failed: 'Google sign-in did not complete. Try again.',
  sso_expired: 'The sign-in took too long. Start again.',
  sso_not_configured: 'Google Workspace sign-in is not configured for this console.',
  email_login_disabled: 'The email-code sign-in is switched off here. Use Google Workspace.',
  unauthorized: 'Please sign in.',
};

/**
 * REQ-ADM-01: staff sign in with Google Workspace SSO, then TOTP. The email-code sign-in is shown only where it is
 * allowed (development; off by default in production builds) and is labelled as such. NestJS enforces both rules again.
 */
export default async function LoginPage({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  let cfg: ReturnType<typeof env>;
  try {
    cfg = env();
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
  const { sso, emailCode } = cfg.signIn;

  return (
    <main id="main" className="auth">
      <div className="panel stack">
        <h1>Aura console</h1>
        <p className="muted">Staff only. Sign in with your organisation account, then your authenticator app.</p>
        {notice ? (
          <p className="callout" role="status">
            {notice}
          </p>
        ) : null}
        {sso && s?.stage !== 'otp' ? (
          <form action="/login/sso" method="get">
            <button type="submit" className="btn">
              Sign in with Google Workspace{sso.domain ? ` (${sso.domain})` : ''}
            </button>
          </form>
        ) : null}
        {!sso && !emailCode ? (
          <p className="callout danger" role="alert">
            Sign-in is not configured: set ADMIN_SSO_PROVIDER=google (and the API’s ADMIN_SSO_ALLOWED_DOMAINS). See docs/setup/admin-console.md.
          </p>
        ) : null}
        {emailCode ? (
          <section className="panel stack" aria-labelledby="h-dev">
            <h2 id="h-dev">Development sign-in (email code)</h2>
            <p className="small muted">
              Development only — not available in production. The API refuses it unless its ADMIN_ALLOW_EMAIL_LOGIN allows it too.
            </p>
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
                  <input id="email" name="email" type="email" autoComplete="username" required />
                </div>
              </ActionForm>
            )}
          </section>
        ) : null}
      </div>
    </main>
  );
}
