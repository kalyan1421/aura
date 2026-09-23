'use server';

import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost } from '@/lib/api';

/** Flip a kill switch (an existing feature flag), with a reason code for the audit log. */
export async function setFlag(key: string, enabled: boolean, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!/^[a-z0-9_.-]{1,80}$/.test(key)) return { ok: false, message: 'Unknown flag.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!/^[a-z0-9_]{1,40}$/.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  return attempt(() => apiPost(`/admin/config/flags/${encodeURIComponent(key)}`, { enabled, reasonCode }), `${key} is now ${enabled ? 'on' : 'off'}.`);
}
