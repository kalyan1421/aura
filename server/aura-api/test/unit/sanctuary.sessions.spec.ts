/**
 * F15 Sanctuary session records (src/sanctuary/sanctuary-sessions.ts): the sync entity `sanctuary_session`
 * validation (op, activity / variant lists, duration bounds, the local-day window, future device time) and the
 * idempotent write (same record twice → one row; someone else's id → id_conflict).
 */
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { uuidv7 } from '../../src/common/uuid';
import {
  MAX_SESSION_S,
  SanctuarySessionSyncHandler,
  SESSION_VARIANTS,
  validateSession,
} from '../../src/sanctuary/sanctuary-sessions';
import { MutationRejected } from '../../src/sync/mutation-rejected';
import type { Mutation } from '../../src/sync/sync.schema';

const IST = 'Asia/Kolkata';
const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const OTHER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0e';
const at = (day: string, hh: number, mm = 0) => zonedInstant(day, hh, mm, IST);
const NOW = at('2026-10-08', 21);

const mutation = (payload: Record<string, unknown>, over: Partial<Mutation> = {}): Mutation =>
  ({
    id: uuidv7(),
    entity: 'sanctuary_session',
    op: 'upsert',
    deviceTs: at('2026-10-08', 20, 30).toISOString(),
    localDay: '2026-10-08',
    tz: IST,
    payload: { id: uuidv7(), activity: 'breathe', variant: 'calm', durationS: 64, ...payload },
    ...over,
  }) as Mutation;

const reason = (f: () => unknown): string => {
  try {
    f();
    return 'ok';
  } catch (e) {
    if (e instanceof MutationRejected) return e.reason;
    throw e;
  }
};
const check = (m: Mutation) => reason(() => validateSession(m, IST, NOW));

describe('sanctuary_session validation', () => {
  it('accepts each activity with its own variants (content-free lists)', () => {
    for (const [activity, variants] of Object.entries(SESSION_VARIANTS)) {
      for (const variant of variants) expect(check(mutation({ activity, variant }))).toBe('ok');
    }
  });

  it('refuses unknown activities, a variant of another activity, text, and missing fields', () => {
    expect(check(mutation({ activity: 'journal' }))).toBe('invalid_payload');
    expect(check(mutation({ activity: 'breathe', variant: 'senses' }))).toBe('invalid_payload');
    expect(check(mutation({ activity: 'grounding', variant: 'my three good things' }))).toBe('invalid_payload');
    expect(check(mutation({ id: 'nope' }))).toBe('invalid_payload');
    expect(check(mutation({}, { deviceTs: undefined }))).toBe('invalid_payload');
    expect(check(mutation({}, { localDay: undefined }))).toBe('invalid_payload');
  });

  it('only upsert', () => {
    expect(check(mutation({}, { op: 'delete' }))).toBe('unknown_op');
  });

  it('duration: a whole number of seconds, 1 … 12 h', () => {
    expect(check(mutation({ durationS: 1 }))).toBe('ok');
    expect(check(mutation({ durationS: MAX_SESSION_S }))).toBe('ok');
    expect(check(mutation({ durationS: 0 }))).toBe('invalid_duration');
    expect(check(mutation({ durationS: MAX_SESSION_S + 1 }))).toBe('invalid_duration');
    expect(check(mutation({ durationS: 12.5 }))).toBe('invalid_duration');
    expect(check(mutation({ durationS: '60' }))).toBe('invalid_payload');
  });

  it('local day: the Aura day it started (≤ 1 day before the finish), ≤ 2 days ahead; never in the future', () => {
    // Started 03:50 (the 7th's Aura day), finished 04:10 on the 8th.
    expect(check(mutation({}, { localDay: '2026-10-07', deviceTs: at('2026-10-08', 4, 10).toISOString() }))).toBe('ok');
    expect(check(mutation({}, { localDay: '2026-10-06' }))).toBe('invalid_local_day');
    expect(check(mutation({}, { localDay: '2026-10-10' }))).toBe('ok');
    expect(check(mutation({}, { localDay: '2026-10-11' }))).toBe('invalid_local_day');
    expect(check(mutation({}, { deviceTs: new Date(NOW.getTime() + 10 * 60_000).toISOString() }))).toBe('device_ts_in_future');
    // An old record from a phone that was offline for a while is still fine.
    expect(check(mutation({}, { localDay: '2026-09-01', deviceTs: at('2026-09-01', 21).toISOString() }))).toBe('ok');
  });
});

describe('SanctuarySessionSyncHandler', () => {
  class FakeTx {
    rows = new Map<string, { user_id: string; params: unknown[] }>();
    async query(sql: string, params: unknown[] = []) {
      if (sql.includes('insert into public.sanctuary_sessions')) {
        if (this.rows.has(params[0] as string)) return { rows: [], rowCount: 0 };
        this.rows.set(params[0] as string, { user_id: params[1] as string, params });
        return { rows: [], rowCount: 1 };
      }
      if (sql.startsWith('select user_id from public.sanctuary_sessions')) {
        const r = this.rows.get(params[0] as string);
        return { rows: r ? [{ user_id: r.user_id }] : [], rowCount: r ? 1 : 0 };
      }
      throw new Error(sql);
    }
  }
  const handler = new SanctuarySessionSyncHandler();

  it('writes one row: id, user, activity, variant, duration, day, device time — nothing else', async () => {
    const tx = new FakeTx();
    const m = mutation({ activity: 'sounds', variant: 'timer_30', durationS: 1800 });
    await handler.apply({ tx: tx as never, userId: USER, tz: IST, now: NOW }, m);
    const p = m.payload as { id: string };
    expect(tx.rows.get(p.id)?.params).toEqual([p.id, USER, 'sounds', 'timer_30', 1800, '2026-10-08', m.deviceTs]);
  });

  it('idempotent on the record id; another account using the id → id_conflict', async () => {
    const tx = new FakeTx();
    const m = mutation({});
    await handler.apply({ tx: tx as never, userId: USER, tz: IST, now: NOW }, m);
    await handler.apply({ tx: tx as never, userId: USER, tz: IST, now: NOW }, { ...m, id: uuidv7() });
    expect(tx.rows.size).toBe(1);
    await expect(handler.apply({ tx: tx as never, userId: OTHER, tz: IST, now: NOW }, { ...m, id: uuidv7() })).rejects.toMatchObject({
      reason: 'id_conflict',
    });
  });
});
