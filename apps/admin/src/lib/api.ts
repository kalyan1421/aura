import { redirect } from 'next/navigation';
import { env } from './env';
import { requireSession } from './session';

/**
 * The console's only data source: the NestJS `/admin/*` routes, called from the Next.js server with the staff
 * member's own Supabase access token (re-verified there on every request: allowlist, AAL2/TOTP, session, role).
 */
export class ApiFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    /** Machine-readable refusal details when the API sends them (e.g. lexicon problems or failed vectors). */
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'ApiFailure';
  }
}

const SIGN_IN_AGAIN = new Set(['unauthorized', 'session_expired', 'mfa_required', 'not_staff', 'staff_account_is_app_account', 'sso_required']);

async function request<T>(method: 'GET' | 'POST', path: string, body?: unknown, token?: string): Promise<T> {
  const at = token ?? (await requireSession()).at;
  const res = await fetch(`${env().apiUrl}${path}`, {
    method,
    headers: { Authorization: `Bearer ${at}`, ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
    body: body === undefined ? undefined : JSON.stringify(body),
    cache: 'no-store',
    signal: AbortSignal.timeout(15_000),
  });
  if (res.status === 204) return undefined as T;
  const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  if (!res.ok) {
    const code = typeof json.code === 'string' ? json.code : 'error';
    if (!token && (res.status === 401 || (res.status === 403 && SIGN_IN_AGAIN.has(code)))) redirect(`/login?reason=${encodeURIComponent(code)}`);
    throw new ApiFailure(res.status, code, typeof json.message === 'string' ? json.message : 'Request failed.', json.details);
  }
  return json as T;
}

export const apiGet = <T>(path: string, token?: string): Promise<T> => request<T>('GET', path, undefined, token);
export const apiPost = <T>(path: string, body?: unknown, token?: string): Promise<T> => request<T>('POST', path, body ?? {}, token);

/** For forms: the API's message on a known failure, a generic one otherwise. */
export function failureMessage(e: unknown): string {
  if (e instanceof ApiFailure) {
    if (e.code === 'forbidden_role') return 'Your console role cannot do this (the attempt was logged).';
    return e.message;
  }
  return 'Something went wrong. Try again.';
}
