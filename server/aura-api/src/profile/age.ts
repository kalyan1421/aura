import { localDate } from '../rules';

export const MIN_AGE = 13;

/** Completed years between `birthDate` and `today` (both `YYYY-MM-DD`). */
export function ageOn(birthDate: string, today: string): number {
  const [by, bm, bd] = birthDate.split('-').map(Number);
  const [ty, tm, td] = today.split('-').map(Number);
  return ty - by - (tm < bm || (tm === bm && td < bd) ? 1 : 0);
}

/**
 * Under 13 on the user's **own local calendar date** — the same rule the app applies before it ever
 * calls the API, so a 13-year-old is never blocked on their birthday because UTC hasn't caught up.
 * The DB's `profiles_min_age` backstop allows one day of slack for zones ahead of UTC (up to +14 h).
 */
export function isUnder13(birthDate: string, now: Date, tz: string): boolean {
  return ageOn(birthDate, localDate(now, tz)) < MIN_AGE;
}
