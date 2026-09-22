import { auraDay } from './aura-day';

/** RULES.md §2 — credit eligibility for a check-in or habit completion. */
export const MAX_FUTURE_SKEW_MS = 5 * 60_000;
export const MAX_STALENESS_MS = 30 * 86_400_000;

export interface EligibilityInput {
  deviceTs: string | Date;
  serverNow: string | Date;
  tz: string;
  localDay: string;
}

const ms = (v: string | Date): number => (typeof v === 'string' ? Date.parse(v) : v.getTime());

export function isEligible({ deviceTs, serverNow, tz, localDay }: EligibilityInput): boolean {
  const dev = ms(deviceTs);
  const now = ms(serverNow);
  if (Number.isNaN(dev) || Number.isNaN(now)) return false;
  if (dev > now + MAX_FUTURE_SKEW_MS) return false; // future-dated beyond clock skew
  if (now - dev > MAX_STALENESS_MS) return false; // stale
  return localDay === auraDay(new Date(dev), tz); // not a backfill
}
