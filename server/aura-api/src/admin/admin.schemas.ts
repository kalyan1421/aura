import { z } from 'zod';
import { parseOrThrow } from '../common/zod';
import { LANES } from '../safety/safety-types';
import { STAFF_ROLES } from './admin-types';
import { GRIEVANCE_CATEGORIES } from './clocks';

/** Request bodies of the console routes and the two public intakes (validated; errors never echo input). */
export const reasonCode = z.string().regex(/^[a-z0-9_]{1,40}$/, 'must be a reason code ([a-z0-9_], at most 40)');
const text = (min: number, max: number) => z.string().trim().min(min).max(max);
const optionalText = (max: number) =>
  z.preprocess((v) => (typeof v === 'string' && v.trim() === '' ? undefined : v), z.string().trim().max(max).optional());
const pastInstant = z.iso
  .datetime({ offset: true })
  .refine((v) => Date.parse(v) <= Date.now() + 5 * 60_000, 'cannot be in the future');

export const MODERATION_ACTIONS = ['dismiss', 'warn', 'strike', 'shadow_mute', 'suspend', 'pause', 'ban'] as const;

export const queueQuerySchema = z.object({
  lane: z.enum(LANES).optional(),
  limit: z.coerce.number().int().min(1).max(500).optional(),
});

export const actionSchema = z.object({
  action: z.enum(MODERATION_ACTIONS),
  reasonCode,
  hours: z.number().int().min(1).max(720).optional(),
});

export const liftSchema = z.object({ reasonCode });

/** Manual items of the minors & grooming SOP checklist (the rest are computed). The SOP itself is the lawyer's (A3). */
export const MANUAL_CHECKLIST_ITEMS = [
  'pocso_report_prepared',
  'ncrp_report_prepared',
  'ncmec_assessed',
  'counsel_consulted',
  'no_tipping_off_confirmed',
] as const;
export type ManualChecklistItem = (typeof MANUAL_CHECKLIST_ITEMS)[number];

export const checklistSchema = z.object({ item: z.enum(MANUAL_CHECKLIST_ITEMS), done: z.boolean() });

export const recordReportSchema = z.union([
  z.object({ reportedTo: text(2, 200), reportRef: text(1, 200) }).strict(),
  z.object({ legalReason: text(10, 2000) }).strict(),
]);

export const EXPORT_PURPOSES = ['mandatory_report', 'law_enforcement_request', 'court_order', 'counsel_review'] as const;
export const exportSchema = z.object({ purpose: z.enum(EXPORT_PURPOSES) });

export const LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;

export const publicGrievanceSchema = z.object({
  category: z.enum(GRIEVANCE_CATEGORIES),
  email: z.email().max(254),
  name: optionalText(120),
  description: text(10, 5000),
  contentLocation: optionalText(1000),
  locale: z.enum(LOCALES).optional(),
  channel: z.enum(['web_form', 'in_app']).optional(),
  /** Honeypot: people never see it, so it must stay empty. */
  website: z.string().max(0).optional(),
});

export const staffGrievanceSchema = z.object({
  category: z.enum(GRIEVANCE_CATEGORIES),
  email: z.email().max(254),
  name: optionalText(120),
  description: text(10, 5000),
  contentLocation: optionalText(1000),
  locale: z.enum(LOCALES).optional(),
  channel: z.enum(['email', 'post', 'other']),
  receivedAt: pastInstant,
  sendAcknowledgement: z.boolean().optional(),
});

export const GRIEVANCE_OUTCOMES = ['action_taken', 'no_action', 'referred', 'duplicate', 'withdrawn'] as const;
export const resolveGrievanceSchema = z.object({ outcome: z.enum(GRIEVANCE_OUTCOMES), reply: text(10, 5000) });

export const grievanceListSchema = z.object({ status: z.enum(['open', 'acknowledged', 'resolved', 'active', 'all']).optional() });

export const legalOrderSchema = z.object({
  source: z.enum(['court', 'government', 'law_enforcement', 'other']),
  authority: text(2, 200),
  reference: optionalText(200),
  receivedAt: pastInstant.optional(),
  summary: text(3, 5000),
  targets: optionalText(5000),
  isTest: z.boolean().optional(),
});

export const closeLegalOrderSchema = z.object({ status: z.enum(['actioned', 'rejected']), note: text(3, 5000) });

export const flagSchema = z.object({ enabled: z.boolean(), reasonCode });

export const auditQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(500).optional(),
  beforeId: z.coerce.number().int().min(1).optional(),
});

export const sanctionsQuerySchema = z.object({
  active: z.enum(['true', 'false']).optional(),
  subject: z.string().regex(/^[0-9a-f]{8,64}$/).optional(),
});

export const pagesQuerySchema = z.object({ status: z.enum(['open', 'acknowledged', 'resolved', 'expired', 'all']).optional() });

// ------------------------------------------------------------------------------------------------ staff editor
export const staffAddSchema = z.object({
  email: z.email().max(254),
  role: z.enum(STAFF_ROLES),
  displayName: text(1, 60),
});

export const staffUpdateSchema = z
  .object({ role: z.enum(STAFF_ROLES).optional(), displayName: text(1, 60).optional(), disabled: z.boolean().optional() })
  .refine((v) => v.role !== undefined || v.displayName !== undefined || v.disabled !== undefined, 'nothing to change');

// ------------------------------------------------------------------------------------------------ deletion cases (REQ-ADM-11)
export const DELETION_CHANNELS = ['email', 'grievance', 'post', 'other'] as const;
export const deletionCaseSchema = z.object({
  /** The address the requester says the account signs in with. The link only ever goes to the address ON the account. */
  email: z.email().max(254),
  channel: z.enum(DELETION_CHANNELS),
  receivedAt: pastInstant,
  grievanceId: z.uuid().optional(),
});

/** Immediate deletion skips the 7-day grace, so it needs one of these audited reasons (PRD F8 / 19 SOP step 5). */
export const IMMEDIATE_DELETION_REASONS = ['under_13_confirmed', 'requester_asked_immediate', 'legal_requirement'] as const;
export const deletionScheduleSchema = z.discriminatedUnion('mode', [
  z.object({ mode: z.literal('grace') }),
  z.object({ mode: z.literal('immediate'), reasonCode: z.enum(IMMEDIATE_DELETION_REASONS) }),
]);

export const DELETION_CLOSE_OUTCOMES = ['withdrawn', 'unverified', 'duplicate', 'declined_by_holder', 'restored_by_holder', 'other'] as const;
export const deletionCloseSchema = z.object({ outcome: z.enum(DELETION_CLOSE_OUTCOMES) });
export const deletionListSchema = z.object({ status: z.enum(['open', 'closed', 'all']).optional() });

export const parse = parseOrThrow;
