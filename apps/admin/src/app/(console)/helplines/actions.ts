'use server';

import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import { field, type ActionResult } from '@/lib/actions';
import { ApiFailure, apiPost, failureMessage } from '@/lib/api';
import { refusalLines } from '@/lib/format';
import type { HelplinesDiff } from '@/lib/types';

const CODE = /^[a-z0-9_]{1,40}$/;
const BASE = '/admin/helplines';

/** The API's refusal, with its details (schema problems, numbers that would disappear) as lines under the message. */
function refused(e: unknown): ActionResult {
  unstable_rethrow(e);
  return { ok: false, message: failureMessage(e), lines: e instanceof ApiFailure ? refusalLines(e.details) : [] };
}

function diffLines(d: HelplinesDiff): string[] {
  const lines = [`Compared with ${d.from === null ? 'the bundled directory' : `live version ${d.from}`}:`];
  if (d.added.length) lines.push(`added: ${d.added.join(', ')}`);
  if (d.removed.length) lines.push(`removed: ${d.removed.join(', ')}`);
  if (d.changed.length) lines.push(`changed: ${d.changed.join(', ')}`);
  if (d.countriesRemoved.length) lines.push(`regions no longer listed: ${d.countriesRemoved.join(', ')}`);
  lines.push(
    d.numbersRemoved
      ? `${d.numbersRemoved} number(s) phones show now would disappear: publishing needs the Owner’s “allow removals”`
      : 'no number phones show now disappears',
  );
  return lines;
}

/** Stores a new version (Owner). Not live until published; checked against contracts/safety/helplines.schema.json. */
export async function uploadVersion(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  let helplines: unknown;
  try {
    helplines = JSON.parse(field(fd, 'helplines'));
  } catch {
    return { ok: false, message: 'The directory is not valid JSON.' };
  }
  const note = field(fd, 'note');
  const body: Record<string, unknown> = { helplines };
  if (note) body.note = note.slice(0, 500);
  let out: { version: number; lines: number; diff: HelplinesDiff };
  try {
    out = await apiPost(`${BASE}/versions`, body);
  } catch (e) {
    return refused(e);
  }
  refresh();
  return { ok: true, message: `Version ${out.version} stored (${out.lines} lines). It is not live: check it, then publish.`, lines: diffLines(out.diff) };
}

/** Stores the directory every app build bundles, so "back to the bundled numbers" is an ordinary rollback (Owner). */
export async function storeBaseline(_prev: ActionResult): Promise<ActionResult> {
  let out: { version: number; lines: number };
  try {
    out = await apiPost(`${BASE}/versions/baseline`);
  } catch (e) {
    return refused(e);
  }
  refresh();
  return { ok: true, message: `The bundled directory is stored as version ${out.version} (${out.lines} lines).` };
}

/** Publish a stored version — forward, or back (a rollback) — as a new signed bundle (Owner, audited). */
export async function publishVersion(version: number, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!Number.isInteger(version) || version < 1) return { ok: false, message: 'Unknown version.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!CODE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  const body: Record<string, unknown> = { version, reasonCode };
  if (field(fd, 'allowRemovals') === 'yes') body.allowRemovals = true;
  if (field(fd, 'resign') === 'yes') body.resign = true;
  let out: { version: number; previousVersion: number | null; seq: number; action: string };
  try {
    out = await apiPost(`${BASE}/publish`, body);
  } catch (e) {
    return refused(e);
  }
  refresh();
  const what = out.action === 'helplines_rollback' ? 'Rolled back to' : 'Published';
  return {
    ok: true,
    message: `${what} version ${out.version}${out.previousVersion !== null ? ` (was ${out.previousVersion})` : ''}. Apps pick it up on their next config fetch (seq ${out.seq}).`,
  };
}
