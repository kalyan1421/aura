'use server';

import { attempt, field, type ActionResult } from '@/lib/actions';
import { apiPost } from '@/lib/api';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ROLES = new Set(['owner', 'moderator', 'analyst']);

/** Add an existing (signed-in-once, non-app) account to the staff list. NestJS + the database check everything again. */
export async function addStaff(_prev: ActionResult, fd: FormData): Promise<ActionResult> {
  const email = field(fd, 'email');
  const role = field(fd, 'role');
  const displayName = field(fd, 'displayName');
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { ok: false, message: 'Enter the staff member’s email address.' };
  if (!ROLES.has(role)) return { ok: false, message: 'Choose a role.' };
  if (displayName.length < 1 || displayName.length > 60) return { ok: false, message: 'Give a display name (up to 60 characters).' };
  return attempt(() => apiPost('/admin/staff', { email, role, displayName }), `${displayName} can now sign in (after setting up TOTP).`);
}

export async function changeRole(staffId: string, _prev: ActionResult, fd: FormData): Promise<ActionResult> {
  if (!UUID.test(staffId)) return { ok: false, message: 'Unknown staff member.' };
  const role = field(fd, 'role');
  if (!ROLES.has(role)) return { ok: false, message: 'Choose a role.' };
  return attempt(() => apiPost(`/admin/staff/${staffId}`, { role }), 'Role changed; it applies to their next request.');
}

export async function setDisabled(staffId: string, disabled: boolean, _prev: ActionResult): Promise<ActionResult> {
  if (!UUID.test(staffId)) return { ok: false, message: 'Unknown staff member.' };
  return attempt(() => apiPost(`/admin/staff/${staffId}`, { disabled }), disabled ? 'Access removed at once.' : 'Access restored.');
}
