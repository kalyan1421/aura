/**
 * NotificationDelivery + NotificationDispatcher (worker): the rules applied to real-shaped facts (fake DB routed by
 * statement shape, fake transport) — locale rendering and discreet copy, the atomic daily slot (cap, precedence,
 * per-type dedupe), pruning UNREGISTERED tokens, pending-deletion skip, retry on temporary failures, and the
 * quiet-hours deferral (same job re-delayed).
 */
import { Logger } from '@nestjs/common';
import { DelayedError } from 'bullmq';
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { capsuleNoticeId } from '../../src/notifications/catalogue';
import { NotificationDelivery, TransientDeliveryError } from '../../src/notifications/delivery.service';
import { DEFER_JITTER_MS, NotificationDispatcher } from '../../src/notifications/notification-dispatcher';
import type { DeliveryResult, DeviceTarget, NotificationJobData, PushMessage } from '../../src/notifications/notification-types';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const CAPSULE = '0192f0c3-1111-7c1a-9b3d-00000000beef';
const IST = 'Asia/Kolkata';
const DAY = '2026-10-08';
const at = (hh: number, mm = 0, day = DAY) => zonedInstant(day, hh, mm, IST);

interface PrefsState {
  enabled: boolean;
  reminder_enabled: boolean;
  reminder_time: string | null;
  reminder_in_quiet_ok: boolean;
  capsule_enabled: boolean;
  quiet_start: string;
  quiet_end: string;
  discreet: boolean;
  sent_day: string | null;
  sent_types: string[];
}

const defaults = (): PrefsState => ({
  enabled: true,
  reminder_enabled: false,
  reminder_time: null,
  reminder_in_quiet_ok: false,
  capsule_enabled: true,
  quiet_start: '23:00:00',
  quiet_end: '08:00:00',
  discreet: false,
  sent_day: null,
  sent_types: [],
});

class FakeDb {
  profile: { timezone: string; ui_locale: string } | null = { timezone: IST, ui_locale: 'en' };
  prefs: PrefsState | null = { ...defaults(), reminder_enabled: true, reminder_time: '20:00:00' };
  pendingDeletion = false;
  tokens: DeviceTarget[] = [{ token: 'tok-a', platform: 'android' }];
  checkedIn = new Set<string>();
  sealed = new Set<string>([CAPSULE]);
  capsuleDueLater = false;
  statements: string[] = [];

  async query(sql: string, params: unknown[] = []) {
    const s = sql.replace(/\s+/g, ' ').trim();
    this.statements.push(s.slice(0, 40));
    const ok = (rows: unknown[] = []) => ({ rows, rowCount: rows.length });
    if (s.startsWith('select p.timezone, p.ui_locale')) {
      if (!this.profile) return ok();
      const p = this.prefs;
      return ok([
        {
          ...this.profile,
          has_prefs: p !== null,
          ...(p ?? {}),
          field_ts: {},
          pending_deletion: this.pendingDeletion,
        },
      ]);
    }
    if (s.startsWith('select token, platform from public.device_tokens')) return ok(this.tokens.map((t) => ({ ...t })));
    if (s.startsWith('select 1 from public.check_ins')) return ok(this.checkedIn.has(params[1] as string) ? [{}] : []);
    if (s.startsWith('select unlock_local_date from public.capsules')) {
      return ok(this.sealed.has(params[0] as string) ? [{ unlock_local_date: '2027-10-08' }] : []);
    }
    if (s.startsWith('select 1 from public.capsule_unlock_schedule')) return ok(this.capsuleDueLater ? [{}] : []);
    if (s.startsWith('insert into public.notification_prefs as np (user_id, sent_day, sent_types)')) {
      const [, day, type, limit, exempt] = params as [string, string, string, number | null, string[]];
      const p = (this.prefs ??= defaults());
      if (p.sent_day !== day) {
        p.sent_day = day;
        p.sent_types = [type];
        return ok([{}]);
      }
      if (p.sent_types.includes(type)) return ok();
      if (limit !== null && p.sent_types.filter((t) => !exempt.includes(t)).length >= limit) return ok();
      p.sent_types.push(type);
      return ok([{}]);
    }
    if (s.startsWith('update public.notification_prefs set sent_types = array_remove')) {
      const [, day, type] = params as [string, string, string];
      if (this.prefs && this.prefs.sent_day === day) this.prefs.sent_types = this.prefs.sent_types.filter((t) => t !== type);
      return { rows: [], rowCount: 1 };
    }
    if (s.startsWith('delete from public.device_tokens')) {
      const dead = params[1] as string[];
      const before = this.tokens.length;
      this.tokens = this.tokens.filter((t) => !dead.includes(t.token));
      return { rows: [], rowCount: before - this.tokens.length };
    }
    throw new Error(`unexpected SQL: ${s.slice(0, 90)}`);
  }
}

class FakeTransport {
  readonly name = 'fake';
  sent: { target: DeviceTarget; message: PushMessage }[] = [];
  results = new Map<string, DeliveryResult | Error>();
  async send(target: DeviceTarget, message: PushMessage): Promise<DeliveryResult> {
    const r = this.results.get(target.token);
    if (r instanceof Error) throw r;
    this.sent.push({ target, message });
    return r ?? 'sent';
  }
}

const reminder: NotificationJobData = { userId: USER, type: 'daily_reminder', id: null };
const capsule: NotificationJobData = { userId: USER, type: 'capsule_unlocked', id: CAPSULE };

function harness() {
  const db = new FakeDb();
  const transport = new FakeTransport();
  const delivery = new NotificationDelivery(db as never, transport);
  return { db, transport, delivery };
}

beforeAll(() => {
  Logger.overrideLogger(false);
});

describe('NotificationDelivery', () => {
  it('sends the reminder at its time to every install, in English by default, and logs it for today', async () => {
    const h = harness();
    h.db.tokens.push({ token: 'tok-b', platform: 'ios' });
    expect(await h.delivery.deliver(reminder, at(20))).toEqual({ status: 'sent', devices: 2, pruned: 0 });
    expect(h.transport.sent.map((s) => s.target.token)).toEqual(['tok-a', 'tok-b']);
    expect(h.transport.sent[0].message).toEqual({
      type: 'daily_reminder',
      id: null,
      body: "A quiet minute for you. How's today feeling?",
      channelId: 'reminders',
      collapseKey: 'daily_reminder',
      ttlSeconds: 7200,
    });
    expect(h.db.prefs).toMatchObject({ sent_day: DAY, sent_types: ['daily_reminder'] });
  });

  it("renders in the user's app language; discreet mode sends the one gentle line for every type", async () => {
    const h = harness();
    h.db.profile = { timezone: IST, ui_locale: 'te-Latn' };
    await h.delivery.deliver(reminder, at(20));
    expect(h.transport.sent[0].message.body).toBe('Mee kosam oka quiet minute. Ee roju ela anipistondi?');

    const d = harness();
    d.db.profile = { timezone: IST, ui_locale: 'hi' }; // Hindi: English until beta
    d.db.prefs = { ...d.db.prefs!, discreet: true };
    await d.delivery.deliver(capsule, at(10));
    expect(d.transport.sent[0].message).toMatchObject({
      type: 'capsule_unlocked',
      id: CAPSULE,
      body: 'You have a gentle update',
      channelId: 'capsules',
      collapseKey: String(capsuleNoticeId('2027-10-08')),
    });
  });

  it('a capsule push works without a prefs row (defaults) and creates it only to log the send', async () => {
    const h = harness();
    h.db.prefs = null;
    expect(await h.delivery.deliver(capsule, at(10))).toMatchObject({ status: 'sent' });
    expect(h.db.prefs).toMatchObject({ sent_day: DAY, sent_types: ['capsule_unlocked'], enabled: true });
  });

  it('prunes tokens FCM reports UNREGISTERED; the push still counts when another install got it', async () => {
    const h = harness();
    h.db.tokens = [
      { token: 'dead', platform: 'android' },
      { token: 'live', platform: 'ios' },
    ];
    h.transport.results.set('dead', 'unregistered');
    expect(await h.delivery.deliver(reminder, at(20))).toEqual({ status: 'sent', devices: 1, pruned: 1 });
    expect(h.db.tokens.map((t) => t.token)).toEqual(['live']);
  });

  it('nothing delivered (all tokens dead) → undelivered, tokens pruned, the slot given back', async () => {
    const h = harness();
    h.transport.results.set('tok-a', 'unregistered');
    expect(await h.delivery.deliver(reminder, at(20))).toEqual({ status: 'undelivered', pruned: 1 });
    expect(h.db.tokens).toEqual([]);
    expect(h.db.prefs?.sent_types).toEqual([]);
  });

  it('a temporary failure on every install → the slot is given back and the job retries', async () => {
    const h = harness();
    h.transport.results.set('tok-a', 'transient');
    await expect(h.delivery.deliver(reminder, at(20))).rejects.toBeInstanceOf(TransientDeliveryError);
    expect(h.db.prefs?.sent_types).toEqual([]);
    h.transport.results.set('tok-a', new Error('socket hang up'));
    await expect(h.delivery.deliver(reminder, at(20))).rejects.toBeInstanceOf(TransientDeliveryError);
    h.transport.results.delete('tok-a');
    expect(await h.delivery.deliver(reminder, at(20))).toMatchObject({ status: 'sent' });
  });

  it('never sends to an account with a scheduled deletion (nor reads further)', async () => {
    const h = harness();
    h.db.pendingDeletion = true;
    expect(await h.delivery.deliver(reminder, at(20))).toEqual({ status: 'skipped', reason: 'pending_deletion' });
    expect(h.transport.sent).toEqual([]);
  });

  it('signed-out installs have no token: nothing to send; no profile: nothing either', async () => {
    const h = harness();
    h.db.tokens = [];
    expect(await h.delivery.deliver(reminder, at(20))).toEqual({ status: 'skipped', reason: 'no_device' });
    h.db.profile = null;
    expect(await h.delivery.deliver(reminder, at(20))).toEqual({ status: 'skipped', reason: 'no_profile' });
  });

  it('skips the reminder once the user checked in that Aura day (synced check-ins)', async () => {
    const h = harness();
    h.db.checkedIn.add(DAY);
    expect(await h.delivery.deliver(reminder, at(20))).toEqual({ status: 'skipped', reason: 'checked_in' });
    // just after midnight it is still the same Aura day (04:00 rollover)
    const late = harness();
    late.db.checkedIn.add(DAY);
    late.db.prefs = { ...late.db.prefs!, reminder_time: '00:30:00', reminder_in_quiet_ok: true };
    expect(await late.delivery.deliver(reminder, at(0, 30, '2026-10-09'))).toEqual({ status: 'skipped', reason: 'checked_in' });
  });

  it('a capsule push only while the capsule is still sealed', async () => {
    const h = harness();
    h.db.sealed.clear();
    expect(await h.delivery.deliver(capsule, at(10))).toEqual({ status: 'skipped', reason: 'not_sealed' });
  });

  it('REQ-NTF-02: a third push in one local day is never sent; the same type never twice', async () => {
    const h = harness();
    h.db.prefs = { ...h.db.prefs!, sent_day: DAY, sent_types: ['gestures_received', 'lantern_hour'] };
    expect(await h.delivery.deliver(capsule, at(10))).toEqual({ status: 'skipped', reason: 'capped' });
    h.db.prefs = { ...h.db.prefs, sent_types: ['capsule_unlocked'] };
    expect(await h.delivery.deliver(capsule, at(11))).toEqual({ status: 'skipped', reason: 'already_sent' });
    expect(await h.delivery.deliver(reminder, at(20))).toMatchObject({ status: 'sent' }); // the second push of the day
    expect(h.transport.sent).toHaveLength(1);
  });

  it("precedence: the reminder yields the day's last slot to a capsule push still due later today", async () => {
    const h = harness();
    h.db.prefs = { ...h.db.prefs!, reminder_time: '09:00:00', sent_day: DAY, sent_types: ['gestures_received'] };
    h.db.capsuleDueLater = true;
    expect(await h.delivery.deliver(reminder, at(9))).toEqual({ status: 'skipped', reason: 'capped' });
    // with the capsule pushes switched off, nothing is expected: the reminder goes
    h.db.prefs = { ...h.db.prefs, capsule_enabled: false };
    expect(await h.delivery.deliver(reminder, at(9))).toMatchObject({ status: 'sent' });
  });

  it('the slot is taken atomically: two concurrent copies of one push send once', async () => {
    const h = harness();
    const [a, b] = await Promise.all([h.delivery.deliver(reminder, at(20)), h.delivery.deliver(reminder, at(20))]);
    expect([a.status, b.status].sort()).toEqual(['sent', 'skipped']);
    expect(h.transport.sent).toHaveLength(1);
  });

  it('a new Aura day starts a fresh log', async () => {
    const h = harness();
    h.db.prefs = { ...h.db.prefs!, sent_day: '2026-10-07', sent_types: ['capsule_unlocked', 'daily_reminder'] };
    expect(await h.delivery.deliver(reminder, at(20))).toMatchObject({ status: 'sent' });
    expect(h.db.prefs).toMatchObject({ sent_day: DAY, sent_types: ['daily_reminder'] });
  });
});

describe('NotificationDispatcher', () => {
  const job = (data: NotificationJobData, timestamp: number) => ({
    name: 'push',
    data,
    timestamp,
    moveToDelayed: jest.fn(async () => undefined),
  });

  it('quiet hours: the capsule push is re-delayed in place to their end (+ jitter), not failed', async () => {
    const h = harness();
    h.db.prefs = { ...h.db.prefs!, quiet_start: '22:00:00', quiet_end: '11:00:00' };
    const d = new NotificationDispatcher(h.delivery, {} as never);
    const j = job(capsule, at(10).getTime());
    await expect(d.handle(j as never, 'lock-token', at(10))).rejects.toBeInstanceOf(DelayedError);
    const [when, token] = j.moveToDelayed.mock.calls[0] as unknown as [number, string];
    expect(token).toBe('lock-token');
    expect(when).toBeGreaterThanOrEqual(at(11).getTime());
    expect(when).toBeLessThan(at(11).getTime() + DEFER_JITTER_MS);
    expect(h.transport.sent).toEqual([]);

    // when it runs again after the quiet hours, it is sent
    await d.handle(j as never, 'lock-token', at(11, 3));
    expect(h.transport.sent).toHaveLength(1);
  });

  it('uses the job timestamp as the request time (a stale reminder is dropped)', async () => {
    const h = harness();
    const d = new NotificationDispatcher(h.delivery, {} as never);
    await d.handle(job(reminder, at(17).getTime()) as never, undefined, at(20));
    expect(h.transport.sent).toEqual([]);
  });

  it('routes the reminder jobs to the scheduler and ignores unknown names', async () => {
    const reminders = { sweep: jest.fn(async () => ({ due: 0, enqueued: 0, moved: 0 })), reconcile: jest.fn(async () => 0) };
    const d = new NotificationDispatcher({} as never, reminders as never);
    await d.handle({ name: 'reminder-sweep' } as never);
    await d.handle({ name: 'reminder-reconcile' } as never);
    await d.handle({ name: 'something-else' } as never);
    expect(reminders.sweep).toHaveBeenCalledTimes(1);
    expect(reminders.reconcile).toHaveBeenCalledTimes(1);
  });
});
