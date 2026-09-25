// The console's Content-Security-Policy (src/proxy.ts sets it on every response). Pure, unit-tested.

/**
 * `form-action` also governs where a form's redirect chain may go (Chrome, Safari). "Sign in with Google" posts to
 * /login/sso, which 303s to Supabase Auth's /authorize and on to Google's account chooser, so both origins are allowed
 * as form destinations; everything else stays 'self'.
 */
export function formActionSources(supabaseUrl: string | null): string {
  const sources = ["'self'"];
  if (supabaseUrl) {
    try {
      sources.push(new URL(supabaseUrl).origin);
    } catch {
      // unconfigured / malformed: keep 'self' only
    }
  }
  sources.push('https://accounts.google.com');
  return sources.join(' ');
}

export function csp(nonce: string, supabaseUrl: string | null = null): string {
  const dev = process.env.NODE_ENV === 'development';
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${dev ? " 'unsafe-eval'" : ''}`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "object-src 'none'",
    "base-uri 'none'",
    `form-action ${formActionSources(supabaseUrl)}`,
    "frame-ancestors 'none'",
  ].join('; ');
}
