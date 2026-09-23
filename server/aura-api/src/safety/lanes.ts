import { isLanternHour } from '../rooms/regions';
import { CRISIS_REASON, UNDER_13_REASON, type Lane, type ReportReason } from './safety-types';

/**
 * Report → lane (PRD 06b report reasons; 19 admin console "Queues and priority lanes"):
 * - reason 1 (in danger / self-harm) → `crisis` (L0), whoever is involved — crisis sorts above everything;
 * - reason 7 (may be under 13), or anyone involved under 18 by stored DOB → `minors_grooming` (L1);
 * - 2 harassment, 3 sexual, 4 hate, 5 contact/personal info → `harassment` (L2);
 * - 6 spam/selling, 8 other → `spam` (L3).
 */
export function laneFor(reason: ReportReason, involvesMinor: boolean): Lane {
  if (reason === CRISIS_REASON) return 'crisis';
  if (reason === UNDER_13_REASON || involvesMinor) return 'minors_grooming';
  if (reason === 2 || reason === 3 || reason === 4 || reason === 5) return 'harassment';
  return 'spam';
}

export interface Sla {
  dueAt: Date;
  /** 24×7 page (push, then a call): L1 sexual/grooming involving a minor; L0 in India's Lantern Hour. */
  pages: boolean;
}

const MIN = 60_000;

/**
 * SLA clocks (19 admin console): crisis < 15 min in India's Lantern Hour, < 1 h otherwise; minors & grooming:
 * sexual content or grooming signals (contact / personal info) involving a minor < 2 h and pages 24×7, other L1
 * < 4 h [ASSUMPTION]; every other report < 24 h.
 */
export function slaFor(lane: Lane, reason: ReportReason, involvesMinor: boolean, now: Date): Sla {
  const at = (minutes: number): Date => new Date(now.getTime() + minutes * MIN);
  switch (lane) {
    case 'crisis': {
      const indiaLanternHour = isLanternHour('south_asia', now);
      return { dueAt: at(indiaLanternHour ? 15 : 60), pages: indiaLanternHour };
    }
    case 'minors_grooming': {
      const urgent = involvesMinor && (reason === 3 || reason === 5);
      return { dueAt: at(urgent ? 120 : 240), pages: urgent };
    }
    default:
      return { dueAt: at(24 * 60), pages: false };
  }
}
