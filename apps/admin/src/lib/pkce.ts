/**
 * PKCE (RFC 7636) for the console's SSO sign-in through Supabase Auth (GoTrue's PKCE flow): a random verifier kept
 * server-side in a sealed, short-lived cookie, and its S256 challenge in the authorize URL. Web Crypto only (works in
 * route handlers and the proxy); pure and unit-tested with node:test.
 */
function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** 64 random bytes → an 86-character verifier (RFC 7636: 43–128 characters of [A-Za-z0-9-._~]). */
export function newVerifier(): string {
  return b64url(crypto.getRandomValues(new Uint8Array(64)));
}

export async function challengeFor(verifier: string): Promise<string> {
  return b64url(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))));
}

/** The authorize URL for Supabase's Google provider with PKCE; `hd` (the Workspace domain) is forwarded to Google. */
export function authorizeUrl(o: { supabaseUrl: string; redirectTo: string; challenge: string; domain: string | null }): string {
  const q = new URLSearchParams({
    provider: 'google',
    redirect_to: o.redirectTo,
    code_challenge: o.challenge,
    code_challenge_method: 's256',
    // Always show the account chooser (a shared machine must not silently reuse someone else's Google session).
    prompt: 'select_account',
  });
  if (o.domain) q.set('hd', o.domain);
  return `${o.supabaseUrl}/auth/v1/authorize?${q.toString()}`;
}
