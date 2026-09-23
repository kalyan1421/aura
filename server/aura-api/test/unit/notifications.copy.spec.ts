/**
 * Push copy (src/notifications/push-copy.ts): rendered server-side in the user's app language, the PRD's exact
 * lines, English fallback for Hindi / Hinglish until beta, and discreet mode's one line for every push (rule 4).
 */
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

  it('Hindi and Hinglish fall back to English until they ship (beta); unknown locales too', () => {
    expect(PUSH_COPY.hi).toBeNull();
    expect(PUSH_COPY['hi-Latn']).toBeNull();
    expect(renderPushBody('daily_reminder', 'hi', false)).toBe(renderPushBody('daily_reminder', 'en', false));
    expect(renderPushBody('capsule_unlocked', 'hi-Latn', true)).toBe('You have a gentle update');
    expect(resolvePushLocale('te-Latn')).toBe('te-Latn');
    expect(resolvePushLocale('fr')).toBe('en');
    expect(resolvePushLocale(null)).toBe('en');
  });

  it('every locale renders every type and the discreet line (no empty copy)', () => {
    for (const locale of PUSH_LOCALES) {
      const table = copyTableFor(locale);
      for (const key of [...NOTIFICATION_TYPES, 'discreet'] as const) expect(table[key].trim().length).toBeGreaterThan(5);
    }
  });
});
