/**
 * Tonight's intention list in the console (PRD 19 "the Tonight's intention list per language"): the
 * `/admin/intentions*` shapes (contracts/api/v1-rooms.md §1.10) and pure helpers (labels, form parsing). No Next.js
 * imports: unit-tested with node:test.
 */
export const INTENTION_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type IntentionLocale = (typeof INTENTION_LOCALES)[number];
export type IntentionTexts = Record<IntentionLocale, string>;

export const INTENTION_POOLS = ['en', 'te', 'hi'] as const;
export type IntentionPool = (typeof INTENTION_POOLS)[number];

export interface IntentionPreset {
  pool: IntentionPool;
  key: string;
  position: number;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
  /** Rooms showing it for a night that started in the last 24 h (a room count, never who). */
  inUseTonight: number;
}

export interface IntentionWords {
  key: string;
  texts: IntentionTexts;
  updatedAt: string;
  pools: IntentionPool[];
}

export interface IntentionsOverview {
  locales: IntentionLocale[];
  maxChars: number;
  previewTimezone: string;
  pools: Array<{ pool: IntentionPool; presets: IntentionPreset[]; rotation: Array<{ date: string; key: string | null }> }>;
  words: IntentionWords[];
  /** Latest changes, newest first (the audit log; `actor` is the staff member's display name). */
  history: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null; detail: Record<string, unknown> }>;
}

export const POOL_LABEL: Record<IntentionPool, string> = {
  en: 'English pool',
  te: 'Telugu + Tenglish pool',
  hi: 'Hindi + Hinglish pool',
};

export const LOCALE_LABEL: Record<IntentionLocale, string> = {
  en: 'English',
  te: 'Telugu (తెలుగు)',
  'te-Latn': 'Tenglish',
  hi: 'Hindi (हिन्दी)',
  'hi-Latn': 'Hinglish',
};

/** Form field name for one language's line (`text_te-Latn` is a valid FormData name). */
export const textField = (l: IntentionLocale): string => `text_${l}`;

export const INTENTION_ACTION_LABEL: Record<string, string> = {
  intention_preset_add: 'Added to a pool',
  intention_words_edit: 'Reworded',
  intention_preset_retire: 'Retired',
  intention_preset_restore: 'Back in rotation',
  intention_preset_move: 'Moved',
};

/** One history line's subject, e.g. `sleep_before_midnight · en` or `phone_down_10 (te, hi)`. */
export function historySubject(detail: Record<string, unknown>): string {
  const key = typeof detail.key === 'string' ? detail.key : '?';
  if (typeof detail.pool === 'string') return `${key} · ${detail.pool}`;
  if (Array.isArray(detail.changed)) return `${key} (${detail.changed.join(', ') || 'no change'})`;
  return key;
}

export const KEY_RE = /^[a-z][a-z0-9_]{1,47}$/;
export const REASON_RE = /^[a-z0-9_]{1,40}$/;

export const isPool = (v: string): v is IntentionPool => (INTENTION_POOLS as readonly string[]).includes(v);

type Get = (name: string) => string;

/** The five lines from a form, trimmed; `null` when every one is empty (reuse the key's words). */
export function textsFrom(get: Get): { texts: IntentionTexts | null; missing: IntentionLocale[] } {
  const entries = INTENTION_LOCALES.map((l) => [l, get(textField(l)).trim()] as const);
  const filled = entries.filter(([, v]) => v !== '');
  if (filled.length === 0) return { texts: null, missing: [] };
  const missing = entries.filter(([, v]) => v === '').map(([l]) => l);
  return { texts: Object.fromEntries(entries) as IntentionTexts, missing };
}

/** "Add a preset" form → request body, or the problem to show. */
export function addBodyFrom(get: Get): { ok: true; body: Record<string, unknown> } | { ok: false; message: string } {
  const pool = get('pool');
  const key = get('key').trim();
  const reasonCode = get('reasonCode').trim();
  if (!isPool(pool)) return { ok: false, message: 'Pick a pool.' };
  if (!KEY_RE.test(key)) return { ok: false, message: 'The key is a–z, 0–9 and _, starting with a letter (2–48 characters).' };
  if (!REASON_RE.test(reasonCode)) return { ok: false, message: 'Give a reason code (a–z, 0–9, _).' };
  const { texts, missing } = textsFrom(get);
  if (texts && missing.length) return { ok: false, message: `Every language needs its line (missing: ${missing.join(', ')}).` };
  const body: Record<string, unknown> = { pool, key, reasonCode, enabled: get('enabled') === 'yes' };
  if (texts) body.texts = texts;
  const position = get('position').trim();
  if (position) {
    const n = Number(position);
    if (!Number.isInteger(n) || n < 0 || n > 100_000) return { ok: false, message: 'Position is a whole number from 0 to 100000.' };
    body.position = n;
  }
  return { ok: true, body };
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/** "Thu 24 Sep" for a YYYY-MM-DD night (fixed English labels: the same on every server's ICU). */
export function nightLabel(date: string): string {
  const d = new Date(`${date}T12:00:00Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(d.getTime())) return date;
  return `${WEEKDAYS[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()]}`;
}
