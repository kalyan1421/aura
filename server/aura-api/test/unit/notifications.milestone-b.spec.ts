/**
 * F14 Milestone B kinds (PRD 12 catalogue; contracts/api/v1-notifications.md §6–§9): per-kind rules in `decide`
 * (toggles, type-specific skips, quiet hours, cap + precedence), the schedule planners (wind-down, Lantern Hour on the
 * region clock, habit nudges), the copy variants, the welcome-back window, habit "due" maths, the settings patch
 * schema, and the sweeps / delivery against a fake DB routed by statement shape.
 */
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { NotificationDelivery } from '../../src/notifications/delivery.service';
import { GesturesPushSweep } from '../../src/notifications/gestures-push';
import { auraMinutes, dueNudgeHabits, eveningStart, expectedLaterFor } from '../../src/notifications/kind-facts';
import { mergePrefs, prefsFromRow, prefsPatchSchema } from '../../src/notifications/notification-prefs';
import type { DeviceTarget, PushMessage } from '../../src/notifications/notification-types';
import { decide, DEFAULT_NOTIFICATION_PREFS, type DeliveryFacts, type NotificationPrefsValues } from '../../src/notifications/policy';
import { COPY_KEYS, pushCopyKey, renderPushLine } from '../../src/notifications/push-copy';
import {
  nextAtFor,
  nextLanternStart,
  planSchedules,
  ScheduleSweep,
  scheduleDedupeKey,
  SCHEDULE_MAX_LATE_MS,
} from '../../src/notifications/schedules';
import { inWelcomeWindow, WelcomeBackSweep } from '../../src/notifications/welcome-back';
import { buildLintTerms, lintTemplates, serverPushTemplates } from '../../src/notifications/copy-lint';

const IST = 'Asia/Kolkata';
const DUBAI = 'Asia/Dubai';
const NY = 'America/New_York';
const DAY = '2026-10-08';
const at = (day: string, hh: number, mm = 0, tz = IST): Date => zonedInstant(day, hh, mm, tz);
const H = 3600_000;
const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const ROOM = '0192f0c3-2222-7c1a-9b3d-0000000000aa';
const HABIT_A = '0192f0c3-3333-7c1a-9b3d-0000000000a1';
const HABIT_B = '0192f0c3-3333-7c1a-9b3d-0000000000b2';

const prefs = (over: Partial<NotificationPrefsValues> = {}): NotificationPrefsValues => ({ ...DEFAULT_NOTIFICATION_PREFS, ...over });

const facts = (over: Partial<DeliveryFacts> = {}): DeliveryFacts => {
  const now = over.now ?? at(DAY, 22, 30);
  return {
    type: 'wind_down_reminder',
    now,
    createdAt: now,
    tz: IST,
    prefs: prefs({ windDownEnabled: true, windDownTime: '22:30', lanternHour: true, habitNudges: { [HABIT_A]: '09:00' } }),
    pendingDeletion: false,
    devices: 1,
    sentToday: [],
    expectedLater: [],
    sanctuaryThisEvening: false,
    roomsOpen: true,
    inRoomToday: false,
    gestureCount: 2,
    activeAgain: false,
    dueHabits: ['hydrate'],
    ...over,
  };
};

describe('defaults and toggles (rule 8)', () => {
  it('opt-in kinds start off; gestures and welcome back start on', () => {
    expect(DEFAULT_NOTIFICATION_PREFS).toMatchObject({
      gestures: true,
      welcomeBack: true,
      lanternHour: false,
      windDownEnabled: false,
      windDownTime: null,
      habitNudges: {},
    });
    const d = prefs();
    expect(decide(facts({ prefs: d, type: 'wind_down_reminder' }))).toEqual({ action: 'skip', reason: 'type_disabled' });
    expect(decide(facts({ prefs: d, type: 'lantern_hour', now: at(DAY, 21) }))).toEqual({ action: 'skip', reason: 'type_disabled' });
    expect(decide(facts({ prefs: d, type: 'habit_nudge', now: at(DAY, 9) }))).toEqual({ action: 'skip', reason: 'type_disabled' });
    expect(decide(facts({ prefs: d, type: 'gestures_received', now: at(DAY, 19) }))).toEqual({ action: 'send' });
    expect(decide(facts({ prefs: d, type: 'welcome_back', now: at(DAY, 19) }))).toEqual({ action: 'send' });
  });

  it('REQ-NTF-04: the wind-down reminder is off until a time is picked; the master switch wins', () => {
    const noTime = prefs({ windDownEnabled: true, windDownTime: null });
    expect(decide(facts({ prefs: noTime }))).toEqual({ action: 'skip', reason: 'type_disabled' });
    expect(decide(facts({ prefs: { ...facts().prefs, enabled: false } }))).toEqual({ action: 'skip', reason: 'disabled' });
    expect(decide(facts({ prefs: { ...facts().prefs, gestures: false }, type: 'gestures_received', now: at(DAY, 19) }))).toEqual({
      action: 'skip',
      reason: 'type_disabled',
    });
    expect(decide(facts({ prefs: { ...facts().prefs, welcomeBack: false }, type: 'welcome_back', now: at(DAY, 19) }))).toEqual({
      action: 'skip',
      reason: 'type_disabled',
    });
  });
});

describe('type-specific rules', () => {
  it('wind-down: never sent once Sanctuary was used that evening (REQ-NTF-04)', () => {
    expect(decide(facts())).toEqual({ action: 'send' });
    expect(decide(facts({ sanctuaryThisEvening: true }))).toEqual({ action: 'skip', reason: 'sanctuary_opened' });
    // "That evening" = from 18:00 of the Aura day (after midnight it is still the same evening).
    expect(eveningStart(at(DAY, 22, 30), IST)).toEqual(at(DAY, 18));
    expect(eveningStart(at('2026-10-09', 1, 0), IST)).toEqual(at(DAY, 18));
  });

  it('Lantern Hour: skipped if already in a room today, or rooms are off / closed to the account', () => {
    const f = (over: Partial<DeliveryFacts>) => facts({ type: 'lantern_hour', now: at(DAY, 21), ...over });
    expect(decide(f({}))).toEqual({ action: 'send' });
    expect(decide(f({ inRoomToday: true }))).toEqual({ action: 'skip', reason: 'in_room_today' });
    expect(decide(f({ roomsOpen: false }))).toEqual({ action: 'skip', reason: 'rooms_closed' });
    // Its own quiet hours: someone quiet from 20:00 gets none (system-initiated, never deferred to the morning).
    expect(decide(f({ prefs: { ...facts().prefs, quietStart: '20:00' } }))).toEqual({ action: 'skip', reason: 'quiet_hours' });
    // Stale after an hour (the window is 2 h).
    expect(decide(f({ createdAt: at(DAY, 19, 50) }))).toEqual({ action: 'skip', reason: 'expired' });
  });

  it('gestures: something to tell, rooms not closed to the account; dropped inside quiet hours', () => {
    const f = (over: Partial<DeliveryFacts>) => facts({ type: 'gestures_received', now: at(DAY, 19), ...over });
    expect(decide(f({}))).toEqual({ action: 'send' });
    expect(decide(f({ gestureCount: 0 }))).toEqual({ action: 'skip', reason: 'nothing_new' });
    expect(decide(f({ roomsOpen: false }))).toEqual({ action: 'skip', reason: 'rooms_closed' });
    expect(decide(f({ now: at(DAY, 23, 30), createdAt: at(DAY, 23, 30) }))).toEqual({ action: 'skip', reason: 'quiet_hours' });
  });

  it('welcome back: not if the person came back; waits out quiet hours', () => {
    const f = (over: Partial<DeliveryFacts>) => facts({ type: 'welcome_back', now: at(DAY, 19), ...over });
    expect(decide(f({}))).toEqual({ action: 'send' });
    expect(decide(f({ activeAgain: true }))).toEqual({ action: 'skip', reason: 'active_again' });
    expect(decide(f({ now: at(DAY, 23, 10), createdAt: at(DAY, 19) }))).toMatchObject({ action: 'defer' });
  });

  it('habit nudge: only while something is due and not done; inside quiet hours skipped', () => {
    const f = (over: Partial<DeliveryFacts>) => facts({ type: 'habit_nudge', now: at(DAY, 9), ...over });
    expect(decide(f({}))).toEqual({ action: 'send' });
    expect(decide(f({ dueHabits: [] }))).toEqual({ action: 'skip', reason: 'nothing_due' });
    expect(decide(f({ now: at(DAY, 7), createdAt: at(DAY, 7) }))).toEqual({ action: 'skip', reason: 'quiet_hours' });
  });

  it('rule 1: a wind-down time inside quiet hours is honoured only after the one-time confirmation', () => {
    const p = { ...facts().prefs, windDownTime: '23:30' };
    const now = at(DAY, 23, 30);
    expect(decide(facts({ prefs: p, now }))).toEqual({ action: 'skip', reason: 'quiet_hours' });
    expect(decide(facts({ prefs: { ...p, windDownInQuietHours: true }, now }))).toEqual({ action: 'send' });
  });
});

describe('cap and precedence (rule 2)', () => {
  it('each counts toward 2/day; wind-down ranks below Lantern Hour (REQ-NTF-04)', () => {
    expect(decide(facts({ sentToday: ['daily_reminder', 'capsule_unlocked'] }))).toEqual({ action: 'skip', reason: 'capped' });
    // One slot left, Lantern Hour still expected tonight: the wind-down yields it.
    expect(decide(facts({ sentToday: ['daily_reminder'], expectedLater: ['lantern_hour'] }))).toEqual({
      action: 'skip',
      reason: 'capped',
    });
    // Lantern Hour does not yield to a lower wind-down.
    expect(
      decide(facts({ type: 'lantern_hour', now: at(DAY, 21), sentToday: ['daily_reminder'], expectedLater: ['wind_down_reminder'] })),
    ).toEqual({ action: 'send' });
    // Welcome back is last: capped → waits for the next Aura day instead of being dropped.
    expect(decide(facts({ type: 'welcome_back', now: at(DAY, 19), sentToday: ['daily_reminder', 'gestures_received'] }))).toEqual({
      action: 'defer',
      until: at('2026-10-09', 4),
    });
    expect(decide(facts({ type: 'habit_nudge', now: at(DAY, 9), sentToday: ['habit_nudge'] }))).toEqual({
      action: 'skip',
      reason: 'already_sent',
    });
  });

  it('expectedLaterFor reads only higher-priority kinds still due this Aura day', async () => {
    const seen: string[] = [];
    const q = {
      async query(sql: string, params: unknown[] = []) {
        const s = sql.replace(/\s+/g, ' ').trim();
        seen.push(s.slice(0, 50));
        if (s.startsWith('select 1 from public.capsule_unlock_schedule')) return { rows: [], rowCount: 0 };
        if (s.startsWith('select 1 from public.notification_prefs np')) return { rows: [{}], rowCount: 1 };
        if (s.startsWith('select kind from public.notification_schedule')) {
          const kinds = params[1] as string[];
          return { rows: kinds.includes('lantern_hour') ? [{ kind: 'lantern_hour' }] : [], rowCount: 1 };
        }
        throw new Error(`unexpected ${s}`);
      },
    };
    const p = prefs({ reminderEnabled: true, reminderTime: '20:00' });
    expect(await expectedLaterFor(q as never, USER, 'wind_down_reminder', at(DAY, 19), IST, p)).toEqual(['daily_reminder', 'lantern_hour']);
    seen.length = 0;
    expect(await expectedLaterFor(q as never, USER, 'capsule_unlocked', at(DAY, 9), IST, p)).toEqual([]);
    expect(seen).toEqual([]); // the top kind reads nothing
  });
});

describe('planning (schedules.ts)', () => {
  it('wind-down: the chosen time, next occurrence in the profile zone; off → none', () => {
    const p = prefs({ windDownEnabled: true, windDownTime: '22:30' });
    expect(nextAtFor('wind_down_reminder', at(DAY, 12), IST, p)).toEqual(at(DAY, 22, 30));
    expect(nextAtFor('wind_down_reminder', at(DAY, 22, 30), IST, p)).toEqual(at('2026-10-09', 22, 30));
    expect(nextAtFor('wind_down_reminder', at(DAY, 12), IST, { ...p, windDownEnabled: false })).toBeNull();
    expect(nextAtFor('wind_down_reminder', at(DAY, 12), IST, { ...p, enabled: false })).toBeNull();
  });

  it("Lantern Hour: 21:00 on the REGION clock (Dubai → south_asia's 9 pm IST = 7:30 pm local), strictly next", () => {
    const p = prefs({ lanternHour: true });
    expect(nextLanternStart(at(DAY, 12), IST)).toEqual(at(DAY, 21));
    expect(nextAtFor('lantern_hour', at(DAY, 21), IST, p)).toEqual(at('2026-10-09', 21));
    expect(nextAtFor('lantern_hour', at(DAY, 22), IST, p)).toEqual(at('2026-10-09', 21));
    expect(nextAtFor('lantern_hour', at(DAY, 12, 0, DUBAI), DUBAI, p)).toEqual(at(DAY, 21)); // 19:30 Dubai
    expect(nextAtFor('lantern_hour', at(DAY, 12, 0, NY), NY, p)).toEqual(at(DAY, 21, 0, 'America/Chicago'));
    // The console's window moves it.
    expect(nextLanternStart(at(DAY, 12), IST, { start: { hour: 20, minute: 30 }, end: { hour: 22, minute: 30 } })).toEqual(at(DAY, 20, 30));
    expect(nextAtFor('lantern_hour', at(DAY, 12), IST, prefs())).toBeNull();
  });

  it('habit nudges: the earliest next time among the habits', () => {
    const p = prefs({ habitNudges: { [HABIT_A]: '09:00', [HABIT_B]: '18:00' } });
    expect(nextAtFor('habit_nudge', at(DAY, 8), IST, p)).toEqual(at(DAY, 9));
    expect(nextAtFor('habit_nudge', at(DAY, 9), IST, p)).toEqual(at(DAY, 18));
    expect(nextAtFor('habit_nudge', at(DAY, 19), IST, p)).toEqual(at('2026-10-09', 9));
    expect(nextAtFor('habit_nudge', at(DAY, 8), IST, prefs())).toBeNull();
  });

  it('dedupe: once per Aura day; habit nudges per time', () => {
    expect(scheduleDedupeKey('wind_down_reminder', at('2026-10-09', 0, 30), IST)).toBe(DAY);
    expect(scheduleDedupeKey('habit_nudge', at(DAY, 9), IST)).toBe(`${DAY}:${at(DAY, 9).toISOString()}`);
    expect(SCHEDULE_MAX_LATE_MS.lantern_hour).toBeLessThan(SCHEDULE_MAX_LATE_MS.wind_down_reminder);
  });

  it('planSchedules writes a row per wanted kind and deletes the rest', async () => {
    const calls: Array<[string, unknown[]]> = [];
    const q = {
      async query(sql: string, params: unknown[] = []) {
        calls.push([sql.replace(/\s+/g, ' ').trim().slice(0, 30), params]);
        if (sql.includes('matching_config')) return { rows: [{ lantern_start: '21:00:00', lantern_end: '23:00:00' }], rowCount: 1 };
        return { rows: [], rowCount: 1 };
      },
    };
    await planSchedules(q as never, USER, IST, at(DAY, 12), prefs({ windDownEnabled: true, windDownTime: '22:30', lanternHour: true }));
    const ops = calls.map(([s, p]) => `${s.split(' ')[0]}:${String(p[1] ?? '')}`);
    expect(ops).toEqual(['select:', 'insert:wind_down_reminder', 'insert:lantern_hour', 'delete:habit_nudge']);
    expect(calls[1][1]).toEqual([USER, 'wind_down_reminder', at(DAY, 22, 30), IST]);
  });
});

describe('habit nudges: what is due', () => {
  it('times count within the Aura day (04:00 rollover)', () => {
    expect(auraMinutes(4 * 60)).toBe(0);
    expect(auraMinutes(3 * 60)).toBe(23 * 60);
    const n = { [HABIT_A]: '09:00', [HABIT_B]: '23:30' };
    expect(dueNudgeHabits(at(DAY, 8), IST, n)).toEqual([]);
    expect(dueNudgeHabits(at(DAY, 9), IST, n)).toEqual([HABIT_A]);
    expect(dueNudgeHabits(at('2026-10-09', 1), IST, n)).toEqual([HABIT_A, HABIT_B]); // still the 8th's Aura day
  });
});

describe('copy (push-copy.ts)', () => {
  it('gestures: one person or a count, never a name', () => {
    expect(pushCopyKey('gestures_received', { gestureCount: 1 })).toEqual({ key: 'gestures_received_one', params: {} });
    const three = pushCopyKey('gestures_received', { gestureCount: 3 });
    expect(renderPushLine(three.key, 'en', false, three.params)).toBe('3 people in your room sent you warmth.');
    expect(renderPushLine(three.key, 'te-Latn', false, three.params)).toBe('Mee room lo 3 mandi meeku warmth pampaaru.');
    expect(renderPushLine('gestures_received_one', 'en', false)).toBe('Someone in your room sent you warmth.');
    expect(renderPushLine(three.key, 'en', true, three.params)).toBe('You have a gentle update');
  });

  it("habit nudge: a single preset's own line; custom or several → the bundled line (no habit name)", () => {
    const one = pushCopyKey('habit_nudge', { dueHabits: ['hydrate'] });
    expect(renderPushLine(one.key, 'en', false)).toBe('Small one: a glass of water?');
    expect(renderPushLine(one.key, 'te-Latn', false)).toBe('Chinna pani: oka glass neellu?');
    expect(pushCopyKey('habit_nudge', { dueHabits: ['custom'] }).key).toBe('habit_nudge');
    expect(pushCopyKey('habit_nudge', { dueHabits: ['hydrate', 'move'] }).key).toBe('habit_nudge');
  });

  it("the PRD's lines for Lantern Hour, wind-down and welcome back", () => {
    expect(renderPushLine('lantern_hour', 'en', false)).toBe('Lantern Hour is on. Others are here tonight.');
    expect(renderPushLine('lantern_hour', 'te-Latn', false)).toBe('Lantern Hour modalaindi. Ee raatri inka kondaru ikkade unnaru.');
    expect(renderPushLine('wind_down_reminder', 'en', false)).toBe('A few quiet minutes before sleep, whenever you want them.');
    expect(renderPushLine('wind_down_reminder', 'te-Latn', false)).toBe('Padukune mundu konchem quiet time? Aura ikkade undi.');
    expect(renderPushLine('welcome_back', 'en', false)).toBe('No catch-up needed. Aura is here whenever you want a quiet minute.');
    for (const key of COPY_KEYS) expect(renderPushLine(key, 'te', false)).toMatch(/[ఀ-౿]/);
  });

  it('REQ-NTF-01 / REQ-NTF-04: every new line passes the lint, incl. "no promise of better sleep"', () => {
    const terms = buildLintTerms([]);
    expect(lintTemplates(serverPushTemplates(), terms)).toEqual([]);
    const claim = lintTemplates([{ source: 't', locale: 'en', key: 'x', text: 'Sleep better tonight with a healing sound' }], terms);
    expect(claim.map((v) => `${v.reason}:${v.term}`)).toEqual(expect.arrayContaining(['health_claim:sleep better', 'health_claim:healing']));
    expect(lintTemplates([{ source: 't', locale: 'en', key: 'x', text: 'Your health is yours' }], terms)).toEqual([]);
  });
});

describe('settings patch (notification_prefs §6)', () => {
  it('accepts the Milestone B fields; habit ids lower-cased; bad values refused', () => {
    const ok = prefsPatchSchema.safeParse({
      gestures: false,
      lanternHour: true,
      windDownEnabled: true,
      windDownTime: '22:30',
      windDownInQuietHours: false,
      welcomeBack: false,
      habitNudges: { [HABIT_A.toUpperCase()]: '09:00' },
    });
    expect(ok.success && ok.data.habitNudges).toEqual({ [HABIT_A]: '09:00' });
    expect(prefsPatchSchema.safeParse({ windDownTime: '24:00' }).success).toBe(false);
    expect(prefsPatchSchema.safeParse({ habitNudges: { 'not-a-uuid': '09:00' } }).success).toBe(false);
    expect(prefsPatchSchema.safeParse({ habitNudges: { [HABIT_A]: 'Drink water' } }).success).toBe(false);
    const many = Object.fromEntries(Array.from({ length: 17 }, (_, i) => [`0192f0c3-3333-7c1a-9b3d-${String(i).padStart(12, '0')}`, '09:00']));
    expect(prefsPatchSchema.safeParse({ habitNudges: many }).success).toBe(false);
  });

  it('habit nudges are one last-write-wins field (the whole map)', () => {
    const cur = { values: prefs({ habitNudges: { [HABIT_A]: '09:00' } }), fieldTs: {} };
    const next = mergePrefs(cur, { habitNudges: { [HABIT_B]: '18:00' } }, at(DAY, 12)).next;
    expect(next.values.habitNudges).toEqual({ [HABIT_B]: '18:00' });
  });

  it('rows without the Milestone B columns read as the defaults; malformed nudges are dropped', () => {
    const base = {
      enabled: true, reminder_enabled: false, reminder_time: null, reminder_in_quiet_ok: false, capsule_enabled: true,
      quiet_start: '23:00:00', quiet_end: '08:00:00', discreet: false, field_ts: {},
    };
    expect(prefsFromRow(base).values).toMatchObject({ gestures: true, lanternHour: false, habitNudges: {} });
    const v = prefsFromRow({ ...base, wind_down_enabled: true, wind_down_time: '22:30:00', habit_nudges: { [HABIT_A]: '09:00', x: 'y' } }).values;
    expect(v).toMatchObject({ windDownEnabled: true, windDownTime: '22:30', habitNudges: { [HABIT_A]: '09:00' } });
  });
});

describe('welcome back', () => {
  it('goes out in the early evening, local time', () => {
    expect(inWelcomeWindow(at(DAY, 17, 59), IST)).toBe(false);
    expect(inWelcomeWindow(at(DAY, 18), IST)).toBe(true);
    expect(inWelcomeWindow(at(DAY, 20, 59), IST)).toBe(true);
    expect(inWelcomeWindow(at(DAY, 21), IST)).toBe(false);
  });

  it('the sweep claims before enqueueing (step 0 → 1), outside the window it waits', async () => {
    const enq: unknown[][] = [];
    const updates: unknown[][] = [];
    const last = new Date(at(DAY, 19).getTime() - 8 * 24 * H);
    const db = {
      async query(sql: string, params: unknown[] = []) {
        if (sql.includes('from public.notification_activity a')) {
          return {
            rows: [{ user_id: USER, last_active_at: last, last_active_text: last.toISOString(), welcome_step: 0, welcome_sent_at: null, timezone: IST }],
            rowCount: 1,
          };
        }
        if (sql.includes('update public.notification_activity')) {
          updates.push(params);
          return { rows: [], rowCount: 1 };
        }
        throw new Error(sql);
      },
    };
    const sweep = new WelcomeBackSweep(db as never, {} as never, { enqueue: async (...a: unknown[]) => void enq.push(a) } as never);
    expect(await sweep.sweep(at(DAY, 16))).toEqual({ candidates: 1, enqueued: 0 });
    expect(await sweep.sweep(at(DAY, 19))).toEqual({ candidates: 1, enqueued: 1 });
    expect(updates[0].slice(0, 2)).toEqual([USER, 0]);
    expect(enq[0]).toEqual([USER, 'welcome_back', null, { dedupeKey: `${last.toISOString()}:0` }]);
  });
});

describe('sweeps', () => {
  it('schedule sweep: a due wind-down is claimed (moved to tomorrow) and enqueued; a stale one only moved', async () => {
    const enq: unknown[][] = [];
    const claims: unknown[][] = [];
    const row = (next: Date) => ({
      user_id: USER, kind: 'wind_down_reminder', next_at: next, planned_tz: IST, timezone: IST,
      enabled: true, reminder_enabled: false, reminder_time: null, reminder_in_quiet_ok: false, capsule_enabled: true,
      quiet_start: '23:00:00', quiet_end: '08:00:00', discreet: false, field_ts: {},
      wind_down_enabled: true, wind_down_time: '22:30:00', wind_down_in_quiet_ok: false, habit_nudges: {},
    });
    let due = [row(at(DAY, 22, 30))];
    const db = {
      async query(sql: string, params: unknown[] = []) {
        if (sql.includes('from public.notification_schedule s')) return { rows: due, rowCount: due.length };
        if (sql.startsWith('update public.notification_schedule')) {
          claims.push(params);
          return { rows: [], rowCount: 1 };
        }
        throw new Error(sql);
      },
    };
    const sweep = new ScheduleSweep(db as never, {} as never, { enqueue: async (...a: unknown[]) => void enq.push(a) } as never);
    expect(await sweep.sweep(at(DAY, 22, 30, IST))).toEqual({ due: 1, enqueued: 1, moved: 0 });
    expect(claims[0][3]).toEqual(at('2026-10-09', 22, 30));
    expect(enq[0]).toEqual([USER, 'wind_down_reminder', null, { dedupeKey: DAY }]);
    due = [row(at(DAY, 20))];
    expect(await sweep.sweep(at(DAY, 22, 30))).toEqual({ due: 1, enqueued: 0, moved: 1 }); // 2.5 h late
  });

  it('gestures sweep: one logged push per recipient, room and Aura day (the log row and the enqueue together)', async () => {
    const enq: unknown[][] = [];
    const logged = new Set<string>();
    const tx = {
      async query(sql: string, params: unknown[] = []) {
        if (sql.includes('insert into public.gesture_push_log')) {
          const k = params.join('|');
          if (logged.has(k)) return { rows: [], rowCount: 0 };
          logged.add(k);
          return { rows: [], rowCount: 1 };
        }
        throw new Error(sql);
      },
    };
    const now = at(DAY, 19);
    const db = {
      async query(sql: string) {
        if (sql.includes('from public.room_gestures g')) {
          return { rows: [{ user_id: USER, room_id: ROOM, timezone: IST, ready_at: new Date(now.getTime() - 15 * 60_000) }], rowCount: 1 };
        }
        throw new Error(sql);
      },
      withTx: async <T>(f: (t: typeof tx) => Promise<T>) => f(tx),
    };
    const sweep = new GesturesPushSweep(db as never, {} as never, { enqueue: async (...a: unknown[]) => void enq.push(a) } as never);
    expect(await sweep.sweep(now)).toEqual({ candidates: 1, enqueued: 1 });
    expect(await sweep.sweep(now)).toEqual({ candidates: 1, enqueued: 0 });
    expect(enq).toEqual([[USER, 'gestures_received', ROOM, { dedupeKey: `${ROOM}:${DAY}` }]]);
    // Yesterday's gestures (before the 04:00 rollover) don't make today's push.
    const early = await new GesturesPushSweep(
      { ...db, query: async () => ({ rows: [{ user_id: USER, room_id: ROOM, timezone: IST, ready_at: at(DAY, 3) }], rowCount: 1 }) } as never,
      {} as never,
      { enqueue: async () => undefined } as never,
    ).sweep(at(DAY, 5));
    expect(early.enqueued).toBe(0);
  });
});

describe('delivery of a Milestone B push (fake DB)', () => {
  class Transport {
    readonly name = 'fake';
    sent: PushMessage[] = [];
    async send(_t: DeviceTarget, m: PushMessage): Promise<'sent'> {
      this.sent.push(m);
      return 'sent';
    }
  }
  const make = (gestures: number, locale = 'en') => {
    const db = {
      async query(sql: string) {
        const s = sql.replace(/\s+/g, ' ').trim();
        const ok = (rows: unknown[] = []) => ({ rows, rowCount: rows.length });
        if (s.startsWith('select p.timezone, p.ui_locale')) {
          return ok([
            {
              timezone: IST, ui_locale: locale, has_prefs: true, enabled: true, reminder_enabled: false, reminder_time: null,
              reminder_in_quiet_ok: false, capsule_enabled: true, quiet_start: '23:00:00', quiet_end: '08:00:00', discreet: false,
              field_ts: {}, sent_day: null, sent_types: [], pending_deletion: false, gestures_enabled: true, habit_nudges: {},
            },
          ]);
        }
        if (s.startsWith('select token, platform')) return ok([{ token: 't', platform: 'android' }]);
        if (s.startsWith('select 1 from public.sanctions')) return ok();
        if (s.startsWith('select count(distinct g.from_member_id)')) return ok([{ n: gestures }]);
        if (s.startsWith('select 1 from public.capsule_unlock_schedule') || s.startsWith('select kind from public.notification_schedule')) {
          return ok(); // nothing higher expected later today
        }
        if (s.startsWith('insert into public.notification_prefs as np (user_id, sent_day, sent_types)')) return ok([{}]);
        throw new Error(`unexpected ${s.slice(0, 60)}`);
      },
    };
    const t = new Transport();
    return { d: new NotificationDelivery(db as never, t), t };
  };

  it('counts the senders at delivery and renders the room-count line on the Rooms channel', async () => {
    const { d, t } = make(3, 'te-Latn');
    const out = await d.deliver({ userId: USER, type: 'gestures_received', id: ROOM }, at(DAY, 19));
    expect(out).toEqual({ status: 'sent', devices: 1, pruned: 0 });
    expect(t.sent[0]).toMatchObject({
      type: 'gestures_received',
      id: ROOM,
      body: 'Mee room lo 3 mandi meeku warmth pampaaru.',
      channelId: 'rooms',
      collapseKey: 'gestures_received',
    });
  });

  it('nothing left to tell → skipped', async () => {
    const { d, t } = make(0);
    expect(await d.deliver({ userId: USER, type: 'gestures_received', id: ROOM }, at(DAY, 19))).toEqual({
      status: 'skipped',
      reason: 'nothing_new',
    });
    expect(t.sent).toEqual([]);
  });
});
