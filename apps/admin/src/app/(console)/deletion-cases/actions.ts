'use server';

import { redirect, unstable_rethrow } from 'next/navigation';
import { attempt, field, istLocalToIso, type ActionResult } from '@/lib/actions';
import { apiPost, failureMessage } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CHANNELS = new Set(['email', 'grievance', 'post', 'other']);
const IMMEDIATE = new Set(['requester_asked_immediate', 'under_13_confirmed', 'legal_requirement']);
const OUTCOMES = new Set(['withdrawn', 'unverified', 'duplicate', 'declined_by_holder', 'restored_by_holder', 'other']);

/**
 * Open a deletion case (REQ-ADM-11). The address typed here only FINDS the account: the one-time link always goes to the
 * address stored on that account, so nobody can delete someone else's account by writing in with their email.
 */
export async function openCase(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const email = field(fd, 'email');
  const channel = field(fd, 'channel');
  const receivedAt = istLocalToIso(field(fd, 'receivedAt'));
  const grievanceId = field(fd, 'grievanceId');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { ok: false, message: 'Enter the email address the request names.' };
  if (!CHANNELS.has(channel)) return { ok: false, message: 'Choose how the request arrived.' };
  if (!receivedAt) return { ok: false, message: 'Enter when it was received (IST).' };
  if (grievanceId && !UUID.test(grievanceId)) return { ok: false, message: 'Unknown grievance.' };
  let id = '';
  try {
    id = (await apiPost<{ caseId: string }>('/admin/deletion-cases', { email, channel, receivedAt, grievanceId: grievanceId || undefined })).caseId;
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  redirect(`/deletion-cases/${id}`);
}

export async function resendLink(caseId: string, _prev: ActionResult): Promise<ActionResult> {
  if (!UUID.test(caseId)) return { ok: false, message: 'Unknown case.' };
  return attempt(() => apiPost(`/admin/deletion-cases/${caseId}/resend`), 'A new link is on its way to the address on the account (the old one no longer works).');
}

export async function startDeletion(caseId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(caseId)) return { ok: false, message: 'Unknown case.' };
  const mode = field(fd, 'mode');
  if (mode === 'grace') return attempt(() => apiPost(`/admin/deletion-cases/${caseId}/delete`, { mode: 'grace' }), 'Deletion started: deactivated now, deleted after 7 days.');
  const reasonCode = field(fd, 'reasonCode');
  if (mode !== 'immediate' || !IMMEDIATE.has(reasonCode)) return { ok: false, message: 'Choose the 7-day grace, or immediate with a reason.' };
  if (field(fd, 'confirmImmediate') !== 'yes') return { ok: false, message: 'Tick the confirmation: an immediate deletion cannot be undone.' };
  return attempt(() => apiPost(`/admin/deletion-cases/${caseId}/delete`, { mode, reasonCode }), 'Deletion started: the account goes at the next hourly purge.');
}

export async function closeCase(caseId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(caseId)) return { ok: false, message: 'Unknown case.' };
  const outcome = field(fd, 'outcome');
  if (!OUTCOMES.has(outcome)) return { ok: false, message: 'Choose an outcome.' };
  return attempt(() => apiPost(`/admin/deletion-cases/${caseId}/close`, { outcome }), 'Case closed.');
}
