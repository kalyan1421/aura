/** The sealed session cookie's name and shape (no Next.js imports: shared by the proxy and server code). */
export const SESSION_COOKIE = 'aura_admin';

/** The SSO sign-in's PKCE verifier (sealed, 10 minutes, path /login, SameSite=Lax for the redirect back). */
export const PKCE_COOKIE = 'aura_admin_pkce';

export interface PkceState {
  v: 1;
  verifier: string;
  /** Epoch ms. */
  started: number;
}

export type Stage = 'otp' | 'aal1' | 'aal2';

export interface ConsoleSession {
  v: 1;
  stage: Stage;
  /** Only while waiting for the email code. */
  email?: string;
  at?: string;
  rt?: string;
  /** Access-token expiry, epoch seconds. */
  exp?: number;
  /** A TOTP factor being enrolled. */
  factorId?: string;
  /** Sign-in start, epoch ms (the cookie's hard limit). */
  started: number;
}
