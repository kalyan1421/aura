/**
 * F6 reflections in the console: the `/admin/reflections*` shapes (contracts/api/v1-reflections.md §4) and pure
 * helpers (labels, score formatting, decision-form validation). No Next.js imports: unit-tested with node:test.
 * Reflection text is only ever rendered, never logged.
 */
import { LANE_LABEL } from './format.ts';
import type { Lane } from './types';

export type AdminStatus = 'pending' | 'published' | 'held' | 'rejected' | 'crisis_diverted' | 'removed' | 'deleted' | 'expired';
export type HoldReason =
  | 'uncertain'
  | 'strict_threshold'
  | 'overnight'
  | 'provider_unavailable'
  | 'timeout'
  | 'hold_all'
  | 'active_strike'
  | 'sanction'
  | 'near_duplicate'
  | 'reported';
export type RejectReason = 'contact_details' | 'link' | 'personal_questions' | 'hurtful' | 'sexual' | 'other';
export type LanguagePool = 'en' | 'te' | 'hi';
export type ReflectionDecision = 'approve' | 'remove' | 'escalate';
export type EscalationLane = 'minors_grooming' | 'crisis';

export interface ReviewItem {
  reflectionId: string;
  status: AdminStatus;
  /** Published but hidden by the report threshold (waits for a human). */
  hidden: boolean;
  holdReason: HoldReason | null;
  rejectReason: RejectReason | null;
  /** Decrypted by NestJS; null once scrubbed (deleted / expired). */
  text: string | null;
  charCount: number;
  languagePool: LanguagePool;
  /** Stricter thresholds applied (under-18 involved, or the te / hi pool). */
  strict: boolean;
  /** Decided inside the overnight window. */
  overnight: boolean;
  /** The console's "Under 18" flag — never a DOB. */
  involvesMinor: boolean;
  createdAt: string;
  decidedAt: string | null;
  decidedBy: string | null;
  room: { roomId: string; quadrant: string; tzRegion: string; state: string } | null;
  /** The most urgent OPEN report on it. */
  report: {
    reportId: string;
    lane: Lane;
    reasonKey: string;
    source: 'user' | 'auto';
    autoSignal: string | null;
    slaDueAt: string;
    pages: boolean;
    overdue: boolean;
  } | null;
}

export interface ReviewView extends ReviewItem {
  scores: Record<string, number> | null;
  ruleHits: string[];
  stage: 'rules' | 'provider' | 'human' | 'author' | 'system' | null;
  publishedAt: string | null;
  removedAt: string | null;
  hiddenAt: string | null;
  gestureCount: number;
  /** US-42: the support sheet opened for the author (a crisis diversion). */
  supportShown?: boolean;
  author: {
    pseudonym: string;
    hash: string | null;
    accountAgeDays: number | null;
    under18: boolean;
    activeStrikes: number;
    strikes: Array<{ strikeId: string; reasonCode: string; createdAt: string; expiresAt: string; active: boolean }>;
    sanctions: Array<{ sanctionId: string; kind: string; reasonCode: string; source: string; startsAt: string; endsAt: string | null; active: boolean }>;
    /** US-42 "the author's recent flags": other reports about the same account. */
    otherReports?: Array<{ reportId: string; lane: Lane; reasonKey: string; status: string; createdAt: string }>;
  };
  roomContext: {
    roomId: string;
    quadrant: string;
    languagePool: string;
    tzRegion: string;
    ageHours: number;
    state: string;
    memoryAt: string;
    purgeAt: string;
    others: Array<{ reflectionId: string; pseudonym: string; text: string | null; publishedAt: string }>;
  } | null;
  reports: Array<{
    reportId: string;
    lane: Lane;
    reasonKey: string;
    source: 'user' | 'auto';
    autoSignal: string | null;
    status: 'open' | 'actioned' | 'dismissed';
    createdAt: string;
    slaDueAt: string;
    pages: boolean;
  }>;
  audit: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null }>;
  /** For this staff member and this item. */
  allowedDecisions: ReflectionDecision[];
  /** An open, non-crisis report exists. */
  canStrike: boolean;
}

export interface PoolState {
  pool: LanguagePool;
  paused: boolean;
  held: number;
}

export interface ReflectionList {
  items: ReviewItem[];
  pools: PoolState[];
}

export interface DecisionResult {
  reflectionId: string;
  previousStatus: AdminStatus;
  status: AdminStatus;
  hidden: boolean;
  reportsResolved: number;
  sanctionsLifted: number;
  strike: { activeStrikes: number | null; autoBan: boolean } | null;
  escalated: { reportId: string; lane: Lane; pages: boolean } | null;
}

export interface DecisionBody {
  decision: ReflectionDecision;
  reasonCode: string;
  strike?: true;
  rejectReason?: RejectReason;
  lane?: EscalationLane;
}

// ---------------------------------------------------------------- labels

export const STATUS_TABS = ['held', 'pending', 'published', 'rejected', 'crisis_diverted', 'removed', 'all'] as const;
export type StatusTab = (typeof STATUS_TABS)[number];

/** The list's status tab from `?status=`; anything unknown → `held` (the review queue). */
export function statusTab(v: unknown): StatusTab {
  return typeof v === 'string' && (STATUS_TABS as readonly string[]).includes(v) ? (v as StatusTab) : 'held';
}

export const STATUS_LABEL: Record<string, string> = {
  pending: 'Pending (still checking)',
  published: 'Published',
  held: 'Held for review',
  rejected: 'Rejected',
  crisis_diverted: 'Crisis-diverted',
  removed: 'Removed',
  deleted: 'Deleted by the author',
  expired: 'Expired (room became a memory)',
  all: 'All',
};

/** Short tab labels. */
export const STATUS_TAB_LABEL: Record<StatusTab, string> = {
  held: 'Held',
  pending: 'Pending',
  published: 'Published',
  rejected: 'Rejected',
  crisis_diverted: 'Crisis',
  removed: 'Removed',
  all: 'All',
};

export const HOLD_REASON_LABEL: Record<string, string> = {
  uncertain: 'Uncertain score',
  strict_threshold: 'Stricter threshold (under 18 or te / hi pool)',
  overnight: 'Overnight (waits for the morning)',
  provider_unavailable: 'Moderation provider unavailable',
  timeout: 'Moderation timed out',
  hold_all: 'Hold-all is on',
  active_strike: 'Author has an active strike',
  sanction: 'Author has a sanction',
  near_duplicate: 'Same text in several rooms',
  reported: 'Hidden by reports',
};

export const REJECT_REASON_LABEL: Record<RejectReason, string> = {
  contact_details: 'Contact details',
  link: 'Link',
  personal_questions: 'Personal questions',
  hurtful: 'Hurtful',
  sexual: 'Sexual',
  other: 'Other',
};
export const REJECT_REASONS = Object.keys(REJECT_REASON_LABEL) as RejectReason[];

export const POOL_LABEL: Record<string, string> = {
  en: 'English',
  te: 'Telugu + Tenglish',
  hi: 'Hindi + Hinglish',
};
export const POOLS: LanguagePool[] = ['en', 'te', 'hi'];

export const ESCALATION_LANES: EscalationLane[] = ['minors_grooming', 'crisis'];

export const STAGE_LABEL: Record<string, string> = {
  rules: 'Rules',
  provider: 'Omni-moderation',
  human: 'A moderator',
  author: 'The author',
  system: 'The system',
};

/** Reason codes offered on the decision form (plus "custom…"). */
export const REFLECTION_REASON_CODES = [
  'no_violation',
  'false_positive',
  'crisis_support',
  'contact_details',
  'link',
  'personal_questions',
  'harassment',
  'hate',
  'sexual',
  'grooming',
  'minor_sexual_content',
  'spam',
  'other',
];

/** A sensible default reason code for the item (the reviewer can change it). */
export function defaultReasonCode(v: Pick<ReviewItem, 'status' | 'rejectReason'>): string {
  if (v.status === 'crisis_diverted') return 'crisis_support';
  if (v.rejectReason === 'contact_details' || v.rejectReason === 'link' || v.rejectReason === 'personal_questions') return v.rejectReason;
  if (v.rejectReason === 'hurtful') return 'harassment';
  if (v.rejectReason === 'sexual') return 'sexual';
  return 'no_violation';
}

// ---------------------------------------------------------------- crisis

/**
 * Crisis-flagged (US-42): crisis-diverted, a crisis-lexicon hit, or a crisis-lane report on it. These get the
 * playbook, the "keep unpublished / release as false positive / escalate" wording, and never a strike.
 */
export function isCrisis(v: Pick<ReviewView, 'status' | 'ruleHits' | 'reports'>): boolean {
  return (
    v.status === 'crisis_diverted' ||
    v.ruleHits.includes('crisis_lexicon') ||
    v.reports.some((r) => r.lane === 'crisis' || r.autoSignal === 'reflection_crisis')
  );
}

/**
 * Whether the F9 support sheet opened on the author's phone: crisis-diverted items, crisis-lexicon hits and automatic
 * crisis signals (a person's "in danger" report on a published reflection does not open it for the author).
 */
export function supportSheetShown(v: Pick<ReviewView, 'status' | 'ruleHits' | 'reports' | 'supportShown'>): boolean {
  if (v.supportShown !== undefined) return v.supportShown;
  return v.status === 'crisis_diverted' || v.ruleHits.includes('crisis_lexicon') || v.reports.some((r) => r.autoSignal === 'reflection_crisis');
}

/** The decision's wording for this item (crisis items use the US-42 words; removing a published one takes it down). */
export function decisionLabel(d: ReflectionDecision, v: { status: AdminStatus; crisis: boolean }): string {
  const published = v.status === 'published';
  if (d === 'approve') {
    if (v.crisis) return published ? 'Keep published (a false alarm)' : 'Release as a false positive';
    return published ? 'Approve (keep published)' : 'Approve and publish';
  }
  if (d === 'remove') return published ? 'Take down' : v.crisis ? 'Keep unpublished' : 'Reject';
  return 'Escalate';
}

// ---------------------------------------------------------------- scores

/** Scores at or above this are highlighted (the reviewer's eye goes there first). */
export const SCORE_HIGHLIGHT = 0.4;

/** "0.62", "0.05", "<0.01" (never exponent notation). */
export function formatScore(n: number): string {
  if (!Number.isFinite(n)) return '—';
  if (n > 0 && n < 0.01) return '<0.01';
  return n.toFixed(2);
}

/** Category scores, highest first, each flagged when ≥ the highlight threshold. */
export function scoreRows(
  scores: Record<string, number> | null | undefined,
  threshold = SCORE_HIGHLIGHT,
): Array<{ category: string; score: number; text: string; high: boolean }> {
  if (!scores) return [];
  return Object.entries(scores)
    .filter(([, s]) => typeof s === 'number' && Number.isFinite(s))
    .sort(([a, x], [b, y]) => y - x || a.localeCompare(b))
    .map(([category, score]) => ({ category, score, text: formatScore(score), high: score >= threshold }));
}

// ---------------------------------------------------------------- forms

export const REASON_CODE = /^[a-z0-9_]{1,40}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isUuid = (v: string): boolean => UUID.test(v);
export const isPool = (v: string): v is LanguagePool => (POOLS as string[]).includes(v);

/** What the decision form reads (FormData satisfies it). */
export interface FormLike {
  get(name: string): unknown;
}

function text(fd: FormLike, name: string): string {
  const v = fd.get(name);
  return typeof v === 'string' ? v.trim() : '';
}

/** A reason code from a select with a "custom…" option and a free-text field. */
export function reasonCodeFrom(fd: FormLike): string {
  const picked = text(fd, 'reasonCode');
  return picked === 'custom' ? text(fd, 'customReason') : picked;
}

/**
 * The decision form → the API body, or a message for the reviewer. `ctx` is what the review view allowed; NestJS
 * checks all of it again (roles, item state, crisis never strikes).
 */
export function decisionBody(
  fd: FormLike,
  ctx: { allowed: readonly ReflectionDecision[]; canStrike: boolean; crisis: boolean },
): { ok: true; body: DecisionBody } | { ok: false; message: string } {
  const decision = text(fd, 'decision') as ReflectionDecision;
  if (!ctx.allowed.includes(decision)) return { ok: false, message: 'Choose a decision.' };
  const reasonCode = reasonCodeFrom(fd);
  if (!REASON_CODE.test(reasonCode)) return { ok: false, message: 'Choose a reason code (lowercase letters, digits and _ only, up to 40).' };
  const body: DecisionBody = { decision, reasonCode };
  const strike = text(fd, 'strike') === 'yes';
  if (strike && decision !== 'remove') return { ok: false, message: 'A strike can only go with removing the reflection.' };
  if (decision === 'remove') {
    if (strike) {
      if (ctx.crisis) return { ok: false, message: 'A crisis-flagged reflection never adds a strike.' };
      if (!ctx.canStrike) return { ok: false, message: 'A strike needs an open report on this reflection.' };
      body.strike = true;
    }
    const rr = text(fd, 'rejectReason');
    if (rr) {
      if (!(REJECT_REASONS as string[]).includes(rr)) return { ok: false, message: 'Choose a reason the author will see.' };
      body.rejectReason = rr as RejectReason;
    }
  }
  if (decision === 'escalate') {
    const lane = text(fd, 'lane');
    if (!(ESCALATION_LANES as string[]).includes(lane)) return { ok: false, message: 'Choose the lane to escalate to.' };
    body.lane = lane as EscalationLane;
  }
  return { ok: true, body };
}

const plural = (n: number, one: string, many = `${one}s`): string => `${n} ${n === 1 ? one : many}`;

/** The decision's outcome in one line for the form's status region. */
export function decisionResultText(r: DecisionResult): string {
  const from = STATUS_LABEL[r.previousStatus] ?? r.previousStatus;
  const to = STATUS_LABEL[r.status] ?? r.status;
  const parts = [r.previousStatus === r.status ? `Status stays ${to.toLowerCase()}.` : `${from} → ${to.toLowerCase()}.`];
  if (r.hidden) parts.push('Still hidden by reports.');
  if (r.reportsResolved) parts.push(`${plural(r.reportsResolved, 'report')} closed.`);
  if (r.sanctionsLifted) parts.push(`${plural(r.sanctionsLifted, 'automatic sanction')} lifted.`);
  if (r.strike) {
    if (r.strike.autoBan) parts.push('Strike recorded: 4th active strike, the account is now banned from rooms (automatic).');
    else parts.push(`Strike recorded${r.strike.activeStrikes === null ? '' : ` (${r.strike.activeStrikes} active)`}.`);
  }
  if (r.escalated) parts.push(`Report moved to ${LANE_LABEL[r.escalated.lane] ?? r.escalated.lane}${r.escalated.pages ? '; the Owner is paged' : ''}.`);
  return parts.join(' ');
}

/** The list URL for a tab. */
export function listHref(tab: StatusTab): string {
  return tab === 'held' ? '/reflections' : `/reflections?status=${tab}`;
}
