import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { env } from './env';
import { seal, unseal } from './seal';
import { SESSION_COOKIE, type ConsoleSession } from './session-shape';

export { SESSION_COOKIE, type ConsoleSession, type Stage } from './session-shape';

/**
 * The console session lives in ONE sealed, httpOnly, SameSite=Strict cookie holding the staff member's Supabase
 * tokens and sign-in stage. The browser never sees a token. Short: it expires ADMIN_SESSION_MAX_HOURS after sign-in,
 * and NestJS independently refuses sessions older than that, signed-out sessions and anything below AAL2.
 */
export function cookieOptions(maxAgeSeconds: number) {
  return {
    httpOnly: true,
    secure: env().secureCookies,
    sameSite: 'strict' as const,
    path: '/',
    maxAge: Math.max(0, Math.floor(maxAgeSeconds)),
  };
}

export function remainingSeconds(s: ConsoleSession): number {
  return (s.started + env().sessionMaxHours * 3_600_000 - Date.now()) / 1000;
}

export async function openSession(raw: string | undefined): Promise<ConsoleSession | null> {
  const s = await unseal<ConsoleSession>(raw, env().cookieSecret, 'session');
  if (!s || s.v !== 1 || remainingSeconds(s) <= 0) return null;
  return s;
}

export async function readSession(): Promise<ConsoleSession | null> {
  return openSession((await cookies()).get(SESSION_COOKIE)?.value);
}

/** Server actions / route handlers only (server components cannot set cookies). */
export async function writeSession(s: ConsoleSession): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, await seal(s, env().cookieSecret, 'session'), cookieOptions(remainingSeconds(s)));
}

export async function clearSession(): Promise<void> {
  (await cookies()).set(SESSION_COOKIE, '', { ...cookieOptions(0), maxAge: 0 });
}

/** A signed-in (AAL2) staff session or a redirect to sign-in. */
export async function requireSession(): Promise<ConsoleSession & { at: string }> {
  const s = await readSession();
  if (!s || !s.at) redirect('/login');
  if (s.stage !== 'aal2') redirect('/mfa');
  return s as ConsoleSession & { at: string };
}
