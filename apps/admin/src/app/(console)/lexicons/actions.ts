'use server';

import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import { field, type ActionResult } from '@/lib/actions';
import { ApiFailure, apiPost, failureMessage } from '@/lib/api';
import { VERDICT_LABEL, refusalLines } from '@/lib/format';
import type { LexiconDiff, LexiconVerdict } from '@/lib/types';

const CODE = /^[a-z0-9_]{1,40}$/;
const BASE = '/admin/lexicons/crisis';

/** The API's refusal, with its details (problems, failed vectors) as lines under the message. */
function refused(e: unknown): ActionResult {
  unstable_rethrow(e);
  return { ok: false, message: failureMessage(e), lines: e instanceof ApiFailure ? refusalLines(e.details) : [] };
}

function diffLines(d: LexiconDiff): string[] {
  const lines = [`Compared with ${d.from === null ? 'the bundled baseline' : `live version ${d.from}`}:`];
  if (d.added.length) lines.push(`added: ${d.added.join(', ')}`);
  if (d.removed.length) lines.push(`removed: ${d.removed.join(', ')}`);
  if (d.changed.length) lines.push(`changed: ${d.changed.join(', ')}`);
  lines.push(`crisis forms: +${d.crisisFormsAdded} / −${d.crisisFormsRemoved}${d.crisisFormsRemoved ? ' (publishing needs the Owner’s “allow crisis removals”)' : ''}`);
  return lines;
}

/** "Test on samples" (Owner + Moderator): verdicts only; the samples are not stored or logged anywhere. */
export async function testSamples(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const samples = field(fd, 'samples')
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);
  if (samples.length === 0) return { ok: false, message: 'Type at least one sample, one per line.' };
  if (samples.length > 50) return { ok: false, message: 'At most 50 samples at a time.' };
  if (samples.some((s) => s.length > 500)) return { ok: false, message: 'Keep each sample under 500 characters.' };
  const source = field(fd, 'version');
  const body: Record<string, unknown> = { samples };
  if (/^\d+$/.test(source)) body.version = Number(source);
  let out: { version: number | null; results: Array<{ index: number; verdict: LexiconVerdict }> };
  try {
    out = await apiPost(`${BASE}/test`, body);
  } catch (e) {
    return refused(e);
  }
  const counts = out.results.reduce<Record<string, number>>((m, r) => ({ ...m, [r.verdict]: (m[r.verdict] ?? 0) + 1 }), {});
  return {
    ok: true,
    message: `Version ${out.version ?? 'draft'}: ${counts.crisis ?? 0} crisis · ${counts.soft ?? 0} soft · ${counts.none ?? 0} none.`,
    lines: out.results.map((r) => `${r.index + 1}. “${samples[r.index]}” → ${VERDICT_LABEL[r.verdict] ?? r.verdict}`),
  };
}

/** Stores a new version (Owner). Not live until published; checked against the contract and its own vectors. */
export async function uploadVersion(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  let lexicon: unknown;
  let vectors: unknown;
  try {
    lexicon = JSON.parse(field(fd, 'lexicon'));
  } catch {
    return { ok: false, message: 'The lexicon is not valid JSON.' };
  }
  const rawVectors = field(fd, 'vectors');
  if (rawVectors) {
    try {
      vectors = JSON.parse(rawVectors);
    } catch {
      return { ok: false, message: 'The test cases are not valid JSON (an array of { text, verdict, why? }).' };
    }
    if (!Array.isArray(vectors)) return { ok: false, message: 'The test cases must be a JSON array.' };
  }
  const note = field(fd, 'note');
  const body: Record<string, unknown> = { lexicon };
  if (vectors) body.vectors = vectors;
  if (note) body.note = note.slice(0, 500);
  let out: { version: number; entries: number; diff: LexiconDiff };
  try {
    out = await apiPost(`${BASE}/versions`, body);
  } catch (e) {
    return refused(e);
  }
  refresh();
  return { ok: true, message: `Version ${out.version} stored (${out.entries} entries). It is not live: test it, then publish.`, lines: diffLines(out.diff) };
}

/** Stores the app's bundled lexicon as a version, so "back to the baseline" is an ordinary rollback (Owner). */
export async function storeBaseline(_prev: ActionResult): Promise<ActionResult> {
  let out: { version: number; entries: number };
  try {
    out = await apiPost(`${BASE}/versions/baseline`);
  } catch (e) {
    return refused(e);
  }
  refresh();
  return { ok: true, message: `The bundled baseline is stored as version ${out.version} (${out.entries} entries).` };
}

/** Publish a stored version — forward, or back (a rollback) — as a new signed bundle (Owner, audited). */
export async function publishVersion(version: number, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!Number.isInteger(version) || version < 1) return { ok: false, message: 'Unknown version.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!CODE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  const body: Record<string, unknown> = { version, reasonCode };
  if (field(fd, 'allowCrisisRemovals') === 'yes') body.allowCrisisRemovals = true;
  if (field(fd, 'resign') === 'yes') body.resign = true;
  let out: { version: number; previousVersion: number | null; seq: number; action: string };
  try {
    out = await apiPost(`${BASE}/publish`, body);
  } catch (e) {
    return refused(e);
  }
  refresh();
  const what = out.action === 'lexicon_rollback' ? 'Rolled back to' : 'Published';
  return {
    ok: true,
    message: `${what} version ${out.version}${out.previousVersion !== null ? ` (was ${out.previousVersion})` : ''}. Apps pick it up on their next config fetch (seq ${out.seq}).`,
  };
}
