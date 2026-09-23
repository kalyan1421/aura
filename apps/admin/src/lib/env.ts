import { signInModes, type SignInModes } from './sign-in-modes';

/**
 * Server-side configuration, read lazily (the build needs none of it). Nothing here is sent to the browser: the
 * console has no NEXT_PUBLIC_ variables at all.
 */
export interface ConsoleEnv {
  apiUrl: string;
  supabaseUrl: string;
  anonKey: string;
  cookieSecret: string;
  sessionMaxHours: number;
  secureCookies: boolean;
  /** The console's own public URL (the SSO callback is `${consoleUrl}/login/callback`). */
  consoleUrl: string;
  /** REQ-ADM-01: Google Workspace SSO (+ TOTP), and whether the development email-code sign-in is offered. */
  signIn: SignInModes;
}

let cached: ConsoleEnv | null = null;

export class ConsoleConfigError extends Error {}

export function env(): ConsoleEnv {
  if (cached) return cached;
  const secret = process.env.ADMIN_COOKIE_SECRET ?? '';
  const anon = process.env.SUPABASE_ANON_KEY ?? '';
  const problems: string[] = [];
  if (secret.length < 32) problems.push('ADMIN_COOKIE_SECRET (at least 32 characters)');
  if (!anon) problems.push('SUPABASE_ANON_KEY');
  if (problems.length) throw new ConsoleConfigError(`Admin console is not configured: set ${problems.join(', ')} (apps/admin/.env.example).`);
  const hours = Number(process.env.ADMIN_SESSION_MAX_HOURS ?? '12');
  cached = {
    apiUrl: (process.env.AURA_API_URL ?? 'http://127.0.0.1:3310').replace(/\/+$/, ''),
    supabaseUrl: (process.env.SUPABASE_URL ?? 'http://127.0.0.1:55521').replace(/\/+$/, ''),
    anonKey: anon,
    cookieSecret: secret,
    sessionMaxHours: Number.isFinite(hours) && hours >= 1 && hours <= 24 ? hours : 12,
    secureCookies: process.env.NODE_ENV === 'production',
    consoleUrl: (process.env.ADMIN_CONSOLE_URL ?? 'http://localhost:3320').replace(/\/+$/, ''),
    signIn: signInModes(process.env),
  };
  return cached;
}
