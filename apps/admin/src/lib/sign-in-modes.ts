/**
 * How staff sign in to the console (PRD 19 REQ-ADM-01: SSO + TOTP). Pure, unit-tested with node:test.
 *
 * - SSO: `ADMIN_SSO_PROVIDER=google` — Google Workspace through Supabase's Google provider; `ADMIN_SSO_DOMAIN` is sent
 *   to Google as the `hd` hint (the account chooser shows only that Workspace). The API enforces the domain itself
 *   (the ID token's `hd` claim, `ADMIN_SSO_ALLOWED_DOMAINS`) — the hint is only a convenience.
 * - The email-code sign-in is DEVELOPMENT ONLY: offered by default outside production and refused by default in
 *   production builds (`ADMIN_ALLOW_EMAIL_LOGIN=true` to override, e.g. a staging stack without SSO; the API refuses it
 *   unless its own `ADMIN_ALLOW_EMAIL_LOGIN` agrees).
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
  const emailCode = flag === '' ? !production : ['true', '1', 'yes'].includes(flag);
  return {
    sso: provider === 'google' ? { provider: 'google', domain: DOMAIN_RE.test(domain) ? domain : null } : null,
    emailCode,
    production,
  };
}
