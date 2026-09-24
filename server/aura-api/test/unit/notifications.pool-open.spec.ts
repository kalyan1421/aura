/**
 * "Tell me when they open" (src/notifications/pool-waitlist.ts; PRD 06b F5, 14-states; 12-notifications rules): the
 * `rooms_pool_open` push under the global rules (quiet hours defer, the cap defers to the next Aura day, master switch,
 * pending deletion, a pool that closed again), its generic localized copy and channel, the sync entity, and the sweep
 * — once per opt-in, idempotent under repeated flag flips, never for deleted or closed accounts, and a Redis failure
 * leaves the opt-ins for the next sweep.
 */
import { Logger } from '@nestjs/common';
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { TYPE_RULES } from '../../src/notifications/catalogue';
import { decide, DEFAULT_NOTIFICATION_PREFS, endOfAuraDay, type DeliveryFacts } from '../../src/notifications/policy';
import { PoolOpenSweep, PoolWaitlistSyncHandler, POOL_OPEN_BATCH } from '../../src/notifications/pool-waitlist';
import { renderPushBody } from '../../src/notifications/push-copy';
import { MutationRejected } from '../../src/sync/mutation-rejected';

const IST = 'Asia/Kolkata';
const DAY = '2026-10-08';
const H = 3600_000;
const at = (hh: number, mm = 0, day = DAY): Date => zonedInstant(day, hh, mm, IST);

const facts = (over: Partial<DeliveryFacts> = {}): DeliveryFacts => {
  const now = over.now ?? at(12);
  return {
    type: 'rooms_pool_open',
    now,
    createdAt: now,
    tz: IST,
    prefs: { ...DEFAULT_NOTIFICATION_PREFS },
    pendingDeletion: false,
    devices: 1,
    sentToday: [],
    expectedLater: [],
    poolOpen: true,
    ...over,
  };
};

describe('rooms_pool_open under the global rules', () => {
  it('is sent with the defaults (no toggle of its own: the tap is the opt-in)', () => {
    expect(decide(facts())).toEqual({ action: 'send' });
  });

  it('respects the master switch, pending deletion, signed-out installs and a missing profile', () => {
    expect(decide(facts({ prefs: { ...DEFAULT_NOTIFICATION_PREFS, enabled: false } }))).toEqual({ action: 'skip', reason: 'disabled' });
    expect(decide(facts({ pendingDeletion: true }))).toEqual({ action: 'skip', reason: 'pending_deletion' });
    expect(decide(facts({ devices: 0 }))).toEqual({ action: 'skip', reason: 'no_device' });
    expect(decide(facts({ tz: null }))).toEqual({ action: 'skip', reason: 'no_profile' });
  });

  it('is not sent when the pool closed again meanwhile', () => {
    expect(decide(facts({ poolOpen: false }))).toEqual({ action: 'skip', reason: 'pool_closed' });
  });

  it('waits out quiet hours (deferred to their end, not dropped)', () => {
    const d = decide(facts({ now: at(23, 30) }));
    expect(d).toEqual({ action: 'defer', until: at(8, 0, '2026-10-09') });
  });

  it('once per day, and when two pushes already went out today it waits for the next Aura day', () => {
    expect(decide(facts({ sentToday: ['rooms_pool_open'] }))).toEqual({ action: 'skip', reason: 'already_sent' });
    const capped = decide(facts({ sentToday: ['daily_reminder', 'capsule_unlocked'] }));
    expect(capped).toEqual({ action: 'defer', until: endOfAuraDay(at(12), IST) });
  });

  it('gives up after 3 days (a worker outage, a long deferral)', () => {
    expect(decide(facts({ createdAt: new Date(at(12).getTime() - 73 * H) }))).toEqual({ action: 'skip', reason: 'expired' });
  });

  it('goes to the Android "Rooms & Lantern Hour" channel', () => {
    expect(TYPE_RULES.rooms_pool_open.channel).toBe('rooms');
  });

  it('copy: generic, in the app language (Hindi and Hinglish readers get their own words), discreet wins', () => {
    expect(renderPushBody('rooms_pool_open', 'en', false)).toBe('Hindi and Hinglish rooms are open now.');
    expect(renderPushBody('rooms_pool_open', 'te-Latn', false)).toBe('Hindi, Hinglish rooms ippudu modalayyaayi.');
    expect(renderPushBody('rooms_pool_open', 'te', false)).toMatch(/రూమ్‌లు/);
    expect(renderPushBody('rooms_pool_open', 'hi-Latn', false)).toBe('Hindi aur Hinglish rooms ab khul gaye hain.');
    expect(renderPushBody('rooms_pool_open', 'hi', false)).toBe('हिंदी और हिंग्लिश रूम अब खुल गए हैं।');
    expect(renderPushBody('rooms_pool_open', 'en', true)).toBe('You have a gentle update');
  });
});

describe('sync entity room_pool_waitlist', () => {
  const handler = new PoolWaitlistSyncHandler();
  const run = async (op: string, payload: Record<string, unknown>) => {
    const calls: Array<{ sql: string; params: unknown[] }> = [];
    const tx = { query: async (sql: string, params: unknown[]) => (calls.push({ sql, params }), { rows: [], rowCount: 1 }) };
    await handler.apply({ tx: tx as never, userId: 'u1' }, { id: 'm', entity: 'room_pool_waitlist', op, payload } as never);
    return calls;
  };

  it('upsert records the tap once (a repeat keeps the first)', async () => {
    const [c] = await run('upsert', { pool: 'hi' });
    expect(c.sql).toMatch(/insert into public\.room_pool_waitlist .* on conflict \(user_id, pool\) do nothing/s);
    expect(c.params).toEqual(['u1', 'hi']);
  });

  it('delete withdraws it', async () => {
    const [c] = await run('delete', { pool: 'hi' });
    expect(c.sql).toMatch(/delete from public\.room_pool_waitlist/);
  });

  it('refuses an unknown pool or op', async () => {
    await expect(run('upsert', { pool: 'te' })).rejects.toThrow(MutationRejected);
    await expect(run('upsert', {})).rejects.toThrow(MutationRejected);
    await expect(run('seal', { pool: 'hi' })).rejects.toThrow(MutationRejected);
  });
});

/** An in-memory waitlist with transaction semantics (deletes land only on commit). */
class FakeDb {
  flag = false;
  rows: Array<{ user_id: string; pool: string; eligible: boolean }> = [];

  async query(sql: string): Promise<{ rows: unknown[]; rowCount: number }> {
    if (sql.includes('from public.feature_flags')) return { rows: [{ enabled: this.flag }], rowCount: 1 };
    throw new Error(`unexpected statement outside a transaction: ${sql.slice(0, 60)}`);
  }

  async withTx<T>(fn: (tx: { query: (sql: string, params?: unknown[]) => Promise<{ rows: unknown[]; rowCount: number }> }) => Promise<T>): Promise<T> {
    let pending = this.rows;
    const tx = {
      query: async (sql: string, params: unknown[] = []) => {
        if (!sql.includes('delete from public.room_pool_waitlist')) throw new Error('unexpected statement');
        const [pool, limit] = params as [string, number];
        const claimed = pending.filter((r) => r.pool === pool).slice(0, limit);
        pending = pending.filter((r) => !claimed.includes(r));
        return { rows: claimed.map((r) => ({ user_id: r.user_id, eligible: r.eligible })), rowCount: claimed.length };
      },
    };
    const out = await fn(tx);
    this.rows = pending; // commit
    return out;
  }
}

describe('pool-open sweep', () => {
  beforeAll(() => Logger.overrideLogger(['error']));
  const setup = () => {
    const db = new FakeDb();
    const enqueued: Array<{ userId: string; type: string; key?: string }> = [];
    let failAfter = Infinity;
    const notifications = {
      enqueue: async (userId: string, type: string, _id: null, opts: { dedupeKey?: string }) => {
        if (enqueued.length >= failAfter) throw new Error('redis down');
        enqueued.push({ userId, type, key: opts.dedupeKey });
      },
    };
    const sweep = new PoolOpenSweep(db as never, {} as never, notifications as never);
    return { db, enqueued, sweep, failAt: (n: number) => (failAfter = n) };
  };
  const waiting = (id: string, eligible = true) => ({ user_id: id, pool: 'hi', eligible });

  it('does nothing while the Hindi + Hinglish pool is closed (the opt-ins wait)', async () => {
    const t = setup();
    t.db.rows = [waiting('a'), waiting('b')];
    expect(await t.sweep.sweep()).toEqual({ claimed: 0, enqueued: 0, skipped: 0 });
    expect(t.db.rows).toHaveLength(2);
  });

  it('once open: one push per opt-in, deleted and closed accounts get none, and every opt-in is cleared', async () => {
    const t = setup();
    t.db.rows = [waiting('a'), waiting('deleted', false), waiting('b')];
    t.db.flag = true;
    expect(await t.sweep.sweep()).toEqual({ claimed: 3, enqueued: 2, skipped: 1 });
    expect(t.enqueued).toEqual([
      { userId: 'a', type: 'rooms_pool_open', key: 'pool:hi' },
      { userId: 'b', type: 'rooms_pool_open', key: 'pool:hi' },
    ]);
    expect(t.db.rows).toEqual([]);
  });

  it('is idempotent: sweeping again, or flipping the flag off and on, sends nothing twice', async () => {
    const t = setup();
    t.db.rows = [waiting('a')];
    t.db.flag = true;
    await t.sweep.sweep();
    await t.sweep.sweep();
    t.db.flag = false;
    await t.sweep.sweep();
    t.db.flag = true;
    await t.sweep.sweep();
    expect(t.enqueued.map((e) => e.userId)).toEqual(['a']);
  });

  it('someone who taps again while the pool is closed is told at the next opening', async () => {
    const t = setup();
    t.db.rows = [waiting('a')];
    t.db.flag = true;
    await t.sweep.sweep();
    t.db.flag = false;
    t.db.rows = [waiting('a')];
    await t.sweep.sweep();
    t.db.flag = true;
    await t.sweep.sweep();
    expect(t.enqueued.map((e) => e.userId)).toEqual(['a', 'a']);
  });

  it('Redis refusing a job rolls the batch back: the opt-ins stay for the next sweep', async () => {
    const t = setup();
    t.db.rows = [waiting('a'), waiting('b')];
    t.db.flag = true;
    t.failAt(1);
    await expect(t.sweep.sweep()).rejects.toThrow('redis down');
    expect(t.db.rows.map((r) => r.user_id)).toEqual(['a', 'b']);
  });

  it('works through a long waitlist in batches', async () => {
    const t = setup();
    t.db.rows = Array.from({ length: POOL_OPEN_BATCH + 3 }, (_, i) => waiting(`u${i}`));
    t.db.flag = true;
    expect((await t.sweep.sweep()).enqueued).toBe(POOL_OPEN_BATCH + 3);
    expect(t.db.rows).toEqual([]);
  });
});
