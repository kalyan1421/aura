/**
 * Push copy (src/notifications/push-copy.ts): rendered server-side in the user's app language, the PRD's exact
 * lines, Hindi / Hinglish in their own words (Milestone B: no English fallback), and discreet mode's one line for every
 * push (rule 4).
 */
import { readFileSync } from 'fs';
import { resolve } from 'path';
import { NOTIFICATION_TYPES } from '../../src/notifications/notification-types';
import { copyTableFor, PUSH_COPY, PUSH_LOCALES, renderPushBody, resolvePushLocale } from '../../src/notifications/push-copy';

describe('push copy', () => {
  it("uses the PRD's lines (English and Tenglish; Telugu reminder)", () => {
    expect(renderPushBody('daily_reminder', 'en', false)).toBe("A quiet minute for you. How's today feeling?");
    expect(renderPushBody('daily_reminder', 'te-Latn', false)).toBe('Mee kosam oka quiet minute. Ee roju ela anipistondi?');
    expect(renderPushBody('daily_reminder', 'te', false)).toBe('మీ కోసం ఒక నిమిషం. ఈ రోజు ఎలా అనిపిస్తోంది?');
    expect(renderPushBody('capsule_unlocked', 'en', false)).toBe('Something you sealed is ready to open.');
    expect(renderPushBody('capsule_unlocked', 'te-Latn', false)).toBe('Meeru daachukunnadi ippudu open cheyyochu.');
    expect(renderPushBody('capsule_unlocked', 'te', false)).toMatch(/[ఀ-౿]/); // Telugu script
  });

  it('discreet mode: "Aura · You have a gentle update" for every push, in the user\'s language', () => {
    for (const type of NOTIFICATION_TYPES) {
      expect(renderPushBody(type, 'en', true)).toBe('You have a gentle update');
      expect(renderPushBody(type, 'te-Latn', true)).toBe('Meeku oka gentle update undi');
      expect(renderPushBody(type, 'te', true)).toMatch(/[ఀ-౿]/);
    }
  });

  it('Hindi and Hinglish have their own tables (Milestone B, drafts): no English fallback; unknown locales → English', () => {
    for (const locale of PUSH_LOCALES) expect(PUSH_COPY[locale]).not.toBeNull();
    expect(renderPushBody('daily_reminder', 'hi', false)).toBe('आपके लिए सुकून का एक मिनट। आज कैसा लग रहा है?');
    expect(renderPushBody('daily_reminder', 'hi-Latn', false)).toBe('Aapke liye sukoon ka ek minute. Aaj kaisa lag raha hai?');
    expect(renderPushBody('capsule_unlocked', 'hi', true)).toBe('आपके लिए एक हल्का-सा अपडेट है');
    expect(renderPushBody('capsule_unlocked', 'hi-Latn', true)).toBe('Aapke liye ek gentle update hai');
    for (const type of NOTIFICATION_TYPES) {
      expect(renderPushBody(type, 'hi', false)).toMatch(/[\u0900-\u097F]/); // Devanagari
      expect(renderPushBody(type, 'hi-Latn', false)).not.toMatch(/[\u0900-\u097F]/);
      expect(renderPushBody(type, 'hi-Latn', false)).not.toBe(renderPushBody(type, 'en', false));
    }
    expect(resolvePushLocale('hi-Latn')).toBe('hi-Latn');
    expect(resolvePushLocale('te-Latn')).toBe('te-Latn');
    expect(resolvePushLocale('fr')).toBe('en');
    expect(resolvePushLocale(null)).toBe('en');
  });

  it("Hindi and Hinglish pushes read the same as the app's own banner / notice for that event", () => {
    const arb = (f: string): Record<string, string> =>
      JSON.parse(readFileSync(resolve(__dirname, '../../../../apps/mobile/lib/l10n', f), 'utf8')) as Record<string, string>;
    for (const [locale, file] of [['hi', 'app_hi.arb'], ['hi-Latn', 'app_hi_Latn.arb']] as const) {
      const app = arb(file);
      expect(renderPushBody('daily_reminder', locale, false)).toBe(app.notif_reminderBanner);
      expect(renderPushBody('capsule_unlocked', locale, false)).toBe(app.capsules_readyTitle);
      expect(renderPushBody('rooms_pool_open', locale, false)).toBe(app.notif_roomsPoolBanner);
      expect(renderPushBody('lantern_hour', locale, false)).toBe(app.notif_lanternBanner);
      expect(renderPushBody('wind_down_reminder', locale, false)).toBe(app.notif_windDownBanner);
      expect(renderPushBody('habit_nudge', locale, false)).toBe(app.notif_habitBanner);
    }
  });

  it('every line keeps its placeholders in every locale ({count}, {date}, {price})', () => {
    const names = (t: string): string[] => [...t.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
    const en = copyTableFor('en');
    for (const locale of PUSH_LOCALES) {
      const table = copyTableFor(locale);
      for (const key of Object.keys(en) as (keyof typeof en)[]) expect(names(table[key])).toEqual(names(en[key]));
    }
  });

  it('every locale renders every type and the discreet line (no empty copy)', () => {
    for (const locale of PUSH_LOCALES) {
      const table = copyTableFor(locale);
      for (const key of [...NOTIFICATION_TYPES, 'discreet'] as const) expect(table[key].trim().length).toBeGreaterThan(5);
    }
  });
});
