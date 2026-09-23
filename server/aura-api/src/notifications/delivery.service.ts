import { Inject, Injectable, Logger } from '@nestjs/common';
import { DbService } from '../db/db.service';
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
import { auraDayOf, decide, endOfAuraDay, reservedSlots, type DeliveryFacts, type SkipReason } from './policy';
import { renderPushBody, resolvePushLocale } from './push-copy';

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
              np.field_ts, np.sent_day, np.sent_types,
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
        if (prefs.capsuleUnlocked && (await this.capsuleDueLater(n.userId, now, endOfAuraDay(now, tz)))) {
          facts.expectedLater = ['capsule_unlocked'];
        }
      } else {
        unlockDate = n.id === null ? null : await this.sealedCapsuleDate(n.userId, n.id);
        facts.capsuleSealed = unlockDate !== null;
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
    if (!(await this.reserve(n.userId, day, n.type, limit))) return { status: 'skipped', reason: 'capped' };

    const message: PushMessage = {
      type: n.type,
      id: n.id,
      body: renderPushBody(n.type, resolvePushLocale(locale), facts.prefs.discreet),
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
    // TODO(analytics, F14): emit `notification_sent { type }` here for 18+ accounts only
    // (public.user_is_minor(uid) = false); under-18 accounts are counted in aggregate only (PRD 12 rule 9,
    // 13-analytics). Wired by the analytics work; nothing is sent to analytics today.
    this.logger.log(`push ${n.type}: sent to ${sent}/${devices.length} device(s)${pruned ? `, pruned ${pruned}` : ''}`);
    return { status: 'sent', devices: sent, pruned };
  }

  private async checkedIn(userId: string, day: string): Promise<boolean> {
    const r = await this.db.query(
      'select 1 from public.check_ins where user_id = $1 and local_day = $2 and not backfill limit 1',
      [userId, day],
    );
    return (r.rowCount ?? 0) > 0;
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
