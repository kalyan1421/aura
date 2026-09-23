'use server';

import { redirect, unstable_rethrow } from 'next/navigation';
import { attempt, field, istLocalToIso, type ActionResult } from '@/lib/actions';
import { apiPost, failureMessage } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Record a court / government order (or a drill). It pages the Owner at once; the 3 h clock runs from receipt. */
export async function createOrder(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const receivedRaw = field(fd, 'receivedAt');
  const receivedAt = receivedRaw ? istLocalToIso(receivedRaw) : null;
  if (receivedRaw && !receivedAt) return { ok: false, message: 'Enter when the order was received (IST).' };
  const body = {
    source: field(fd, 'source'),
    authority: field(fd, 'authority'),
    reference: field(fd, 'reference') || undefined,
    receivedAt: receivedAt ?? undefined,
    summary: field(fd, 'summary'),
    targets: field(fd, 'targets') || undefined,
    isTest: field(fd, 'isTest') === 'yes',
  };
  let id = '';
  try {
    id = (await apiPost<{ legalOrderId: string }>('/admin/legal-orders', body)).legalOrderId;
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  redirect(`/legal-orders/${id}`);
}

/** The quick drill: a TEST takedown order that pages exactly like a real one (week 13 exit criterion). */
export async function sendDrill(_prev: ActionResult): Promise<ActionResult> {
  let id = '';
  try {
    id = (
      await apiPost<{ legalOrderId: string }>('/admin/legal-orders', {
        source: 'government',
        authority: 'Drill (test takedown order)',
        summary: 'Drill: a test takedown order to check that paging reaches the Owner. No content is affected.',
        isTest: true,
      })
    ).legalOrderId;
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  redirect(`/legal-orders/${id}`);
}

export async function acknowledgeOrder(id: string, _prev: ActionResult): Promise<ActionResult> {
  if (!UUID.test(id)) return { ok: false, message: 'Unknown order.' };
  return attempt(() => apiPost(`/admin/legal-orders/${id}/acknowledge`), 'Acknowledged: paging stopped. The 3-hour clock keeps running.');
}

export async function closeOrder(id: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(id)) return { ok: false, message: 'Unknown order.' };
  const status = field(fd, 'status');
  const note = field(fd, 'note');
  if (note.length < 3) return { ok: false, message: 'Record what was done (or why it was rejected).' };
  return attempt(() => apiPost(`/admin/legal-orders/${id}/close`, { status, note }), status === 'actioned' ? 'Marked actioned.' : 'Marked rejected.');
}
