'use server';

import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost } from '@/lib/api';
import { isPseudonymShaped } from '@/lib/pseudonyms';

/** Take a room pseudonym out of use, or hand it out again (Owner; audited with the reason, PRD 19 Configuration). */
export async function setPseudonymBlocked(blocked: boolean, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const pseudonym = field(fd, 'pseudonym');
  if (!isPseudonymShaped(pseudonym)) return { ok: false, message: 'Two words, letters only (e.g. Quiet Comet).' };
  const reasonCode = field(fd, 'reasonCode');
  if (!/^[a-z0-9_]{1,40}$/.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  return attempt(
    () => apiPost(`/admin/config/pseudonyms/${blocked ? 'block' : 'unblock'}`, { pseudonym, reasonCode }),
    blocked ? `${pseudonym} is no longer handed out.` : `${pseudonym} is handed out again.`,
  );
}
