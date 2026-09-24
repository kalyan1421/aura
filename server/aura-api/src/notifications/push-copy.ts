import type { NotificationType } from './notification-types';

/**
 * Push copy, rendered server-side in the user's app language (PRD 12-notifications rule 8; 18-localization "server-
 * sent strings use the same catalogue, rendered in NestJS"). Every line is generic: it never names a mood, quadrant,
 * room theme, capsule title, date, pseudonym or streak, and it passes the copy lint (REQ-NTF-01,
 * test/unit/notifications.copy-lint.spec.ts), which runs in `pnpm lint` and `pnpm test`.
 *
 * English and Tenglish reminder/capsule lines are the PRD's own; Telugu-script lines where the PRD gives none, and
 * the discreet line in te / te-Latn, are drafts for native review (like every non-English string). Hindi and Hinglish
 * (Milestone B) are drafts too, NEEDING NATIVE REVIEW (docs/l10n/hindi-review.md): respectful *aap*, no gendered verb
 * forms. A `null` table would fall back to English; every locale has its own table now.
 */
export const PUSH_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type PushLocale = (typeof PUSH_LOCALES)[number];

/**
 * Variant lines a type renders instead of its own line when they fit (pushCopyKey, Milestone B): the one-person form of
 * "gestures received", and a habit nudge for exactly one preset habit. A custom habit's name never appears anywhere.
 */
export const VARIANT_COPY_KEYS = [
  'gestures_received_one',
  'habit_nudge_hydrate',
  'habit_nudge_breathe',
  'habit_nudge_move',
  'habit_nudge_journal',
  'habit_nudge_go_outside',
  'habit_nudge_sleep_on_time',
  // F12 trial reminder (trial-ending.ts): the annual plan's line, and the line when no store price was captured.
  'trial_ending_year',
  'trial_ending_no_price',
] as const;
export type VariantCopyKey = (typeof VARIANT_COPY_KEYS)[number];

/** One line per push type (+ variants), plus `discreet`: the single line every push uses in discreet mode (rule 4). */
export type CopyKey = NotificationType | VariantCopyKey | 'discreet';
export const COPY_KEYS: readonly CopyKey[] = [
  'daily_reminder',
  'capsule_unlocked',
  'rooms_pool_open',
  'gestures_received',
  'lantern_hour',
  'wind_down_reminder',
  'habit_nudge',
  'welcome_back',
  'trial_ending',
  ...VARIANT_COPY_KEYS,
  'discreet',
];

export type CopyTable = Readonly<Record<CopyKey, string>>;

export const PUSH_COPY: Readonly<Record<PushLocale, CopyTable | null>> = {
  en: {
    daily_reminder: "A quiet minute for you. How's today feeling?",
    capsule_unlocked: 'Something you sealed is ready to open.',
    // "Tell me when they open" (14-states): names the pool the person asked about, nothing about them or a mood.
    rooms_pool_open: 'Hindi and Hinglish rooms are open now.',
    // Milestone B: the PRD catalogue's lines. Counts without names; never a mood, theme, habit history or promise.
    gestures_received: '{count} people in your room sent you warmth.',
    gestures_received_one: 'Someone in your room sent you warmth.',
    lantern_hour: 'Lantern Hour is on. Others are here tonight.',
    // REQ-NTF-04 / 06d "calm, not treatment": no promise of better sleep.
    wind_down_reminder: 'A few quiet minutes before sleep, whenever you want them.',
    habit_nudge: "A small habit or two, whenever you're ready.",
    habit_nudge_hydrate: 'Small one: a glass of water?',
    habit_nudge_breathe: 'Small one: a few slow breaths?',
    habit_nudge_move: 'Small one: a little stretch?',
    habit_nudge_journal: 'Small one: a line or two for yourself?',
    habit_nudge_go_outside: 'Small one: a minute of fresh air?',
    habit_nudge_sleep_on_time: 'Small one: starting to wind down for bed?',
    welcome_back: 'No catch-up needed. Aura is here whenever you want a quiet minute.',
    // F12 (PRD 12 catalogue line; facts only: date, the store's price string, cancel anytime).
    trial_ending: "Your free month of Aura Plus ends on {date}. After that it's {price}/month. Keep it or cancel anytime.",
    trial_ending_year: "Your free month of Aura Plus ends on {date}. After that it's {price}/year. Keep it or cancel anytime.",
    trial_ending_no_price: 'Your free month of Aura Plus ends on {date}. Keep it or cancel anytime in the store.',
    // Rule 4: "Aura · You have a gentle update" — the OS shows the app name, the body is the line.
    discreet: 'You have a gentle update',
  },
  te: {
    daily_reminder: 'మీ కోసం ఒక నిమిషం. ఈ రోజు ఎలా అనిపిస్తోంది?',
    capsule_unlocked: 'మీరు దాచుకున్నది ఇప్పుడు తెరవొచ్చు.', // draft (= the app's local notice)
    rooms_pool_open: 'హిందీ, హింగ్లిష్ రూమ్‌లు ఇప్పుడు మొదలయ్యాయి.', // draft
    gestures_received: 'మీ రూమ్‌లో {count} మంది మీకు ఆత్మీయత పంపారు.', // draft
    gestures_received_one: 'మీ రూమ్‌లో ఒకరు మీకు ఆత్మీయత పంపారు.', // draft
    lantern_hour: 'Lantern Hour మొదలైంది. ఈ రాత్రి ఇంకా కొందరు ఇక్కడే ఉన్నారు.', // PRD's Telugu line
    wind_down_reminder: 'పడుకునే ముందు కొంచెం నిశ్శబ్ద సమయం? Aura ఇక్కడే ఉంది.', // draft
    habit_nudge: 'ఒక చిన్న అలవాటు, మీకు వీలైనప్పుడు.', // draft
    habit_nudge_hydrate: 'చిన్న పని: ఒక గ్లాసు నీళ్లు?', // draft
    habit_nudge_breathe: 'చిన్న పని: కొన్ని నెమ్మదైన శ్వాసలు?', // draft
    habit_nudge_move: 'చిన్న పని: కొంచెం స్ట్రెచ్?', // draft
    habit_nudge_journal: 'చిన్న పని: మీ కోసం ఒకటి రెండు వాక్యాలు?', // draft
    habit_nudge_go_outside: 'చిన్న పని: ఒక నిమిషం బయటి గాలి?', // draft
    habit_nudge_sleep_on_time: 'చిన్న పని: నిద్రకు సిద్ధమవడం మొదలుపెడదామా?', // draft
    welcome_back: 'ఏదీ పూడ్చుకోవాల్సిన అవసరం లేదు. మీకు ఎప్పుడు కావాలంటే అప్పుడు Aura ఇక్కడే ఉంటుంది.', // draft
    trial_ending: 'మీ Aura Plus ఉచిత నెల {date}తో ముగుస్తుంది. తర్వాత నెలకు {price}. కొనసాగించవచ్చు, లేదా ఎప్పుడైనా రద్దు చేయవచ్చు.', // PRD's Telugu line
    trial_ending_year: 'మీ Aura Plus ఉచిత నెల {date}తో ముగుస్తుంది. తర్వాత సంవత్సరానికి {price}. కొనసాగించవచ్చు, లేదా ఎప్పుడైనా రద్దు చేయవచ్చు.', // draft
    trial_ending_no_price: 'మీ Aura Plus ఉచిత నెల {date}తో ముగుస్తుంది. కొనసాగించవచ్చు, లేదా ఎప్పుడైనా రద్దు చేయవచ్చు.', // draft
    discreet: 'మీకు ఒక మృదువైన అప్‌డేట్ ఉంది', // draft
  },
  'te-Latn': {
    daily_reminder: 'Mee kosam oka quiet minute. Ee roju ela anipistondi?',
    capsule_unlocked: 'Meeru daachukunnadi ippudu open cheyyochu.',
    rooms_pool_open: 'Hindi, Hinglish rooms ippudu modalayyaayi.', // draft
    gestures_received: 'Mee room lo {count} mandi meeku warmth pampaaru.',
    gestures_received_one: 'Mee room lo okaru meeku warmth pampaaru.', // draft
    lantern_hour: 'Lantern Hour modalaindi. Ee raatri inka kondaru ikkade unnaru.',
    wind_down_reminder: 'Padukune mundu konchem quiet time? Aura ikkade undi.',
    habit_nudge: 'Oka chinna habit, meeku veelainappudu.', // draft
    habit_nudge_hydrate: 'Chinna pani: oka glass neellu?',
    habit_nudge_breathe: 'Chinna pani: konni nemmadi swaasalu?', // draft
    habit_nudge_move: 'Chinna pani: konchem stretch?', // draft
    habit_nudge_journal: 'Chinna pani: mee kosam okati rendu lines?', // draft
    habit_nudge_go_outside: 'Chinna pani: oka nimisham bayati gaali?', // draft
    habit_nudge_sleep_on_time: 'Chinna pani: nidraki ready avvadam modalupedadaamaa?', // draft
    welcome_back: 'Catch-up emi avasaram ledu. Meeku eppudu kaavalante appudu Aura ikkade untundi.',
    trial_ending: 'Mee Aura Plus free month {date} tho aipotundi. Tarvatha nelaki {price}. Continue cheyyochu, leda eppudaina cancel cheyyochu.',
    trial_ending_year: 'Mee Aura Plus free month {date} tho aipotundi. Tarvatha samvatsaraaniki {price}. Continue cheyyochu, leda eppudaina cancel cheyyochu.', // draft
    trial_ending_no_price: 'Mee Aura Plus free month {date} tho aipotundi. Continue cheyyochu, leda eppudaina cancel cheyyochu.', // draft
    discreet: 'Meeku oka gentle update undi', // draft
  },
  // DRAFT — NEEDS NATIVE REVIEW (Milestone B; docs/l10n/hindi-review.md). Gender-neutral: imperatives and nouns,
  // never a verb that agrees with the reader's gender. The copy lint's Devanagari stems match inside words (so no
  // शांति: it contains the mood name शांत).
  hi: {
    daily_reminder: 'आपके लिए सुकून का एक मिनट। आज कैसा लग रहा है?', // = the app's banner (notif_reminderBanner)
    capsule_unlocked: 'आपने जो सील किया था, वह अब खुल सकता है।', // = the app's local notice (capsules_readyTitle)
    rooms_pool_open: 'हिंदी और हिंग्लिश रूम अब खुल गए हैं।',
    gestures_received: 'आपके रूम में {count} लोगों ने आपको अपनापन भेजा।',
    gestures_received_one: 'आपके रूम में किसी ने आपको अपनापन भेजा।',
    lantern_hour: 'Lantern Hour शुरू हो गया है। आज रात और लोग भी यहाँ हैं।',
    wind_down_reminder: 'सोने से पहले सुकून के कुछ पल, जब भी मन हो।',
    habit_nudge: 'एक-दो छोटी आदतें, जब भी आप तैयार हों।',
    habit_nudge_hydrate: 'छोटी-सी बात: एक गिलास पानी?',
    habit_nudge_breathe: 'छोटी-सी बात: कुछ धीमी साँसें?',
    habit_nudge_move: 'छोटी-सी बात: थोड़ा-सा स्ट्रेच?',
    habit_nudge_journal: 'छोटी-सी बात: अपने लिए एक-दो लाइनें?',
    habit_nudge_go_outside: 'छोटी-सी बात: एक मिनट ताज़ी हवा?',
    habit_nudge_sleep_on_time: 'छोटी-सी बात: सोने की तैयारी शुरू करें?',
    welcome_back: 'पिछला कुछ भी पूरा करने की ज़रूरत नहीं। जब भी सुकून का एक मिनट चाहिए, Aura यहीं है।',
    trial_ending: 'Aura Plus का आपका मुफ़्त महीना {date} को पूरा होगा। उसके बाद {price}/महीना। इसे जारी रखें या कभी भी रद्द करें।',
    trial_ending_year: 'Aura Plus का आपका मुफ़्त महीना {date} को पूरा होगा। उसके बाद {price}/साल। इसे जारी रखें या कभी भी रद्द करें।',
    trial_ending_no_price: 'Aura Plus का आपका मुफ़्त महीना {date} को पूरा होगा। इसे जारी रखें या स्टोर में कभी भी रद्द करें।',
    discreet: 'आपके लिए एक हल्का-सा अपडेट है',
  },
  // DRAFT — NEEDS NATIVE REVIEW (Hinglish: Hindi in Latin letters, English words kept where people use them).
  'hi-Latn': {
    daily_reminder: 'Aapke liye sukoon ka ek minute. Aaj kaisa lag raha hai?',
    capsule_unlocked: 'Aapne jo seal kiya tha, woh ab khul sakta hai.',
    rooms_pool_open: 'Hindi aur Hinglish rooms ab khul gaye hain.',
    gestures_received: 'Aapke room mein {count} logon ne aapko warmth bheji.',
    gestures_received_one: 'Aapke room mein kisi ne aapko warmth bheji.',
    lantern_hour: 'Lantern Hour shuru ho gaya hai. Aaj raat aur log bhi yahan hain.',
    wind_down_reminder: 'Sone se pehle sukoon ke kuch pal, jab bhi mann ho.',
    habit_nudge: 'Ek-do chhoti habits, jab bhi aap taiyaar hon.',
    habit_nudge_hydrate: 'Chhoti si baat: ek glass paani?',
    habit_nudge_breathe: 'Chhoti si baat: kuch dheemi saansein?',
    habit_nudge_move: 'Chhoti si baat: thoda sa stretch?',
    habit_nudge_journal: 'Chhoti si baat: apne liye ek-do lines?',
    habit_nudge_go_outside: 'Chhoti si baat: ek minute taazi hawa?',
    habit_nudge_sleep_on_time: 'Chhoti si baat: sone ki taiyaari shuru karein?',
    welcome_back: 'Kuch bhi catch-up karne ki zaroorat nahi. Jab bhi sukoon ka ek minute chahiye, Aura yahin hai.',
    trial_ending: 'Aapka Aura Plus free month {date} ko poora hoga. Uske baad {price}/month. Ise continue karein ya kabhi bhi cancel karein.',
    trial_ending_year: 'Aapka Aura Plus free month {date} ko poora hoga. Uske baad {price}/year. Ise continue karein ya kabhi bhi cancel karein.',
    trial_ending_no_price: 'Aapka Aura Plus free month {date} ko poora hoga. Ise continue karein ya store mein kabhi bhi cancel karein.',
    discreet: 'Aapke liye ek gentle update hai',
  },
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

/** Values a line's `{placeholders}` take (Milestone B: `{count}`, a number — never content). */
export type CopyParams = Readonly<Record<string, number | string>>; // strings: F12 trial date + store price

/**
 * A line by key (a type or one of its variants) with its `{placeholders}` filled; the discreet line when discreet
 * mode is on. An unknown placeholder stays as written (the copy spec keeps every line's placeholders covered).
 */
export function renderPushLine(key: CopyKey, locale: PushLocale, discreet: boolean, params: CopyParams = {}): string {
  const text = copyTableFor(locale)[discreet ? 'discreet' : key];
  return text.replace(/\{(\w+)\}/g, (m, name: string) => (name in params ? String(params[name]) : m));
}

/**
 * Which line a Milestone B push uses, from what delivery read (counts and preset keys only): one person or several
 * for gestures; a single preset habit's own line, else the bundled one (custom habits, several habits).
 */
export function pushCopyKey(
  type: NotificationType,
  facts: { gestureCount?: number; dueHabits?: readonly string[] },
): { key: CopyKey; params: CopyParams } {
  if (type === 'gestures_received') {
    const count = facts.gestureCount ?? 0;
    return count === 1 ? { key: 'gestures_received_one', params: {} } : { key: type, params: { count } };
  }
  if (type === 'habit_nudge') {
    const due = facts.dueHabits ?? [];
    const own = due.length === 1 ? `habit_nudge_${due[0]}` : null;
    if (own && (VARIANT_COPY_KEYS as readonly string[]).includes(own)) return { key: own as CopyKey, params: {} };
    return { key: type, params: {} };
  }
  return { key: type, params: {} };
}
