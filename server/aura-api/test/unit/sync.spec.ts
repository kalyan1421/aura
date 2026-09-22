/**
 * SyncService orchestration against an in-memory repository: idempotency, per-mutation
 * rejection, eligibility, append-only ledger with cap, deletes keep Starlight.
 * (The same scenarios run against the real DB in test/e2e.)
 */
import { Logger } from '@nestjs/common';
import { ApiError } from '../../src/common/api-error';
import { uuidv7 } from '../../src/common/uuid';
import { computeSnapshot } from '../../src/progression/snapshot';
import { addDays, auraDay } from '../../src/rules';
import { MutationRejected, rejectionReason } from '../../src/sync/mutation-rejected';
import { habitCreditId, SyncService } from '../../src/sync/sync.service';
import { checkInPayloadSchema, habitPayloadSchema } from '../../src/sync/sync.schema';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const OTHER = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const TZ = 'Asia/Kolkata';
const NOW = new Date('2026-10-08T10:00:00Z');
const TODAY = auraDay(NOW, TZ);

class MemRepo {
  mutations = new Map<string, { status: 'applied' | 'rejected'; reason: string | null }>();
  checkIns = new Map<string, { user: string; moodId: string; localDay: string; backfill: boolean }>();
  habits = new Map<string, { user: string; kind: string; presetKey: string | null; active: boolean }>();
  logs = new Map<string, { user: string; habitId: string; localDay: string }>();
  ledger: { user: string; amount: number; reason: string; sourceId: string; habitKey: string | null; localDay: string }[] = [];
  active = new Set<string>();

  async lockUser(): Promise<void> {}
  async findMutation(_: unknown, u: string, id: string) {
    return this.mutations.get(`${u}:${id}`) ?? null;
  }
  async recordMutation(_: unknown, m: { userId: string; mutationId: string; status: 'applied' | 'rejected'; reason: string | null }) {
    const k = `${m.userId}:${m.mutationId}`;
    if (!this.mutations.has(k)) this.mutations.set(k, { status: m.status, reason: m.reason });
  }
  async checkInOwner(_: unknown, id: string) {
    return this.checkIns.get(id)?.user ?? null;
  }
  async insertCheckIn(_: unknown, c: { userId: string; p: { id: string; moodId: string }; localDay: string; backfill: boolean }) {
    this.checkIns.set(c.p.id, { user: c.userId, moodId: c.p.moodId, localDay: c.localDay, backfill: c.backfill });
  }
  async updateCheckIn(_: unknown, u: string, p: { id: string; moodId: string }) {
    const c = this.checkIns.get(p.id);
    if (c && c.user === u) c.moodId = p.moodId;
  }
  async deleteCheckIn(_: unknown, u: string, id: string) {
    if (this.checkIns.get(id)?.user === u) this.checkIns.delete(id);
  }
  async upsertHabit(_: unknown, u: string, h: { id: string; kind: string; presetKey?: string | null; active: boolean }) {
    const cur = this.habits.get(h.id);
    if (cur && cur.user !== u) return false;
    this.habits.set(h.id, { user: u, kind: h.kind, presetKey: h.kind === 'preset' ? (h.presetKey ?? null) : null, active: h.active });
    return true;
  }
  async presetHabitTaken(_: unknown, u: string, presetKey: string, exceptId: string) {
    return [...this.habits.entries()].some(([id, h]) => id !== exceptId && h.user === u && h.kind === 'preset' && h.presetKey === presetKey);
  }
  async countActiveCustomHabits(_: unknown, u: string, exceptId: string) {
    return [...this.habits.entries()].filter(([id, h]) => id !== exceptId && h.user === u && h.kind === 'custom' && h.active).length;
  }
  async findHabit(_: unknown, u: string, id: string) {
    const h = this.habits.get(id);
    return h && h.user === u ? { presetKey: h.presetKey } : null;
  }
  async deleteHabit(_: unknown, u: string, id: string) {
    if (this.habits.get(id)?.user === u) this.habits.delete(id);
  }
  async habitLogOwner(_: unknown, id: string) {
    return this.logs.get(id)?.user ?? null;
  }
  async insertHabitLog(_: unknown, l: { id: string; userId: string; habitId: string; localDay: string }) {
    for (const x of this.logs.values()) if (x.habitId === l.habitId && x.localDay === l.localDay) return false;
    this.logs.set(l.id, { user: l.userId, habitId: l.habitId, localDay: l.localDay });
    return true;
  }
  async deleteHabitLog(_: unknown, u: string, id: string) {
    if (this.logs.get(id)?.user === u) this.logs.delete(id);
  }
  async ledgerHas(_: unknown, reason: string, sourceId: string) {
    return this.ledger.some((r) => r.reason === reason && r.sourceId === sourceId);
  }
  async dayLedger(_: unknown, u: string, day: string) {
    const rows = this.ledger.filter((r) => r.user === u && r.localDay === day);
    return { checkIns: rows.filter((r) => r.reason === 'checkin').length, total: rows.reduce((a, r) => a + r.amount, 0) };
  }
  async insertLedger(_: unknown, e: { userId: string; amount: number; reason: string; sourceId: string; habitKey: string | null; localDay: string }) {
    if (!(await this.ledgerHas(null, e.reason, e.sourceId))) this.ledger.push({ ...e, user: e.userId });
  }
  async markActive(_: unknown, u: string, day: string) {
    this.active.add(`${u}:${day}`);
  }
  total(u = USER): number {
    return this.ledger.filter((r) => r.user === u).reduce((a, r) => a + r.amount, 0);
  }
}

function makeService(repo: MemRepo, hasProfile = true): SyncService {
  const tx = { savepoint: <T>(fn: () => Promise<T>) => fn() };
  const db = { withTx: <T>(fn: (t: typeof tx) => Promise<T>) => fn(tx) };
  const profiles = {
    require: async () => {
      if (!hasProfile) throw ApiError.conflict('profile_required', 'x');
      return { timezone: TZ };
    },
  };
  const moods: Record<string, string> = { anxious: 'storm', calm: 'moonlight', joyful: 'sunrise' };
  const catalogue = {
    moodQuadrant: async (id: string) => moods[id],
    isPresetHabit: async (k: string) => ['breathe', 'sleep_on_time', 'hydrate', 'move', 'journal', 'go_outside'].includes(k),
  };
  const progression = {
    recompute: async (_: unknown, u: string, tz: string, now: Date) =>
      computeSnapshot(
        {
          totalStarlight: repo.total(u),
          todayStarlight: repo.ledger.filter((r) => r.user === u && r.localDay === auraDay(now, tz)).reduce((a, r) => a + r.amount, 0),
          breatheCompletions: 0,
          sleepCompletions: 0,
          hueCounts: {},
          activeDays: [...repo.active].filter((k) => k.startsWith(`${u}:`)).map((k) => k.split(':')[1]),
          equippedCosmetics: [],
        },
        now,
        tz,
      ),
  };
  return new SyncService(db as never, repo as never, profiles as never, catalogue as never, progression as never);
}

const ts = NOW.toISOString();
const checkIn = (moodId = 'anxious', over: Record<string, unknown> = {}) => ({
  id: uuidv7(),
  entity: 'check_in',
  op: 'upsert',
  deviceTs: ts,
  localDay: TODAY,
  payload: { id: uuidv7(), moodId, tags: ['study'], noteCt: null, source: 'app' },
  ...over,
});
const habit = (id: string, presetKey: string | null = null) => ({
  id: uuidv7(),
  entity: 'habit',
  op: 'upsert',
  deviceTs: ts,
  localDay: TODAY,
  payload: presetKey ? { id, kind: 'preset', presetKey, name: null, active: true } : { id, kind: 'custom', name: `h-${id.slice(-4)}`, active: true },
});
const log = (habitId: string, over: Record<string, unknown> = {}) => ({
  id: uuidv7(),
  entity: 'habit_log',
  op: 'upsert',
  deviceTs: ts,
  localDay: TODAY,
  payload: { id: uuidv7(), habitId },
  ...over,
});
const del = (entity: string, id: string) => ({ id: uuidv7(), entity, op: 'delete', deviceTs: ts, localDay: TODAY, payload: { id } });
const push = (s: SyncService, mutations: unknown[], user = USER) =>
  s.push(user, { deviceId: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9caa', mutations }, NOW);

describe('SyncService (in-memory repo)', () => {
  beforeAll(() => Logger.overrideLogger(false));
  it('requires a profile and a well-formed request', async () => {
    await expect(push(makeService(new MemRepo(), false), [])).rejects.toMatchObject({ status: 409, code: 'profile_required' });
    const s = makeService(new MemRepo());
    await expect(s.push(USER, { deviceId: 'x', mutations: [] }, NOW)).rejects.toMatchObject({ status: 400, code: 'invalid_request' });
    await expect(push(s, Array.from({ length: 201 }, () => checkIn()))).rejects.toMatchObject({ status: 400, code: 'too_many_mutations' });
  });

  it('applies, then replays as duplicate without new credit', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const muts = [checkIn(), checkIn('calm')];
    const first = await push(s, muts);
    expect(first.results.map((r) => r.status)).toEqual(['applied', 'applied']);
    expect(first.snapshot.starlight).toEqual({ total: 12, today: 12 });
    const again = await push(s, muts);
    expect(again.results.map((r) => r.status)).toEqual(['duplicate', 'duplicate']);
    expect(repo.ledger).toHaveLength(2);
  });

  it('legit daily max is 59 (6 presets + 3 custom + 4 check-ins), one ledger row per eligible event', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const habitIds = Array.from({ length: 9 }, () => uuidv7());
    const presets = ['hydrate', 'sleep_on_time', 'move', 'breathe', 'journal', 'go_outside'];
    const r = await push(s, [
      ...habitIds.map((h, i) => habit(h, presets[i] ?? null)),
      checkIn(),
      checkIn(),
      checkIn(),
      checkIn(),
      ...habitIds.map((h) => log(h)),
    ]);
    expect(r.results.every((x) => x.status === 'applied')).toBe(true);
    expect(r.snapshot.starlight.today).toBe(59);
    expect(repo.ledger.map((x) => x.amount)).toEqual([10, 2, 2, 0, 5, 5, 5, 5, 5, 5, 5, 5, 5]);
    expect(repo.ledger.filter((x) => x.habitKey === 'breathe')).toHaveLength(1);
  });

  it('rejects one bad mutation while the rest apply; replayed rejection stays rejected', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const bad = checkIn('ecstatic');
    const r = await push(s, [checkIn(), bad, checkIn('joyful')]);
    expect(r.results.map((x) => [x.status, x.reason])).toEqual([
      ['applied', undefined],
      ['rejected', 'unknown_mood'],
      ['applied', undefined],
    ]);
    const replay = await push(s, [bad]);
    expect(replay.results[0]).toEqual({ id: bad.id, status: 'rejected', reason: 'unknown_mood' });
  });

  it.each<[string, () => unknown, string]>([
    ['unknown entity', () => ({ ...checkIn(), entity: 'capsule' }), 'unknown_entity'],
    ['unknown op', () => ({ ...checkIn(), op: 'patch' }), 'unknown_op'],
    ['bad payload', () => ({ ...checkIn(), payload: { id: 'nope', moodId: 'calm' } }), 'invalid_payload'],
    ['missing deviceTs on a new event', () => ({ ...checkIn(), deviceTs: undefined }), 'invalid_payload'],
    ['habit_log for an unknown habit', () => log(uuidv7()), 'habit_not_found'],
    ['unknown preset habit', () => habit(uuidv7(), 'levitate'), 'unknown_preset_habit'],
    ['backfill older than 7 days', () => checkIn('calm', { localDay: addDays(TODAY, -8) }), 'backfill_too_old'],
    ['localDay far in the future', () => checkIn('calm', { localDay: addDays(TODAY, 3) }), 'invalid_local_day'],
  ])('rejects %s', async (_, make, reason) => {
    const r = await push(makeService(new MemRepo()), [make()]);
    expect(r.results[0]).toMatchObject({ status: 'rejected', reason });
  });

  it('rejects a mutation without a usable id without recording it', async () => {
    const repo = new MemRepo();
    const r = await push(makeService(repo), [{ ...checkIn(), id: 42 }]);
    expect(r.results[0]).toEqual({ id: '', status: 'rejected', reason: 'invalid_mutation_id' });
    expect(repo.mutations.size).toBe(0);
  });

  it('stores backfills and stale/future events without credit or active days', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const future = new Date(NOW.getTime() + 10 * 60_000).toISOString();
    const r = await push(s, [
      checkIn('calm', { localDay: addDays(TODAY, -2) }),
      checkIn('calm', { deviceTs: future, localDay: auraDay(future, TZ) }),
    ]);
    expect(r.results.map((x) => x.status)).toEqual(['applied', 'applied']);
    expect(repo.checkIns.size).toBe(2);
    expect([...repo.checkIns.values()].map((c) => c.backfill)).toEqual([true, false]);
    expect(repo.ledger).toHaveLength(0);
    expect(repo.active.size).toBe(0);
  });

  it('deletes never remove Starlight or active days; re-logging a habit earns nothing', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const c = checkIn();
    const h = uuidv7();
    const l = log(h);
    await push(s, [c, habit(h), l]);
    expect(repo.total()).toBe(15);
    const r = await push(s, [del('check_in', c.payload.id), del('habit_log', (l.payload as { id: string }).id), log(h)]);
    expect(r.results.map((x) => x.status)).toEqual(['applied', 'applied', 'applied']);
    expect(repo.checkIns.size).toBe(0);
    expect(repo.total()).toBe(15);
    expect(repo.ledger).toHaveLength(2);
    expect(repo.active.size).toBe(1);
  });

  it('edits keep the original credit and never re-evaluate timing', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const c = checkIn();
    await push(s, [c]);
    const edit = { ...c, id: uuidv7(), localDay: addDays(TODAY, -20), payload: { ...c.payload, moodId: 'joyful' } };
    const r = await push(s, [edit]);
    expect(r.results[0].status).toBe('applied');
    expect(repo.checkIns.get(c.payload.id)).toMatchObject({ moodId: 'joyful', localDay: TODAY });
    expect(repo.ledger).toHaveLength(1);
  });

  it("cannot touch another user's rows", async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const c = checkIn();
    const h = uuidv7();
    await push(s, [c, habit(h)]);
    const r = await push(s, [{ ...c, id: uuidv7() }, habit(h), log(h), del('check_in', c.payload.id)], OTHER);
    expect(r.results.map((x) => x.reason ?? x.status)).toEqual(['id_conflict', 'id_conflict', 'habit_not_found', 'applied']);
    expect(repo.checkIns.get(c.payload.id)?.user).toBe(USER); // delete scoped by user_id → no-op
  });

  it('a second log of the same habit on the same day is already_logged', async () => {
    const s = makeService(new MemRepo());
    const h = uuidv7();
    const r = await push(s, [habit(h), log(h), log(h)]);
    expect(r.results[2]).toMatchObject({ status: 'rejected', reason: 'already_logged' });
  });
});

describe('SyncService review fixes', () => {
  beforeAll(() => Logger.overrideLogger(false));

  it('habit limits: each preset once per user, at most 3 active custom habits', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const [p1, p2, c1, c2, c3, c4] = Array.from({ length: 6 }, () => uuidv7());
    const r = await push(s, [habit(p1, 'breathe'), habit(p2, 'breathe'), habit(c1), habit(c2), habit(c3), habit(c4)]);
    expect(r.results.map((x) => x.reason ?? x.status)).toEqual([
      'applied',
      'duplicate_preset_habit',
      'applied',
      'applied',
      'applied',
      'too_many_custom_habits',
    ]);
    // re-sending an existing preset (same id) is fine; deactivating a custom habit frees a slot
    const deactivate = { ...habit(c1), payload: { id: c1, kind: 'custom', name: 'h-old', active: false } };
    const r2 = await push(s, [habit(p1, 'breathe'), deactivate, habit(c4)]);
    expect(r2.results.map((x) => x.status)).toEqual(['applied', 'applied', 'applied']);
  });

  it("judges timing in the mutation's own tz: a check-in stamped in New York is live, not a backfill", async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    // 20:00 in New York on 2026-10-08 = 05:30 IST on 2026-10-09 (profile tz is Asia/Kolkata).
    const nyEvening = new Date('2026-10-09T00:00:00Z');
    const mk = (tz?: string) => ({
      ...checkIn(),
      deviceTs: nyEvening.toISOString(),
      localDay: '2026-10-08',
      ...(tz ? { tz } : {}),
    });
    const withTz = await s.push(USER, { deviceId: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9caa', mutations: [mk('America/New_York')] }, nyEvening);
    expect(withTz.results[0].status).toBe('applied');
    expect(repo.ledger).toHaveLength(1);
    expect(repo.ledger[0]).toMatchObject({ amount: 10, localDay: '2026-10-08' });
    // Without tz the profile zone (IST) is used → it looks like a backfill and earns nothing.
    const noTz = await s.push(USER, { deviceId: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9caa', mutations: [mk()] }, nyEvening);
    expect(noTz.results[0].status).toBe('applied');
    expect(repo.ledger).toHaveLength(1);
    const bad = await s.push(USER, { deviceId: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9caa', mutations: [mk('Mars/Olympus')] }, nyEvening);
    expect(bad.results[0]).toMatchObject({ status: 'rejected', reason: 'invalid_tz' });
  });
});

describe('sync helpers', () => {
  it('maps pg errors to reasons, leaves infrastructure errors alone', () => {
    expect(rejectionReason(new MutationRejected('unknown_mood'))).toBe('unknown_mood');
    expect(rejectionReason({ code: '23505' })).toBe('conflict');
    expect(rejectionReason({ code: '23503' })).toBe('invalid_reference');
    expect(rejectionReason({ code: '22P02' })).toBe('invalid_payload');
    expect(rejectionReason({ code: '23514' })).toBe('invalid_payload');
    expect(rejectionReason({ code: '40001' })).toBeUndefined();
    expect(rejectionReason({ code: '57P01' })).toBeUndefined();
    expect(rejectionReason(new TypeError('bug'))).toBeUndefined();
  });

  it('habit credit ids are deterministic per (habit, aura day)', () => {
    const h = uuidv7();
    expect(habitCreditId(h, '2026-10-08')).toBe(habitCreditId(h, '2026-10-08'));
    expect(habitCreditId(h, '2026-10-08')).not.toBe(habitCreditId(h, '2026-10-09'));
    expect(habitCreditId(h, '2026-10-08')).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('payload schemas', () => {
    expect(checkInPayloadSchema.parse({ id: uuidv7(), moodId: 'calm' })).toMatchObject({ tags: [], noteCt: null, source: 'app' });
    expect(checkInPayloadSchema.safeParse({ id: uuidv7(), moodId: 'calm', noteCt: 'not base64!' }).success).toBe(false);
    expect(checkInPayloadSchema.safeParse({ id: uuidv7(), moodId: 'calm', tags: Array(11).fill('x') }).success).toBe(false);
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'custom', name: '' }).success).toBe(false);
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'custom', name: 'x'.repeat(41) }).success).toBe(false);
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'custom', presetKey: 'breathe', name: 'x' }).success).toBe(false);
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'preset' }).success).toBe(false);
  });
});
