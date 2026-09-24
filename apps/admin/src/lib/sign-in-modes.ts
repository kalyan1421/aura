/**
 * How staff sign in to the console (PRD 19 REQ-ADM-01: SSO + TOTP). Pure, unit-tested with node:test.
 *
 * - SSO: `ADMIN_SSO_PROVIDER=google` — Google Workspace through Supabase's Google provider; `ADMIN_SSO_DOMAIN` is sent
 *   to Google as the `hd` hint (the account chooser shows only that Workspace). The API enforces the domain itself
 *   (the ID token's `hd` claim, `ADMIN_SSO_ALLOWED_DOMAINS`) — the hint is only a convenience.
 * - The email-code sign-in is DEVELOPMENT ONLY: offered by default only when NODE_ENV is `development` / `test`, never
 *   in production builds (the API refuses to boot with it in production — SR-1, docs/security/milestone-b-review.md),
 *   and off when NODE_ENV is unset or unknown unless `ADMIN_ALLOW_EMAIL_LOGIN=true` (e.g. a staging stack without SSO,
 *   running with NODE_ENV=development on both sides).
 * TOTP (Supabase MFA, AAL2) follows either first factor.
 */
export interface SignInModes {
  sso: { provider: 'google'; domain: string | null } | null;
  /** The development email-code sign-in is offered. */
  emailCode: boolean;
  production: boolean;
}

const DOMAIN_RE = /^(?=.{3,253}$)[a-z0-9-]+(\.[a-z0-9-]+)+$/;

export function signInModes(e: Record<string, string | undefined>): SignInModes {
  const production = e.NODE_ENV === 'production';
  const provider = (e.ADMIN_SSO_PROVIDER ?? '').trim().toLowerCase();
  const domain = (e.ADMIN_SSO_DOMAIN ?? '').trim().toLowerCase();
  const flag = (e.ADMIN_ALLOW_EMAIL_LOGIN ?? '').trim().toLowerCase();
  const development = e.NODE_ENV === 'development' || e.NODE_ENV === 'test';
  const emailCode = production ? false : flag === '' ? development : ['true', '1', 'yes'].includes(flag);
  return {
    sso: provider === 'google' ? { provider: 'google', domain: DOMAIN_RE.test(domain) ? domain : null } : null,
    emailCode,
    production,
  };
}
