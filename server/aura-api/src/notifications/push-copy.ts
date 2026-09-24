import type { NotificationType } from './notification-types';

/**
 * Push copy, rendered server-side in the user's app language (PRD 12-notifications rule 8; 18-localization "server-
 * sent strings use the same catalogue, rendered in NestJS"). Every line is generic: it never names a mood, quadrant,
 * room theme, capsule title, date, pseudonym or streak, and it passes the copy lint (REQ-NTF-01,
 * test/unit/notifications.copy-lint.spec.ts), which runs in `pnpm lint` and `pnpm test`.
 *
 * English and Tenglish reminder/capsule lines are the PRD's own; Telugu-script lines where the PRD gives none, and
 * the discreet line in te / te-Latn, are drafts for native review (like every non-English string). Hindi and Hinglish
 * are beta: until translated they fall back to English (`null` below).
 */
export const PUSH_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type PushLocale = (typeof PUSH_LOCALES)[number];

/** One line per push type, plus `discreet`: the single line every push uses in discreet mode (rule 4). */
export type CopyKey = NotificationType | 'discreet';
export const COPY_KEYS: readonly CopyKey[] = ['daily_reminder', 'capsule_unlocked', 'rooms_pool_open', 'discreet'];

export type CopyTable = Readonly<Record<CopyKey, string>>;

export const PUSH_COPY: Readonly<Record<PushLocale, CopyTable | null>> = {
  en: {
    daily_reminder: "A quiet minute for you. How's today feeling?",
    capsule_unlocked: 'Something you sealed is ready to open.',
    // "Tell me when they open" (14-states): names the pool the person asked about, nothing about them or a mood.
    rooms_pool_open: 'Hindi and Hinglish rooms are open now.',
    // Rule 4: "Aura · You have a gentle update" — the OS shows the app name, the body is the line.
    discreet: 'You have a gentle update',
  },
  te: {
    daily_reminder: 'మీ కోసం ఒక నిమిషం. ఈ రోజు ఎలా అనిపిస్తోంది?',
    capsule_unlocked: 'మీరు దాచుకున్నది ఇప్పుడు తెరవొచ్చు.', // draft (= the app's local notice)
    rooms_pool_open: 'హిందీ, హింగ్లిష్ రూమ్‌లు ఇప్పుడు మొదలయ్యాయి.', // draft
    discreet: 'మీకు ఒక మృదువైన అప్‌డేట్ ఉంది', // draft
  },
  'te-Latn': {
    daily_reminder: 'Mee kosam oka quiet minute. Ee roju ela anipistondi?',
    capsule_unlocked: 'Meeru daachukunnadi ippudu open cheyyochu.',
    rooms_pool_open: 'Hindi, Hinglish rooms ippudu modalayyaayi.', // draft
    discreet: 'Meeku oka gentle update undi', // draft
  },
  // TODO(l10n-hi): Hindi and Hinglish ship from beta; English until then.
  hi: null,
  'hi-Latn': null,
};

/** `profiles.ui_locale` → a catalogue locale (unknown → English). */
export function resolvePushLocale(uiLocale: string | null | undefined): PushLocale {
  return (PUSH_LOCALES as readonly string[]).includes(uiLocale ?? '') ? (uiLocale as PushLocale) : 'en';
}

/** The table a locale actually renders with (untranslated locales fall back to English). */
export function copyTableFor(locale: PushLocale): CopyTable {
  return PUSH_COPY[locale] ?? (PUSH_COPY.en as CopyTable);
}

/** The body of a push: the type's line, or the discreet line for every type when discreet mode is on. */
export function renderPushBody(type: NotificationType, locale: PushLocale, discreet: boolean): string {
  return copyTableFor(locale)[discreet ? 'discreet' : type];
}
