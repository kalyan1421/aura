import { MAIL_COPY, mailLocale, type MailLocale } from '../admin/mail/copy';
import type { Queryable } from '../db/db';
import { inQuietHours, nextWallTime } from '../notifications/policy';
import { ACTIVE_SANCTION_SQL } from '../safety/safety-types';

/**
 * The trial-ending EMAIL (PRD 12 catalogue "Aura Plus trial ending": Push + in-app card + email; "Email (trial-ending
 * reminder only, and only if the account has a verified email)"; "Trial-ending reminder rules"; REQ-NTF-03), the
 * twin of the `trial_ending` push (src/notifications/trial-ending.ts), claimed by the same billing sweep
 * (src/billing/trial-reminder.ts). Facts only: the end date, the store's own localized price string and period, and
 * one link to the store's own subscription page ("One tap to cancel … with no retention screen"). Pure rules here; the
 * ledger and the transport are in trial-email.sender.ts.
 */

/** What the rules need, read in one query (service role: the address lives only in auth.users). */
export interface TrialEmailFacts {
  /** The subscription exists and still belongs to this account. */
  owned: boolean;
  state: string | null;
  autoRenew: boolean;
  trialEndsAt: Date | null;
  price: string | null;
  productId: string | null;
  store: 'apple' | 'google' | null;
  /** auth.users row exists and isn't soft-deleted. */
  userExists: boolean;
  email: string | null;
  emailVerified: boolean;
  pendingDeletion: boolean;
  closed: boolean;
  locale: MailLocale;
  timezone: string | null;
  quietStart: string;
  quietEnd: string;
}

export type TrialEmailSkip =
  | 'trial_changed'
  | 'auto_renew_off'
  | 'account_deleted'
  | 'account_closed'
  | 'no_email'
  | 'email_unverified'
  | 'too_late'
  | 'mail_not_configured';

export type TrialEmailDecision =
  | { action: 'send' }
  | { action: 'skip'; reason: TrialEmailSkip }
  | { action: 'defer'; until: Date };

/** A reminder that would land less than this before the end of the free month is pointless (the push uses 2 h). */
export const TRIAL_EMAIL_MIN_LEAD_MS = 60 * 60_000;
const DEFAULT_QUIET = { start: '23:00', end: '08:00' };
const EMAIL_RE = /^[^\s@<>()[\]\\,;:"]+@[^\s@<>()[\]\\,;:"]+\.[^\s@<>()[\]\\,;:"]+$/;

/**
 * Send, skip (with a reason) or wait for the end of quiet hours. The order matters: a changed trial or auto-renew off
 * comes first (PRD 12: "Not sent if auto-renew is already off"), then the account, then the address. Quiet hours
 * (11 pm–8 am local by default, the person's own setting when they have one) apply to the email like the push —
 * unless waiting would leave less than an hour of the free month.
 */
export function decideTrialEmail(f: TrialEmailFacts, now: Date): TrialEmailDecision {
  const skip = (reason: TrialEmailSkip): TrialEmailDecision => ({ action: 'skip', reason });
  if (!f.owned || f.state !== 'trial' || !f.trialEndsAt || f.trialEndsAt.getTime() <= now.getTime()) return skip('trial_changed');
  if (!f.autoRenew) return skip('auto_renew_off');
  if (!f.userExists || f.pendingDeletion) return skip('account_deleted');
  if (f.closed) return skip('account_closed');
  if (!f.email || !EMAIL_RE.test(f.email)) return skip('no_email');
  if (!f.emailVerified) return skip('email_unverified');
  const left = f.trialEndsAt.getTime() - now.getTime();
  if (left < TRIAL_EMAIL_MIN_LEAD_MS) return skip('too_late');
  const tz = f.timezone ?? 'Asia/Kolkata';
  if (inQuietHours(now, tz, f.quietStart, f.quietEnd)) {
    const until = nextWallTime(now, tz, f.quietEnd);
    if (f.trialEndsAt.getTime() - until.getTime() >= TRIAL_EMAIL_MIN_LEAD_MS) return { action: 'defer', until };
  }
  return { action: 'send' };
}

export async function readTrialEmailFacts(q: Queryable, subscriptionId: string, userId: string): Promise<TrialEmailFacts> {
  const r = await q.query<{
    owner_user_id: string | null;
    state: string | null;
    auto_renew: boolean | null;
    trial_ends_at: Date | null;
    price_display: string | null;
    product_id: string | null;
    store: 'apple' | 'google' | null;
    user_exists: boolean;
    email: string | null;
    email_verified: boolean;
    ui_locale: string | null;
    timezone: string | null;
    quiet_start: string | null;
    quiet_end: string | null;
    pending_deletion: boolean;
    closed: boolean;
  }>(
    `select s.owner_user_id, s.state, s.auto_renew, s.trial_ends_at, s.price_display, s.product_id, s.store,
            (u.id is not null and u.deleted_at is null) as user_exists,
            nullif(btrim(u.email), '') as email,
            (u.email_confirmed_at is not null) as email_verified,
            p.ui_locale, p.timezone,
            np.quiet_start::text as quiet_start, np.quiet_end::text as quiet_end,
            exists (select 1 from public.account_deletions d where d.user_id = q.uid) as pending_deletion,
            exists (select 1 from public.sanctions x where x.user_id = q.uid and x.kind = 'account_ban' and ${ACTIVE_SANCTION_SQL('x')}) as closed
       from (select $1::uuid as sid, $2::uuid as uid) q
       left join public.subscriptions s on s.id = q.sid
       left join auth.users u on u.id = q.uid
       left join public.profiles p on p.user_id = q.uid
       left join public.notification_prefs np on np.user_id = q.uid`,
    [subscriptionId, userId],
  );
  const x = r.rows[0];
  const hm = (v: string | null | undefined, d: string): string => (v && /^\d{2}:\d{2}/.test(v) ? v.slice(0, 5) : d);
  return {
    owned: !!x?.owner_user_id && x.owner_user_id === userId,
    state: x?.state ?? null,
    autoRenew: x?.auto_renew ?? false,
    trialEndsAt: x?.trial_ends_at ?? null,
    price: x?.price_display ?? null,
    productId: x?.product_id ?? null,
    store: x?.store ?? null,
    userExists: x?.user_exists ?? false,
    email: x?.email ?? null,
    emailVerified: x?.email_verified ?? false,
    pendingDeletion: x?.pending_deletion ?? false,
    closed: x?.closed ?? false,
    locale: mailLocale(x?.ui_locale),
    timezone: x?.timezone ?? null,
    quietStart: hm(x?.quiet_start, DEFAULT_QUIET.start),
    quietEnd: hm(x?.quiet_end, DEFAULT_QUIET.end),
  };
}

/** The store's own subscription page (PRD 12 "One tap to cancel"): no Aura page, no retention step in between. */
export function manageSubscriptionUrl(store: 'apple' | 'google', productId: string | null, packageName = 'com.akvega.aura'): string {
  if (store === 'apple') return 'https://apps.apple.com/account/subscriptions';
  const u = new URL('https://play.google.com/store/account/subscriptions');
  if (productId && /^[a-z0-9_.]{1,64}$/.test(productId)) u.searchParams.set('sku', productId);
  u.searchParams.set('package', packageName);
  return u.toString();
}

const STORE_NAME = { apple: 'App Store', google: 'Google Play' } as const;
const dateFormats = new Map<string, Intl.DateTimeFormat>();

/** "3 Nov 2026" in the person's zone, written the way their language writes dates (PRD 18). */
export function trialEmailDate(d: Date, tz: string | null, locale: MailLocale): string {
  const tag = MAIL_COPY[locale].dateLocale;
  const zone = tz ?? 'Asia/Kolkata';
  const id = `${tag}|${zone}`;
  try {
    let f = dateFormats.get(id);
    if (!f) {
      f = new Intl.DateTimeFormat(tag, { day: 'numeric', month: 'short', year: 'numeric', timeZone: zone });
      dateFormats.set(id, f);
    }
    return f.format(d);
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

/** Store strings arrive from the phone (≤ 32 chars): one line, no control characters. */
const oneLine = (s: string): string => s.replace(/[\p{Cc}\p{Zl}\p{Zp}]+/gu, ' ').trim().slice(0, 32);

export interface TrialEmailContent {
  endsAt: Date;
  timezone: string | null;
  price: string | null;
  productId: string | null;
  store: 'apple' | 'google';
  locale: MailLocale;
  packageName?: string;
}

/** Subject + plain text. No greeting by name, no mood, no content, no account detail: the facts and the store link. */
export function trialEndingEmail(c: TrialEmailContent): { subject: string; text: string } {
  const t = MAIL_COPY[c.locale];
  const date = trialEmailDate(c.endsAt, c.timezone, c.locale);
  const price = c.price ? oneLine(c.price) : '';
  const yearly = c.productId === 'aura_plus_annual';
  const facts = !price
    ? t.trialEnding.factsNoPrice(date)
    : yearly
      ? t.trialEnding.factsYear(date, price)
      : t.trialEnding.facts(date, price);
  return {
    subject: t.trialEnding.subject(date),
    text: [
      t.hello,
      '',
      facts,
      '',
      t.trialEnding.cancelHow(STORE_NAME[c.store]),
      manageSubscriptionUrl(c.store, c.productId, c.packageName),
      '',
      t.trialEnding.once,
      t.publisher,
    ].join('\n'),
  };
}
