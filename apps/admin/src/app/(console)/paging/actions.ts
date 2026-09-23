'use server';

import { attempt, type ActionResult } from '@/lib/actions';
import { apiPost } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function ackPage(id: string, _prev: ActionResult): Promise<ActionResult> {
  if (!UUID.test(id)) return { ok: false, message: 'Unknown page.' };
  return attempt(() => apiPost(`/admin/pages/${id}/ack`), 'Acknowledged: no more repeats for this page.');
}

export async function testPage(_prev: ActionResult): Promise<ActionResult> {
  return attempt(() => apiPost('/admin/pages/test'), 'Test page sent. Acknowledge it when it arrives.');
}
