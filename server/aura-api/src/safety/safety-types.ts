/**
 * F9 core safety vocabulary (PRD 06b "Report reasons", 06c F9, 19 admin console). Lanes, `involves_minor` and
 * sanction details are server/console-only — never returned to app clients (DS-10).
 */

/**
 * Report reasons, one tap (06b): the integer is the wire value. Codes never change meaning (older apps keep sending
 * 1–8); new reasons are appended.
 */
export const REPORT_REASONS = {
  1: 'in_danger',
  2: 'harassment',
  3: 'sexual',
  4: 'hate',
  5: 'contact_info',
  6: 'spam',
  7: 'under_13',
  8: 'other',
  9: 'targeting_minor',
} as const;
export type ReportReason = keyof typeof REPORT_REASONS;
export type ReportReasonKey = (typeof REPORT_REASONS)[ReportReason];

export const MAX_REPORT_REASON = 9;

export const isReportReason = (v: unknown): v is ReportReason =>
  typeof v === 'number' && Number.isInteger(v) && v >= 1 && v <= MAX_REPORT_REASON;

/** Crisis reports are never a violation: never a strike, never rate-limited, never auto-hidden. */
export const CRISIS_REASON: ReportReason = 1;
export const UNDER_13_REASON: ReportReason = 7;
/**
 * "Seems to be targeting a young person": a bystander's sense that someone is going after a young person. Minors &
 * grooming lane whatever the ages on record; the young person may be anyone in the room (see ReportsService).
 */
export const TARGETING_MINOR_REASON: ReportReason = 9;

export const LANES = ['crisis', 'minors_grooming', 'harassment', 'spam'] as const;
export type Lane = (typeof LANES)[number];

/** Queue order (L0 → L3): crisis > minors & grooming > harassment > spam/other. */
export const LANE_PRIORITY: Readonly<Record<Lane, number>> = { crisis: 0, minors_grooming: 1, harassment: 2, spam: 3 };

export const REPORT_TARGET_KINDS = ['member', 'gesture', 'room'] as const;
export type ReportTargetKind = (typeof REPORT_TARGET_KINDS)[number];

export const SANCTION_KINDS = [
  'warning',
  'gesture_shadow_mute',
  'shadow_mute',
  'room_suspension',
  'rooms_pause',
  'social_ban',
  'account_ban',
] as const;
export type SanctionKind = (typeof SANCTION_KINDS)[number];

/** Sanctions that take rooms away (403 on /v1/rooms*, refused on Realtime, hidden from other members). */
export const ROOM_ACCESS_SANCTIONS: readonly SanctionKind[] = ['room_suspension', 'rooms_pause', 'social_ban', 'account_ban'];
/** Sanctions that silently drop the account's gestures (never visible to them). */
export const SHADOW_SANCTIONS: readonly SanctionKind[] = ['gesture_shadow_mute', 'shadow_mute'];

/** SQL list literal for the room-access sanctions (constants only — safe to inline). */
export const ROOM_ACCESS_SANCTIONS_SQL = `('room_suspension','rooms_pause','social_ban','account_ban')`;
export const SHADOW_SANCTIONS_SQL = `('gesture_shadow_mute','shadow_mute')`;

/** A sanction is active when not lifted, started, and not ended. `s` = the sanctions alias. */
export const ACTIVE_SANCTION_SQL = (s: string): string =>
  `${s}.lifted_at is null and ${s}.starts_at <= now() and (${s}.ends_at is null or ${s}.ends_at > now())`;

/**
 * Accounts hidden from other members (members lists, "here now", gesture targets): a pending account deletion
 * (deactivated during the grace period) or an active room-access sanction. `col` = an account id expression.
 */
export const HIDDEN_ACCOUNT_SQL = (col: string): string =>
  `(exists (select 1 from public.account_deletions hd where hd.user_id = ${col})
    or exists (select 1 from public.sanctions hs where hs.user_id = ${col}
                and hs.kind in ${ROOM_ACCESS_SANCTIONS_SQL} and ${ACTIVE_SANCTION_SQL('hs')}))`;
