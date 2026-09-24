import { COPY_KEYS, copyTableFor, PUSH_LOCALES, type PushLocale } from './push-copy';

/**
 * REQ-NTF-01 copy lint: no push template, in any of the five languages, may name a mood, a quadrant or a room theme
 * ("Rain Sanctuary" reveals the quadrant), or use guilt / loss / streak / urgency words (miss, lose, streak, broken,
 * fading, last chance, hurry — and their Telugu, Tenglish, Hindi and Hinglish equivalents). Pure: the CI gate is
 * test/unit/notifications.copy-lint.spec.ts (`pnpm lint`, `pnpm lint:copy`, `pnpm test`), which feeds it the mood
 * catalogue from contracts/moods.json, the server's push catalogue (push-copy.ts) and the app's notification strings
 * (ARB keys starting with `notif`).
 */
export type LintLocale = PushLocale;
export type LintReason = 'banned_word' | 'mood_name' | 'quadrant_name' | 'theme_name' | 'health_claim';

export interface LintTerm {
  /** What is reported (the term as written in the list). */
  label: string;
  reason: LintReason;
  test: (text: string) => boolean;
}

export interface TemplateSource {
  /** Where the template lives, e.g. `server:push-copy` or `app:app_te.arb`. */
  source: string;
  locale: LintLocale;
  key: string;
  text: string;
}

export interface CopyViolation {
  source: string;
  locale: LintLocale;
  key: string;
  term: string;
  reason: LintReason;
}

/**
 * Banned words by language. Latin-script entries match whole words (case-insensitive; a trailing `*` also matches
 * longer words, e.g. `kolpo*` → kolpoyaru); Telugu and Devanagari entries match anywhere (no reliable word
 * boundaries around combining marks), so they are stems. te / hi entries beyond the PRD's English list are drafts.
 */
export const BANNED_WORDS: Readonly<Record<LintLocale, readonly string[]>> = {
  en: [
    'miss', 'misses', 'missed', 'missing', 'lose', 'loses', 'losing', 'lost', 'loss', 'streak*', 'broken', 'break your',
    'fading', 'fade', 'fades', 'faded', 'last chance', 'hurry', 'hurried', 'hurrying',
  ],
  te: ['మిస్', 'కోల్పో', 'పోగొట్ట', 'స్ట్రీక్', 'విరిగి', 'తెగిపో', 'మసకబా', 'వాడిపో', 'చివరి అవకాశ', 'త్వరపడ', 'తొందర'],
  'te-Latn': [
    'kolpo*', 'pogott*', 'streak*', 'virigi*', 'tegipo*', 'masakabaa*', 'vaadipo*', 'chivari avakaasham', 'chivari chance',
    'tvarapad*', 'twarapad*', 'tondara*',
  ],
  hi: [
    'मिस', 'खो दे', 'खो दो', 'खोना', 'खो जा', 'स्ट्रीक', 'टूट', 'फीका', 'आखिरी मौका', 'आख़िरी मौका', 'जल्दी',
    // Milestone B (drafts): "missed" (छूट गया), "lose / waste" (गँवा), "hurry" (फटाफट).
    'छूट ग', 'गँवा', 'गंवा', 'फटाफट',
  ],
  'hi-Latn': [
    'kho do', 'kho doge', 'kho denge', 'khona', 'kho ja*', 'toot*', 'tut gaya', 'pheeka', 'feeka', 'aakhri mauka',
    'akhri mauka', 'jaldi', 'chhoot ga*', 'chhut ga*', 'choot ga*', 'ganwa*', 'gawa do', 'phataphat', 'fatafat',
  ],
};

/**
 * "Calm, not treatment" (PRD 06d REQ-SAN-12) and REQ-NTF-04 ("no copy promises better sleep"): treatment words and
 * sleep or health outcome claims, for every template (the wind-down reminder above all). Whole words (Latin script).
 */
export const CLAIM_WORDS: readonly string[] = [
  'binaural', 'heal', 'heals', 'healing', 'healed', 'cure', 'cures', 'cured', 'treat', 'treats', 'treatment',
  'therapy', 'therapeutic', 'therapist', 'clinical', 'clinically', 'insomnia', 'better sleep', 'sleep better',
  'fall asleep', 'deep sleep', 'sleep faster', 'guaranteed',
];

/** Quadrant names (the app's `quadrant_*` strings; hi / hi-Latn drafts). Theme names stay English in every language. */
export const QUADRANT_NAMES: readonly string[] = [
  'storm*', 'rain', 'rains', 'rainy', 'moonlight', 'sunrise',
  'తుఫాను', 'వాన', 'వెన్నెల', 'సూర్యోదయ',
  'तूफ़ान', 'तूफान', 'बारिश', 'चाँदनी', 'चांदनी', 'सूर्योदय',
  'toofan*', 'toofaan*', 'tufaan*', 'baarish', 'barish', 'chaandni', 'chandni', 'suryoday*',
];

/** Room themes by quadrant (contracts/api/v1-rooms.md, brief: The Lighthouse, The Rain Sanctuary, …). */
export const THEME_NAMES: readonly string[] = [
  'lighthouse', 'rain sanctuary', 'rain_sanctuary', 'midnight observatory', 'midnight_observatory', 'observatory',
  'sunrise deck', 'sunrise_deck', 'లైట్‌హౌస్', 'లైట్ హౌస్', 'అబ్జర్వేటరీ',
  // The Hindi theme names (app `rooms_theme_*`, drafts); Hinglish keeps the English ones above.
  'प्रकाश स्तंभ', 'वेधशाला', 'लाइटहाउस',
];

/** One mood's names by locale (contracts/moods.json `moods[].names`). */
export type MoodNames = Partial<Record<LintLocale, string>>;

const LATIN = /[A-Za-z]/;
const escape = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** A matcher for one list entry (see BANNED_WORDS for the rules). */
export function termMatcher(entry: string, suffixes = ''): (text: string) => boolean {
  const prefix = entry.endsWith('*');
  const word = prefix ? entry.slice(0, -1) : entry;
  if (!LATIN.test(word)) {
    const needle = word.normalize('NFC');
    return (text) => text.normalize('NFC').includes(needle);
  }
  const body = escape(word.toLowerCase()).replace(/[\s_]+/g, '[\\s_]+');
  const re = new RegExp(`(?<![\\p{L}\\p{N}])${body}${prefix ? '' : `${suffixes}(?![\\p{L}\\p{N}])`}`, 'iu');
  return (text) => re.test(text);
}

/** Telugu-script adverbial `-గా` / Tenglish `-ga`, `-nga`, `-gaa`: the stem catches other forms of the word. */
function moodStems(name: string): string[] {
  if (name.includes(' ')) return [];
  if (!LATIN.test(name)) {
    const stem = name.replace(/గా$/u, '');
    return stem !== name && [...stem].length >= 3 ? [stem] : [];
  }
  const stem = name.replace(/(n?ga+)$/i, '');
  return stem !== name && stem.length >= 5 ? [`${stem}*`] : [];
}

/** Every term the lint looks for: banned words of all languages, then mood, quadrant and theme names. */
export function buildLintTerms(moods: readonly MoodNames[]): LintTerm[] {
  const terms: LintTerm[] = [];
  const add = (entry: string, reason: LintReason, suffixes = ''): void => {
    terms.push({ label: entry, reason, test: termMatcher(entry, suffixes) });
  };
  for (const list of Object.values(BANNED_WORDS)) for (const w of list) add(w, 'banned_word');
  for (const m of moods) {
    for (const name of Object.values(m)) {
      if (!name) continue;
      add(name, 'mood_name', '(?:s|ly|ness)?');
      for (const stem of moodStems(name)) add(stem, 'mood_name');
    }
  }
  for (const q of QUADRANT_NAMES) add(q, 'quadrant_name');
  for (const c of CLAIM_WORDS) add(c, 'health_claim');
  for (const t of THEME_NAMES) add(t, 'theme_name');
  return terms;
}

/** Violations in `templates` (every template is checked against every term: languages mix, e.g. Tenglish). */
export function lintTemplates(templates: readonly TemplateSource[], terms: readonly LintTerm[]): CopyViolation[] {
  const out: CopyViolation[] = [];
  for (const t of templates) {
    for (const term of terms) {
      if (term.test(t.text)) out.push({ source: t.source, locale: t.locale, key: t.key, term: term.label, reason: term.reason });
    }
  }
  return out;
}

/** The server's push templates as each of the five locales renders them (fallbacks included). */
export function serverPushTemplates(): TemplateSource[] {
  return PUSH_LOCALES.flatMap((locale) => {
    const table = copyTableFor(locale);
    return COPY_KEYS.map((key) => ({ source: 'server:push-copy', locale, key, text: table[key] }));
  });
}

/** One line per violation, for CI output. */
export const formatViolation = (v: CopyViolation): string =>
  `${v.source} [${v.locale}] ${v.key}: contains ${v.reason.replace('_', ' ')} "${v.term}"`;
