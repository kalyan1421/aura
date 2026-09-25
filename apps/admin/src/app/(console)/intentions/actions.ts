'use server';

import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import { field, type ActionResult } from '@/lib/actions';
import { ApiFailure, apiPost, failureMessage } from '@/lib/api';
import { refusalLines } from '@/lib/format';
import { KEY_RE, REASON_RE, addBodyFrom, isPool, textsFrom, type IntentionPreset } from '@/lib/intentions';

const BASE = '/admin/intentions';

/** The API's refusal, with the words check's lines (one per problem) under the message. */
function refused(e: unknown): ActionResult {
  unstable_rethrow(e);
  return { ok: false, message: failureMessage(e), lines: e instanceof ApiFailure ? refusalLines(e.details) : [] };
}

/** Add a preset to a pool (Owner, audited). A new key needs all five lines; an existing key reuses its words. */
export async function addPreset(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const parsed = addBodyFrom((n) => field(fd, n));
  if (!parsed.ok) return { ok: false, message: parsed.message };
  let out: { preset: IntentionPreset; newWords: boolean };
  try {
    out = await apiPost(`${BASE}/presets`, parsed.body);
  } catch (e) {
    return refused(e);
  }
  refresh();
  return {
    ok: true,
    message: `${out.preset.key} added to the ${out.preset.pool} list${out.newWords ? ' with its words' : ''}, ${
      out.preset.enabled ? 'in rotation from the next Lantern Hour that starts' : 'retired (restore it to put it in rotation)'
    }.`,
  };
}

/** Retire (out of the rotation; rooms showing it tonight keep it) or restore (Owner, audited). */
export async function setEnabled(pool: string, key: string, enabled: boolean, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!isPool(pool) || !KEY_RE.test(key)) return { ok: false, message: 'Unknown preset.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!REASON_RE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  let out: { preset: IntentionPreset };
  try {
    out = await apiPost(`${BASE}/presets/${pool}/${key}`, { enabled, reasonCode });
  } catch (e) {
    return refused(e);
  }
  refresh();
  if (enabled) return { ok: true, message: `${key} is back in the ${pool} rotation from the next Lantern Hour that starts.` };
  const n = out.preset.inUseTonight;
  return {
    ok: true,
    message: `${key} is retired from the ${pool} rotation.${n > 0 ? ` ${n} room${n === 1 ? '' : 's'} showing it tonight keep${n === 1 ? 's' : ''} it.` : ''}`,
  };
}

/** Move a preset in the pool's rotation order (Owner, audited). */
export async function movePreset(pool: string, key: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!isPool(pool) || !KEY_RE.test(key)) return { ok: false, message: 'Unknown preset.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!REASON_RE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  const position = Number(field(fd, 'position'));
  if (!Number.isInteger(position) || position < 0 || position > 100_000) return { ok: false, message: 'Position is a whole number from 0 to 100000.' };
  try {
    await apiPost(`${BASE}/presets/${pool}/${key}`, { position, reasonCode });
  } catch (e) {
    return refused(e);
  }
  refresh();
  return { ok: true, message: `${key} moved to position ${position} in the ${pool} list.` };
}

/** Reword a key in all five languages (every pool using it; Owner, audited). */
export async function editWords(key: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!KEY_RE.test(key)) return { ok: false, message: 'Unknown intention.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!REASON_RE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  const { texts, missing } = textsFrom((n) => field(fd, n));
  if (!texts || missing.length) return { ok: false, message: `Every language needs its line${missing.length ? ` (missing: ${missing.join(', ')})` : ''}.` };
  let out: { changed: string[] };
  try {
    out = await apiPost(`${BASE}/words/${key}`, { texts, reasonCode });
  } catch (e) {
    return refused(e);
  }
  refresh();
  return {
    ok: true,
    message: out.changed.length ? `Saved (${out.changed.join(', ')}). Phones show the new words the next time they load them.` : 'Nothing changed.',
  };
}
