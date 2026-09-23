'use server';

import { redirect } from 'next/navigation';
import { field, type ActionResult } from '@/lib/actions';
import { apiGet } from '@/lib/api';
import { sendEmailCode, signOut, verifyEmailCode } from '@/lib/gotrue';
import { clearSession, readSession, writeSession } from '@/lib/session';
import type { SessionInfo } from '@/lib/types';

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** Step 1: a one-time code to an EXISTING account (no sign-up). The answer never says whether the account exists. */
export async function requestCode(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const email = field(fd, 'email').toLowerCase();
  if (!EMAIL_RE.test(email) || email.length > 254) return { ok: false, message: 'Enter a valid email address.' };
  const r = await sendEmailCode(email).catch(() => 'refused' as const);
  if (r === 'rate_limited') return { ok: false, message: 'Too many codes were requested. Wait a minute, then try again.' };
  await writeSession({ v: 1, stage: 'otp', email, started: Date.now() });
  redirect('/login');
}

/** Step 2: the code → a Supabase session; then the console's staff check BEFORE any two-factor step. */
export async function verifyCode(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const s = await readSession();
  if (!s || s.stage !== 'otp' || !s.email) redirect('/login');
  const code = field(fd, 'code').replace(/\s+/g, '');
  if (!/^\d{6}$/.test(code)) return { ok: false, message: 'Enter the 6-digit code from the email.' };
  const t = await verifyEmailCode(s.email, code).catch(() => null);
  if (!t) return { ok: false, message: 'That code is not valid or has expired. Request a new one.' };
  let allowed = false;
  try {
    await apiGet<SessionInfo>('/admin/session', t.access_token);
    allowed = true;
  } catch {
    allowed = false;
  }
  if (!allowed) {
    await signOut(t.access_token);
    await clearSession();
    return { ok: false, message: 'This account cannot use the console. Staff accounts are separate from app accounts.' };
  }
  await writeSession({ v: 1, stage: 'aal1', at: t.access_token, rt: t.refresh_token, exp: t.expires_at, started: Date.now() });
  redirect('/mfa');
}

export async function startOver(): Promise<void> {
  const s = await readSession();
  if (s?.at) await signOut(s.at);
  await clearSession();
  redirect('/login');
}
