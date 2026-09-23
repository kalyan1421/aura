import { isLanternHour } from '../rooms/regions';
import { CRISIS_REASON, TARGETING_MINOR_REASON, UNDER_13_REASON, type Lane, type ReportReason } from './safety-types';

/**
 * Report → lane (PRD 06b report reasons; 19 admin console "Queues and priority lanes"):
 * - reason 1 (in danger / self-harm) → `crisis` (L0), whoever is involved — crisis sorts above everything;
 * - reason 7 (may be under 13) or 9 (targeting a young person) → `minors_grooming` (L1) whatever the ages on record:
 *   the reporter's perception is the signal; any other reason too when anyone involved is under 18 (stored DOB or a
 *   platform age signal);
 * - 2 harassment, 3 sexual, 4 hate, 5 contact/personal info → `harassment` (L2);
 * - 6 spam/selling, 8 other → `spam` (L3).
 */
export function laneFor(reason: ReportReason, involvesMinor: boolean): Lane {
  if (reason === CRISIS_REASON) return 'crisis';
  if (reason === UNDER_13_REASON || reason === TARGETING_MINOR_REASON || involvesMinor) return 'minors_grooming';
  if (reason === 2 || reason === 3 || reason === 4 || reason === 5) return 'harassment';
  return 'spam';
}

/**
 * Minors & grooming items that are sexual content or grooming signals: 3 sexual content or advances, 5 contact /
 * personal info (asking for contact, age, school, city, photos, to meet), 9 targeting a young person.
 */
const SEXUAL_OR_GROOMING: ReadonlySet<ReportReason> = new Set<ReportReason>([3, 5, TARGETING_MINOR_REASON]);

export interface Sla {
  dueAt: Date;
  /** 24×7 page (push, then a call): L1 sexual/grooming involving a minor; L0 in India's Lantern Hour. */
  pages: boolean;
}

const MIN = 60_000;

/**
 * SLA clocks (19 admin console): crisis < 15 min in India's Lantern Hour, < 1 h otherwise; minors & grooming:
 * sexual content or grooming signals (3, 5, 9) involving a minor < 2 h and pages 24×7, other L1 < 4 h [ASSUMPTION]
 * (e.g. a "targeting a young person" report where nobody involved is under 18 on record); every other report < 24 h.
 */
export function slaFor(lane: Lane, reason: ReportReason, involvesMinor: boolean, now: Date): Sla {
  const at = (minutes: number): Date => new Date(now.getTime() + minutes * MIN);
  switch (lane) {
    case 'crisis': {
      const indiaLanternHour = isLanternHour('south_asia', now);
      return { dueAt: at(indiaLanternHour ? 15 : 60), pages: indiaLanternHour };
    }
    case 'minors_grooming': {
      const urgent = involvesMinor && SEXUAL_OR_GROOMING.has(reason);
      return { dueAt: at(urgent ? 120 : 240), pages: urgent };
    }
    default:
      return { dueAt: at(24 * 60), pages: false };
  }
}
