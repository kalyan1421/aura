/**
 * U07 Orbit Loom constellations (src/constellations/loom-constellations.ts): the sync entity `loom_constellation`
 * validation (shape via RULES.md §14, meanings, the local-day window, future device time), the per-day limit, the
 * idempotent keep (same id twice → one row; someone else's id → id_conflict) and the soft delete that erases the shape.
 */
import { zonedInstant } from '../../src/capsules/capsule-rules';
import { uuidv7 } from '../../src/common/uuid';
import { LoomConstellationSyncHandler, validateConstellation } from '../../src/constellations/loom-constellations';
import { MAX_LOOM_CONSTELLATIONS_PER_DAY } from '../../src/rules';
import { MutationRejected } from '../../src/sync/mutation-rejected';
import type { Mutation } from '../../src/sync/sync.schema';

const IST = 'Asia/Kolkata';
const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const OTHER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0e';
const at = (day: string, hh: number, mm = 0) => zonedInstant(day, hh, mm, IST);
const NOW = at('2026-10-08', 21);
const TRIANGLE = [
  [0.2, 0.2],
  [0.8, 0.25],
  [0.5, 0.8],
];

const keep = (payload: Record<string, unknown> = {}, over: Partial<Mutation> = {}): Mutation =>
  ({
    id: uuidv7(),
    entity: 'loom_constellation',
    op: 'upsert',
    deviceTs: at('2026-10-08', 20, 30).toISOString(),
    localDay: '2026-10-08',
    tz: IST,
    payload: { id: uuidv7(), stars: TRIANGLE, links: [[0, 1], [1, 2]], meaning: 'noticed', ...payload },
    ...over,
  }) as Mutation;

const reason = async (f: () => unknown): Promise<string> => {
  try {
    await f();
    return 'ok';
  } catch (e) {
    if (e instanceof MutationRejected) return e.reason;
    throw e;
  }
};
const check = (m: Mutation) => reason(() => validateConstellation(m, IST, NOW));

describe('validateConstellation', () => {
  it('accepts a shape, with or without a meaning, and with no lines', async () => {
    expect(await check(keep())).toBe('ok');
    expect(await check(keep({ meaning: null }))).toBe('ok');
    expect(await check(keep({ meaning: undefined }))).toBe('ok');
    expect(await check(keep({ links: [] }))).toBe('ok');
    expect(validateConstellation(keep({ meaning: undefined }), IST, NOW).payload.meaning).toBeNull();
  });

  it('refuses a shape the rule refuses (RULES.md §14), and free text as a meaning', async () => {
    expect(await check(keep({ stars: TRIANGLE.slice(0, 2) }))).toBe('invalid_constellation');
    expect(await check(keep({ stars: [...TRIANGLE, [1.2, 0.5]] }))).toBe('invalid_constellation');
    expect(await check(keep({ links: [[0, 0]] }))).toBe('invalid_constellation');
    expect(await check(keep({ links: [[0, 1], [1, 0]] }))).toBe('invalid_constellation');
    expect(await check(keep({ meaning: 'I was sad today' }))).toBe('invalid_constellation');
  });

  it('refuses a malformed payload or missing time', async () => {
    expect(await check(keep({ stars: 'three' }))).toBe('invalid_payload');
    expect(await check(keep({ id: 'nope' }))).toBe('invalid_payload');
    expect(await check(keep({ meaning: 7 }))).toBe('invalid_payload');
    expect(await check(keep({}, { deviceTs: undefined }))).toBe('invalid_payload');
    expect(await check(keep({}, { localDay: undefined }))).toBe('invalid_payload');
  });

  it('refuses a future time and a day that does not fit the time', async () => {
    expect(await check(keep({}, { deviceTs: at('2026-10-08', 21, 10).toISOString() }))).toBe('device_ts_in_future');
    expect(await check(keep({}, { localDay: '2026-10-05' }))).toBe('invalid_local_day');
    // Kept offline a week ago, arriving now: fine.
    expect(await check(keep({}, { deviceTs: at('2026-10-01', 12).toISOString(), localDay: '2026-10-01' }))).toBe('ok');
  });
});

describe('LoomConstellationSyncHandler', () => {
  type Row = { user_id: string; local_day: string; deleted: boolean; params: unknown[] };
  class FakeTx {
    rows = new Map<string, Row>();
    async query(sql: string, params: unknown[] = []) {
      if (sql.startsWith('select user_id from public.loom_constellations')) {
        const r = this.rows.get(params[0] as string);
        return { rows: r ? [{ user_id: r.user_id }] : [], rowCount: r ? 1 : 0 };
      }
      if (sql.includes('select count(*)::int as n from public.loom_constellations')) {
        const n = [...this.rows.values()].filter((r) => r.user_id === params[0] && r.local_day === params[1] && !r.deleted).length;
        return { rows: [{ n }], rowCount: 1 };
      }
      if (sql.includes('insert into public.loom_constellations')) {
        if (this.rows.has(params[0] as string)) return { rows: [], rowCount: 0 };
        this.rows.set(params[0] as string, { user_id: params[1] as string, local_day: params[5] as string, deleted: false, params });
        return { rows: [], rowCount: 1 };
      }
      if (sql.includes('update public.loom_constellations')) {
        const r = this.rows.get(params[0] as string);
        if (r && r.user_id === params[1] && !r.deleted) {
          r.deleted = true;
          r.params = [params[0], r.user_id, null, null, null, r.local_day, r.params[6]];
          return { rows: [], rowCount: 1 };
        }
        return { rows: [], rowCount: 0 };
      }
      throw new Error(sql);
    }
  }
  const handler = new LoomConstellationSyncHandler();
  const ctx = (tx: FakeTx, userId = USER) => ({ tx: tx as never, userId, tz: IST, now: NOW });

  it('keeps one row: id, user, stars, lines, meaning, day, device time — nothing else', async () => {
    const tx = new FakeTx();
    const m = keep();
    await handler.apply(ctx(tx), m);
    const p = m.payload as { id: string };
    expect(tx.rows.get(p.id)?.params).toEqual([
      p.id,
      USER,
      JSON.stringify(TRIANGLE),
      JSON.stringify([[0, 1], [1, 2]]),
      'noticed',
      '2026-10-08',
      m.deviceTs,
    ]);
  });

  it('idempotent on the constellation id; another account using the id → id_conflict', async () => {
    const tx = new FakeTx();
    const m = keep();
    await handler.apply(ctx(tx), m);
    await handler.apply(ctx(tx), { ...m, id: uuidv7() });
    expect(tx.rows.size).toBe(1);
    expect(await reason(() => handler.apply(ctx(tx, OTHER), { ...m, id: uuidv7() }))).toBe('id_conflict');
  });

  it(`at most ${MAX_LOOM_CONSTELLATIONS_PER_DAY} a day; letting one go frees its place; another day is fresh`, async () => {
    const tx = new FakeTx();
    const kept: Mutation[] = [];
    for (let i = 0; i < MAX_LOOM_CONSTELLATIONS_PER_DAY; i++) {
      const m = keep();
      kept.push(m);
      await handler.apply(ctx(tx), m);
    }
    expect(await reason(() => handler.apply(ctx(tx), keep()))).toBe('too_many_constellations');
    // A resend of one already kept is still fine at the limit.
    expect(await reason(() => handler.apply(ctx(tx), { ...kept[0], id: uuidv7() }))).toBe('ok');
    const first = (kept[0].payload as { id: string }).id;
    await handler.apply(ctx(tx), { ...keep(), op: 'delete', payload: { id: first } });
    expect(await reason(() => handler.apply(ctx(tx), keep()))).toBe('ok');
    const tomorrow = { deviceTs: at('2026-10-07', 20).toISOString(), localDay: '2026-10-07' };
    expect(await reason(() => handler.apply(ctx(tx), keep({}, tomorrow)))).toBe('ok');
  });

  it('letting go erases the shape and meaning; again is fine; unknown ids are fine; others\' ids are not', async () => {
    const tx = new FakeTx();
    const m = keep();
    await handler.apply(ctx(tx), m);
    const id = (m.payload as { id: string }).id;
    const del = { ...m, id: uuidv7(), op: 'delete' as const, payload: { id } };
    await handler.apply(ctx(tx), del);
    expect(tx.rows.get(id)).toMatchObject({ deleted: true });
    expect(tx.rows.get(id)?.params.slice(2, 5)).toEqual([null, null, null]);
    expect(await reason(() => handler.apply(ctx(tx), { ...del, id: uuidv7() }))).toBe('ok');
    expect(await reason(() => handler.apply(ctx(tx), { ...del, payload: { id: uuidv7() } }))).toBe('ok');
    expect(await reason(() => handler.apply(ctx(tx, OTHER), del))).toBe('id_conflict');
    expect(await reason(() => handler.apply(ctx(tx), { ...del, payload: { id: 'nope' } }))).toBe('invalid_payload');
    // A let-go constellation is never brought back by a late resend of its keep.
    await handler.apply(ctx(tx), { ...m, id: uuidv7() });
    expect(tx.rows.get(id)).toMatchObject({ deleted: true });
  });

  it('other ops are unknown', async () => {
    expect(await reason(() => handler.apply(ctx(new FakeTx()), { ...keep(), op: 'seal' }))).toBe('unknown_op');
  });
});
