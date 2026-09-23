import { LANE_PRIORITY, type Lane } from '../safety/safety-types';

/**
 * Statutory clocks and work order for the console (pure; unit-tested in test/unit/admin.clocks.spec.ts).
 *
 * Grievances and orders: IT (Intermediary Guidelines) Rules, 2021 as amended on 20 Feb 2026, as summarised in PRD 19
 * "Grievances and deletion" (verified 23 Sep 2026; legal review still required [LEGAL]): acknowledge within 24 h,
 * resolve within 7 days; unlawful content 36 h; nudity / CSAM 2 h; non-consensual intimate imagery 2 h (both page the
 * Owner 24×7); court or government orders 3 h (Owner only, L0 priority, page 24×7).
 */
export const GRIEVANCE_CATEGORIES = ['general', 'unlawful_content', 'nudity_csam', 'ncii', 'data_request', 'moderation_appeal'] as const;
export type GrievanceCategory = (typeof GRIEVANCE_CATEGORIES)[number];

export const GRIEVANCE_ACK_HOURS = 24;
export const LEGAL_ORDER_HOURS = 3;

export const GRIEVANCE_RULES: Readonly<Record<GrievanceCategory, { resolveHours: number; pages: boolean; label: string }>> = {
  general: { resolveHours: 7 * 24, pages: false, label: 'Complaint about content or conduct' },
  unlawful_content: { resolveHours: 36, pages: false, label: 'Unlawful content' },
  nudity_csam: { resolveHours: 2, pages: true, label: 'Nudity, sexual content or child sexual abuse material' },
  ncii: { resolveHours: 2, pages: true, label: 'Intimate images shared without consent' },
  data_request: { resolveHours: 7 * 24, pages: false, label: 'My data or my account' },
  moderation_appeal: { resolveHours: 7 * 24, pages: false, label: 'Appeal a moderation decision' },
};

const HOUR = 3_600_000;

export interface GrievanceClock {
  ackDueAt: Date;
  resolveDueAt: Date;
  pages: boolean;
}

export function grievanceClock(category: GrievanceCategory, receivedAt: Date): GrievanceClock {
  const rule = GRIEVANCE_RULES[category];
  return {
    ackDueAt: new Date(receivedAt.getTime() + GRIEVANCE_ACK_HOURS * HOUR),
    resolveDueAt: new Date(receivedAt.getTime() + rule.resolveHours * HOUR),
    pages: rule.pages,
  };
}

export function legalOrderDueAt(receivedAt: Date): Date {
  return new Date(receivedAt.getTime() + LEGAL_ORDER_HOURS * HOUR);
}

/** The PRD's appeal route for grievance replies (IT Rules 2021, Rule 3A; [LEGAL] wording to be confirmed). */
export const GAC_APPEAL_TEXT =
  'If you are not satisfied with this decision, you may appeal to the Grievance Appellate Committee (GAC) within ' +
  '30 days of receiving it, at https://gac.gov.in (Information Technology (Intermediary Guidelines and Digital Media ' +
  'Ethics Code) Rules, 2021, Rule 3A).';

// ------------------------------------------------------------------------------------------------ work order
/**
 * The console's "Now" list merges moderation reports, grievances and legal orders. Priority first (PRD 19: legal
 * orders are an L0-priority ticket type; crisis is L0; minors & grooming L1 and the 2 h grievances with it; harassment
 * and unlawful-content grievances L2; spam / other and 7-day grievances L3), then the earliest deadline, then oldest.
 * So a new L0 item always sorts above every L1–L3 item (REQ-ADM-04).
 */
export type WorkKind = 'legal_order' | 'report' | 'grievance';

export interface WorkItem {
  kind: WorkKind;
  id: string;
  priority: number;
  dueAt: string;
  createdAt: string;
}

export function reportPriority(lane: Lane): number {
  return LANE_PRIORITY[lane];
}

export function grievancePriority(category: GrievanceCategory): number {
  if (GRIEVANCE_RULES[category].pages) return 1;
  if (category === 'unlawful_content') return 2;
  return 3;
}

export const LEGAL_ORDER_PRIORITY = 0;

export function compareWork(a: WorkItem, b: WorkItem): number {
  if (a.priority !== b.priority) return a.priority - b.priority;
  const due = Date.parse(a.dueAt) - Date.parse(b.dueAt);
  if (due !== 0) return due;
  const created = Date.parse(a.createdAt) - Date.parse(b.createdAt);
  if (created !== 0) return created;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

/** SLA state for display: minutes left (negative when overdue). */
export function minutesLeft(dueAt: Date | string, now: Date): number {
  return Math.floor(((typeof dueAt === 'string' ? Date.parse(dueAt) : dueAt.getTime()) - now.getTime()) / 60_000);
}
