import { DEFAULT_LANTERN_END, DEFAULT_LANTERN_START, isLanternHour, type ClockTime, type TzRegion } from '../rooms/regions';
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
  /**
   * Page the Owner at once (push within 60 s, then a call, repeating every 5 min until acknowledged): L1 sexual /
   * grooming involving a minor (24×7); L0 crisis in India's Lantern Hour or the room's own region's Lantern Hour.
   * Crisis items that don't page at filing page once they have waited `PAGING_CRISIS_AFTER_MINUTES` (the worker sweep).
   */
  pages: boolean;
}

/** Where a report was filed, for the crisis clock: the room's region (its Lantern Hour) and the configured window. */
export interface SlaContext {
  roomRegion?: TzRegion | null;
  lanternStart?: ClockTime;
  lanternEnd?: ClockTime;
}

const MIN = 60_000;

/**
 * SLA clocks (19 admin console): crisis < 15 min in India's Lantern Hour, < 1 h otherwise; minors & grooming:
 * sexual content or grooming signals (3, 5, 9) involving a minor < 2 h and pages 24×7, other L1 < 4 h [ASSUMPTION]
 * (e.g. a "targeting a young person" report where nobody involved is under 18 on record); every other report < 24 h.
 *
 * REQ-ADM-05: an L0 item filed in India's Lantern Hour pages at once. So does one filed in the Lantern Hour of the
 * room's own region (its evening, when that room is busiest) — the safer reading; the 15-minute SLA stays India's
 * (PRD). Outside those windows the worker pages crisis items still open after 5 minutes, 24×7 (06c F9 "crisis items
 * unassigned 5 min"; src/admin/paging/paging.service.ts).
 */
export function slaFor(lane: Lane, reason: ReportReason, involvesMinor: boolean, now: Date, ctx: SlaContext = {}): Sla {
  const at = (minutes: number): Date => new Date(now.getTime() + minutes * MIN);
  switch (lane) {
    case 'crisis': {
      const start = ctx.lanternStart ?? DEFAULT_LANTERN_START;
      const end = ctx.lanternEnd ?? DEFAULT_LANTERN_END;
      const indiaLanternHour = isLanternHour('south_asia', now, start, end);
      const roomLanternHour = ctx.roomRegion ? isLanternHour(ctx.roomRegion, now, start, end) : false;
      return { dueAt: at(indiaLanternHour ? 15 : 60), pages: indiaLanternHour || roomLanternHour };
    }
    case 'minors_grooming': {
      const urgent = involvesMinor && SEXUAL_OR_GROOMING.has(reason);
      return { dueAt: at(urgent ? 120 : 240), pages: urgent };
    }
    default:
      return { dueAt: at(24 * 60), pages: false };
  }
}
