'use server';

import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import type { ActionResult } from '@/lib/actions';
import { apiPost, failureMessage } from '@/lib/api';
import type { AuditExportResult } from '@/lib/types';

/** Export the audit log now (everything since the last export) to the configured destinations; audited. */
export async function exportNow(_prev: ActionResult): Promise<ActionResult> {
  let r: AuditExportResult;
  try {
    r = await apiPost<AuditExportResult>('/admin/audit/exports');
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  refresh();
  if (r.status === 'exported') {
    return {
      ok: r.manifest.chainVerified,
      message: `Exported rows ${r.manifest.fromId}–${r.manifest.toId} (${r.manifest.rows}) to ${r.destinations.join(' and ')}. Chain ${r.manifest.chainVerified ? 'verified' : 'NOT verified — investigate'}.${r.failed.length ? ` Failed: ${r.failed.join(', ')}.` : ''}`,
    };
  }
  if (r.status === 'failed') return { ok: false, message: `The export reached no destination (${r.failed.join(', ')}).` };
  return { ok: r.reason === 'nothing_new', message: r.reason === 'nothing_new' ? 'Nothing new since the last export.' : 'No export destination is configured (ADMIN_AUDIT_EXPORT_DIR / ADMIN_AUDIT_EXPORT_EMAIL).' };
}
