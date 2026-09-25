import { Inject, Injectable, Logger } from '@nestjs/common';
import { MAILER, mailErrorCode, type Mailer } from '../admin/mail/mailer';
import type { Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { decideTrialEmail, readTrialEmailFacts, trialEndingEmail, type TrialEmailSkip } from './trial-ending-email';

/**
 * Sends one trial's trial-ending email, at most once (PRD 12 "Once per account"; the ledger is per trial:
 * `trial_ending_emails`, migration 20261005000025):
 *  1. read the facts and decide (trial-ending-email.ts) — a skip is recorded with its reason, a quiet-hours wait is
 *     returned to the queue (nothing recorded yet);
 *  2. claim the trial (`sending`) — only a new row or an earlier `failed` attempt can be claimed, so two workers,
 *     retries or a restart can never email twice (a crash after the claim leaves `sending`: at most once);
 *  3. send through the console's SMTP transport (src/admin/mail; Mailpit locally) to the address in auth.users;
 *  4. record `sent`, or `failed` with the transport's short code (the queue retries a few times).
 * Nothing is logged but counts and reason codes: never the address, the price or the date.
 */
export const TRIAL_EMAIL_MAX_ATTEMPTS = 5;

export type TrialEmailOutcome =
  | { outcome: 'sent' }
  | { outcome: 'skipped'; reason: TrialEmailSkip }
  | { outcome: 'deferred'; until: Date }
  | { outcome: 'duplicate' }
  | { outcome: 'failed'; code: string; retry: boolean };

export interface TrialEmailOptions {
  /** The Play package for the subscriptions deep link (BillingConfig.googlePackageName). */
  packageName?: string;
}

@Injectable()
export class TrialEmailSender {
  private readonly logger = new Logger('TrialEmail');

  constructor(
    private readonly db: DbService,
    @Inject(MAILER) private readonly mailer: Mailer,
  ) {}

  async process(subscriptionId: string, userId: string, now = new Date(), opts: TrialEmailOptions = {}): Promise<TrialEmailOutcome> {
    const facts = await readTrialEmailFacts(this.db, subscriptionId, userId);
    const d = decideTrialEmail(facts, now);
    if (d.action === 'defer') return { outcome: 'deferred', until: d.until };
    if (d.action === 'skip') return this.skip(subscriptionId, userId, d.reason);
    if (!this.mailer.enabled) return this.skip(subscriptionId, userId, 'mail_not_configured');

    const attempt = await claim(this.db, subscriptionId, userId, facts.locale);
    if (attempt === null) return { outcome: 'duplicate' };

    const mail = trialEndingEmail({
      endsAt: facts.trialEndsAt as Date,
      timezone: facts.timezone,
      price: facts.price,
      productId: facts.productId,
      store: facts.store ?? 'apple',
      locale: facts.locale,
      packageName: opts.packageName,
    });
    try {
      await this.mailer.send({ to: [facts.email as string], subject: mail.subject, text: mail.text, autoSubmitted: true });
    } catch (err) {
      const code = mailErrorCode(err);
      await this.db.query(`update public.trial_ending_emails set state = 'failed', reason = $2 where subscription_id = $1`, [subscriptionId, code]);
      const retry = attempt < TRIAL_EMAIL_MAX_ATTEMPTS;
      this.logger.warn(`not sent (${code}), attempt ${attempt}${retry ? ', will retry' : ', giving up'}`);
      return { outcome: 'failed', code, retry };
    }
    await this.db.query(
      `update public.trial_ending_emails set state = 'sent', reason = null, sent_at = now() where subscription_id = $1`,
      [subscriptionId],
    );
    return { outcome: 'sent' };
  }

  private async skip(subscriptionId: string, userId: string, reason: TrialEmailSkip): Promise<TrialEmailOutcome> {
    // A skip is final, but never overwrites a trial already emailed (or being emailed).
    await this.db.query(
      `insert into public.trial_ending_emails (subscription_id, user_id, state, reason)
       select $1, $2, 'skipped', $3
        where exists (select 1 from public.subscriptions s where s.id = $1)
          and exists (select 1 from auth.users u where u.id = $2)
       on conflict (subscription_id) do update set state = 'skipped', reason = excluded.reason
         where public.trial_ending_emails.state = 'failed'`,
      [subscriptionId, userId, reason],
    );
    return { outcome: 'skipped', reason };
  }
}

/** Claims the trial for this attempt; null = already sent, being sent or skipped (or out of attempts). */
export async function claim(q: Queryable, subscriptionId: string, userId: string, locale: string): Promise<number | null> {
  const r = await q.query<{ attempts: number }>(
    `insert into public.trial_ending_emails (subscription_id, user_id, state, attempts, locale)
     values ($1, $2, 'sending', 1, $3)
     on conflict (subscription_id) do update set state = 'sending', attempts = public.trial_ending_emails.attempts + 1,
                                                 locale = excluded.locale
       where public.trial_ending_emails.state = 'failed' and public.trial_ending_emails.attempts < $4
     returning attempts`,
    [subscriptionId, userId, locale, TRIAL_EMAIL_MAX_ATTEMPTS],
  );
  return r.rows[0]?.attempts ?? null;
}

/**
 * Trials whose reminder the billing sweep has claimed (`billing_accounts.trial_reminder_at`, the push's once-per-account
 * mark) and that have no email row yet — so the email follows every claimed push, also when Redis dropped a job or the
 * worker restarted. Still a trial with auto-renew on, ending at least an hour from now.
 */
export async function dueTrialEmails(q: Queryable, now: Date, limit = 200): Promise<Array<{ subscriptionId: string; userId: string }>> {
  const r = await q.query<{ id: string; owner_user_id: string }>(
    `select distinct on (s.owner_user_id) s.id, s.owner_user_id
       from public.subscriptions s
       join public.billing_accounts b on b.user_id = s.owner_user_id
      where b.trial_reminder_at is not null
        and s.state = 'trial' and s.auto_renew
        and s.trial_ends_at > $1::timestamptz + interval '1 hour'
        and s.trial_ends_at <= b.trial_reminder_at + interval '48 hours 30 minutes'
        and not exists (select 1 from public.trial_ending_emails e where e.subscription_id = s.id)
      order by s.owner_user_id, s.trial_ends_at
      limit $2`,
    [now, limit],
  );
  return r.rows.map((x) => ({ subscriptionId: x.id, userId: x.owner_user_id }));
}
