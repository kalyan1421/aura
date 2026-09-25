import { NextResponse, type NextRequest } from 'next/server';
import { csp } from './lib/csp';
import { env } from './lib/env';
import { refreshSession } from './lib/gotrue';
import { seal, unseal } from './lib/seal';
import { SESSION_COOKIE, type ConsoleSession } from './lib/session-shape';

/**
 * Runs before every page request:
 * - a fresh nonce and a strict Content-Security-Policy (no third-party scripts, styles, fonts or frames);
 * - the staff session's access token is refreshed shortly before it expires (tokens never reach the browser);
 * - an optimistic redirect to sign-in for console pages without a signed-in session. The real checks happen in NestJS
 *   on every API call (allowlist, AAL2/TOTP, session age, role).
 */
const PUBLIC_PATHS = ['/login', '/mfa'];

export async function proxy(request: NextRequest): Promise<NextResponse> {
  const nonce = btoa(crypto.randomUUID());
  const path = request.nextUrl.pathname;
  const isPublic = PUBLIC_PATHS.some((p) => path === p || path.startsWith(`${p}/`));

  let cfg: ReturnType<typeof env> | null = null;
  try {
    cfg = env();
  } catch {
    cfg = null; // unconfigured: pages render the configuration message
  }
  const policy = csp(nonce, process.env.SUPABASE_URL ?? null);

  let session: ConsoleSession | null = null;
  let resealed: string | null = null;
  let clear = false;
  if (cfg) {
    const raw = request.cookies.get(SESSION_COOKIE)?.value;
    session = await unseal<ConsoleSession>(raw, cfg.cookieSecret, 'session');
    if (session && session.started + cfg.sessionMaxHours * 3_600_000 <= Date.now()) {
      session = null;
      clear = !!raw;
    }
    if (session?.rt && session.exp && session.exp - 90 <= Date.now() / 1000) {
      const fresh = await refreshSession(session.rt).catch(() => null);
      if (fresh) {
        session = { ...session, at: fresh.access_token, rt: fresh.refresh_token, exp: fresh.expires_at };
        resealed = await seal(session, cfg.cookieSecret, 'session');
        request.cookies.set(SESSION_COOKIE, resealed); // so this request's server components see the fresh token
      } else {
        session = null;
        clear = true;
      }
    }
  }

  if (cfg && !isPublic && (!session || session.stage !== 'aal2')) {
    const to = new URL(session && session.stage !== 'otp' ? '/mfa' : '/login', request.url);
    const res = NextResponse.redirect(to);
    res.headers.set('Content-Security-Policy', policy);
    if (clear) res.cookies.set(SESSION_COOKIE, '', { path: '/', maxAge: 0 });
    return res;
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-nonce', nonce);
  requestHeaders.set('Content-Security-Policy', policy);
  const response = NextResponse.next({ request: { headers: requestHeaders } });
  response.headers.set('Content-Security-Policy', policy);
  response.headers.set('Cache-Control', 'no-store');
  if (resealed && session && cfg) {
    const maxAge = Math.floor((session.started + cfg.sessionMaxHours * 3_600_000 - Date.now()) / 1000);
    response.cookies.set(SESSION_COOKIE, resealed, { httpOnly: true, secure: cfg.secureCookies, sameSite: 'strict', path: '/', maxAge });
  } else if (clear) {
    response.cookies.set(SESSION_COOKIE, '', { path: '/', maxAge: 0 });
  }
  return response;
}

export const config = {
  matcher: [
    {
      source: '/((?!_next/static|_next/image|favicon.ico).*)',
      missing: [
        { type: 'header', key: 'next-router-prefetch' },
        { type: 'header', key: 'purpose', value: 'prefetch' },
      ],
    },
  ],
};
