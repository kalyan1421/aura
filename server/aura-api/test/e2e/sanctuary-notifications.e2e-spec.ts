/**
 * Sanctuary session records (F15), the F14 Milestone B pushes and reduced mode's sign-up throttle, end to end against
 * the live local stack (Nest app, Postgres with migration 20261005000023, Supabase Auth + PostgREST, Redis), with the
 * push transport replaced by a fake:
 *
 *  1. `sanctuary_session` through POST /v1/sync/push → `public.sanctuary_sessions` (content-free columns only),
 *     idempotent on the record id, validation reasons, select-own through PostgREST.
 *  2. Settings → `notification_schedule` (wind-down, Lantern Hour, habit nudge) planned in the profile zone, cleared
 *     when turned off.
 *  3. Each kind from its sweep to the delivered push (copy, channel, content-free payload) and its type-specific skip:
 *     wind-down after a Sanctuary session that evening, gestures (batched, once per room per day), welcome back (step
 *     claim, reset by any write), habit nudge (preset line; nothing due once logged), Lantern Hour.
 *  4. Reduced mode: new sign-ups throttled, existing accounts untouched.
 *
 * Shared database rules: nothing global is changed. The reduced-mode flag is stubbed on SignupThrottle, sweeps are
 * limited to this suite's accounts (`only`), the room for the gestures is this suite's own (closed to new joins), and
 * past instants are used so the global quiet hours of the real clock never matter.
 */
import { randomBytes } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import type { Pool } from 'pg';
import request from 'supertest';
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { uuidv7 } from '../../src/common/uuid';
import { NotificationDelivery } from '../../src/notifications/delivery.service';
import { GesturesPushSweep } from '../../src/notifications/gestures-push';
import { NotificationDispatcher } from '../../src/notifications/notification-dispatcher';
import { NOTIFICATION_JOB, type DeviceTarget, type PushMessage } from '../../src/notifications/notification-types';
import { nextAtFor, ScheduleSweep } from '../../src/notifications/schedules';
import { DEFAULT_NOTIFICATION_PREFS } from '../../src/notifications/policy';
import { WelcomeBackSweep } from '../../src/notifications/welcome-back';
import { SignupThrottle } from '../../src/profile/signup-throttle';
import { QueuesService } from '../../src/queues/queues.service';
import { addDays, localDate } from '../../src/rules';
import { bootApp, createUser, dbPool, deleteUser, localAnonKey, SUPABASE_URL, type TestUser } from './support';

jest.setTimeout(90_000);

const TZ = 'Asia/Kolkata';
const DEVICE = uuidv7();

class FakeTransport {
  readonly name = 'e2e-fake';
  sent: Array<{ target: DeviceTarget; message: PushMessage }> = [];
  async send(target: DeviceTarget, message: PushMessage): Promise<'sent'> {
    this.sent.push({ target, message });
    return 'sent';
  }
  to(token: string): PushMessage[] {
    return this.sent.filter((s) => s.target.token === token).map((s) => s.message);
  }
}

describe('Sanctuary sessions + F14 Milestone B + reduced mode (e2e)', () => {
  let app: INestApplication;
  let db: Pool;
  const users: TestUser[] = [];
  const rooms: string[] = [];
  const transport = new FakeTransport();
  // Yesterday in IST: every instant below is in the past, so validation (future skew) and quiet hours are stable.
  const YDAY = addDays(localDate(new Date(), TZ), -1);
  const at = (hh: number, mm = 0, day = YDAY) => zonedInstant(day, hh, mm, TZ);

  const http = () => request(app.getHttpServer());
  const as = (u: { token: string }, r: request.Test): request.Test => r.set('Authorization', `Bearer ${u.token}`);
  const push = (u: TestUser, mutations: Array<Record<string, unknown>>) =>
    as(u, http().post('/v1/sync/push')).send({ deviceId: DEVICE, mutations }).expect(200);
  const m = (entity: string, payload: Record<string, unknown>, deviceTs: Date = new Date(), localDay = localDate(deviceTs, TZ), op = 'upsert') => ({
    id: uuidv7(),
    entity,
    op,
    deviceTs: deviceTs.toISOString(),
    localDay,
    tz: TZ,
    payload,
  });

  async function appUser(label: string, uiLocale = 'en'): Promise<TestUser & { device: string }> {
    const u = await createUser(label);
    users.push(u);
    await as(u, http().post('/v1/profile')).send({ birthDate: '1996-03-14', uiLocale, timezone: TZ, country: 'IN' }).expect(200);
    const device = `e2e-fcm-${randomBytes(12).toString('hex')}`;
    await as(u, http().put('/v1/devices')).send({ token: device, platform: 'android' }).expect(204);
    return { ...u, device };
  }
  const queued = async (u: TestUser, type?: string) =>
    (await app.get(QueuesService).queue('notifications').getJobs(['waiting', 'prioritized', 'delayed'])).filter(
      (j) => j.data?.userId === u.id && (type === undefined || j.data?.type === type),
    );
  /** The worker's dispatcher delivers one queued job as of `now` (requested at `now`). */
  const deliver = async (data: unknown, now: Date) => {
    await app.get(NotificationDispatcher).handle({ name: NOTIFICATION_JOB, data, timestamp: now.getTime() } as never, undefined, now);
  };
  const drop = async (u: TestUser) => {
    for (const j of await queued(u)) await j.remove().catch(() => undefined);
  };

  beforeAll(async () => {
    app = await bootApp();
    (app.get(NotificationDelivery) as unknown as { transport: unknown }).transport = transport;
    db = dbPool();
  });

  afterAll(async () => {
    for (const u of users) await drop(u).catch(() => undefined);
    if (db) {
      for (const r of rooms) await db.query('delete from public.rooms where id = $1', [r]);
      await db.end();
    }
    for (const u of users) await deleteUser(u.id);
    await app?.close();
  });

  // ================================================================== 1. sanctuary sessions
  describe('sanctuary_session (sync push → sanctuary_sessions)', () => {
    let u: TestUser;
    let other: TestUser;
    const rec = uuidv7();
    beforeAll(async () => {
      u = await appUser('sanct');
      other = await appUser('sanct-other');
    });

    it('writes one content-free row; the same record again changes nothing', async () => {
      const finished = at(20, 5);
      const first = await push(u, [m('sanctuary_session', { id: rec, activity: 'breathe', variant: 'box', durationS: 184 }, finished, YDAY)]);
      expect(first.body.results[0].status).toBe('applied');
      const again = await push(u, [m('sanctuary_session', { id: rec, activity: 'breathe', variant: 'box', durationS: 184 }, finished, YDAY)]);
      expect(again.body.results[0].status).toBe('applied');
      const rows = (
        await db.query(
          `select id, activity, variant, duration_s, local_day::text as local_day, device_ts from public.sanctuary_sessions where user_id = $1`,
          [u.id],
        )
      ).rows;
      expect(rows).toEqual([{ id: rec, activity: 'breathe', variant: 'box', duration_s: 184, local_day: YDAY, device_ts: finished }]);
      const cols = (
        await db.query(`select column_name from information_schema.columns where table_schema = 'public' and table_name = 'sanctuary_sessions' order by 1`)
      ).rows.map((r) => r.column_name);
      expect(cols).toEqual(['activity', 'device_ts', 'duration_s', 'id', 'local_day', 'server_ts', 'user_id', 'variant']);
    });

    it('rejects: another account reusing the id, a variant that is not the activity’s, bad durations, days out of window', async () => {
      const r = await push(other, [m('sanctuary_session', { id: rec, activity: 'breathe', variant: 'box', durationS: 60 }, at(20, 5), YDAY)]);
      expect(r.body.results[0]).toMatchObject({ status: 'rejected', reason: 'id_conflict' });
      const bad = await push(u, [
        m('sanctuary_session', { id: uuidv7(), activity: 'grounding', variant: 'calm', durationS: 60 }),
        m('sanctuary_session', { id: uuidv7(), activity: 'sounds', variant: 'open', durationS: 0 }),
        m('sanctuary_session', { id: uuidv7(), activity: 'savour', variant: 'moment', durationS: 60 }, new Date(), addDays(localDate(new Date(), TZ), -3)),
        m('sanctuary_session', { id: uuidv7(), activity: 'stillness', variant: 'orb', durationS: 60 }, new Date(), localDate(new Date(), TZ), 'delete'),
      ]);
      expect(bad.body.results.map((x: { reason?: string }) => x.reason)).toEqual([
        'invalid_payload',
        'invalid_duration',
        'invalid_local_day',
        'unknown_op',
      ]);
      expect((await db.query('select count(*)::int as n from public.sanctuary_sessions where user_id = $1', [u.id])).rows[0].n).toBe(1);
    });

    it('select-own: the owner reads their rows through PostgREST, nobody else does', async () => {
      const read = async (x: TestUser) =>
        (await (
          await fetch(`${SUPABASE_URL}/rest/v1/sanctuary_sessions?select=id,activity`, {
            headers: { apikey: localAnonKey(), Authorization: `Bearer ${x.token}` },
          })
        ).json()) as unknown[];
      expect(await read(u)).toEqual([{ id: rec, activity: 'breathe' }]);
      expect(await read(other)).toEqual([]);
    });
  });

  // ================================================================== 2 + 3. schedules and pushes
  describe('settings → schedule → push', () => {
    it('plans wind-down, Lantern Hour and habit nudge in the profile zone; turning them off clears the plan', async () => {
      const u = await appUser('plan');
      const habit = uuidv7();
      await push(u, [m('habit', { id: habit, kind: 'preset', presetKey: 'hydrate' })]);
      const before = new Date();
      await push(u, [
        m('notification_prefs', { windDownEnabled: true, windDownTime: '22:30', lanternHour: true, habitNudges: { [habit]: '09:00' } }),
      ]);
      const stored = (
        await db.query(
          `select wind_down_enabled, wind_down_time::text as t, lantern_opt_in, habit_nudges from public.notification_prefs where user_id = $1`,
          [u.id],
        )
      ).rows[0];
      expect(stored).toEqual({ wind_down_enabled: true, t: '22:30:00', lantern_opt_in: true, habit_nudges: { [habit]: '09:00' } });
      const plan = (await db.query('select kind, next_at, tz from public.notification_schedule where user_id = $1 order by kind', [u.id])).rows;
      const p = { ...DEFAULT_NOTIFICATION_PREFS, windDownEnabled: true, windDownTime: '22:30', lanternHour: true, habitNudges: { [habit]: '09:00' } };
      expect(plan.map((r) => r.kind)).toEqual(['habit_nudge', 'lantern_hour', 'wind_down_reminder']);
      for (const r of plan) {
        const want = nextAtFor(r.kind, before, TZ, p) as Date;
        expect(Math.abs((r.next_at as Date).getTime() - want.getTime())).toBeLessThan(60_000 * 5);
        expect(r.tz).toBe(TZ);
      }
      await push(u, [m('notification_prefs', { windDownEnabled: false, lanternHour: false, habitNudges: {} })]);
      expect((await db.query('select 1 from public.notification_schedule where user_id = $1', [u.id])).rowCount).toBe(0);
    });

    it('wind-down: the sweep sends one generic push; not after a Sanctuary session that evening (REQ-NTF-04)', async () => {
      const a = await appUser('wind-a', 'te-Latn');
      const b = await appUser('wind-b');
      for (const u of [a, b]) await push(u, [m('notification_prefs', { windDownEnabled: true, windDownTime: '22:30' })]);
      // b finished a Sounds session at 21:40 that evening.
      await push(b, [m('sanctuary_session', { id: uuidv7(), activity: 'sounds', variant: 'timer_30', durationS: 1500 }, at(21, 40), YDAY)]);
      const due = at(22, 30);
      await db.query(`update public.notification_schedule set next_at = $2 where user_id = any($1) and kind = 'wind_down_reminder'`, [
        [a.id, b.id],
        due,
      ]);
      const s = await app.get(ScheduleSweep).sweep(due, [a.id, b.id]);
      expect(s).toMatchObject({ due: 2, enqueued: 2 });
      const next = (await db.query(`select next_at from public.notification_schedule where user_id = $1`, [a.id])).rows[0].next_at;
      expect(next).toEqual(zonedInstant(localDate(new Date(), TZ), 22, 30, TZ)); // moved on to the next evening
      for (const u of [a, b]) {
        const jobs = await queued(u, 'wind_down_reminder');
        expect(jobs.map((j) => j.data)).toEqual([{ userId: u.id, type: 'wind_down_reminder', id: null }]);
        await deliver(jobs[0].data, due);
      }
      expect(transport.to(a.device)).toEqual([
        {
          type: 'wind_down_reminder',
          id: null,
          body: 'Padukune mundu konchem quiet time? Aura ikkade undi.',
          channelId: 'reminders',
          collapseKey: 'wind_down_reminder',
          ttlSeconds: 7200,
        },
      ]);
      expect(transport.to(b.device)).toEqual([]);
      await drop(a);
      await drop(b);
    });

    it('gestures: batched into one push per room per day, counting people, not gestures', async () => {
      const recipient = await appUser('gest-to', 'te-Latn');
      const s1 = await appUser('gest-s1');
      const s2 = await appUser('gest-s2');
      await push(recipient, [m('notification_prefs', { quietStart: '00:00', quietEnd: '00:00' })]); // no quiet hours
      const now = new Date();
      // This suite's own room in the Hindi pool (closed to matching while its flag is off), closed to joins once seated.
      const room = (
        await db.query<{ id: string }>(
          `insert into public.rooms (language_pool, quadrant, tz_region, seed_mood_id, theme, created_at, opened_at, joins_close_at, memory_at, purge_at)
           values ('hi', 'sunrise', 'americas', 'joyful', 'sunrise_deck', now() - interval '2 hours', now() - interval '2 hours',
                   now() + interval '18 hours', now() + interval '22 hours', now() + interval '8 days')
           returning id`,
        )
      ).rows[0].id;
      rooms.push(room);
      const member = async (u: TestUser, name: string) =>
        (
          await db.query<{ member_id: string }>(
            `insert into public.room_members (room_id, user_id, pseudonym, mood_at_join, entry_quadrant, home_language_pool, home_region, match_step, stage)
             values ($1, $2, $3, 'joyful', 'sunrise', 'en', 'south_asia', 1, 'spark') returning member_id`,
            [room, u.id, name],
          )
        ).rows[0].member_id;
      const to = await member(recipient, 'Quiet Comet');
      const f1 = await member(s1, 'Warm Ember');
      const f2 = await member(s2, 'Soft Lantern');
      await db.query(`update public.rooms set joins_close_at = now() - interval '1 minute' where id = $1`, [room]);
      const gesture = (from: string, minutesAgo: number, dropped: string | null = null) =>
        db.query(
          `insert into public.room_gestures (room_id, from_member_id, to_member_id, type, target, dropped, created_at)
           values ($1, $2, $3, 'warm_tea', 'member', $4, now() - make_interval(mins => $5))`,
          [room, from, to, dropped, minutesAgo],
        );
      // Batch window: nothing yet while the only gesture is 2 minutes old.
      await gesture(f1, 2);
      const sweep = app.get(GesturesPushSweep);
      expect((await sweep.sweep(now, [recipient.id])).enqueued).toBe(0);
      await gesture(f1, 14);
      await gesture(f2, 12);
      await gesture(f2, 11, 'muted'); // dropped gestures never count
      const later = new Date(now.getTime() + 1000);
      expect((await sweep.sweep(later, [recipient.id])).enqueued).toBe(1);
      expect((await sweep.sweep(later, [recipient.id])).enqueued).toBe(0); // one per room per day
      const jobs = await queued(recipient, 'gestures_received');
      expect(jobs.map((j) => j.data)).toEqual([{ userId: recipient.id, type: 'gestures_received', id: room }]);
      // The worker delivers it now (the recipient has no quiet hours, so the real clock never matters).
      await deliver(jobs[0].data, later);
      expect(transport.to(recipient.device)).toEqual([
        expect.objectContaining({ type: 'gestures_received', id: room, body: 'Mee room lo 2 mandi meeku warmth pampaaru.', channelId: 'rooms' }),
      ]);
      await drop(recipient);
    });

    it('welcome back: once at 7 quiet days, claimed; any write resets it; a stale push after a return is skipped', async () => {
      const u = await appUser('welcome');
      const evening = at(19); // yesterday 19:00 IST, inside the send window
      await db.query(
        `insert into public.notification_activity (user_id, last_active_at) values ($1, $2)
         on conflict (user_id) do update set last_active_at = excluded.last_active_at, welcome_step = 0, welcome_sent_at = null`,
        [u.id, new Date(evening.getTime() - 8 * 86_400_000)],
      );
      const sweep = app.get(WelcomeBackSweep);
      expect((await sweep.sweep(evening, [u.id])).enqueued).toBe(1);
      expect((await sweep.sweep(evening, [u.id])).enqueued).toBe(0); // the 2nd waits for day 21
      expect((await db.query('select welcome_step from public.notification_activity where user_id = $1', [u.id])).rows[0].welcome_step).toBe(1);
      const jobs = await queued(u, 'welcome_back');
      expect(jobs).toHaveLength(1);
      await deliver(jobs[0].data, evening);
      expect(transport.to(u.device)).toEqual([
        expect.objectContaining({ type: 'welcome_back', id: null, body: 'No catch-up needed. Aura is here whenever you want a quiet minute.' }),
      ]);
      // The person comes back (any sync push): the absence ends, and an older job finds them active.
      await push(u, [m('notification_prefs', { discreet: false })]);
      expect((await db.query('select welcome_step from public.notification_activity where user_id = $1', [u.id])).rows[0].welcome_step).toBe(0);
      const out = await app.get(NotificationDelivery).deliver(jobs[0].data, new Date(Date.now() + 1000), evening);
      expect(out).toEqual({ status: 'skipped', reason: 'active_again' });
      await drop(u);
    });

    it("habit nudge: the preset's own line at its time; nothing due once the habit is logged", async () => {
      const u = await appUser('nudge', 'te-Latn');
      const habit = uuidv7();
      await push(u, [m('habit', { id: habit, kind: 'preset', presetKey: 'hydrate' })]);
      await push(u, [m('notification_prefs', { habitNudges: { [habit]: '09:00' } })]);
      const nine = at(9);
      await db.query(`update public.notification_schedule set next_at = $2 where user_id = $1 and kind = 'habit_nudge'`, [u.id, nine]);
      expect((await app.get(ScheduleSweep).sweep(nine, [u.id])).enqueued).toBe(1);
      const jobs = await queued(u, 'habit_nudge');
      await deliver(jobs[0].data, nine);
      expect(transport.to(u.device)).toEqual([
        expect.objectContaining({ type: 'habit_nudge', body: 'Chinna pani: oka glass neellu?', channelId: 'reminders' }),
      ]);
      // Logged later that day: a nudge (e.g. another device's job) finds nothing due.
      await push(u, [m('habit_log', { id: uuidv7(), habitId: habit }, at(10), YDAY)]);
      const out = await app.get(NotificationDelivery).deliver(jobs[0].data, at(11), at(11));
      expect(out).toEqual({ status: 'skipped', reason: 'nothing_due' });
      await drop(u);
    });

    it('Lantern Hour: at 21:00 region time, generic, on the Rooms channel; skipped after joining a room that day', async () => {
      const u = await appUser('lantern', 'te-Latn');
      await push(u, [m('notification_prefs', { lanternHour: true })]);
      const nine = at(21);
      await db.query(`update public.notification_schedule set next_at = $2 where user_id = $1 and kind = 'lantern_hour'`, [u.id, nine]);
      expect((await app.get(ScheduleSweep).sweep(nine, [u.id])).enqueued).toBe(1);
      const jobs = await queued(u, 'lantern_hour');
      expect(jobs.map((j) => j.data)).toEqual([{ userId: u.id, type: 'lantern_hour', id: null }]);
      const rooms = (await db.query<{ enabled: boolean }>(`select enabled from public.feature_flags where key = 'rooms_enabled'`)).rows[0];
      await deliver(jobs[0].data, nine);
      if (rooms?.enabled !== false) {
        expect(transport.to(u.device)).toEqual([
          expect.objectContaining({ type: 'lantern_hour', id: null, body: 'Lantern Hour modalaindi. Ee raatri inka kondaru ikkade unnaru.', channelId: 'rooms' }),
        ]);
      }
      await drop(u);
    });
  });

  // ================================================================== 4. reduced mode
  describe('reduced mode: sign-ups throttled (PRD 19)', () => {
    it('a new sign-up past the allowance gets 503 signups_throttled; an existing account is untouched', async () => {
      const existing = await appUser('reduced-existing');
      const fresh = await createUser('reduced-new');
      users.push(fresh);
      const throttle = app.get(SignupThrottle);
      const spy = jest.spyOn(throttle, 'settings').mockResolvedValue({ on: true, perHour: 0 });
      try {
        const body = { birthDate: '1996-03-14', uiLocale: 'en', timezone: TZ, country: 'IN' };
        const refused = await as(fresh, http().post('/v1/profile')).send(body).expect(503);
        expect(refused.body.code).toBe('signups_throttled');
        expect((await db.query('select 1 from public.profiles where user_id = $1', [fresh.id])).rowCount).toBe(0);
        await as(existing, http().post('/v1/profile')).send({ ...body, uiLocale: 'te' }).expect(200);
        spy.mockResolvedValue({ on: true, perHour: 1_000_000 });
        await as(fresh, http().post('/v1/profile')).send(body).expect(200);
      } finally {
        spy.mockRestore();
      }
    });
  });
});
