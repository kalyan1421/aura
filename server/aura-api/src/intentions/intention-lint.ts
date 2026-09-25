import { BANNED_WORDS, CLAIM_WORDS, QUADRANT_NAMES, THEME_NAMES, termMatcher } from '../notifications/copy-lint';

/**
 * Words check for Tonight's intention presets (PRD 06b "Tonight's intention"; PRD 19 "the Tonight's intention list
 * per language"). An intention is a gentle, shared, one-line invitation: "Sleep before midnight", "Be gentle with
 * myself tonight". It reuses the push copy lint (src/notifications/copy-lint.ts, REQ-NTF-01) where it fits — guilt /
 * loss / urgency words and treatment or outcome claims in every language, quadrant and room-theme names — and adds the
 * Insights template rules (REQ-INS-03, apps/mobile/test/insights_copy_lint_test.dart): no clinical labels and no
 * scoring. Mood names are NOT refused: a room intention is shown inside a room, never on a lock screen, and words
 * like "calm" are fine there. Pure: the console (POST /admin/intentions/*) and the unit tests call it.
 */
export const INTENTION_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type IntentionLocale = (typeof INTENTION_LOCALES)[number];
export type IntentionTexts = Readonly<Record<IntentionLocale, string>>;

/** Longest intention, in characters (the DB check is the same): one line on a small phone at 200 % text. */
export const INTENTION_MAX_CHARS = 80;

/** Guilt and pass/fail words beyond the push list (PRD 14-states: no "failed", "missed" or "almost" copy). */
export const GUILT_WORDS: readonly string[] = [
  'should', 'must', 'have to', 'fail*', 'almost', 'guilt*', 'shame*', 'ashamed', 'lazy', 'weak', 'no excuses', 'excuse',
  'promise', 'prove', 'deadline',
  // Tenglish / Hinglish (drafts)
  'cheyyaali', 'chesi teeraali', 'karna hi', 'karna padega', 'sharam*', 'sharm*', 'fail ho*',
  // Telugu / Devanagari stems (matched anywhere)
  'తప్పకుండా', 'సిగ్గు', 'విఫల', 'चाहिए', 'शर्म', 'असफल', 'ज़रूर करना', 'जरूर करना',
];

/** Clinical labels and diagnoses (REQ-INS-03: "no … labels or diagnoses"). */
export const CLINICAL_WORDS: readonly string[] = [
  'disorder', 'depress*', 'anxiety', 'diagnos*', 'symptom*', 'bipolar', 'ocd', 'adhd', 'ptsd', 'mental illness',
  'medication', 'medicine', 'pill*', 'dose', 'patient', 'illness', 'sick', 'relapse', 'recover*', 'suicid*', 'self-harm',
  'self harm',
  'డిప్రెషన్', 'వ్యాధి', 'లక్షణ', 'మందు', 'डिप्रेशन', 'बीमारी', 'लक्षण', 'दवा', 'दवाई',
];

/** Scoring, ranking and comparison (REQ-INS-03: "no numbers, percentages, scores"; F5: "no individual counts"). */
export const SCORE_WORDS: readonly string[] = [
  'score*', 'rating*', 'rank*', 'percent*', 'points', 'leaderboard', 'winner*', 'win', 'wins', 'beat', 'best',
  'worse', 'worst', 'better', 'perfect', 'goal*', 'target*', 'level up', 'compete*', 'challenge*',
  'behtar', 'badtar', 'स्कोर', 'रेटिंग', 'प्रतिशत', 'बेहतर', 'बदतर', 'స్కోర్', 'ర్యాంక్',
];

export type IntentionProblemReason =
  | 'empty'
  | 'too_long'
  | 'line_break'
  | 'link_or_contact'
  | 'banned_word'
  | 'health_claim'
  | 'guilt_word'
  | 'clinical_word'
  | 'score_word'
  | 'quadrant_name'
  | 'theme_name'
  | 'script';

export interface IntentionProblem {
  locale: IntentionLocale;
  reason: IntentionProblemReason;
  /** The listed term that matched (for word problems). */
  term?: string;
}

interface Term {
  label: string;
  reason: IntentionProblemReason;
  test: (text: string) => boolean;
}

function buildTerms(): Term[] {
  const out: Term[] = [];
  const add = (list: readonly string[], reason: IntentionProblemReason): void => {
    for (const w of list) out.push({ label: w, reason, test: termMatcher(w) });
  };
  for (const list of Object.values(BANNED_WORDS)) add(list, 'banned_word');
  add(CLAIM_WORDS, 'health_claim');
  add(GUILT_WORDS, 'guilt_word');
  add(CLINICAL_WORDS, 'clinical_word');
  add(SCORE_WORDS, 'score_word');
  add(QUADRANT_NAMES, 'quadrant_name');
  add(THEME_NAMES, 'theme_name');
  return out;
}

const TERMS = buildTerms();

const LINK = /(https?:\/\/|www\.|\.[a-z]{2,}\/|@[a-z0-9_]{2,}|\b[\w.+-]+@[\w-]+\.[\w.]+|\+?\d[\d\s-]{7,}\d)/iu;
// eslint-disable-next-line no-control-regex
const CONTROL = /[\u0000-\u001f\u007f-\u009f\u2028\u2029]/u;
const TELUGU = /\p{Script=Telugu}/u;
const DEVANAGARI = /\p{Script=Devanagari}/u;

/** Script sanity: te and hi carry their own script; the romanized locales and English carry none of it. */
function scriptProblem(locale: IntentionLocale, text: string): boolean {
  switch (locale) {
    case 'te':
      return !TELUGU.test(text);
    case 'hi':
      return !DEVANAGARI.test(text);
    default:
      return TELUGU.test(text) || DEVANAGARI.test(text);
  }
}

/** Problems with one language's line (empty = fine). Every term is checked against every language (lines mix). */
export function lintIntentionText(locale: IntentionLocale, raw: string): IntentionProblem[] {
  const text = raw.normalize('NFC');
  const problems: IntentionProblem[] = [];
  if (text.trim().length === 0) return [{ locale, reason: 'empty' }];
  if ([...text].length > INTENTION_MAX_CHARS) problems.push({ locale, reason: 'too_long' });
  if (CONTROL.test(text)) problems.push({ locale, reason: 'line_break' });
  if (LINK.test(text)) problems.push({ locale, reason: 'link_or_contact' });
  if (scriptProblem(locale, text)) problems.push({ locale, reason: 'script' });
  for (const t of TERMS) if (t.test(text)) problems.push({ locale, reason: t.reason, term: t.label });
  return problems;
}

/** All five lines (a missing language is `empty`). */
export function lintIntentionTexts(texts: Partial<Record<IntentionLocale, string>>): IntentionProblem[] {
  return INTENTION_LOCALES.flatMap((l) => lintIntentionText(l, texts[l] ?? ''));
}

const REASON_TEXT: Readonly<Record<IntentionProblemReason, string>> = {
  empty: 'is empty (every language needs its line)',
  too_long: `is longer than ${INTENTION_MAX_CHARS} characters`,
  line_break: 'has a line break or control character',
  link_or_contact: 'has a link, handle, email address or phone number',
  banned_word: 'has a guilt, loss or urgency word',
  health_claim: 'has a treatment or health-outcome word',
  guilt_word: 'has a pressure or pass/fail word',
  clinical_word: 'has a clinical word',
  score_word: 'has a scoring or comparison word',
  quadrant_name: 'names a quadrant',
  theme_name: 'names a room theme',
  script: 'is not in its language’s script (te: Telugu script, hi: Devanagari, the others: Latin)',
};

/** One console line per problem, e.g. `te-Latn: has a guilt, loss or urgency word ("tondara*")`. */
export const describeIntentionProblem = (p: IntentionProblem): string =>
  `${p.locale}: ${REASON_TEXT[p.reason]}${p.term ? ` ("${p.term}")` : ''}`;
