import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { DelayedError, type Job } from 'bullmq';
import { MAIL_LOCALES, type MailLocale } from '../../src/admin/mail/copy';
import { buildLintTerms, formatViolation, lintTemplates, type MoodNames, type TemplateSource } from '../../src/notifications/copy-lint';
import { renderPushLine } from '../../src/notifications/push-copy';
import type { TrialEmailOutcome } from '../../src/user-mail/trial-email.sender';
import {
  decideTrialEmail,
  manageSubscriptionUrl,
  trialEmailDate,
  trialEndingEmail,
  type TrialEmailFacts,
} from '../../src/user-mail/trial-ending-email';
import { TRIAL_EMAIL_JOB, UserMailWorkerHost, trialEmailJobId } from '../../src/user-mail/user-mail.worker';

/** PRD 12 "Aura Plus trial ending": the email twin of the push (REQ-NTF-03), facts only, once per trial. */
const ENDS = new Date('2026-11-03T06:30:00Z');
const NOON_IST = new Date('2026-11-01T06:30:00Z');
const facts = (over: Partial<TrialEmailFacts> = {}): TrialEmailFacts => ({
  owned: true,
  state: 'trial',
  autoRenew: true,
  trialEndsAt: ENDS,
  price: '₹49.00',
  productId: 'aura_plus_monthly',
  store: 'apple',
  userExists: true,
  email: 'person@privaterelay.appleid.com',
  emailVerified: true,
  pendingDeletion: false,
  closed: false,
  locale: 'en',
  timezone: 'Asia/Kolkata',
  quietStart: '23:00',
  quietEnd: '08:00',
  ...over,
});

describe('trial-ending email: who gets it', () => {
  it('sends to a verified address while the trial is still ending with auto-renew on (Apple private relay included)', () => {
    expect(decideTrialEmail(facts(), NOON_IST)).toEqual({ action: 'send' });
  });

  it.each<[string, Partial<TrialEmailFacts>, string]>([
    ['auto-renew is off (PRD 12 "Not sent if auto-renew is already off")', { autoRenew: false }, 'auto_renew_off'],
    ['the trial converted', { state: 'active' }, 'trial_changed'],
    ['the trial lapsed', { state: 'expired' }, 'trial_changed'],
    ['the subscription moved to another account', { owned: false }, 'trial_changed'],
    ['the trial already ended', { trialEndsAt: new Date(NOON_IST.getTime() - 1) }, 'trial_changed'],
    ['the account is pending deletion', { pendingDeletion: true }, 'account_deleted'],
    ['the account is gone', { userExists: false }, 'account_deleted'],
    ['the account was closed for breaking the rules', { closed: true }, 'account_closed'],
    ['the account has no email (e.g. phone sign-in)', { email: null }, 'no_email'],
    ['the address is not an address', { email: 'not an address' }, 'no_email'],
    ['the address is not verified', { emailVerified: false }, 'email_unverified'],
    ['less than an hour of the free month is left', { trialEndsAt: new Date(NOON_IST.getTime() + 59 * 60_000) }, 'too_late'],
  ])('skips when %s', (_, over, reason) => {
    expect(decideTrialEmail(facts(over), NOON_IST)).toEqual({ action: 'skip', reason });
  });

  it('auto-renew off wins over a missing address (the reason recorded is the store fact)', () => {
    expect(decideTrialEmail(facts({ autoRenew: false, email: null }), NOON_IST)).toEqual({ action: 'skip', reason: 'auto_renew_off' });
  });

  it('waits out quiet hours (the person’s own window) like the push', () => {
    const at0200Ist = new Date('2026-10-31T20:30:00Z');
    expect(decideTrialEmail(facts(), at0200Ist)).toEqual({ action: 'defer', until: new Date('2026-11-01T02:30:00Z') }); // 08:00 IST
    expect(decideTrialEmail(facts({ quietStart: '01:00', quietEnd: '06:00' }), at0200Ist)).toEqual({
      action: 'defer',
      until: new Date('2026-11-01T00:30:00Z'),
    });
    expect(decideTrialEmail(facts({ quietStart: '00:00', quietEnd: '00:00' }), at0200Ist)).toEqual({ action: 'send' });
  });

  it('does not wait out quiet hours when waiting would leave under an hour', () => {
    const at0200Ist = new Date('2026-10-31T20:30:00Z');
    expect(decideTrialEmail(facts({ trialEndsAt: new Date('2026-11-01T03:00:00Z') }), at0200Ist)).toEqual({ action: 'send' });
  });
});

describe('trial-ending email: what it says', () => {
  const pushKey = { month: 'trial_ending', year: 'trial_ending_year', none: 'trial_ending_no_price' } as const;

  it.each(MAIL_LOCALES)('%s: the facts sentence is the push line word for word, in every variant', (locale) => {
    const date = trialEmailDate(ENDS, 'Asia/Kolkata', locale);
    const monthly = trialEndingEmail({ endsAt: ENDS, timezone: 'Asia/Kolkata', price: '₹49.00', productId: 'aura_plus_monthly', store: 'apple', locale });
    const yearly = trialEndingEmail({ endsAt: ENDS, timezone: 'Asia/Kolkata', price: '₹399.00', productId: 'aura_plus_annual', store: 'google', locale });
    const noPrice = trialEndingEmail({ endsAt: ENDS, timezone: 'Asia/Kolkata', price: null, productId: 'aura_plus_monthly', store: 'apple', locale });
    expect(monthly.text).toContain(renderPushLine(pushKey.month, locale, false, { date, price: '₹49.00' }));
    expect(yearly.text).toContain(renderPushLine(pushKey.year, locale, false, { date, price: '₹399.00' }));
    expect(noPrice.text).toContain(renderPushLine(pushKey.none, locale, false, { date }));
    expect(monthly.subject).toContain(date);
  });

  it('English, in full: date, store price, one link to the store’s own page, nothing else', () => {
    const m = trialEndingEmail({ endsAt: ENDS, timezone: 'Asia/Kolkata', price: '₹49.00', productId: 'aura_plus_monthly', store: 'apple', locale: 'en' });
    expect(m.subject).toBe('Aura Plus: your free month ends on 3 Nov 2026');
    expect(m.text).toBe(
      [
        'Hello,',
        '',
        "Your free month of Aura Plus ends on 3 Nov 2026. After that it's ₹49.00/month. Keep it or cancel anytime.",
        '',
        'To cancel or change it, open your App Store subscriptions:',
        'https://apps.apple.com/account/subscriptions',
        '',
        'This is a one-time email: your free month is ending, and Aura sends no other email about it.',
        'Aura is published by AKVega.',
      ].join('\n'),
    );
    expect(m.text).not.toMatch(/unsubscribe|lose|last chance|perks|miss/i);
  });

  it('uses the person’s zone for the date', () => {
    const lateUtc = new Date('2026-11-03T20:00:00Z'); // 4 Nov in IST, 3 Nov in New York
    expect(trialEmailDate(lateUtc, 'Asia/Kolkata', 'en')).toBe('4 Nov 2026');
    expect(trialEmailDate(lateUtc, 'America/New_York', 'en')).toBe('3 Nov 2026');
  });

  it('keeps a store price string to one short line', () => {
    const m = trialEndingEmail({ endsAt: ENDS, timezone: null, price: '₹49.00\r\nBcc: x@y.z', productId: null, store: 'apple', locale: 'en' });
    expect(m.text.split('\n')[2]).toBe("Your free month of Aura Plus ends on 3 Nov 2026. After that it's ₹49.00 Bcc: x@y.z/month. Keep it or cancel anytime.");
  });

  it('links to the store’s own subscription page (no Aura page in between)', () => {
    expect(manageSubscriptionUrl('apple', 'aura_plus_monthly')).toBe('https://apps.apple.com/account/subscriptions');
    expect(manageSubscriptionUrl('google', 'aura_plus_annual')).toBe(
      'https://play.google.com/store/account/subscriptions?sku=aura_plus_annual&package=com.akvega.aura',
    );
    expect(manageSubscriptionUrl('google', 'bad id!')).toBe('https://play.google.com/store/account/subscriptions?package=com.akvega.aura');
  });

  it('passes the REQ-NTF-01 copy lint in all five languages (no mood, quadrant, theme, guilt or urgency word)', () => {
    const root = resolve(__dirname, '..', '..', '..', '..');
    const moods = (JSON.parse(readFileSync(resolve(root, 'contracts', 'moods.json'), 'utf8')) as { moods: { names: MoodNames }[] }).moods.map(
      (m) => m.names,
    );
    const templates: TemplateSource[] = MAIL_LOCALES.flatMap((locale: MailLocale) =>
      (['aura_plus_monthly', 'aura_plus_annual'] as const).flatMap((productId) => {
        const m = trialEndingEmail({ endsAt: ENDS, timezone: 'Asia/Kolkata', price: '₹49.00', productId, store: 'google', locale });
        return [
          { source: 'server:trial-email', locale, key: `${productId}.subject`, text: m.subject },
          { source: 'server:trial-email', locale, key: `${productId}.text`, text: m.text.replace(/https:\/\/\S+/g, '') },
        ];
      }),
    );
    expect(lintTemplates(templates, buildLintTerms(moods)).map(formatViolation)).toEqual([]);
  });
});

describe('trial-ending email: the queue', () => {
  const SUB = '0190aaaa-0000-7000-8000-000000000001';
  const USER = '0190bbbb-0000-7000-8000-000000000002';

  function host(outcome: TrialEmailOutcome): { h: UserMailWorkerHost; process: jest.Mock } {
    const process = jest.fn().mockResolvedValue(outcome);
    const h = new UserMailWorkerHost({} as never, {} as never, {} as never, { process } as never, { googlePackageName: 'com.akvega.aura' } as never);
    return { h, process };
  }
  const job = (data: unknown, name = TRIAL_EMAIL_JOB): Job & { moveToDelayed: jest.Mock } =>
    ({ name, data, moveToDelayed: jest.fn().mockResolvedValue(undefined) }) as unknown as Job & { moveToDelayed: jest.Mock };

  it('one job per trial', () => {
    expect(trialEmailJobId(SUB.toUpperCase())).toBe(`trial-email-${SUB}`);
  });

  it('quiet hours: the job waits on the queue (not an attempt)', async () => {
    const until = new Date('2026-11-01T02:30:00Z');
    const { h } = host({ outcome: 'deferred', until });
    const j = job({ subscriptionId: SUB, userId: USER });
    await expect(h.handle(j, 'tok')).rejects.toBeInstanceOf(DelayedError);
    expect(j.moveToDelayed).toHaveBeenCalledWith(until.getTime(), 'tok');
  });

  it('a transport failure throws (BullMQ retries with backoff) until attempts run out', async () => {
    await expect(host({ outcome: 'failed', code: 'smtp_connect', retry: true }).h.handle(job({ subscriptionId: SUB, userId: USER }))).rejects.toThrow(
      'smtp_connect',
    );
    await expect(host({ outcome: 'failed', code: 'smtp_connect', retry: false }).h.handle(job({ subscriptionId: SUB, userId: USER }))).resolves.toBe(
      'failed:smtp_connect',
    );
  });

  it('sent, skipped and duplicate jobs complete', async () => {
    await expect(host({ outcome: 'sent' }).h.handle(job({ subscriptionId: SUB, userId: USER }))).resolves.toBe('sent');
    await expect(host({ outcome: 'skipped', reason: 'no_email' }).h.handle(job({ subscriptionId: SUB, userId: USER }))).resolves.toBe('skipped:no_email');
    await expect(host({ outcome: 'duplicate' }).h.handle(job({ subscriptionId: SUB, userId: USER }))).resolves.toBe('duplicate');
  });

  it('ignores malformed jobs without touching the sender', async () => {
    const { h, process } = host({ outcome: 'sent' });
    await expect(h.handle(job({ subscriptionId: 'x', userId: USER }))).resolves.toBe('bad_job');
    await expect(h.handle(job({}, 'other'))).resolves.toBe('unknown_job');
    expect(process).not.toHaveBeenCalled();
  });
});
