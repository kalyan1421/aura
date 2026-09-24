/**
 * Display helpers shared by server and client components (pure; unit-tested with node:test).
 * Times are shown in IST, the Owner's clock; every timestamp also carries its ISO value in a <time> element.
 */
const IST = new Intl.DateTimeFormat('en-IN', {
  timeZone: 'Asia/Kolkata',
  day: 'numeric',
  month: 'short',
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});
const IST_DATE = new Intl.DateTimeFormat('en-IN', { timeZone: 'Asia/Kolkata', day: 'numeric', month: 'short', year: 'numeric' });

export function ist(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : `${IST.format(d)} IST`;
}

export function istDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : IST_DATE.format(d);
}

/** "45 min", "2 h 5 min", "3 d 4 h". */
export function durationText(totalMinutes: number): string {
  const m = Math.max(0, Math.floor(Math.abs(totalMinutes)));
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  if (h < 48) return m % 60 ? `${h} h ${m % 60} min` : `${h} h`;
  const d = Math.floor(h / 24);
  return h % 24 ? `${d} d ${h % 24} h` : `${d} d`;
}

export type SlaState = 'closed' | 'overdue' | 'soon' | 'ok';

/** SLA wording and state for a deadline: "1 h 5 min left", "overdue by 12 min". */
export function slaText(dueAt: string, nowMs: number, closed = false): { text: string; state: SlaState } {
  if (closed) return { text: 'closed', state: 'closed' };
  const mins = Math.floor((Date.parse(dueAt) - nowMs) / 60_000);
  if (mins < 0) return { text: `overdue by ${durationText(-mins)}`, state: 'overdue' };
  return { text: `${durationText(mins)} left`, state: mins < 60 ? 'soon' : 'ok' };
}

export function shortHash(h: string | null | undefined): string {
  return h ? h.slice(0, 12) : '—';
}

export const LANE_LABEL: Record<string, string> = {
  crisis: 'L0 Crisis',
  minors_grooming: 'L1 Minors & grooming',
  harassment: 'L2 Harassment',
  spam: 'L3 Spam / other',
};

export const REASON_LABEL: Record<string, string> = {
  in_danger: 'In danger / self-harm',
  harassment: 'Harassment',
  sexual: 'Sexual content or advances',
  hate: 'Hate',
  contact_info: 'Contact or personal info',
  spam: 'Spam or selling',
  under_13: 'May be under 13',
  targeting_minor: 'Targeting a young person',
  other: 'Other',
};

export const ACTION_LABEL: Record<string, string> = {
  dismiss: 'Dismiss (no violation)',
  warn: 'Warn',
  strike: 'Strike (ladder)',
  shadow_mute: 'Shadow-mute',
  suspend: 'Suspend rooms',
  pause: 'Pause rooms (pending review)',
  ban: 'Ban account',
};

export const SANCTION_LABEL: Record<string, string> = {
  warning: 'Warning',
  gesture_shadow_mute: 'Gesture shadow-mute (auto)',
  shadow_mute: 'Shadow-mute',
  room_suspension: 'Room suspension',
  rooms_pause: 'Rooms paused',
  social_ban: 'Social ban (4th strike)',
  account_ban: 'Account ban',
};

export const GRIEVANCE_LABEL: Record<string, string> = {
  general: 'Content or conduct',
  unlawful_content: 'Unlawful content (36 h)',
  nudity_csam: 'Nudity / CSAM (2 h)',
  ncii: 'Intimate images without consent (2 h)',
  data_request: 'Data or account',
  moderation_appeal: 'Moderation appeal',
};

export const DELETION_STATUS_LABEL: Record<string, string> = {
  awaiting_verification: 'Waiting for the account holder',
  verified: 'Confirmed by the account holder',
  declined: 'Declined by the account holder',
  deletion_scheduled: 'Deletion started',
  completed: 'Deleted',
  closed: 'Closed',
  no_account: 'No app account for that email',
  staff_account: 'Staff account (refused)',
};

export const CLOSE_OUTCOME_LABEL: Record<string, string> = {
  withdrawn: 'Withdrawn by the requester',
  unverified: 'Never confirmed',
  duplicate: 'Duplicate request',
  declined_by_holder: '“This wasn’t me”',
  restored_by_holder: 'Account holder kept the account',
  no_account: 'No app account',
  staff_account: 'Staff account',
  account_gone: 'Account already deleted',
  other: 'Other',
};

export const IMMEDIATE_REASON_LABEL: Record<string, string> = {
  requester_asked_immediate: 'The account holder asked for deletion without the 7-day grace period',
  under_13_confirmed: 'Under 13 confirmed (delete without the grace period)',
  legal_requirement: 'A legal requirement',
};

export const ROLE_LABEL: Record<string, string> = { owner: 'Owner', moderator: 'Moderator', analyst: 'Read-only analyst' };

/** "1 h 20 min left in this queue session" / "Queue session limit reached — back at 9:40 pm IST". */
export function queueSessionText(q: { active: boolean; capped: boolean; minutesLeft: number; breakUntil: string | null } | null | undefined): string | null {
  if (!q || !q.active) return null;
  if (q.capped) return `Queue session limit reached — non-urgent items open again at ${ist(q.breakUntil)}`;
  return `${durationText(q.minutesLeft)} left in this queue session`;
}

export const PAGE_KIND_LABEL: Record<string, string> = {
  legal_order: 'Legal order',
  grievance: 'Grievance',
  report: 'Report',
  test: 'Test page',
};

export function label(map: Record<string, string>, key: string | null | undefined): string {
  if (!key) return '—';
  return map[key] ?? key.replace(/_/g, ' ');
}

/** "Test on samples" verdicts of the crisis lexicon (what the app would do with that text). */
export const VERDICT_LABEL: Record<string, string> = {
  crisis: 'crisis — the full support sheet',
  soft: 'soft — the “Help is here” card',
  none: 'none — nothing shown',
};

export const LEXICON_ACTION_LABEL: Record<string, string> = {
  lexicon_upload: 'Stored',
  lexicon_publish: 'Published',
  lexicon_rollback: 'Rolled back',
};

export const HELPLINES_ACTION_LABEL: Record<string, string> = {
  helplines_upload: 'Stored',
  helplines_publish: 'Published',
  helplines_rollback: 'Rolled back',
};

/**
 * A refusal's `details` as short lines for a form (lexicon problems, failed vectors). Strings stay as they are;
 * objects become `key: value` pairs; at most `max` lines.
 */
export function refusalLines(details: unknown, max = 30): string[] {
  if (!Array.isArray(details)) return [];
  const lines = details.slice(0, max).map((d) => {
    if (typeof d === 'string') return d;
    if (d && typeof d === 'object') {
      return Object.entries(d as Record<string, unknown>)
        .filter(([, v]) => v !== undefined && v !== null && v !== '')
        .map(([k, v]) => `${k}: ${typeof v === 'object' ? JSON.stringify(v) : String(v)}`)
        .join(' · ');
    }
    return String(d);
  });
  if (details.length > max) lines.push(`…and ${details.length - max} more`);
  return lines;
}
