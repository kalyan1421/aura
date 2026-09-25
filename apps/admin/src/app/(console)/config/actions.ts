'use server';

import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost } from '@/lib/api';
import { REGION_FLAG_LABEL, REGION_LABEL, isRegionFlag, isRegionName } from '@/lib/kill-switches';

/** Flip a kill switch (an existing feature flag), with a reason code for the audit log. */
export async function setFlag(key: string, enabled: boolean, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!/^[a-z0-9_.-]{1,80}$/.test(key)) return { ok: false, message: 'Unknown flag.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!/^[a-z0-9_]{1,40}$/.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  return attempt(() => apiPost(`/admin/config/flags/${encodeURIComponent(key)}`, { enabled, reasonCode }), `${key} is now ${enabled ? 'on' : 'off'}.`);
}

/** Pause or resume one timezone region of Quiet Together / the Lantern Hour wind-down (Owner; `payload.pausedRegions`). */
export async function setRegionPaused(key: string, region: string, paused: boolean, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!isRegionFlag(key)) return { ok: false, message: 'Unknown switch.' };
  if (!isRegionName(region)) return { ok: false, message: 'Unknown region.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!/^[a-z0-9_]{1,40}$/.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  return attempt(
    () => apiPost(`/admin/config/regions/${key}/${region}/${paused ? 'pause' : 'resume'}`, { reasonCode }),
    `${REGION_FLAG_LABEL[key] ?? key} ${paused ? 'paused' : 'resumed'} in ${REGION_LABEL[region] ?? region}.`,
  );
}
