import type { Queryable } from '../db/db';
import type { NotificationJobData } from './notification-types';
import type { PushLocale } from './push-copy';

/**
 * F12 "Aura Plus trial ending" push (PRD 12 catalogue + "Trial-ending reminder rules"; REQ-NTF-03): 48 h before the
 * free month ends (validated store state in NestJS), once per account, exempt from the daily cap, outside quiet hours
 * (deferred to their end). Facts only — the end date, the store's localized price string the paywall showed (never a
 * hard-coded ₹49) and the period; tapping it opens the store's own subscription page. Not sent once auto-renew is off
 * (the app shows "Plus stays on until {date}. You won't be charged." instead) or when the trial already converted,
 * lapsed or moved to another account. The job's opaque id is the subscription id (never content).
 * Scheduled by the billing worker (src/billing/trial-reminder.ts).
 */
export interface TrialEndingFacts {
  /** Still a trial on the same account, auto-renew on, ending in the future. */
  stillEnding: boolean;
  endsAt: Date | null;
  price: string | null;
  period: 'month' | 'year';
}

export async function readTrialEndingFacts(q: Queryable, n: NotificationJobData, now: Date): Promise<TrialEndingFacts> {
  if (n.id === null) return { stillEnding: false, endsAt: null, price: null, period: 'month' };
  const r = await q.query<{ state: string; auto_renew: boolean; trial_ends_at: Date | null; price_display: string | null; product_id: string }>(
    `select state, auto_renew, trial_ends_at, price_display, product_id from public.subscriptions
      where id = $1 and owner_user_id = $2`,
    [n.id, n.userId],
  );
  const s = r.rows[0];
  const stillEnding = !!s && s.state === 'trial' && s.auto_renew && !!s.trial_ends_at && s.trial_ends_at > now;
  return {
    stillEnding,
    endsAt: s?.trial_ends_at ?? null,
    price: s?.price_display ?? null,
    period: s?.product_id === 'aura_plus_annual' ? 'year' : 'month',
  };
}

const DATE_LOCALE: Readonly<Record<PushLocale, string>> = { en: 'en-IN', te: 'te-IN', 'te-Latn': 'en-IN', hi: 'hi-IN', 'hi-Latn': 'en-IN' };

/** "30 Oct" in the person's zone and language. */
export function trialDate(d: Date, tz: string, locale: PushLocale): string {
  try {
    return new Intl.DateTimeFormat(DATE_LOCALE[locale], { day: 'numeric', month: 'short', timeZone: tz }).format(d);
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

/** The copy key + placeholder values for the push (push-copy.ts `trial_ending*` lines). */
export function trialEndingCopy(
  f: TrialEndingFacts,
  tz: string,
  locale: PushLocale,
): { key: 'trial_ending' | 'trial_ending_year' | 'trial_ending_no_price'; params: Readonly<Record<string, string>> } {
  const date = f.endsAt ? trialDate(f.endsAt, tz, locale) : '';
  if (!f.price) return { key: 'trial_ending_no_price', params: { date } };
  return { key: f.period === 'year' ? 'trial_ending_year' : 'trial_ending', params: { date, price: f.price } };
}
