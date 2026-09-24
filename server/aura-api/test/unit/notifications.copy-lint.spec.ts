/**
 * REQ-NTF-01 copy lint — the CI gate (`pnpm lint` / `pnpm lint:copy` / `pnpm test`): no push template in any of the
 * five languages names a mood, quadrant or room theme, or uses miss / lose / streak / broken / fading / last chance /
 * hurry (or their te / te-Latn / hi / hi-Latn equivalents). Checks the server's push catalogue (as every locale
 * renders it, fallbacks included) and the app's notification strings (ARB keys starting with `notif_`: in-app
 * banners for pushes and any lock-screen copy). The second half proves the linter catches each kind of breach.
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  BANNED_WORDS,
  buildLintTerms,
  formatViolation,
  lintTemplates,
  serverPushTemplates,
  termMatcher,
  type LintLocale,
  type MoodNames,
  type TemplateSource,
} from '../../src/notifications/copy-lint';
import { COPY_KEYS, PUSH_LOCALES } from '../../src/notifications/push-copy';

const ROOT = resolve(__dirname, '..', '..', '..', '..');
const moods = (JSON.parse(readFileSync(resolve(ROOT, 'contracts', 'moods.json'), 'utf8')) as { moods: { names: MoodNames }[] }).moods.map(
  (m) => m.names,
);
const TERMS = buildLintTerms(moods);

/** App ARB file per lint locale (apps/mobile/lib/l10n). */
const ARB_FILES: Record<LintLocale, string> = {
  en: 'app_en.arb',
  te: 'app_te.arb',
  'te-Latn': 'app_te_Latn.arb',
  hi: 'app_hi.arb',
  'hi-Latn': 'app_hi_Latn.arb',
};

/**
 * Lock-screen copy the app renders itself that predates the `notif_` convention: the capsules feature's offline
 * "ready to open" notice and its Android channel.
 */
const LOCKSCREEN_KEYS = ['capsules_readyTitle', 'capsules_channelName', 'capsules_channelDescription'];

/** The app's notification copy: ARB keys `notif_*` (the convention for banner / lock-screen strings) + the above. */
function appNotificationTemplates(): TemplateSource[] {
  const dir = resolve(ROOT, 'apps', 'mobile', 'lib', 'l10n');
  if (!existsSync(dir)) return [];
  const out: TemplateSource[] = [];
  for (const locale of PUSH_LOCALES) {
    const file = resolve(dir, ARB_FILES[locale]);
    if (!existsSync(file)) continue;
    const arb = JSON.parse(readFileSync(file, 'utf8')) as Record<string, unknown>;
    for (const [key, text] of Object.entries(arb)) {
      if ((key.startsWith('notif_') || LOCKSCREEN_KEYS.includes(key)) && typeof text === 'string') {
        out.push({ source: `app:${ARB_FILES[locale]}`, locale, key, text });
      }
    }
  }
  return out;
}

describe('REQ-NTF-01: shipped notification copy passes the lint', () => {
  it('the server push catalogue, in all five languages (as rendered, fallbacks included)', () => {
    const templates = serverPushTemplates();
    expect(templates).toHaveLength(5 * COPY_KEYS.length); // every type, its variants and discreet, in 5 languages
    const violations = lintTemplates(templates, TERMS);
    expect(violations.map(formatViolation)).toEqual([]);
  });

  it("the app's notification strings (ARB `notif_*` and the capsule notice)", () => {
    const violations = lintTemplates(appNotificationTemplates(), TERMS);
    expect(violations.map(formatViolation)).toEqual([]);
  });
});

describe('the linter', () => {
  const lint = (text: string, locale: LintLocale = 'en') =>
    lintTemplates([{ source: 'test', locale, key: 'k', text }], TERMS).map((v) => `${v.reason}:${v.term}`);

  it('flags the PRD banned patterns (guilt, loss, streak threats, urgency)', () => {
    expect(lint("You haven't checked in, we miss you")).toContain('banned_word:miss');
    expect(lint("Don't lose your 12-day streak!")).toEqual(expect.arrayContaining(['banned_word:lose', 'banned_word:streak*']));
    expect(lint('Your Aura is fading')).toContain('banned_word:fading');
    expect(lint('Your glow is broken')).toContain('banned_word:broken');
    expect(lint('Last chance! Hurry')).toEqual(expect.arrayContaining(['banned_word:last chance', 'banned_word:hurry']));
    expect(lint('You missed yesterday')).toContain('banned_word:missed');
    expect(lint('Streaks matter')).toContain('banned_word:streak*');
  });

  it('flags mood, quadrant and room theme names in every script', () => {
    expect(lint('Still feeling anxious?')).toContain('mood_name:Anxious');
    expect(lint('Feeling lonely tonight?')).toContain('mood_name:Lonely');
    expect(lint('A calm evening awaits')).toContain('mood_name:Calm');
    expect(lint('Quietly hopeful today?')).toContain('mood_name:Quietly Hopeful');
    expect(lint('The Rain Sanctuary is open')).toEqual(expect.arrayContaining(['theme_name:rain sanctuary', 'quadrant_name:rain']));
    expect(lint('Back at the Lighthouse')).toContain('theme_name:lighthouse');
    expect(lint('A storm day?')).toContain('quadrant_name:storm*');
    expect(lint('ఈ రోజు ఒంటరిగా ఉన్నారా?', 'te')).toContain('mood_name:ఒంటరిగా');
    expect(lint('మీరు ఒంటరి కాదు', 'te')).toContain('mood_name:ఒంటరి'); // the stem catches other forms
    expect(lint('వాన రోజు', 'te')).toContain('quadrant_name:వాన');
    expect(lint('Ee roju ontariga unnara?', 'te-Latn')).toContain('mood_name:Ontariga');
    expect(lint('Meeru prashaanthamga undandi', 'te-Latn')).toContain('mood_name:Prashaantha*');
    expect(lint('Aaj udaas ho?', 'hi-Latn')).toContain('mood_name:Udaas');
    expect(lint('क्या आप उदास हैं?', 'hi')).toContain('mood_name:उदास');
  });

  it('flags the te / te-Latn / hi / hi-Latn equivalents of the banned words', () => {
    expect(lint('మీ స్ట్రీక్ పోతుంది', 'te')).toContain('banned_word:స్ట్రీక్');
    expect(lint('మీరు కోల్పోతారు', 'te')).toContain('banned_word:కోల్పో');
    expect(lint('చివరి అవకాశం!', 'te')).toContain('banned_word:చివరి అవకాశ');
    expect(lint('త్వరపడండి', 'te')).toContain('banned_word:త్వరపడ');
    expect(lint('Mee streak kolpotaru', 'te-Latn')).toEqual(expect.arrayContaining(['banned_word:streak*', 'banned_word:kolpo*']));
    expect(lint('Tondaraga open cheyandi', 'te-Latn')).toContain('banned_word:tondara*');
    expect(lint('आखिरी मौका! जल्दी करें', 'hi')).toEqual(expect.arrayContaining(['banned_word:आखिरी मौका', 'banned_word:जल्दी']));
    expect(lint('Aakhri mauka, jaldi karo', 'hi-Latn')).toEqual(expect.arrayContaining(['banned_word:aakhri mauka', 'banned_word:jaldi']));
    for (const locale of Object.keys(BANNED_WORDS) as LintLocale[]) expect(BANNED_WORDS[locale].length).toBeGreaterThan(5);
  });

  it('matches whole words only in Latin script (no false alarms inside other words)', () => {
    expect(lint('A mission for today')).toEqual([]);
    expect(lint('Brainstorming is fine')).toEqual([]); // not "rain", not "storm*" mid-word
    expect(lint('Training later?')).toEqual([]);
    expect(lint('A closer look')).toEqual([]); // "lose" inside "closer"
    expect(lint('Something you sealed is ready to open.')).toEqual([]);
    expect(termMatcher('last chance')('LAST   CHANCE')).toBe(true);
    expect(termMatcher('streak*')('streaky')).toBe(true);
    expect(termMatcher('miss')('Mississippi')).toBe(false);
  });
});
