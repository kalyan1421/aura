/**
 * Sync entity `notification_prefs` (per-field last-write-wins patches; the daily reminder is re-planned in the same
 * transaction) and the ReminderScheduler (minute sweep: claim → enqueue once per Aura day; zone reconcile).
 */
import { Logger } from '@nestjs/common';
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { uuidv7 } from '../../src/common/uuid';
import {
  mergePrefs,
  NotificationPrefsSyncHandler,
  prefsPatchSchema,
  type StoredPrefs,
} from '../../src/notifications/notification-prefs';
import { DEFAULT_NOTIFICATION_PREFS } from '../../src/notifications/policy';
import { REMINDER_MAX_LATE_MS, ReminderScheduler } from '../../src/notifications/reminder.service';
import { MutationRejected } from '../../src/sync/mutation-rejected';
import type { Mutation } from '../../src/sync/sync.schema';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const IST = 'Asia/Kolkata';
const at = (day: string, hh: number, mm = 0, tz = IST) => zonedInstant(day, hh, mm, tz);
const T0 = new Date('2026-10-08T06:00:00Z');
const later = (ms: number) => new Date(T0.getTime() + ms);

const stored = (over: Partial<StoredPrefs['values']> = {}, fieldTs: StoredPrefs['fieldTs'] = {}): StoredPrefs => ({
  values: { ...DEFAULT_NOTIFICATION_PREFS, ...over },
  fieldTs,
});

describe('prefsPatchSchema', () => {
  it('a patch is any subset of the settings; times are HH:MM (24 h); unknown keys are ignored', () => {
    expect(prefsPatchSchema.safeParse({ reminderEnabled: true, reminderTime: '20:00' }).success).toBe(true);
    expect(prefsPatchSchema.safeParse({ reminderTime: null }).success).toBe(true);
    expect(prefsPatchSchema.safeParse({ discreet: true, lanternOptIn: true }).data).toEqual({ discreet: true });
    for (const bad of [{}, { future: 1 }, { reminderTime: '24:00' }, { quietStart: '8:00' }, { quietEnd: '08:00:00' }, { quietStart: null }, { enabled: 'yes' }]) {
      expect(prefsPatchSchema.safeParse(bad).success).toBe(false);
    }
  });
});

describe('mergePrefs (16-offline: settings are last-write-wins per field)', () => {
  it('applies newer fields and stamps them', () => {
    const { next, changed } = mergePrefs(stored(), { reminderEnabled: true, reminderTime: '21:15' }, T0);
    expect(changed).toEqual(['reminderEnabled', 'reminderTime']);
    expect(next.values).toMatchObject({ reminderEnabled: true, reminderTime: '21:15', capsuleUnlocked: true });
    expect(next.fieldTs).toEqual({ reminderEnabled: T0.toISOString(), reminderTime: T0.toISOString() });
  });

  it('an older write leaves a field alone; other fields of the same patch still apply', () => {
    const cur = stored({ discreet: true }, { discreet: later(60_000).toISOString() });
    const { next, changed } = mergePrefs(cur, { discreet: false, quietStart: '22:30' }, T0);
    expect(changed).toEqual(['quietStart']);
    expect(next.values).toMatchObject({ discreet: true, quietStart: '22:30' });
  });

  it('two phones editing different settings offline both win', () => {
    const phoneA = { discreet: true };
    const phoneB = { reminderTime: '07:30', reminderEnabled: true };
    const a = mergePrefs(stored(), phoneB, later(5_000)).next; // B syncs first (made later)
    const b = mergePrefs(a, phoneA, T0).next; // A's older edit to another field still lands
    expect(b.values).toMatchObject({ discreet: true, reminderTime: '07:30', reminderEnabled: true });
  });

  it('a tie goes to the later-received write', () => {
    const cur = stored({ discreet: true }, { discreet: T0.toISOString() });
    expect(mergePrefs(cur, { discreet: false }, T0).next.values.discreet).toBe(false);
  });
});

describe('NotificationPrefsSyncHandler', () => {
  class FakeTx {
    row: Record<string, unknown> | undefined;
    writes: unknown[][] = [];
    async query(sql: string, params: unknown[] = []) {
      if (sql.includes('from public.notification_prefs where user_id = $1')) {
        return { rows: this.row ? [this.row] : [], rowCount: this.row ? 1 : 0 };
      }
      if (sql.includes('insert into public.notification_prefs as np')) {
        this.writes.push(params);
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`unexpected SQL ${sql.slice(0, 60)}`);
    }
  }
  const mutation = (payload: Record<string, unknown>, deviceTs: string | null = T0.toISOString(), op = 'upsert'): Mutation =>
    ({ id: uuidv7(), entity: 'notification_prefs', op, deviceTs: deviceTs ?? undefined, payload }) as Mutation;
  const handler = new NotificationPrefsSyncHandler();
  const ctx = (tx: FakeTx, now = later(1000)) => ({ tx: tx as never, userId: USER, tz: IST, now });
  const reason = async (p: Promise<unknown>) => {
    try {
      await p;
      return 'applied';
    } catch (e) {
      if (e instanceof MutationRejected) return e.reason;
      throw e;
    }
  };

  it('writes the merged settings and plans the next reminder in the profile zone', async () => {
    const tx = new FakeTx();
    const now = at('2026-10-08', 12);
    await handler.apply(ctx(tx, now), mutation({ reminderEnabled: true, reminderTime: '20:00' }, now.toISOString()));
    const p = tx.writes[0];
    expect(p.slice(0, 10)).toEqual([USER, true, true, '20:00', false, true, '23:00', '08:00', false, expect.any(String)]);
    expect(JSON.parse(p[9] as string)).toEqual({ reminderEnabled: now.toISOString(), reminderTime: now.toISOString() });
    expect(p[10]).toEqual(at('2026-10-08', 20)); // today 20:00 IST
    expect(p[11]).toBe(IST);
  });

  it('turning the reminder (or everything) off clears the plan', async () => {
    const tx = new FakeTx();
    tx.row = {
      enabled: true, reminder_enabled: true, reminder_time: '20:00:00', reminder_in_quiet_ok: false, capsule_enabled: true,
      quiet_start: '23:00:00', quiet_end: '08:00:00', discreet: false, field_ts: {},
    };
    await handler.apply(ctx(tx), mutation({ enabled: false }));
    expect(tx.writes[0][10]).toBeNull();
    expect(tx.writes[0][11]).toBeNull();
  });

  it('a device clock in the future never pins a field (stamps are clamped to server time)', async () => {
    const tx = new FakeTx();
    const now = later(1000);
    await handler.apply(ctx(tx, now), mutation({ discreet: true }, new Date(now.getTime() + 86_400_000).toISOString()));
    expect(JSON.parse(tx.writes[0][9] as string)).toEqual({ discreet: now.toISOString() });
  });

  it('a patch older than every stored field changes nothing (applied, no write)', async () => {
    const tx = new FakeTx();
    tx.row = {
      enabled: true, reminder_enabled: false, reminder_time: null, reminder_in_quiet_ok: false, capsule_enabled: true,
      quiet_start: '23:00:00', quiet_end: '08:00:00', discreet: true, field_ts: { discreet: later(500).toISOString() },
    };
    expect(await reason(handler.apply(ctx(tx), mutation({ discreet: false })))).toBe('applied');
    expect(tx.writes).toEqual([]);
  });

  it('rejects: bad shape / times → invalid_payload; missing deviceTs → invalid_payload; other ops → unknown_op', async () => {
    const tx = new FakeTx();
    expect(await reason(handler.apply(ctx(tx), mutation({ reminderTime: '25:00' })))).toBe('invalid_payload');
    expect(await reason(handler.apply(ctx(tx), mutation({})))).toBe('invalid_payload');
    expect(await reason(handler.apply(ctx(tx), mutation({ discreet: true }, null)))).toBe('invalid_payload');
    expect(await reason(handler.apply(ctx(tx), mutation({ discreet: true }, T0.toISOString(), 'delete')))).toBe('unknown_op');
    expect(tx.writes).toEqual([]);
  });
});

describe('ReminderScheduler', () => {
  interface Row {
    user_id: string;
    reminder_next_at: Date | null;
    reminder_tz: string | null;
    timezone: string;
    enabled: boolean;
    reminder_enabled: boolean;
    reminder_time: string | null;
    reminder_in_quiet_ok: boolean;
    capsule_enabled: boolean;
    quiet_start: string;
    quiet_end: string;
    discreet: boolean;
  }
  class FakeDb {
    rows: Row[] = [];
    async query(sql: string, params: unknown[] = []) {
      const s = sql.replace(/\s+/g, ' ');
      if (s.includes('where np.reminder_next_at <= $1')) {
        const now = params[0] as Date;
        const due = this.rows.filter((r) => r.reminder_next_at && r.reminder_next_at <= now);
        return { rows: due.map((r) => ({ ...r })), rowCount: due.length };
      }
      if (s.includes('np.reminder_tz is distinct from p.timezone')) {
        const sel = this.rows.filter(
          (r) =>
            (r.enabled && r.reminder_enabled && r.reminder_time && (!r.reminder_next_at || r.reminder_tz !== r.timezone)) ||
            ((!r.enabled || !r.reminder_enabled || !r.reminder_time) && r.reminder_next_at),
        );
        return { rows: sel.map((r) => ({ ...r })), rowCount: sel.length };
      }
      if (s.startsWith('update public.notification_prefs set reminder_next_at = $2, reminder_tz = $3')) {
        const [user, next, tz, old] = params as [string, Date | null, string | null, Date | null];
        const r = this.rows.find((x) => x.user_id === user && (x.reminder_next_at?.getTime() ?? null) === (old?.getTime() ?? null));
        if (!r) return { rows: [], rowCount: 0 };
        r.reminder_next_at = next;
        r.reminder_tz = tz;
        return { rows: [], rowCount: 1 };
      }
      if (s.startsWith('update public.notification_prefs set reminder_next_at = $2 where')) {
        const [user, restore, cur] = params as [string, Date, Date];
        const r = this.rows.find((x) => x.user_id === user && x.reminder_next_at?.getTime() === cur.getTime());
        if (r) r.reminder_next_at = restore;
        return { rows: [], rowCount: r ? 1 : 0 };
      }
      throw new Error(`unexpected SQL ${s.slice(0, 80)}`);
    }
  }
  const row = (over: Partial<Row> = {}): Row => ({
    user_id: USER,
    reminder_next_at: at('2026-10-08', 20),
    reminder_tz: IST,
    timezone: IST,
    enabled: true,
    reminder_enabled: true,
    reminder_time: '20:00:00',
    reminder_in_quiet_ok: false,
    capsule_enabled: true,
    quiet_start: '23:00:00',
    quiet_end: '08:00:00',
    discreet: false,
    ...over,
  });
  function harness() {
    const db = new FakeDb();
    const notifications = { enqueue: jest.fn(async () => undefined) };
    const s = new ReminderScheduler(db as never, {} as never, notifications as never);
    return { db, notifications, s };
  }
  beforeAll(() => Logger.overrideLogger(false));

  it('a due reminder is claimed, moved to tomorrow and enqueued once, deduplicated per Aura day', async () => {
    const h = harness();
    h.db.rows = [row()];
    expect(await h.s.sweep(at('2026-10-08', 20, 0))).toEqual({ due: 1, enqueued: 1, moved: 0 });
    expect(h.notifications.enqueue).toHaveBeenCalledWith(USER, 'daily_reminder', null, { dedupeKey: '2026-10-08' });
    expect(h.db.rows[0].reminder_next_at).toEqual(at('2026-10-09', 20));
    // the next sweep finds nothing due
    expect(await h.s.sweep(at('2026-10-08', 20, 1))).toEqual({ due: 0, enqueued: 0, moved: 0 });
  });

  it('a reminder more than 2 h late (worker outage) is moved on, not sent', async () => {
    const h = harness();
    h.db.rows = [row()];
    const now = new Date(at('2026-10-08', 20).getTime() + REMINDER_MAX_LATE_MS + 60_000);
    expect(await h.s.sweep(now)).toEqual({ due: 1, enqueued: 0, moved: 1 });
    expect(h.notifications.enqueue).not.toHaveBeenCalled();
    expect(h.db.rows[0].reminder_next_at).toEqual(at('2026-10-09', 20));
  });

  it('planned in another zone (the person travelled): re-planned in the new zone, not sent at the old time', async () => {
    const h = harness();
    h.db.rows = [row({ timezone: 'Europe/London' })];
    const now = at('2026-10-08', 20); // 15:30 in London
    expect(await h.s.sweep(now)).toEqual({ due: 1, enqueued: 0, moved: 1 });
    expect(h.db.rows[0]).toMatchObject({ reminder_next_at: at('2026-10-08', 20, 0, 'Europe/London'), reminder_tz: 'Europe/London' });
  });

  it('when Redis refuses the enqueue, the plan is put back for the next sweep', async () => {
    const h = harness();
    h.db.rows = [row()];
    h.notifications.enqueue.mockRejectedValueOnce(new Error('ECONNREFUSED'));
    expect(await h.s.sweep(at('2026-10-08', 20))).toEqual({ due: 1, enqueued: 0, moved: 0 });
    expect(h.db.rows[0].reminder_next_at).toEqual(at('2026-10-08', 20));
    expect(await h.s.sweep(at('2026-10-08', 20, 1))).toMatchObject({ enqueued: 1 });
  });

  it('reconcile: re-plans after a zone change, plans missing ones, clears unwanted ones', async () => {
    const h = harness();
    const OTHER = uuidv7();
    const THIRD = uuidv7();
    h.db.rows = [
      row({ timezone: 'America/New_York' }), // moved
      row({ user_id: OTHER, reminder_next_at: null, reminder_tz: null }), // never planned
      row({ user_id: THIRD, reminder_enabled: false }), // switched off elsewhere
    ];
    const now = at('2026-10-08', 12);
    expect(await h.s.reconcile(now)).toBe(3);
    expect(h.db.rows[0]).toMatchObject({ reminder_next_at: at('2026-10-08', 20, 0, 'America/New_York'), reminder_tz: 'America/New_York' });
    expect(h.db.rows[1]).toMatchObject({ reminder_next_at: at('2026-10-08', 20), reminder_tz: IST });
    expect(h.db.rows[2]).toMatchObject({ reminder_next_at: null, reminder_tz: null });
    expect(await h.s.reconcile(now)).toBe(0);
  });
});
