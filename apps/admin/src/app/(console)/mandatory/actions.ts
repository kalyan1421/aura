'use server';

import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MANUAL = new Set(['pocso_report_prepared', 'ncrp_report_prepared', 'ncmec_assessed', 'counsel_consulted', 'no_tipping_off_confirmed']);

export async function setChecklist(holdId: string, item: string, done: boolean, _prev: ActionResult): Promise<ActionResult> {
  if (!UUID.test(holdId) || !MANUAL.has(item)) return { ok: false, message: 'Unknown checklist item.' };
  return attempt(() => apiPost(`/admin/mandatory-reports/${holdId}/checklist`, { item, done }), done ? 'Ticked.' : 'Unticked.');
}

/** Closes the task: an external reference, or an Owner-recorded legal reason (REQ-ADM-14). */
export async function recordReport(holdId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(holdId)) return { ok: false, message: 'Unknown evidence hold.' };
  const reportedTo = field(fd, 'reportedTo');
  const reportRef = field(fd, 'reportRef');
  const legalReason = field(fd, 'legalReason');
  if (reportedTo && reportRef) {
    return attempt(() => apiPost(`/admin/mandatory-reports/${holdId}/record`, { reportedTo, reportRef }), 'Report reference recorded; the task is closed.');
  }
  if (legalReason.length >= 10) {
    return attempt(() => apiPost(`/admin/mandatory-reports/${holdId}/record`, { legalReason }), 'Legal reason recorded; the task is closed.');
  }
  return { ok: false, message: 'Enter where it was reported and the reference, or a legal reason (at least 10 characters).' };
}
