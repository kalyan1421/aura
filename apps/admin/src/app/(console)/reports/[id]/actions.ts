'use server';

import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost, failureMessage } from '@/lib/api';
import { ACTION_LABEL } from '@/lib/format';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CODE = /^[a-z0-9_]{1,40}$/;

function reasonFrom(fd: FormData): string {
  const picked = field(fd, 'reasonCode');
  return picked === 'custom' ? field(fd, 'customReason') : picked;
}

/** One moderation action via NestJS → ModerationService (role-checked and audited there). */
export async function actOnReport(reportId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(reportId)) return { ok: false, message: 'Unknown report.' };
  const action = field(fd, 'action');
  if (!(action in ACTION_LABEL)) return { ok: false, message: 'Choose an action.' };
  const reasonCode = reasonFrom(fd);
  if (!CODE.test(reasonCode)) return { ok: false, message: 'Choose a reason code (lowercase letters, digits and _ only).' };
  const body: Record<string, unknown> = { action, reasonCode };
  if (action === 'shadow_mute') body.hours = Number(field(fd, 'muteHours') || '168');
  if (action === 'suspend') body.hours = Number(field(fd, 'suspendHours') || '24');
  if (action === 'ban' && field(fd, 'confirmBan') !== 'yes') return { ok: false, message: 'Tick the confirmation before banning.' };
  let out: { status: string; activeStrikes: number | null; mandatoryReport: { evidenceHoldId: string } | null };
  try {
    out = await apiPost(`/admin/reports/${reportId}/actions`, body);
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  refresh();
  if (out.mandatoryReport) {
    return { ok: true, message: 'Account closed. Evidence is held 180 days and the mandatory-report task is open (Mandatory reports).' };
  }
  const strikes = out.activeStrikes !== null ? ` Active strikes: ${out.activeStrikes}.` : '';
  return { ok: true, message: `${ACTION_LABEL[action]} applied; the report is ${out.status}.${strikes}` };
}

export async function liftSanction(sanctionId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(sanctionId)) return { ok: false, message: 'Unknown sanction.' };
  const reasonCode = field(fd, 'reasonCode') || 'lifted';
  if (!CODE.test(reasonCode)) return { ok: false, message: 'Reason codes use lowercase letters, digits and _.' };
  return attempt(() => apiPost(`/admin/sanctions/${sanctionId}/lift`, { reasonCode }), 'Sanction lifted.');
}
