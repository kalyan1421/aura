'use server';

import { redirect } from 'next/navigation';
import { apiPost } from '@/lib/api';
import { signOut } from '@/lib/gotrue';
import { clearSession, readSession } from '@/lib/session';

/** Audited sign-out: the Supabase session is revoked, so the NestJS guard refuses its tokens at once. */
export async function signOutAction(): Promise<void> {
  const s = await readSession();
  if (s?.at) {
    await apiPost('/admin/session/ended', undefined, s.at).catch(() => undefined);
    await signOut(s.at);
  }
  await clearSession();
  redirect('/login');
}
