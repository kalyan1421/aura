import { CAP_EXEMPT, TYPE_RULES } from '../../src/notifications/catalogue';
import { NOTIFICATION_TYPES } from '../../src/notifications/notification-types';
import { DEFAULT_NOTIFICATION_PREFS, decide, type DeliveryFacts } from '../../src/notifications/policy';
import { renderPushLine } from '../../src/notifications/push-copy';
import { trialEndingCopy, type TrialEndingFacts } from '../../src/notifications/trial-ending';

/** F12 "Aura Plus trial ending" push (PRD 12; REQ-NTF-03). */
const TZ = 'Asia/Kolkata';
const ENDS = new Date('2026-11-03T06:30:00Z');
const trial = (over: Partial<TrialEndingFacts> = {}): TrialEndingFacts => ({ stillEnding: true, endsAt: ENDS, price: '₹49.00', period: 'month', ...over });
const facts = (over: Partial<DeliveryFacts> = {}): DeliveryFacts => ({
  type: 'trial_ending',
  now: new Date('2026-11-01T06:30:00Z'), // 12:00 IST
  createdAt: new Date('2026-11-01T06:30:00Z'),
  tz: TZ,
  prefs: { ...DEFAULT_NOTIFICATION_PREFS },
  pendingDeletion: false,
  devices: 1,
  sentToday: [],
  expectedLater: [],
  trialEnding: trial(),
  ...over,
});

describe('trial_ending push', () => {
  it('is a registered, cap-exempt type on the Account channel', () => {
    expect(NOTIFICATION_TYPES).toContain('trial_ending');
    expect(CAP_EXEMPT).toContain('trial_ending');
    expect(TYPE_RULES.trial_ending.channel).toBe('account');
  });

  it('REQ-NTF-03: a free month ending 3 Nov → the push on 1 Nov with the date and the store price', () => {
    expect(decide(facts())).toEqual({ action: 'send' });
    const { key, params } = trialEndingCopy(trial(), TZ, 'en');
    expect(renderPushLine(key, 'en', false, params)).toBe(
      "Your free month of Aura Plus ends on 3 Nov. After that it's ₹49.00/month. Keep it or cancel anytime.",
    );
  });

  it('exempt from the daily cap: sent even after two other pushes today', () => {
    expect(decide(facts({ sentToday: ['daily_reminder', 'capsule_unlocked'] }))).toEqual({ action: 'send' });
  });

  it('Negative: not sent when auto-renew is already off, or the trial converted / lapsed (trial_changed)', () => {
    expect(decide(facts({ trialEnding: trial({ stillEnding: false }) }))).toEqual({ action: 'skip', reason: 'trial_changed' });
  });

  it('never inside quiet hours: deferred to their end', () => {
    const night = new Date('2026-11-01T18:00:00Z'); // 23:30 IST
    const d = decide(facts({ now: night, createdAt: night }));
    expect(d.action).toBe('defer');
  });

  it('respects the master switch and discreet mode', () => {
    expect(decide(facts({ prefs: { ...DEFAULT_NOTIFICATION_PREFS, enabled: false } }))).toEqual({ action: 'skip', reason: 'disabled' });
    const { key, params } = trialEndingCopy(trial(), TZ, 'en');
    expect(renderPushLine(key, 'en', true, params)).toBe('You have a gentle update');
  });

  it('annual plan, missing price, Telugu and Tenglish lines (PRD’s own)', () => {
    const y = trialEndingCopy(trial({ period: 'year', price: '₹399.00' }), TZ, 'en');
    expect(renderPushLine(y.key, 'en', false, y.params)).toContain('₹399.00/year');
    const np = trialEndingCopy(trial({ price: null }), TZ, 'en');
    expect(renderPushLine(np.key, 'en', false, np.params)).toBe('Your free month of Aura Plus ends on 3 Nov. Keep it or cancel anytime in the store.');
    const tl = trialEndingCopy(trial(), TZ, 'te-Latn');
    expect(renderPushLine(tl.key, 'te-Latn', false, tl.params)).toBe(
      'Mee Aura Plus free month 3 Nov tho aipotundi. Tarvatha nelaki ₹49.00. Continue cheyyochu, leda eppudaina cancel cheyyochu.',
    );
    const te = trialEndingCopy(trial(), TZ, 'te');
    expect(renderPushLine(te.key, 'te', false, te.params)).toContain('₹49.00');
    expect(renderPushLine(te.key, 'te', false, te.params)).not.toContain('{');
  });
});
