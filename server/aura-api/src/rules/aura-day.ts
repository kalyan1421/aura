/**
 * RULES.md §1 — Aura day: `date(toLocal(instantUtc, tz) − 4h)`; rolls over at 04:00 local.
 *
 * We read the *wall-clock* fields of the instant in the IANA zone via Intl and
 * subtract 4 wall-clock hours, so DST transitions (23h/25h days) are handled by
 * the tz database rather than by fixed offsets.
 */
export const ROLLOVER_HOUR = 4;

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(tz: string): Intl.DateTimeFormat {
  let f = formatters.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hourCycle: 'h23',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
    formatters.set(tz, f);
  }
  return f;
}

/** True when `tz` is an IANA zone this runtime can resolve. */
export function isValidTimeZone(tz: unknown): tz is string {
  if (typeof tz !== 'string' || tz.length === 0 || tz.length > 64) return false;
  try {
    formatterFor(tz);
    return true;
  } catch {
    return false;
  }
}

/** Wall-clock fields of `instant` in `tz`. */
export function wallClock(
  instant: Date,
  tz: string,
): { year: number; month: number; day: number; hour: number; minute: number; second: number } {
  const parts = formatterFor(tz).formatToParts(instant);
  const get = (type: Intl.DateTimeFormatPartTypes): number => {
    const p = parts.find((x) => x.type === type);
    if (!p) throw new Error(`Intl did not return ${type} for ${tz}`);
    return Number(p.value);
  };
  return {
    year: get('year'),
    month: get('month'),
    day: get('day'),
    hour: get('hour') % 24,
    minute: get('minute'),
    second: get('second'),
  };
}

function toInstant(utc: string | Date): Date {
  const d = typeof utc === 'string' ? new Date(utc) : utc;
  if (Number.isNaN(d.getTime())) throw new RangeError(`invalid instant: ${String(utc)}`);
  return d;
}

/** Calendar date (`YYYY-MM-DD`) of `instant` in `tz` (no rollover shift). */
export function localDate(utc: string | Date, tz: string): string {
  const w = wallClock(toInstant(utc), tz);
  return new Date(Date.UTC(w.year, w.month - 1, w.day)).toISOString().slice(0, 10);
}

/** RULES.md §1. `utc` is an ISO instant (or Date); returns `YYYY-MM-DD`. */
export function auraDay(utc: string | Date, tz: string): string {
  const w = wallClock(toInstant(utc), tz);
  const shifted = Date.UTC(w.year, w.month - 1, w.day, w.hour - ROLLOVER_HOUR, w.minute, w.second);
  return new Date(shifted).toISOString().slice(0, 10);
}
