import { cookies } from 'next/headers';
import { NextResponse, type NextRequest } from 'next/server';
import { ApiFailure, apiGet } from '@/lib/api';
import { ConsoleConfigError, env } from '@/lib/env';
import { exchangePkce, signOut } from '@/lib/gotrue';
import { seal, unseal } from '@/lib/seal';
import { PKCE_COOKIE, SESSION_COOKIE, type ConsoleSession, type PkceState } from '@/lib/session-shape';
import type { SessionInfo } from '@/lib/types';

/**
 * Step 2 of the SSO sign-in (REQ-ADM-01): Supabase sends the browser back with a one-time `code`. It is exchanged with
 * the PKCE verifier this browser started with, then — BEFORE any second factor — NestJS decides whether the account may
 * use the console at all (staff allowlist, Workspace domain, never an app account). Refused → the new Supabase session is
 * revoked at once. Allowed → the sealed console session (stage aal1) and on to TOTP.
 *
 * The last hop is a tiny page that moves on to /mfa itself: a redirect straight out of a cross-site redirect chain would
 * not carry the SameSite=Strict session cookie on its first request.
 */
const REFUSALS = new Set(['not_staff', 'staff_account_is_app_account', 'sso_required']);

function back(request: NextRequest, reason: string): NextResponse {
  const res = NextResponse.redirect(new URL(`/login?reason=${encodeURIComponent(reason)}`, request.url), 303);
  res.cookies.set(PKCE_COOKIE, '', { path: '/login', maxAge: 0 });
  res.headers.set('Cache-Control', 'no-store');
  return res;
}

export async function GET(request: NextRequest): Promise<NextResponse> {
  let cfg: ReturnType<typeof env>;
  try {
    cfg = env();
  } catch (e) {
    if (e instanceof ConsoleConfigError) return NextResponse.redirect(new URL('/login', request.url), 303);
    throw e;
  }
  const url = request.nextUrl;
  const code = url.searchParams.get('code');
  if (!cfg.signIn.sso) return back(request, 'sso_not_configured');
  if (!code || url.searchParams.get('error')) return back(request, 'sso_failed');

  const jar = await cookies();
  const pkce = await unseal<PkceState>(jar.get(PKCE_COOKIE)?.value, cfg.cookieSecret, 'pkce');
  if (!pkce || pkce.v !== 1 || Date.now() - pkce.started > 10 * 60_000) return back(request, 'sso_expired');

  const t = await exchangePkce(code, pkce.verifier).catch(() => null);
  if (!t) return back(request, 'sso_failed');

  try {
    await apiGet<SessionInfo>('/admin/session', t.access_token);
  } catch (e) {
    await signOut(t.access_token);
    return back(request, e instanceof ApiFailure && REFUSALS.has(e.code) ? e.code : 'not_staff');
  }

  const session: ConsoleSession = { v: 1, stage: 'aal1', at: t.access_token, rt: t.refresh_token, exp: t.expires_at, started: Date.now() };
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=/mfa"><title>Signing in</title></head>
<body><main id="main" class="auth"><p>Signed in with Google Workspace. <a href="/mfa">Continue to two-factor verification</a>.</p></main></body></html>`;
  const res = new NextResponse(html, { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' } });
  res.cookies.set(SESSION_COOKIE, await seal(session, cfg.cookieSecret, 'session'), {
    httpOnly: true,
    secure: cfg.secureCookies,
    sameSite: 'strict',
    path: '/',
    maxAge: cfg.sessionMaxHours * 3600,
  });
  res.cookies.set(PKCE_COOKIE, '', { path: '/login', maxAge: 0 });
  return res;
}
