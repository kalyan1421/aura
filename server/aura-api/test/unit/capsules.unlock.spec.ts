/**
 * The "Date capsule unlocked" push (contracts/api/v1-capsules.md §6): CapsuleUnlockService scheduling / processing /
 * sweep against a fake DB and queue, plus the NotificationsService interface (log-only transport until F14).
 */
import { Logger } from '@nestjs/common';
import { DelayedError } from 'bullmq';
import { unlockAt } from '../../src/capsules/capsule-rules';
import {
  CapsuleUnlockService,
  MAX_LATE_MS,
  OVERDUE_AFTER_MS,
  SWEEP_JOB,
  UNLOCK_JOB,
  unlockJobId,
} from '../../src/capsules/capsule-unlock.service';
import { uuidv7 } from '../../src/common/uuid';
import { LogOnlyNotificationTransport } from '../../src/notifications/log-only.transport';
import { NotificationDispatcher } from '../../src/notifications/notification-dispatcher';
import { NOTIFICATION_JOB, parseNotificationJob } from '../../src/notifications/notification-types';
import { DEFAULT_DEDUPE_TTL_MS, notificationDedupeId, NotificationsService } from '../../src/notifications/notifications.service';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const DATE = '2027-10-08';
const AT_IST = unlockAt(DATE, 'Asia/Kolkata'); // 2027-10-08T04:30:00Z
const H = 3600_000;

interface CapsuleState {
  user_id: string;
  unlock_type: 'date' | 'mood';
  unlock_local_date: string | null;
  deleted: boolean;
  opened: boolean;
  timezone: string | null;
  notified_at: Date | null;
}

/** Routes the service's SQL to in-memory state (by statement shape). */
class FakeDb {
  capsules = new Map<string, CapsuleState>();
  schedule = new Map<string, { notify_at: Date; notify_tz: string; notified_at: Date | null }>();
  stale: string[] = [];
  overdue: string[] = [];
  log: string[] = [];

  async query(sql: string, params: unknown[] = []) {
    const s = sql.replace(/\s+/g, ' ');
    if (s.includes('where c.id = any($1::uuid[])')) {
      const ids = params[0] as string[];
      const rows = ids
        .map((id) => [id, this.capsules.get(id)] as const)
        .filter(([id, c]) => c && c.unlock_type === 'date' && !c.deleted && !c.opened && c.timezone && !this.schedule.get(id)?.notified_at)
        .map(([id, c]) => ({ id, unlock_local_date: c!.unlock_local_date, timezone: c!.timezone }));
      return { rows, rowCount: rows.length };
    }
    if (s.startsWith('select c.user_id, c.unlock_type')) {
      const id = params[0] as string;
      const c = this.capsules.get(id);
      const rows = c ? [{ ...c, notified_at: this.schedule.get(id)?.notified_at ?? null }] : [];
      return { rows, rowCount: rows.length };
    }
    if (s.startsWith('insert into public.capsule_unlock_schedule (capsule_id, notify_at, notify_tz, notified_at)')) {
      const [id, at, tz] = params as [string, Date, string];
      const cur = this.schedule.get(id);
      this.schedule.set(id, { notify_at: cur?.notify_at ?? at, notify_tz: cur?.notify_tz ?? tz, notified_at: cur?.notified_at ?? new Date() });
      this.log.push('mark');
      return { rows: [], rowCount: 1 };
    }
    if (s.startsWith('insert into public.capsule_unlock_schedule')) {
      const [id, at, tz] = params as [string, Date, string];
      const cur = this.schedule.get(id);
      if (!cur?.notified_at) this.schedule.set(id, { notify_at: at, notify_tz: tz, notified_at: null });
      this.log.push('upsert');
      return { rows: [], rowCount: 1 };
    }
    if (s.startsWith('delete from public.capsule_unlock_schedule')) {
      this.schedule.delete(params[0] as string);
      this.log.push('delete');
      return { rows: [], rowCount: 1 };
    }
    if (s.includes('s.notify_tz is distinct from p.timezone')) {
      return { rows: this.stale.map((id) => ({ id })), rowCount: this.stale.length };
    }
    if (s.startsWith('select capsule_id from public.capsule_unlock_schedule')) {
      return { rows: this.overdue.map((capsule_id) => ({ capsule_id })), rowCount: this.overdue.length };
    }
    throw new Error(`unexpected SQL: ${s.slice(0, 80)}`);
  }
}

class FakeJob {
  removed = false;
  constructor(
    readonly id: string,
    readonly name: string,
    readonly data: unknown,
    readonly timestamp: number,
    readonly delay: number,
    public state: string,
  ) {}
  async getState() {
    return this.state;
  }
  async remove() {
    this.removed = true;
  }
}

class FakeQueue {
  jobs = new Map<string, FakeJob>();
  added: { name: string; data: unknown; opts: Record<string, unknown> }[] = [];
  schedulers: unknown[][] = [];
  async getJob(id: string) {
    const j = this.jobs.get(id);
    return j && !j.removed ? j : undefined;
  }
  async add(name: string, data: unknown, opts: Record<string, unknown>) {
    this.added.push({ name, data, opts });
    if (typeof opts.jobId === 'string') {
      this.jobs.set(opts.jobId, new FakeJob(opts.jobId, name, data, Date.now(), Number(opts.delay ?? 0), 'delayed'));
    }
  }
  async upsertJobScheduler(...args: unknown[]) {
    this.schedulers.push(args);
  }
}

function harness() {
  const db = new FakeDb();
  const queue = new FakeQueue();
  const queues = { queue: (name: string) => (name === 'capsule-unlock' ? queue : null) };
  const notifications = { enqueue: jest.fn(async () => undefined) };
  const service = new CapsuleUnlockService(db as never, queues as never, notifications as never);
  return { db, queue, notifications, service };
}

const dateCapsule = (over: Partial<CapsuleState> = {}): CapsuleState => ({
  user_id: USER,
  unlock_type: 'date',
  unlock_local_date: DATE,
  deleted: false,
  opened: false,
  timezone: 'Asia/Kolkata',
  notified_at: null,
  ...over,
});

describe('CapsuleUnlockService', () => {
  beforeAll(() => Logger.overrideLogger(false));

  it('job ids are deterministic per capsule but opaque (logs never carry record ids)', () => {
    const id = uuidv7();
    expect(unlockJobId(id)).toBe(unlockJobId(id.toUpperCase()));
    expect(unlockJobId(id)).not.toContain(id);
    expect(unlockJobId(id)).toMatch(/^unlock-[0-9a-f]{32}$/);
    expect(unlockJobId(id)).not.toBe(unlockJobId(uuidv7()));
  });

  describe('schedule', () => {
    it('adds one delayed job at 10:00 in the profile zone (data = capsule id only) and records it', async () => {
      const h = harness();
      const id = uuidv7();
      h.db.capsules.set(id, dateCapsule());
      const now = new Date(AT_IST.getTime() - 30 * 24 * H);
      expect(await h.service.schedule([id], now)).toBe(1);
      expect(h.queue.added).toEqual([
        {
          name: UNLOCK_JOB,
          data: { capsuleId: id },
          opts: expect.objectContaining({ jobId: unlockJobId(id), delay: 30 * 24 * H, removeOnComplete: true }),
        },
      ]);
      expect(h.db.schedule.get(id)).toEqual({ notify_at: AT_IST, notify_tz: 'Asia/Kolkata', notified_at: null });
    });

    it('skips opened / deleted / trigger / already notified capsules', async () => {
      const h = harness();
      const ids = [uuidv7(), uuidv7(), uuidv7(), uuidv7()];
      h.db.capsules.set(ids[0], dateCapsule({ opened: true }));
      h.db.capsules.set(ids[1], dateCapsule({ deleted: true }));
      h.db.capsules.set(ids[2], dateCapsule({ unlock_type: 'mood', unlock_local_date: null }));
      h.db.capsules.set(ids[3], dateCapsule());
      h.db.schedule.set(ids[3], { notify_at: AT_IST, notify_tz: 'Asia/Kolkata', notified_at: new Date() });
      expect(await h.service.schedule(ids)).toBe(0);
      expect(h.queue.added).toHaveLength(0);
    });

    it('re-scheduling replaces a delayed job at another time, keeps one at the same time, never touches an active one', async () => {
      const h = harness();
      const id = uuidv7();
      h.db.capsules.set(id, dateCapsule());
      const same = new FakeJob(unlockJobId(id), UNLOCK_JOB, { capsuleId: id }, AT_IST.getTime() - 1000, 1000, 'delayed');
      h.queue.jobs.set(same.id, same);
      await h.service.schedule([id], new Date(AT_IST.getTime() - 1000));
      expect(same.removed).toBe(false);
      expect(h.queue.added).toHaveLength(0);

      h.db.capsules.set(id, dateCapsule({ timezone: 'America/New_York' })); // moved west
      await h.service.schedule([id], new Date(AT_IST.getTime() - 1000));
      expect(same.removed).toBe(true);
      expect(h.queue.added).toHaveLength(1);
      expect(h.db.schedule.get(id)?.notify_tz).toBe('America/New_York');

      const active = h.queue.jobs.get(unlockJobId(id))!;
      active.state = 'active';
      h.db.capsules.set(id, dateCapsule({ timezone: 'Europe/London' }));
      await h.service.schedule([id], new Date(AT_IST.getTime() - 1000));
      expect(active.removed).toBe(false);
      expect(h.queue.added).toHaveLength(1);
    });

    it('an unlock already in the past is scheduled to run now (delay 0)', async () => {
      const h = harness();
      const id = uuidv7();
      h.db.capsules.set(id, dateCapsule());
      await h.service.schedule([id], new Date(AT_IST.getTime() + H));
      expect(h.queue.added[0].opts.delay).toBe(0);
    });
  });

  describe('process', () => {
    it('on time: one deduplicated push (per user + unlock date) with the capsule id only, then marked sent', async () => {
      const h = harness();
      const id = uuidv7();
      h.db.capsules.set(id, dateCapsule());
      expect(await h.service.process(id, AT_IST)).toEqual({ status: 'notified' });
      expect(h.notifications.enqueue).toHaveBeenCalledWith(USER, 'capsule_unlocked', id, { dedupeKey: DATE });
      expect(h.db.schedule.get(id)?.notified_at).toBeInstanceOf(Date);
      expect(await h.service.process(id, AT_IST)).toEqual({ status: 'already_notified' });
      expect(h.notifications.enqueue).toHaveBeenCalledTimes(1);
    });

    it('the zone moved west since scheduling → early, re-timed to 10:00 in the new zone', async () => {
      const h = harness();
      const id = uuidv7();
      h.db.capsules.set(id, dateCapsule({ timezone: 'America/New_York' }));
      const out = await h.service.process(id, AT_IST);
      expect(out).toEqual({ status: 'early', at: unlockAt(DATE, 'America/New_York') });
      expect(h.db.schedule.get(id)).toMatchObject({ notify_at: unlockAt(DATE, 'America/New_York'), notify_tz: 'America/New_York' });
      expect(h.notifications.enqueue).not.toHaveBeenCalled();
    });

    it('more than 24 h late → no push (the device already knew), marked done', async () => {
      const h = harness();
      const id = uuidv7();
      h.db.capsules.set(id, dateCapsule());
      expect(await h.service.process(id, new Date(AT_IST.getTime() + MAX_LATE_MS + 1))).toEqual({ status: 'too_late' });
      expect(h.notifications.enqueue).not.toHaveBeenCalled();
      expect(h.db.schedule.get(id)?.notified_at).toBeInstanceOf(Date);
      // up to 24 h late still goes out
      const id2 = uuidv7();
      h.db.capsules.set(id2, dateCapsule());
      expect(await h.service.process(id2, new Date(AT_IST.getTime() + MAX_LATE_MS))).toEqual({ status: 'notified' });
    });

    it('opened, deleted, trigger or profile-less capsules → skipped and their bookkeeping dropped; missing → gone', async () => {
      const h = harness();
      for (const over of [{ opened: true }, { deleted: true }, { unlock_type: 'mood' as const }, { timezone: null }]) {
        const id = uuidv7();
        h.db.capsules.set(id, dateCapsule(over));
        h.db.schedule.set(id, { notify_at: AT_IST, notify_tz: 'Asia/Kolkata', notified_at: null });
        expect(await h.service.process(id, AT_IST)).toEqual({ status: 'skipped' });
        expect(h.db.schedule.has(id)).toBe(false);
      }
      expect(await h.service.process(uuidv7(), AT_IST)).toEqual({ status: 'gone' });
      expect(h.notifications.enqueue).not.toHaveBeenCalled();
    });
  });

  describe('handle (worker processor)', () => {
    const job = (name: string, data: unknown) => {
      const j = { name, data, moveToDelayed: jest.fn(async () => undefined) };
      return j;
    };

    it('an early unlock job is moved back to delayed at the new time (same job id)', async () => {
      const h = harness();
      const id = uuidv7();
      h.db.capsules.set(id, dateCapsule({ timezone: 'America/Los_Angeles' }));
      const j = job(UNLOCK_JOB, { capsuleId: id });
      // "now" for handle() is the real clock: far before 2027-10-08, so it is early in any zone.
      await expect(h.service.handle(j as never, 'lock-token')).rejects.toBeInstanceOf(DelayedError);
      expect(j.moveToDelayed).toHaveBeenCalledWith(unlockAt(DATE, 'America/Los_Angeles').getTime(), 'lock-token');
    });

    it('malformed or unknown jobs are dropped without throwing', async () => {
      const h = harness();
      await expect(h.service.handle(job(UNLOCK_JOB, { capsuleId: 'not-a-uuid' }) as never)).resolves.toBeUndefined();
      await expect(h.service.handle(job(UNLOCK_JOB, null) as never)).resolves.toBeUndefined();
      await expect(h.service.handle(job('something-else', {}) as never)).resolves.toBeUndefined();
    });

    it('the sweep job runs the sweep', async () => {
      const h = harness();
      const spy = jest.spyOn(h.service, 'sweep').mockResolvedValue({ scheduled: 0, overdue: 0, notified: 0 });
      await h.service.handle(job(SWEEP_JOB, {}) as never);
      expect(spy).toHaveBeenCalled();
    });
  });

  it('sweep: schedules never-scheduled / zone-changed capsules and processes overdue ones', async () => {
    const h = harness();
    const stale = uuidv7();
    const overdue = uuidv7();
    h.db.capsules.set(stale, dateCapsule());
    h.db.capsules.set(overdue, dateCapsule());
    h.db.stale = [stale];
    h.db.overdue = [overdue];
    const now = new Date(AT_IST.getTime() + OVERDUE_AFTER_MS + 60_000);
    expect(await h.service.sweep(now)).toEqual({ scheduled: 1, overdue: 1, notified: 1 });
    expect(h.queue.added.map((a) => (a.data as { capsuleId: string }).capsuleId)).toEqual([stale]);
    expect(h.notifications.enqueue).toHaveBeenCalledWith(USER, 'capsule_unlocked', overdue, { dedupeKey: DATE });
  });

  it('registers the repeatable sweep every 10 minutes', async () => {
    const h = harness();
    await h.service.ensureSweepScheduler();
    expect(h.queue.schedulers).toEqual([
      ['aura-capsule-unlock-sweep', { every: 600_000 }, { name: SWEEP_JOB, data: {}, opts: { removeOnComplete: 10, removeOnFail: 50 } }],
    ]);
  });
});

describe('NotificationsService (producer)', () => {
  const setup = () => {
    const added: { name: string; data: unknown; opts: Record<string, unknown> }[] = [];
    const queue = { add: async (name: string, data: unknown, opts: Record<string, unknown>) => void added.push({ name, data, opts }) };
    const service = new NotificationsService({ queue: (n: string) => (n === 'notifications' ? queue : null) } as never);
    return { added, service };
  };

  it('queues { userId, type, id } only; dedupe keys are opaque hashes with a TTL', async () => {
    const { added, service } = setup();
    const capsuleId = uuidv7();
    await service.enqueue(USER.toUpperCase(), 'capsule_unlocked', capsuleId, { dedupeKey: DATE });
    expect(added).toHaveLength(1);
    expect(added[0].name).toBe(NOTIFICATION_JOB);
    expect(added[0].data).toEqual({ userId: USER, type: 'capsule_unlocked', id: capsuleId });
    const dedupe = added[0].opts.deduplication as { id: string; ttl: number };
    expect(dedupe).toEqual({ id: notificationDedupeId(USER, 'capsule_unlocked', DATE), ttl: DEFAULT_DEDUPE_TTL_MS });
    expect(dedupe.id).toMatch(/^[0-9a-f]{64}$/);
    expect(dedupe.id).not.toContain(USER);
    expect(added[0].opts).toMatchObject({ removeOnComplete: true, attempts: 5 });
    // same user + day → same key; another day → another key
    expect(notificationDedupeId(USER, 'capsule_unlocked', DATE)).toBe(notificationDedupeId(USER.toUpperCase(), 'capsule_unlocked', DATE));
    expect(notificationDedupeId(USER, 'capsule_unlocked', '2027-10-09')).not.toBe(dedupe.id);

    await service.enqueue(USER, 'capsule_unlocked', null);
    expect(added[1].opts.deduplication).toBeUndefined();
    expect(added[1].data).toEqual({ userId: USER, type: 'capsule_unlocked', id: null });
  });

  it('refuses anything that is not a user id, a known type and an opaque id (never content)', async () => {
    const { added, service } = setup();
    await expect(service.enqueue('someone', 'capsule_unlocked', null)).rejects.toThrow(TypeError);
    await expect(service.enqueue(USER, 'not_a_push_type' as never, null)).rejects.toThrow(TypeError); // unknown type
    await expect(service.enqueue(USER, 'capsule_unlocked', 'You wrote: dear me')).rejects.toThrow(TypeError);
    expect(added).toHaveLength(0);
  });
});

// F14: the dispatcher now applies the global rules before the transport (test/unit/notifications.delivery.spec.ts);
// here only the job routing and the log-only transport's privacy.
describe('NotificationDispatcher + log-only transport (worker)', () => {
  it('hands valid push jobs to delivery and drops malformed ones', async () => {
    const delivery = { deliver: jest.fn(async () => ({ status: 'sent', devices: 1, pruned: 0 })), transportName: 'fake' };
    const d = new NotificationDispatcher(delivery as never, {} as never);
    const id = uuidv7();
    await d.handle({ name: NOTIFICATION_JOB, data: { userId: USER, type: 'capsule_unlocked', id }, timestamp: Date.now() } as never);
    expect(delivery.deliver).toHaveBeenCalledWith({ userId: USER, type: 'capsule_unlocked', id }, expect.any(Date), expect.any(Date));
    for (const data of [null, { userId: 'x', type: 'capsule_unlocked', id }, { userId: USER, type: 'nope', id }, { userId: USER, type: 'capsule_unlocked', id: 'text' }]) {
      await d.handle({ name: NOTIFICATION_JOB, data } as never);
    }
    expect(delivery.deliver).toHaveBeenCalledTimes(1);
    expect(parseNotificationJob({ userId: USER, type: 'capsule_unlocked', id: null })).toEqual({ userId: USER, type: 'capsule_unlocked', id: null });
  });

  it('the log-only transport records the type only — never the user id, the record id, the copy or the token', async () => {
    const lines: string[] = [];
    const spy = jest.spyOn(Logger.prototype, 'log').mockImplementation((m: unknown) => void lines.push(String(m)));
    try {
      const t = new LogOnlyNotificationTransport();
      const id = uuidv7();
      const body = 'Something you sealed is ready to open.';
      expect(
        await t.send(
          { token: 'fcm-token-secret', platform: 'ios' },
          { type: 'capsule_unlocked', id, body, channelId: 'capsules', collapseKey: 'k', ttlSeconds: 60 },
        ),
      ).toBe('sent');
      expect(lines.join('\n')).not.toContain(body);
      expect(lines.join('\n')).not.toContain('fcm-token-secret');
      expect(t.sent.get('capsule_unlocked')).toBe(1);
      expect(lines.join('\n')).toContain('capsule_unlocked');
      expect(lines.join('\n')).not.toContain(USER);
      expect(lines.join('\n')).not.toContain(id);
    } finally {
      spy.mockRestore();
    }
  });
});
