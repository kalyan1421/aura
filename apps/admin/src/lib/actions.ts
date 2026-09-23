import { refresh } from 'next/cache';
import { unstable_rethrow } from 'next/navigation';
import { failureMessage } from './api';

/** Result shape of every console form. */
export type ActionResult = { ok: boolean; message: string; lines?: string[] } | null;

/**
 * Runs a mutation from a server action: on success refreshes the page's server data and reports `ok`; on failure
 * reports the API's message. Redirects (e.g. "sign in again") pass through.
 */
export async function attempt(fn: () => Promise<unknown>, ok: string): Promise<ActionResult> {
  try {
    await fn();
  } catch (e) {
    unstable_rethrow(e);
    return { ok: false, message: failureMessage(e) };
  }
  refresh();
  return { ok: true, message: ok };
}

export function field(fd: FormData, name: string): string {
  const v = fd.get(name);
  return typeof v === 'string' ? v.trim() : '';
}

/** `datetime-local` values are entered in IST (the Owner's clock) → ISO instant. */
export function istLocalToIso(v: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(v)) return null;
  const d = new Date(`${v}:00+05:30`);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}
