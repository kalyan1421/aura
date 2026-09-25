/**
 * F14 notifications end to end (contracts/api/v1-notifications.md): real Nest app + live local Supabase + Redis, with
 * the push transport replaced by a fake (no FCM). Prefs sync (per-field LWW, select-own pull) → the daily reminder
 * is planned in the profile zone → the minute sweep enqueues one content-free job → the worker's dispatcher delivers
 * it through the global rules (locale, discreet, skip after a check-in, pending deletion) → the 2/day cap holds in
 * the real SQL, and tokens FCM reports UNREGISTERED are pruned.
 *
 * Time: every user gets an `Etc/GMT±N` zone where it is around midday right now, so the reminder (one hour ahead)
 * lands the same local day and outside quiet hours whenever the suite runs.
 */
import { randomBytes } from 'node:crypto';
import { Logger, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import type { Pool } from 'pg';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { configureApp } from '../../src/bootstrap';
import { addDays, localDate } from '../../src/rules';
import { uuidv7 } from '../../src/common/uuid';
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { capsuleNoticeId } from '../../src/notifications/catalogue';
import { NotificationDelivery } from '../../src/notifications/delivery.service';
import { NotificationDispatcher } from '../../src/notifications/notification-dispatcher';
import {
  NOTIFICATION_JOB,
  NOTIFICATION_TRANSPORT,
  type DeliveryResult,
  type DeviceTarget,
  type NotificationTransport,
  type PushMessage,
} from '../../src/notifications/notification-types';
import { auraDayOf, minutesOfDay } from '../../src/notifications/policy';
import { ReminderScheduler } from '../../src/notifications/reminder.service';
import { QueuesService } from '../../src/queues/queues.service';
import { createUser, dbPool, deleteUser, localAnonKey, SUPABASE_URL, type TestUser } from './support';

class FakeTransport implements NotificationTransport {
  readonly name = 'e2e-fake';
  sent: { target: DeviceTarget; message: PushMessage }[] = [];
  results = new Map<string, DeliveryResult>();
  async send(target: DeviceTarget, message: PushMessage): Promise<DeliveryResult> {
    const r = this.results.get(target.token) ?? 'sent';
    if (r === 'sent') this.sent.push({ target, message });
    return r;
  }
  to(token: string) {
    return this.sent.filter((s) => s.target.token === token).map((s) => s.message);
  }
}

/** An Etc/GMT zone where it is 11:00–12:59 now (POSIX sign: Etc/GMT-5 is UTC+5). */
function middayZone(now = new Date()): string {
  const want = 12 - now.getUTCHours(); // hours to add to UTC
  const offset = ((want + 36) % 24) - 12; // −12 … +11
  return offset === 0 ? 'Etc/GMT' : `Etc/GMT${offset > 0 ? '-' : '+'}${Math.abs(offset)}`;
}
const hm = (minutes: number) => `${String(Math.floor(minutes / 60) % 24).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;

describe('F14 notifications (e2e, live local Supabase + Redis, fake transport)', () => {
  let app: INestApplication;
  let db: Pool;
  const transport = new FakeTransport();
  const users: TestUser[] = [];
  const TZ = middayZone();
  const DEVICE = uuidv7();

  const http = () => request(app.getHttpServer());
  const as = (u: TestUser, r: request.Test) => r.set('Authorization', `Bearer ${u.token}`);
  const newUser = async (label: string, uiLocale = 'te-Latn'): Promise<TestUser> => {
    const u = await createUser(`ntf-${label}`);
    users.push(u);
    await as(u, http().post('/v1/profile')).send({ birthDate: '2004-02-10', uiLocale, timezone: TZ, country: 'IN' }).expect(200);
    return u;
  };
  const token = () => `e2e-fcm-${randomBytes(16).toString('hex')}`;
  const register = async (u: TestUser, t = token(), platform = 'android') => {
    await as(u, http().put('/v1/devices')).send({ token: t, platform }).expect(204);
    return t;
  };
  const prefsMutation = (payload: Record<string, unknown>, deviceTs = new Date()) => ({
    id: uuidv7(),
    entity: 'notification_prefs',
    op: 'upsert',
    deviceTs: deviceTs.toISOString(),
    localDay: localDate(deviceTs, TZ),
    tz: TZ,
    payload,
  });
  const push = async (u: TestUser, mutations: unknown[]): Promise<string[]> =>
    (await as(u, http().post('/v1/sync/push')).send({ deviceId: DEVICE, mutations }).expect(200)).body.results.map(
      (r: { status: string; reason?: string }) => r.reason ?? r.status,
    );
  const prefsRow = async (u: TestUser) =>
    (
      await db.query(
        `select enabled, reminder_enabled, reminder_time::text as reminder_time, discreet, field_ts, reminder_next_at,
                reminder_tz, sent_day, sent_types from public.notification_prefs where user_id = $1`,
        [u.id],
      )
    ).rows[0] as Record<string, unknown> | undefined;
  /** The reminder one hour from now, in the user's (midday) zone. */
  const reminderTime = () => hm(minutesOfDay(new Date(), TZ) + 60);
  const plannedFor = (time: string) => {
    const [h, m] = time.split(':').map(Number);
    return zonedInstant(localDate(new Date(), TZ), h, m, TZ);
  };
  const queuedFor = async (u: TestUser) => {
    const q = app.get(QueuesService).queue('notifications');
    return (await q.getJobs(['waiting', 'prioritized', 'delayed'])).filter((j) => j.data?.userId === u.id);
  };
  /** What the worker does with a push job (timestamp = when it was requested). */
  const runJob = (data: Record<string, unknown>, at: Date) =>
    app.get(NotificationDispatcher).handle({ name: NOTIFICATION_JOB, data, timestamp: at.getTime() } as never, undefined, at);

  beforeAll(async () => {
    Logger.overrideLogger(['error']);
    const ref = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(NOTIFICATION_TRANSPORT)
      .useValue(transport)
      .compile();
    app = ref.createNestApplication({ bodyParser: false });
    configureApp(app);
    await app.init();
    await app.listen(0, '127.0.0.1');
    db = dbPool();
  });

  afterAll(async () => {
    const q = app.get(QueuesService).queue('notifications');
    for (const j of await q.getJobs(['waiting', 'prioritized', 'delayed'])) {
      if (users.some((u) => u.id === j.data?.userId)) await j.remove().catch(() => undefined);
    }
    for (const u of users) await deleteUser(u.id);
    await db.end();
    await app.close();
  });

  it('prefs sync → reminder planned in the profile zone → one content-free job → sent in the app language → logged', async () => {
    expect(app.get(NotificationDelivery).transportName).toBe('e2e-fake');
    const u = await newUser('reminder');
    const t = await register(u);
    const time = reminderTime();
    expect(await push(u, [prefsMutation({ reminderEnabled: true, reminderTime: time })])).toEqual(['applied']);

    const planned = plannedFor(time);
    const row = await prefsRow(u);
    expect(row).toMatchObject({ enabled: true, reminder_enabled: true, reminder_time: `${time}:00`, reminder_tz: TZ });
    expect((row?.reminder_next_at as Date).getTime()).toBe(planned.getTime());

    // the app's pull: select-own on public.notification_prefs with the user's JWT
    const pulled = await fetch(`${SUPABASE_URL}/rest/v1/notification_prefs?select=*`, {
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${u.token}` },
    });
    const body = (await pulled.json()) as Record<string, unknown>[];
    expect(body).toHaveLength(1);
    expect(body[0]).toMatchObject({ user_id: u.id, reminder_enabled: true, reminder_time: `${time}:00`, quiet_start: '23:00:00' });
    expect(Object.keys(body[0].field_ts as object).sort()).toEqual(['reminderEnabled', 'reminderTime']);

    // a minute early: nothing is due
    const sweeper = app.get(ReminderScheduler);
    expect((await sweeper.sweep(new Date(planned.getTime() - 60_000))).enqueued).toBe(0);
    expect(await queuedFor(u)).toHaveLength(0);

    // its minute: claimed and enqueued once; the job carries who and what, nothing else
    expect((await sweeper.sweep(planned)).enqueued).toBeGreaterThanOrEqual(1);
    const jobs = await queuedFor(u);
    expect(jobs.map((j) => j.data)).toEqual([{ userId: u.id, type: 'daily_reminder', id: null }]);
    expect(jobs[0].id).not.toContain(u.id);
    expect((await sweeper.sweep(planned)).enqueued).toBe(0); // moved on to tomorrow: no second job
    expect(((await prefsRow(u))?.reminder_next_at as Date).getTime()).toBe(plannedFor(time).getTime() + 86_400_000);

    await runJob(jobs[0].data, planned);
    await jobs[0].remove();
    expect(transport.to(t)).toEqual([
      {
        type: 'daily_reminder',
        id: null,
        body: 'Mee kosam oka quiet minute. Ee roju ela anipistondi?',
        channelId: 'reminders',
        collapseKey: 'daily_reminder',
        ttlSeconds: 7200,
      },
    ]);
    expect(await prefsRow(u)).toMatchObject({ sent_day: auraDayOf(planned, TZ), sent_types: ['daily_reminder'] });

    // the same reminder again the same Aura day → never twice
    await runJob({ userId: u.id, type: 'daily_reminder', id: null }, new Date(planned.getTime() + 60_000));
    expect(transport.to(t)).toHaveLength(1);
  });

  it('REQ-NTF-02: the 2/day cap holds in the real SQL — a third push in one local day is never sent', async () => {
    const u = await newUser('cap', 'en');
    const t = await register(u);
    const sealDay = localDate(new Date(), TZ);
    const capsuleId = uuidv7();
    const seal = {
      id: uuidv7(),
      entity: 'capsule',
      op: 'seal',
      deviceTs: new Date().toISOString(),
      tz: TZ,
      payload: { id: capsuleId, payloadCt: randomBytes(48).toString('base64'), unlockType: 'date', unlockLocalDate: addDays(sealDay, 30) },
    };
    expect(await push(u, [seal])).toEqual(['applied']);
    const now = new Date();
    // two pushes already out today (a future type stands in for the second)
    await db.query(
      `insert into public.notification_prefs (user_id, sent_day, sent_types) values ($1, $2, $3)
       on conflict (user_id) do update set sent_day = excluded.sent_day, sent_types = excluded.sent_types`,
      [u.id, auraDayOf(now, TZ), ['daily_reminder', 'gestures_received']],
    );
    const out = await app.get(NotificationDelivery).deliver({ userId: u.id, type: 'capsule_unlocked', id: capsuleId }, now);
    expect(out).toEqual({ status: 'skipped', reason: 'capped' });
    expect(transport.to(t)).toEqual([]);

    // with one slot free it goes — as the capsule's own notice id (replaces the app's local notice)
    await db.query(`update public.notification_prefs set sent_types = '{daily_reminder}' where user_id = $1`, [u.id]);
    expect(await app.get(NotificationDelivery).deliver({ userId: u.id, type: 'capsule_unlocked', id: capsuleId }, now)).toMatchObject({
      status: 'sent',
    });
    expect(transport.to(t)).toEqual([
      expect.objectContaining({
        type: 'capsule_unlocked',
        id: capsuleId,
        body: 'Something you sealed is ready to open.',
        collapseKey: String(capsuleNoticeId(addDays(sealDay, 30))),
      }),
    ]);
    expect((await prefsRow(u))?.sent_types).toEqual(['daily_reminder', 'capsule_unlocked']);
  });

  it('skipped after a check-in that Aura day; discreet mode; toggles; last-write-wins per field', async () => {
    const u = await newUser('rules');
    const t = await register(u);
    const time = reminderTime();
    const planned = plannedFor(time);
    const now = new Date();
    expect(await push(u, [prefsMutation({ reminderEnabled: true, reminderTime: time })])).toEqual(['applied']);

    // an older edit from another phone doesn't undo a newer one; a newer edit of another field lands
    expect(await push(u, [prefsMutation({ reminderEnabled: false }, new Date(now.getTime() - 3_600_000))])).toEqual(['applied']);
    expect((await prefsRow(u))?.reminder_enabled).toBe(true);
    expect(await push(u, [prefsMutation({ discreet: true })])).toEqual(['applied']);
    expect(await prefsRow(u)).toMatchObject({ reminder_enabled: true, discreet: true });
    expect(await push(u, [prefsMutation({ reminderTime: '25:00' }), prefsMutation({})])).toEqual(['invalid_payload', 'invalid_payload']);

    // discreet: the one gentle line (Tenglish)
    const delivery = app.get(NotificationDelivery);
    expect(await delivery.deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned)).toMatchObject({ status: 'sent' });
    expect(transport.to(t).map((m) => m.body)).toEqual(['Meeku oka gentle update undi']);

    // a check-in that Aura day → the reminder is skipped (log cleared to isolate the rule)
    await db.query(`update public.notification_prefs set sent_types = '{}' where user_id = $1`, [u.id]);
    const checkIn = {
      id: uuidv7(),
      entity: 'check_in',
      op: 'upsert',
      deviceTs: now.toISOString(),
      localDay: auraDayOf(now, TZ),
      tz: TZ,
      payload: { id: uuidv7(), moodId: 'calm', tags: [] },
    };
    expect(await push(u, [checkIn])).toEqual(['applied']);
    expect(await delivery.deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned)).toEqual({
      status: 'skipped',
      reason: 'checked_in',
    });

    // the per-type toggle and the master switch
    expect(await push(u, [prefsMutation({ capsuleUnlocked: false })])).toEqual(['applied']);
    expect(await delivery.deliver({ userId: u.id, type: 'capsule_unlocked', id: uuidv7() }, planned)).toEqual({
      status: 'skipped',
      reason: 'type_disabled',
    });
    expect(await push(u, [prefsMutation({ enabled: false })])).toEqual(['applied']);
    expect(await prefsRow(u)).toMatchObject({ enabled: false, reminder_next_at: null, reminder_tz: null });
    expect(await delivery.deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned)).toEqual({ status: 'skipped', reason: 'disabled' });
    expect(transport.to(t)).toHaveLength(1);
  });

  it('rule 7 smart timing in the real SQL: ignored reminders back off to every other day, then stop; a check-in restores them', async () => {
    const u = await newUser('smart');
    const t = await register(u);
    const time = reminderTime();
    const planned = plannedFor(time);
    expect(await push(u, [prefsMutation({ reminderEnabled: true, reminderTime: time })])).toEqual(['applied']);
    const delivery = app.get(NotificationDelivery);
    const clearLog = () => db.query(`update public.notification_prefs set sent_types = '{}' where user_id = $1`, [u.id]);
    const history = async () =>
      (await db.query<{ reminder_ignored: number }>('select reminder_ignored from public.notification_activity where user_id = $1', [u.id])).rows[0];

    // The first reminder goes out and becomes the one the next is measured against.
    expect(await delivery.deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned)).toMatchObject({ status: 'sent' });
    expect(await history()).toEqual({ reminder_ignored: 0 });

    // Four ignored in a row, the last one yesterday → 5 now: every other day, so today waits.
    const yesterday = new Date(planned.getTime() - 24 * 3_600_000);
    await db.query('update public.notification_activity set reminder_ignored = 4, reminder_last_sent_at = $2 where user_id = $1', [u.id, yesterday]);
    await clearLog();
    expect(await delivery.deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned)).toEqual({ status: 'skipped', reason: 'reminder_backoff' });

    // 13 ignored before this one → stopped (welcome-back takes over).
    await db.query('update public.notification_activity set reminder_ignored = 13 where user_id = $1', [u.id]);
    expect(await delivery.deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned)).toEqual({ status: 'skipped', reason: 'reminder_paused' });

    // Any check-in after the last reminder restores the daily schedule (a backfill for an earlier day counts too).
    const earlier = new Date(Date.now() - 2 * 24 * 3_600_000);
    const backfill = {
      id: uuidv7(),
      entity: 'check_in',
      op: 'upsert',
      deviceTs: earlier.toISOString(),
      localDay: auraDayOf(earlier, TZ),
      tz: TZ,
      payload: { id: uuidv7(), moodId: 'calm', tags: [] },
    };
    expect(await push(u, [backfill])).toEqual(['applied']);
    const before = transport.to(t).length;
    expect(await delivery.deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned)).toMatchObject({ status: 'sent' });
    expect(transport.to(t)).toHaveLength(before + 1);
    expect(await history()).toEqual({ reminder_ignored: 0 });
  });

  it('prunes tokens FCM reports UNREGISTERED; never sends during a scheduled deletion', async () => {
    const u = await newUser('prune', 'en');
    const dead = await register(u);
    const live = await register(u, token(), 'ios');
    transport.results.set(dead, 'unregistered');
    const time = reminderTime();
    expect(await push(u, [prefsMutation({ reminderEnabled: true, reminderTime: time })])).toEqual(['applied']);
    const planned = plannedFor(time);
    const out = await app.get(NotificationDelivery).deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned, planned);
    expect(out).toEqual({ status: 'sent', devices: 1, pruned: 1 });
    const tokens = (await db.query('select token from public.device_tokens where user_id = $1', [u.id])).rows.map((r) => r.token);
    expect(tokens).toEqual([live]);

    await as(u, http().post('/v1/account/deletion')).expect(202);
    await db.query(`update public.notification_prefs set sent_types = '{}' where user_id = $1`, [u.id]);
    expect(await app.get(NotificationDelivery).deliver({ userId: u.id, type: 'daily_reminder', id: null }, planned, planned)).toEqual({
      status: 'skipped',
      reason: 'pending_deletion',
    });
    // …and the sweep leaves accounts with a scheduled deletion out
    const before = (await queuedFor(u)).length;
    await app.get(ReminderScheduler).sweep(new Date(planned.getTime() + 86_400_000));
    expect((await queuedFor(u)).length).toBe(before);
  });

  it('prefs are select-own: another user reads nothing, clients cannot write them', async () => {
    const a = await newUser('iso-a');
    const b = await newUser('iso-b');
    expect(await push(a, [prefsMutation({ discreet: true })])).toEqual(['applied']);
    const read = await fetch(`${SUPABASE_URL}/rest/v1/notification_prefs?select=user_id`, {
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${b.token}` },
    });
    expect(await read.json()).toEqual([]);
    const write = await fetch(`${SUPABASE_URL}/rest/v1/notification_prefs?user_id=eq.${a.id}`, {
      method: 'PATCH',
      headers: { apikey: localAnonKey(), Authorization: `Bearer ${a.token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ sent_types: [] }),
    });
    expect(write.status).toBe(403);
    await write.arrayBuffer();
  });
});
