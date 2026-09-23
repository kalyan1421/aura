'use server';

import { redirect, unstable_rethrow } from 'next/navigation';
import { attempt, field, istLocalToIso, type ActionResult } from '@/lib/actions';
import { apiPost, failureMessage } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function acknowledgeGrievance(id: string, _prev: ActionResult): Promise<ActionResult> {
  if (!UUID.test(id)) return { ok: false, message: 'Unknown grievance.' };
  return attempt(() => apiPost(`/admin/grievances/${id}/acknowledge`), 'Acknowledged; the acknowledgement email is on its way.');
}

/** Resolve with a reply; NestJS appends the Grievance Appellate Committee route to the email. */
export async function resolveGrievance(id: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(id)) return { ok: false, message: 'Unknown grievance.' };
  const outcome = field(fd, 'outcome');
  const reply = field(fd, 'reply');
  if (reply.length < 10) return { ok: false, message: 'Write the reply to the complainant (at least 10 characters).' };
  let emailed = false;
  try {
    const r = await apiPost<{ replyEmailed: boolean }>(`/admin/grievances/${id}/resolve`, { outcome, reply });
    emailed = r.replyEmailed;
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  redirect(`/grievances/${id}?resolved=${emailed ? 'emailed' : 'not-emailed'}`);
}

/** A grievance that arrived by email or post (the statutory clock runs from when it was received). */
export async function createGrievance(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const receivedAt = istLocalToIso(field(fd, 'receivedAt'));
  if (!receivedAt) return { ok: false, message: 'Enter when it was received (IST).' };
  const body = {
    category: field(fd, 'category'),
    channel: field(fd, 'channel'),
    email: field(fd, 'email'),
    name: field(fd, 'name') || undefined,
    description: field(fd, 'description'),
    contentLocation: field(fd, 'contentLocation') || undefined,
    receivedAt,
    sendAcknowledgement: field(fd, 'sendAck') === 'yes',
  };
  let id = '';
  try {
    id = (await apiPost<{ grievanceId: string }>('/admin/grievances', body)).grievanceId;
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  redirect(`/grievances/${id}`);
}
