'use server';

import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost, failureMessage } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DEVICE = /^[0-9a-f]{64}$/;
const CODE = /^[a-z0-9_]{1,40}$/;

/** Ban every device seen for the account a report is about (Owner, audited). */
export async function banAccountDevices(reportId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(reportId)) return { ok: false, message: 'Unknown report.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!CODE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  let out: { devices: number; newlyBanned: number };
  try {
    out = await apiPost('/admin/devices/ban-account', { reportId, reasonCode });
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  refresh();
  return { ok: true, message: `${out.newlyBanned} of ${out.devices} device${out.devices === 1 ? '' : 's'} newly banned (the rest already were).` };
}

/** Ban one device (install hash), optionally tied to a report (Owner, audited). */
export async function banDevice(deviceId: string, reportId: string | null, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!DEVICE.test(deviceId)) return { ok: false, message: 'Unknown device.' };
  if (reportId !== null && !UUID.test(reportId)) return { ok: false, message: 'Unknown report.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!CODE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  return attempt(() => apiPost(`/admin/devices/${deviceId}/ban`, reportId ? { reasonCode, reportId } : { reasonCode }), 'Device banned.');
}

/** Lift a device ban (an upheld appeal; Owner, audited). The ban stays in the history. */
export async function liftDeviceBan(banId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(banId)) return { ok: false, message: 'Unknown ban.' };
  const reasonCode = field(fd, 'reasonCode');
  if (!CODE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  return attempt(() => apiPost(`/admin/devices/bans/${banId}/lift`, { reasonCode }), 'Device ban lifted.');
}
