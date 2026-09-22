/**
 * Calendar-day helpers on `YYYY-MM-DD` strings. Days are treated as abstract
 * calendar dates (anchored at UTC midnight) so arithmetic never sees DST.
 */
const DAY_MS = 86_400_000;
const LOCAL_DAY_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

/** True for a real calendar date in strict `YYYY-MM-DD` form. */
export function isLocalDay(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const m = LOCAL_DAY_RE.exec(value);
  if (!m) return false;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d;
}

function dayToEpochDays(day: string): number {
  if (!isLocalDay(day)) throw new RangeError(`invalid local day: ${day}`);
  const [y, m, d] = day.split('-').map(Number);
  return Date.UTC(y, m - 1, d) / DAY_MS;
}

/** Whole days from `a` to `b` (`b − a`). */
export function daysBetween(a: string, b: string): number {
  return dayToEpochDays(b) - dayToEpochDays(a);
}

/** `day + n` days. */
export function addDays(day: string, n: number): string {
  return new Date((dayToEpochDays(day) + n) * DAY_MS).toISOString().slice(0, 10);
}
