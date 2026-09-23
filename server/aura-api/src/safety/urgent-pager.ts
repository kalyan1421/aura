/**
 * The fast path from a filed report to the Owner's phone (PRD 19 REQ-ADM-05 / REQ-ADM-13 / REQ-ADM-15). The safety
 * module only knows that a report must page (`pages`, src/safety/lanes.ts); the admin console's pager
 * (src/admin/paging/paging.service.ts, bound to this token in AdminCoreModule) raises the page and delivers its first
 * round in the background, within seconds. The pager worker's 30-second sweep is the safety net if this process dies
 * before it delivers. Never throws and never blocks the reporter's request.
 */
export const URGENT_PAGER = Symbol('URGENT_PAGER');

export interface UrgentPager {
  /** A committed report that must page now (idempotent: one page per report, ever). */
  reportFiled(reportId: string): void;
}
