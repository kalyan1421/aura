import type { Queryable } from '../db/db';
import { TRIAL_REMINDER_LEAD_MS } from './state';

/**
 * PRD 12 "Aura Plus trial ending": 48 h before the free month ends, once per account, only while auto-renew is on.
 * The sweep (billing worker, every 10 min) claims the account's one reminder (`billing_accounts.trial_reminder_at`)
 * atomically, then enqueues the `trial_ending` push with the subscription id as its opaque id; delivery
 * (src/notifications/trial-ending.ts) re-checks the facts, waits out quiet hours and renders date + store price.
 * A trial that ends in under 2 h is not reminded any more (it would arrive too late to help).
 */
export const TRIAL_REMINDER_MIN_LEAD_MS = 2 * 3600_000;

export interface TrialReminderDue {
  userId: string;
  subscriptionId: string;
}

export async function claimTrialReminders(q: Queryable, now: Date, limit = 500): Promise<TrialReminderDue[]> {
  const r = await q.query<{ user_id: string; subscription_id: string }>(
    `with due as (
       select distinct on (s.owner_user_id) s.owner_user_id, s.id
         from public.subscriptions s
         join public.billing_accounts b on b.user_id = s.owner_user_id
        where s.state = 'trial' and s.auto_renew and b.trial_reminder_at is null
          and s.trial_ends_at > $2 and s.trial_ends_at <= $3
          and not exists (select 1 from public.account_deletions d where d.user_id = s.owner_user_id)
        order by s.owner_user_id, s.trial_ends_at
        limit $4)
     update public.billing_accounts b set trial_reminder_at = $1
       from due where b.user_id = due.owner_user_id and b.trial_reminder_at is null
     returning b.user_id, due.id as subscription_id`,
    [now, new Date(now.getTime() + TRIAL_REMINDER_MIN_LEAD_MS), new Date(now.getTime() + TRIAL_REMINDER_LEAD_MS), limit],
  );
  return r.rows.map((x) => ({ userId: x.user_id, subscriptionId: x.subscription_id }));
}

/** The push couldn't be queued (Redis down): give the claim back so the next sweep tries again. */
export async function releaseTrialReminder(q: Queryable, userId: string): Promise<void> {
  await q.query('update public.billing_accounts set trial_reminder_at = null where user_id = $1', [userId]);
}
