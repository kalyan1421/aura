import { env } from './env';

/**
 * Supabase Auth (GoTrue) calls for the staff member's own session, made by the Next.js server only.
 * First factor: an email one-time code (no sign-up: `create_user: false`). Second factor: TOTP via Supabase MFA
 * (AAL2). Google Workspace SSO is the PRD's target first factor and comes later (docs/setup/admin-console.md).
 */
export interface Tokens {
  access_token: string;
  refresh_token: string;
  /** Epoch seconds. */
  expires_at: number;
}

export interface Factor {
  id: string;
  factor_type: string;
  status: 'verified' | 'unverified';
  friendly_name?: string;
}

async function call(path: string, init: { method?: string; token?: string; body?: unknown } = {}): Promise<{ ok: boolean; status: number; json: Record<string, unknown> }> {
  const e = env();
  const res = await fetch(`${e.supabaseUrl}/auth/v1${path}`, {
    method: init.method ?? 'POST',
    headers: {
      apikey: e.anonKey,
      Authorization: `Bearer ${init.token ?? e.anonKey}`,
      'Content-Type': 'application/json',
    },
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
    cache: 'no-store',
    signal: AbortSignal.timeout(10_000),
  });
  const text = await res.text();
  let json: Record<string, unknown> = {};
  try {
    json = text ? (JSON.parse(text) as Record<string, unknown>) : {};
  } catch {
    json = {};
  }
  return { ok: res.ok, status: res.status, json };
}

function tokens(j: Record<string, unknown>): Tokens | null {
  if (typeof j.access_token !== 'string' || typeof j.refresh_token !== 'string') return null;
  const exp = typeof j.expires_at === 'number' ? j.expires_at : Math.floor(Date.now() / 1000) + (typeof j.expires_in === 'number' ? j.expires_in : 3600);
  return { access_token: j.access_token, refresh_token: j.refresh_token, expires_at: exp };
}

/** Sends the sign-in code to an EXISTING account only. The caller shows the same message whatever happens. */
export async function sendEmailCode(email: string): Promise<'sent' | 'rate_limited' | 'refused'> {
  const r = await call('/otp', { body: { email, create_user: false } });
  if (r.ok) return 'sent';
  return r.status === 429 ? 'rate_limited' : 'refused';
}

export async function verifyEmailCode(email: string, code: string): Promise<Tokens | null> {
  const r = await call('/verify', { body: { type: 'email', email, token: code } });
  return r.ok ? tokens(r.json) : null;
}

export async function refreshSession(refreshToken: string): Promise<Tokens | null> {
  const r = await call('/token?grant_type=refresh_token', { body: { refresh_token: refreshToken } });
  return r.ok ? tokens(r.json) : null;
}

/** Revokes this session in Supabase: the NestJS guard refuses its tokens at once. */
export async function signOut(accessToken: string): Promise<void> {
  await call('/logout?scope=local', { token: accessToken }).catch(() => undefined);
}

export async function listFactors(accessToken: string): Promise<Factor[]> {
  const r = await call('/user', { method: 'GET', token: accessToken });
  const factors = Array.isArray(r.json.factors) ? (r.json.factors as Factor[]) : [];
  return factors.filter((f) => f.factor_type === 'totp');
}

export async function enrollTotp(accessToken: string): Promise<{ factorId: string; qr: string; secret: string } | null> {
  // Stale, never-verified factors from an abandoned enrolment are removed first (GoTrue caps unverified factors).
  for (const f of await listFactors(accessToken)) {
    if (f.status === 'unverified') await call(`/factors/${f.id}`, { method: 'DELETE', token: accessToken }).catch(() => undefined);
  }
  const r = await call('/factors', {
    token: accessToken,
    body: { factor_type: 'totp', issuer: 'Aura admin', friendly_name: `Aura admin ${new Date().toISOString().slice(0, 16)}` },
  });
  const totp = r.json.totp as { qr_code?: string; secret?: string } | undefined;
  if (!r.ok || typeof r.json.id !== 'string' || !totp?.qr_code || !totp.secret) return null;
  // GoTrue returns the QR code as SVG markup (older versions: a data URI). Shown only through <img> as a base64 data
  // URI, so nothing in it can run and nothing is fetched.
  const qr = totp.qr_code.startsWith('data:') ? totp.qr_code : `data:image/svg+xml;base64,${Buffer.from(totp.qr_code, 'utf8').toString('base64')}`;
  return { factorId: r.json.id, qr, secret: totp.secret };
}

/** Challenge + verify a TOTP factor: on success, the same session's AAL2 tokens. */
export async function verifyTotp(accessToken: string, factorId: string, code: string): Promise<Tokens | null> {
  const ch = await call(`/factors/${factorId}/challenge`, { token: accessToken });
  if (!ch.ok || typeof ch.json.id !== 'string') return null;
  const v = await call(`/factors/${factorId}/verify`, { token: accessToken, body: { challenge_id: ch.json.id, code } });
  return v.ok ? tokens(v.json) : null;
}
