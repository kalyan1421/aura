import { NextResponse, type NextRequest } from 'next/server';
import { ConsoleConfigError, env } from '@/lib/env';
import { authorizeUrl, challengeFor, newVerifier } from '@/lib/pkce';
import { seal } from '@/lib/seal';
import { PKCE_COOKIE, type PkceState } from '@/lib/session-shape';

/**
 * Step 1 of the SSO sign-in (REQ-ADM-01): a PKCE verifier in a sealed, httpOnly, 10-minute cookie (SameSite=Lax, so it
 * survives the redirect back from Google and Supabase), then off to Supabase's Google provider with the Workspace `hd`
 * hint. Nothing about the person is known or stored yet.
 */
export async function GET(request: NextRequest): Promise<NextResponse> {
  let cfg: ReturnType<typeof env>;
  try {
    cfg = env();
  } catch (e) {
    if (e instanceof ConsoleConfigError) return NextResponse.redirect(new URL('/login', request.url), 303);
    throw e;
  }
  if (!cfg.signIn.sso) return NextResponse.redirect(new URL('/login?reason=sso_not_configured', request.url), 303);
  const verifier = newVerifier();
  const state: PkceState = { v: 1, verifier, started: Date.now() };
  const res = NextResponse.redirect(
    authorizeUrl({
      supabaseUrl: cfg.supabaseUrl,
      redirectTo: `${cfg.consoleUrl}/login/callback`,
      challenge: await challengeFor(verifier),
      domain: cfg.signIn.sso.domain,
    }),
    303,
  );
  res.cookies.set(PKCE_COOKIE, await seal(state, cfg.cookieSecret, 'pkce'), {
    httpOnly: true,
    secure: cfg.secureCookies,
    sameSite: 'lax',
    path: '/login',
    maxAge: 600,
  });
  res.headers.set('Cache-Control', 'no-store');
  return res;
}
