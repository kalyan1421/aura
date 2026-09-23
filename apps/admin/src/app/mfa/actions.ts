'use server';

import { redirect } from 'next/navigation';
import { field, type ActionResult } from '@/lib/actions';
import { apiPost } from '@/lib/api';
import { enrollTotp, listFactors, verifyTotp } from '@/lib/gotrue';
import { readSession, writeSession } from '@/lib/session';

export type EnrollState = { ok: boolean; message: string; qr?: string; secret?: string } | null;

/** First sign-in of a staff account: create a TOTP factor and show its QR code (Supabase MFA). */
export async function startEnroll(_prev: EnrollState, _fd: FormData): Promise<EnrollState> {
  const s = await readSession();
  if (!s?.at || s.stage !== 'aal1') redirect('/login');
  const f = await enrollTotp(s.at).catch(() => null);
  if (!f) return { ok: false, message: 'Could not start the set-up. Try again, or sign in again.' };
  await writeSession({ ...s, factorId: f.factorId });
  return { ok: true, message: 'Scan the code with your authenticator app, then enter the 6-digit code it shows.', qr: f.qr, secret: f.secret };
}

/** Verifies a TOTP code (enrolment or a regular challenge) → AAL2 → the console. */
export async function confirmTotp(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const s = await readSession();
  if (!s?.at || s.stage !== 'aal1') redirect('/login');
  const code = field(fd, 'code').replace(/\s+/g, '');
  if (!/^\d{6}$/.test(code)) return { ok: false, message: 'Enter the 6-digit code from your authenticator app.' };
  let factorId = s.factorId;
  if (!factorId) factorId = (await listFactors(s.at).catch(() => [])).find((f) => f.status === 'verified')?.id;
  if (!factorId) return { ok: false, message: 'Set up your authenticator first.' };
  const t = await verifyTotp(s.at, factorId, code).catch(() => null);
  if (!t) return { ok: false, message: 'That code did not match. Check the time on your phone and try again.' };
  await writeSession({ v: 1, stage: 'aal2', at: t.access_token, rt: t.refresh_token, exp: t.expires_at, started: s.started });
  await apiPost('/admin/session/started', undefined, t.access_token).catch(() => undefined);
  redirect('/now');
}
