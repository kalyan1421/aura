import { Inject, Injectable, Logger } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { addDays } from '../rules';
import { CAP_EXEMPT, collapseKeyFor, DAILY_PUSH_CAP, TYPE_RULES } from './catalogue';
import { prefsFromRow } from './notification-prefs';
import {
  NOTIFICATION_TRANSPORT,
  type DeliveryResult,
  type DeviceTarget,
  type NotificationJobData,
  type NotificationTransport,
  type PushMessage,
} from './notification-types';
import { auraDayOf, cappedDecision, decide, endOfAuraDay, ignoredSoFar, reservedSlots, type DeliveryFacts, type SkipReason } from './policy';
import { fillMilestoneBFacts } from './kind-facts';
import { POOL_FLAGS } from './pool-waitlist';
import { milestoneBPrefsSql } from './prefs-milestone-b';
import { pushCopyKey, renderPushLine, resolvePushLocale } from './push-copy';
import { readTrialEndingFacts, trialEndingCopy } from './trial-ending';

export type DeliveryOutcome =
  | { status: 'sent'; devices: number; pruned: number }
  | { status: 'skipped'; reason: SkipReason }
  | { status: 'deferred'; until: Date }
  /** No install accepted it and none will (every token dead or refused): nothing to retry. */
  | { status: 'undelivered'; pruned: number };

/** No install accepted the push and at least one failure was temporary: the job is retried (BullMQ backoff). */
export class TransientDeliveryError extends Error {
  constructor(devices: number) {
    super(`push not delivered to any of ${devices} device(s) (temporary); will retry`);
    this.name = 'TransientDeliveryError';
  }
}

interface ContextRow {
  timezone: string;
  ui_locale: string;
  has_prefs: boolean;
  enabled: boolean;
  reminder_enabled: boolean;
  reminder_time: string | null;
  reminder_in_quiet_ok: boolean;
  capsule_enabled: boolean;
  quiet_start: string;
  quiet_end: string;
  discreet: boolean;
  field_ts: Record<string, unknown> | null;
  sent_day: string | null;
  sent_types: string[] | null;
  pending_deletion: boolean;
  [milestoneB: string]: unknown; // the Milestone B prefs columns (prefs-milestone-b.ts), read by prefsFromRow
}

/**
 * One push to one user under every global rule (policy.ts): reads the facts, decides, takes today's slot atomically,
 * renders the generic copy in the user's language (discreet-aware), hands it to the transport for each registered
 * install and prunes tokens FCM reports as `UNREGISTERED`. Logs carry types, reasons and counts only — never user
 * ids, record ids or tokens.
 */
@Injectable()
export class NotificationDelivery {
  private readonly logger = new Logger('Notifications');

  constructor(
    private readonly db: DbService,
    @Inject(NOTIFICATION_TRANSPORT) private readonly transport: NotificationTransport,
  ) {}

  get transportName(): string {
    return this.transport.name;
  }

  /** Reads everything the rules need for one push. */
  async facts(
    n: NotificationJobData,
    now: Date,
    createdAt: Date,
  ): Promise<{ facts: DeliveryFacts; locale: string | null; devices: DeviceTarget[]; unlockDate: string | null }> {
    const r = await this.db.query<ContextRow>(
      `select p.timezone, p.ui_locale, (np.user_id is not null) as has_prefs,
              np.enabled, np.reminder_enabled, np.reminder_time::text as reminder_time, np.reminder_in_quiet_ok,
              np.capsule_enabled, np.quiet_start::text as quiet_start, np.quiet_end::text as quiet_end, np.discreet,
              np.field_ts, np.sent_day, np.sent_types, ${milestoneBPrefsSql('np')},
              exists (select 1 from public.account_deletions d where d.user_id = p.user_id) as pending_deletion
         from public.profiles p
         left join public.notification_prefs np on np.user_id = p.user_id
        where p.user_id = $1`,
      [n.userId],
    );
    const row = r.rows[0];
    const tz = row?.timezone ?? null;
    const prefs = prefsFromRow(row?.has_prefs ? row : undefined).values;
    const devices = row
      ? (
          await this.db.query<DeviceTarget>(
            'select token, platform from public.device_tokens where user_id = $1 order by updated_at desc',
            [n.userId],
          )
        ).rows
      : [];
    const day = tz ? auraDayOf(now, tz) : null;
    const facts: DeliveryFacts = {
      type: n.type,
      now,
      createdAt,
      tz,
      prefs,
      pendingDeletion: row?.pending_deletion ?? false,
      devices: devices.length,
      sentToday: row?.sent_day && row.sent_day === day ? (row.sent_types ?? []) : [],
      expectedLater: [],
    };
    let unlockDate: string | null = null;
    if (tz && day) {
      if (n.type === 'daily_reminder') {
        facts.checkedInToday = await this.checkedIn(n.userId, day);
        // Rule 7 smart timing: how many reminders in a row went unanswered (policy.ts smartTimingSkip).
        const smart = await this.reminderHistory(n.userId);
        facts.reminderIgnored = ignoredSoFar(smart.ignored, smart.lastSentAt, smart.checkedInSince);
        facts.reminderSentYesterday = smart.lastSentAt !== null && auraDayOf(smart.lastSentAt, tz) === addDays(day, -1);
        if (prefs.capsuleUnlocked && (await this.capsuleDueLater(n.userId, now, endOfAuraDay(now, tz)))) {
          facts.expectedLater = ['capsule_unlocked'];
        }
      } else if (n.type === 'capsule_unlocked') {
        unlockDate = n.id === null ? null : await this.sealedCapsuleDate(n.userId, n.id);
        facts.capsuleSealed = unlockDate !== null;
      } else if (n.type === 'rooms_pool_open') {
        facts.poolOpen = await this.flagOn(POOL_FLAGS.hi);
      } else if (n.type === 'trial_ending') {
        facts.trialEnding = await readTrialEndingFacts(this.db, n, now); // F12 (trial-ending.ts)
      } else {
        await fillMilestoneBFacts(this.db, n, facts, now, tz); // F14 Milestone B kinds (kind-facts.ts)
      }
    }
    return { facts, locale: row?.ui_locale ?? null, devices, unlockDate };
  }

  /** Decide and maybe send. `createdAt` = when the push was requested (the job's timestamp; deferrals keep it). */
  async deliver(n: NotificationJobData, now = new Date(), createdAt = now): Promise<DeliveryOutcome> {
    const { facts, locale, devices, unlockDate } = await this.facts(n, now, createdAt);
    const decision = decide(facts);
    if (decision.action === 'skip') return { status: 'skipped', reason: decision.reason };
    if (decision.action === 'defer') return { status: 'deferred', until: decision.until };

    const day = auraDayOf(now, facts.tz as string);
    const limit = CAP_EXEMPT.includes(n.type) ? null : DAILY_PUSH_CAP - reservedSlots(n.type, facts.sentToday, facts.expectedLater);
    if (!(await this.reserve(n.userId, day, n.type, limit))) {
      const capped = cappedDecision(facts);
      return capped.action === 'defer' ? { status: 'deferred', until: capped.until } : { status: 'skipped', reason: 'capped' };
    }

    const message: PushMessage = {
      type: n.type,
      id: n.id,
      body: (() => {
        // Milestone B variants: "Someone …" / "{count} people …", a single preset habit's own line (push-copy.ts).
        const { key, params } =
          n.type === 'trial_ending' && facts.trialEnding
            ? trialEndingCopy(facts.trialEnding, facts.tz as string, resolvePushLocale(locale)) // F12: date + store price
            : pushCopyKey(n.type, facts);
        return renderPushLine(key, resolvePushLocale(locale), facts.prefs.discreet, params);
      })(),
      channelId: TYPE_RULES[n.type].channel,
      collapseKey: collapseKeyFor(n.type, unlockDate),
      ttlSeconds: TYPE_RULES[n.type].ttlSeconds,
    };
    const results = await Promise.all(
      devices.map(async (d): Promise<DeliveryResult> => {
        try {
          return await this.transport.send(d, message);
        } catch {
          return 'transient';
        }
      }),
    );
    const pruned = await this.prune(
      n.userId,
      devices.filter((_, i) => results[i] === 'unregistered').map((d) => d.token),
    );
    const sent = results.filter((x) => x === 'sent').length;
    if (sent === 0) {
      await this.release(n.userId, day, n.type); // nothing reached the person: the slot stays free
      if (results.includes('transient')) throw new TransientDeliveryError(devices.length);
      this.logger.warn(`push ${n.type}: not delivered (${results.join(',')})`);
      return { status: 'undelivered', pruned };
    }
    if (n.type === 'daily_reminder') await this.noteReminderSent(n.userId, now, facts.reminderIgnored ?? 0);
    // TODO(analytics, F14): emit `notification_sent { type }` here for 18+ accounts only
    // (public.user_is_minor(uid) = false); under-18 accounts are counted in aggregate only (PRD 12 rule 9,
    // 13-analytics). Wired by the analytics work; nothing is sent to analytics today.
    this.logger.log(`push ${n.type}: sent to ${sent}/${devices.length} device(s)${pruned ? `, pruned ${pruned}` : ''}`);
    return { status: 'sent', devices: sent, pruned };
  }

  /** Rule 7: the last reminder delivered, the stored ignored count, and whether any check-in arrived since. */
  private async reminderHistory(userId: string): Promise<{ lastSentAt: Date | null; ignored: number; checkedInSince: boolean }> {
    const r = await this.db.query<{ reminder_last_sent_at: Date | null; reminder_ignored: number; checked_since: boolean }>(
      `select a.reminder_last_sent_at, a.reminder_ignored,
              exists (select 1 from public.check_ins c
                       where c.user_id = a.user_id and c.server_ts > a.reminder_last_sent_at) as checked_since
         from public.notification_activity a where a.user_id = $1`,
      [userId],
    );
    const row = r.rows[0];
    return { lastSentAt: row?.reminder_last_sent_at ?? null, ignored: row?.reminder_ignored ?? 0, checkedInSince: row?.checked_since ?? false };
  }

  /** Rule 7: a delivered reminder becomes the one the next is measured against. Update only (the row exists once the
   *  account has written anything; creating it here would look like activity to the welcome-back sweep). */
  private async noteReminderSent(userId: string, at: Date, ignored: number): Promise<void> {
    await this.db.query('update public.notification_activity set reminder_last_sent_at = $2, reminder_ignored = $3 where user_id = $1', [
      userId,
      at,
      ignored,
    ]);
  }

  private async checkedIn(userId: string, day: string): Promise<boolean> {
    const r = await this.db.query(
      'select 1 from public.check_ins where user_id = $1 and local_day = $2 and not backfill limit 1',
      [userId, day],
    );
    return (r.rowCount ?? 0) > 0;
  }

  /** A feature flag straight from the table (not the API's cached config: the worker has none). Missing = off. */
  private async flagOn(key: string): Promise<boolean> {
    const r = await this.db.query<{ enabled: boolean }>('select enabled from public.feature_flags where key = $1', [key]);
    return r.rows[0]?.enabled === true;
  }

  /** The unlock date of the user's date capsule while it is still sealed (not opened, not deleted), else null. */
  private async sealedCapsuleDate(userId: string, capsuleId: string): Promise<string | null> {
    const r = await this.db.query<{ unlock_local_date: string }>(
      `select unlock_local_date from public.capsules
        where id = $1 and user_id = $2 and unlock_type = 'date' and deleted_at is null and opened_at is null`,
      [capsuleId, userId],
    );
    return r.rows[0]?.unlock_local_date ?? null;
  }

  /** A date-capsule push is still due later in this Aura day: precedence keeps its slot. */
  private async capsuleDueLater(userId: string, now: Date, dayEnd: Date): Promise<boolean> {
    const r = await this.db.query(
      `select 1 from public.capsule_unlock_schedule s
         join public.capsules c on c.id = s.capsule_id
        where c.user_id = $1 and s.notified_at is null and c.deleted_at is null and c.opened_at is null
          and s.notify_at > $2 and s.notify_at < $3
        limit 1`,
      [userId, now, dayEnd],
    );
    return (r.rowCount ?? 0) > 0;
  }

  /**
   * Takes today's slot for `type`, atomically (the row lock serialises concurrent pushes to one user): allowed when
   * the type is not in today's log yet and fewer than `limit` capped pushes are (`limit` = the cap minus the slots
   * kept for higher-priority pushes; null = cap-exempt). A new Aura day starts a fresh log. Creates the prefs row
   * (defaults) for someone who never changed a setting.
   */
  async reserve(userId: string, day: string, type: string, limit: number | null): Promise<boolean> {
    if (limit !== null && limit <= 0) return false;
    const r = await this.db.query(
      `insert into public.notification_prefs as np (user_id, sent_day, sent_types)
       values ($1, $2::date, array[$3::text])
       on conflict (user_id) do update set
         sent_day = excluded.sent_day,
         sent_types = case when np.sent_day = excluded.sent_day then array_append(np.sent_types, $3::text)
                           else array[$3::text] end
       where np.sent_day is distinct from excluded.sent_day
          or (not ($3::text = any(np.sent_types))
              and ($4::int is null
                   or (select count(*) from unnest(np.sent_types) t where t <> all($5::text[])) < $4::int))
       returning 1`,
      [userId, day, type, limit, [...CAP_EXEMPT]],
    );
    return (r.rowCount ?? 0) > 0;
  }

  /** Gives today's slot back (nothing was delivered). */
  async release(userId: string, day: string, type: string): Promise<void> {
    await this.db.query(
      `update public.notification_prefs set sent_types = array_remove(sent_types, $3::text)
        where user_id = $1 and sent_day = $2::date`,
      [userId, day, type],
    );
  }

  private async prune(userId: string, tokens: string[]): Promise<number> {
    if (tokens.length === 0) return 0;
    const r = await this.db.query('delete from public.device_tokens where user_id = $1 and token = any($2::text[])', [
      userId,
      tokens,
    ]);
    return r.rowCount ?? 0;
  }
}
