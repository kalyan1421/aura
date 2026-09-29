/**
 * SyncService orchestration against an in-memory repository: idempotency, per-mutation
 * rejection, eligibility, append-only ledger with cap, deletes keep Starlight.
 * (The same scenarios run against the real DB in test/e2e.)
 */
import { Logger } from '@nestjs/common';
import { ApiError } from '../../src/common/api-error';
import { uuidv7 } from '../../src/common/uuid';
import { computeSnapshot } from '../../src/progression/snapshot';
import { addDays, auraDay, MAX_FUTURE_SKEW_MS } from '../../src/rules';
import { MutationRejected, rejectionReason } from '../../src/sync/mutation-rejected';
import { MediaStoreError } from '../../src/account/private-media';
import {
  CHECK_IN_EDIT_WINDOW_MS,
  EDIT_MAX_FUTURE_SKEW_MS,
  habitCreditId,
  MAX_PAUSE_DAYS,
  SyncService,
  VOICE_CLEANUP_TIMEOUT_MS,
} from '../../src/sync/sync.service';
import { checkInPayloadSchema, habitPayloadSchema, MAX_HABIT_NAME_CHARS, MAX_TAG_CHARS } from '../../src/sync/sync.schema';
import { fitsChars, graphemeCount, MAX_UTF16_UNITS_PER_CHAR } from '../../src/sync/text-limits';

const USER = '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9c0d';
const OTHER = '0192f0c2-7a4e-7c1a-9b3d-000000000001';
const TZ = 'Asia/Kolkata';
const NOW = new Date('2026-10-08T10:00:00Z');
const TODAY = auraDay(NOW, TZ);

class MemRepo {
  mutations = new Map<string, { status: 'applied' | 'rejected'; reason: string | null }>();
  checkIns = new Map<
    string,
    { user: string; moodId: string; tags: string[]; localDay: string; deviceTs: string; backfill: boolean; voicePath: string | null }
  >();
  habits = new Map<
    string,
    {
      user: string;
      kind: string;
      presetKey: string | null;
      name: string | null;
      active: boolean;
      committedFrom: string | null;
      pausedThrough: string | null;
    }
  >();
  minors = new Set<string>();
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
  async lockCheckIn(_: unknown, id: string) {
    const c = this.checkIns.get(id);
    return c ? { userId: c.user, deviceTs: new Date(c.deviceTs), voicePath: c.voicePath } : null;
  }
  async insertCheckIn(
    _: unknown,
    c: {
      userId: string;
      p: { id: string; moodId: string; tags: string[] };
      localDay: string;
      deviceTs: string;
      backfill: boolean;
      voicePath: string | null;
    },
  ) {
    this.checkIns.set(c.p.id, {
      user: c.userId,
      moodId: c.p.moodId,
      tags: c.p.tags,
      localDay: c.localDay,
      deviceTs: c.deviceTs,
      backfill: c.backfill,
      voicePath: c.voicePath,
    });
  }
  async updateCheckIn(
    _: unknown,
    u: string,
    p: { id: string; moodId: string; tags: string[] },
    _q: unknown,
    voicePath: string | null | undefined,
  ) {
    const c = this.checkIns.get(p.id);
    if (c && c.user === u) {
      c.moodId = p.moodId;
      c.tags = p.tags;
      if (voicePath !== undefined) c.voicePath = voicePath;
    }
  }
  async deleteCheckIn(_: unknown, u: string, id: string) {
    const c = this.checkIns.get(id);
    if (c?.user !== u) return undefined;
    this.checkIns.delete(id);
    return { voicePath: c.voicePath };
  }
  async referencedVoicePaths(_: unknown, u: string, paths: string[]) {
    const used = [...this.checkIns.values()].filter((c) => c.user === u && c.voicePath).map((c) => c.voicePath);
    return new Set(paths.filter((p) => used.includes(p)));
  }
  async upsertHabit(
    _: unknown,
    u: string,
    h: {
      id: string;
      kind: string;
      presetKey?: string | null;
      name: string | null;
      active: boolean;
      committedFrom?: string | null;
      pausedThrough?: string | null;
    },
  ) {
    const cur = this.habits.get(h.id);
    if (cur && cur.user !== u) return false;
    this.habits.set(h.id, {
      user: u,
      kind: h.kind,
      presetKey: h.kind === 'preset' ? (h.presetKey ?? null) : null,
      name: h.name,
      active: h.active,
      // undefined keeps, null clears (habitPayloadSchema)
      committedFrom: h.committedFrom === undefined ? (cur?.committedFrom ?? null) : h.committedFrom,
      pausedThrough: h.pausedThrough === undefined ? (cur?.pausedThrough ?? null) : h.pausedThrough,
    });
    return true;
  }
  async isMinor(_: unknown, u: string) {
    return this.minors.has(u);
  }
  async presetHabitTaken(_: unknown, u: string, presetKey: string, exceptId: string) {
    return [...this.habits.entries()].some(([id, h]) => id !== exceptId && h.user === u && h.kind === 'preset' && h.presetKey === presetKey);
  }
  async countActiveCustomHabits(_: unknown, u: string, exceptId: string) {
    return [...this.habits.entries()].filter(([id, h]) => id !== exceptId && h.user === u && h.kind === 'custom' && h.active).length;
  }
  async findHabit(_: unknown, u: string, id: string) {
    const h = this.habits.get(id);
    return h && h.user === u ? { presetKey: h.presetKey, committedFrom: h.committedFrom, pausedThrough: h.pausedThrough } : null;
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

/** PrivateMediaStore stand-in: records removals; can be unconfigured or failing. */
class FakeMedia {
  removed: string[][] = [];
  constructor(
    public configured = true,
    private readonly failWith?: Error,
  ) {}
  async remove(names: string[], opts?: { timeoutMs?: number }): Promise<number> {
    expect(opts?.timeoutMs).toBe(VOICE_CLEANUP_TIMEOUT_MS);
    if (this.failWith) throw this.failWith;
    this.removed.push(names);
    return names.length;
  }
}

function makeService(
  repo: MemRepo,
  hasProfile = true,
  media: FakeMedia = new FakeMedia(),
  over: { recompute?: () => Promise<never> } = {},
): SyncService {
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
    recompute:
      over.recompute ??
      (async (_: unknown, u: string, tz: string, now: Date) =>
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
      )),
  };
  return new SyncService(db as never, repo as never, profiles as never, catalogue as never, progression as never, media as never);
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
    ['unknown entity', () => ({ ...checkIn(), entity: 'not_an_entity' }), 'unknown_entity'],
    ['unknown op', () => ({ ...checkIn(), op: 'patch' }), 'unknown_op'],
    ['an op the entity does not support', () => ({ ...checkIn(), op: 'seal' }), 'unknown_op'],
    ['capsule entity without the capsule handler', () => ({ ...checkIn(), entity: 'capsule', op: 'seal' }), 'unknown_entity'],
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

  describe('W02 habit commitments (RULES.md §13)', () => {
    const custom = (id: string, extra: Record<string, unknown> = {}) => ({
      ...habit(id),
      payload: { id, kind: 'custom', name: 'Read', active: true, ...extra },
    });
    const reasons = async (s: SyncService, ms: unknown[]) => (await push(s, ms)).results.map((x) => x.reason ?? x.status);

    it('stores a commitment and a pause; an omitted field keeps them, null clears them', async () => {
      const repo = new MemRepo();
      const s = makeService(repo);
      const id = uuidv7();
      expect(await reasons(s, [custom(id, { committedFrom: TODAY, pausedThrough: addDays(TODAY, 5) })])).toEqual(['applied']);
      expect(repo.habits.get(id)).toMatchObject({ committedFrom: TODAY, pausedThrough: addDays(TODAY, 5) });
      // an older client renaming the habit sends neither field: nothing is cleared
      expect(await reasons(s, [custom(id, { name: 'Read more' })])).toEqual(['applied']);
      expect(repo.habits.get(id)).toMatchObject({ name: 'Read more', committedFrom: TODAY, pausedThrough: addDays(TODAY, 5) });
      // ending the pause, then the commitment
      expect(await reasons(s, [custom(id, { pausedThrough: null })])).toEqual(['applied']);
      expect(repo.habits.get(id)).toMatchObject({ committedFrom: TODAY, pausedThrough: null });
      expect(await reasons(s, [custom(id, { committedFrom: null })])).toEqual(['applied']);
      expect(repo.habits.get(id)).toMatchObject({ committedFrom: null, pausedThrough: null });
    });

    it('never touches the ledger: committing or pausing earns and costs nothing', async () => {
      const repo = new MemRepo();
      const s = makeService(repo);
      const r = await push(s, [custom(uuidv7(), { committedFrom: TODAY })]);
      expect(r.results.map((x) => x.status)).toEqual(['applied']);
      expect(repo.ledger).toHaveLength(0);
      expect(r.snapshot.starlight).toEqual({ total: 0, today: 0 });
    });

    it('a minor cannot start a commitment, can still track habits, and an unchanged resend is not refused', async () => {
      const repo = new MemRepo();
      const s = makeService(repo);
      const id = uuidv7();
      repo.minors.add(USER);
      expect(await reasons(s, [custom(id, { committedFrom: TODAY }), custom(uuidv7())])).toEqual(['commitment_not_available', 'applied']);
      expect(repo.habits.get(id)).toBeUndefined();
      // a commitment made as an adult keeps working if a later age signal flags the account
      const kept = uuidv7();
      repo.minors.delete(USER);
      await push(s, [custom(kept, { committedFrom: TODAY })]);
      repo.minors.add(USER);
      expect(await reasons(s, [custom(kept, { name: 'Read again', committedFrom: TODAY })])).toEqual(['applied']);
    });

    it('rejects a pause without a commitment, a start far from today and an over-long pause', async () => {
      const s = makeService(new MemRepo());
      expect(await reasons(s, [custom(uuidv7(), { pausedThrough: addDays(TODAY, 3) })])).toEqual(['invalid_commitment']);
      expect(await reasons(s, [custom(uuidv7(), { committedFrom: addDays(TODAY, 5) })])).toEqual(['invalid_commitment']);
      expect(await reasons(s, [custom(uuidv7(), { committedFrom: addDays(TODAY, -5) })])).toEqual(['invalid_commitment']);
      expect(await reasons(s, [custom(uuidv7(), { committedFrom: TODAY, pausedThrough: addDays(TODAY, MAX_PAUSE_DAYS + 1) })])).toEqual(['invalid_commitment']);
      expect(await reasons(s, [custom(uuidv7(), { committedFrom: TODAY, pausedThrough: addDays(TODAY, MAX_PAUSE_DAYS) })])).toEqual(['applied']);
      expect(await reasons(s, [custom(uuidv7(), { committedFrom: 'not-a-day' })])).toEqual(['invalid_payload']);
    });

    it('works for a preset habit too', async () => {
      const repo = new MemRepo();
      const s = makeService(repo);
      const id = uuidv7();
      const m = { ...habit(id, 'breathe'), payload: { id, kind: 'preset', presetKey: 'breathe', name: null, active: true, committedFrom: TODAY } };
      expect(await reasons(s, [m])).toEqual(['applied']);
      expect(repo.habits.get(id)?.committedFrom).toBe(TODAY);
    });
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
    expect(checkInPayloadSchema.safeParse({ id: uuidv7(), moodId: 'calm', tags: ['  '] }).success).toBe(false);
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'custom', name: '' }).success).toBe(false);
    // lengths are counted in grapheme clusters by SyncService (tag_too_long / habit_name_too_long), not by zod
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'custom', name: 'x'.repeat(41) }).success).toBe(true);
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'custom', presetKey: 'breathe', name: 'x' }).success).toBe(false);
    expect(habitPayloadSchema.safeParse({ id: uuidv7(), kind: 'preset' }).success).toBe(false);
  });
});

describe('SyncService voice notes (F1)', () => {
  beforeAll(() => Logger.overrideLogger(false));
  afterEach(() => jest.restoreAllMocks());

  const voiceOf = (id: string, user = USER) => `${user}/voice/${id}`;
  const withVoice = (voicePath: unknown, moodId = 'calm') => {
    const m = checkIn(moodId);
    return { ...m, payload: { ...m.payload, voicePath: voicePath === '<own>' ? voiceOf(m.payload.id) : voicePath } };
  };
  const edit = (m: ReturnType<typeof checkIn>, payload: Record<string, unknown>) => ({
    ...m,
    id: uuidv7(),
    payload: { ...m.payload, ...payload },
  });

  it('stores <user_id>/voice/<id> on insert (canonical lower-case); absent → null', async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const s = makeService(repo, true, media);
    const a = withVoice('<own>');
    const b = checkIn();
    const upper = withVoice(null);
    upper.payload.voicePath = voiceOf(upper.payload.id).toUpperCase();
    const r = await push(s, [a, b, upper]);
    expect(r.results.map((x) => x.status)).toEqual(['applied', 'applied', 'applied']);
    expect(repo.checkIns.get(a.payload.id)?.voicePath).toBe(voiceOf(a.payload.id));
    expect(repo.checkIns.get(b.payload.id)?.voicePath).toBeNull();
    expect(repo.checkIns.get(upper.payload.id)?.voicePath).toBe(voiceOf(upper.payload.id));
    expect(media.removed).toEqual([]);
  });

  it.each<[string, (id: string) => unknown]>([
    ["another user's prefix", (id) => voiceOf(id, OTHER)],
    ['another check-in id', () => voiceOf(uuidv7())],
    ['another folder', (id) => `${USER}/capsules/${id}`],
    ['a file extension', (id) => `${voiceOf(id)}.m4a`],
    ['path traversal', (id) => `${USER}/voice/../${OTHER}/voice/${id}`],
    ['a leading slash', (id) => `/${voiceOf(id)}`],
    ['an empty string', () => ''],
    ['a number', () => 42],
    ['an object', (id) => ({ path: voiceOf(id) })],
  ])('rejects %s → invalid_voice_path (nothing stored, stays rejected on replay)', async (_, make) => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const m = checkIn();
    const bad = { ...m, payload: { ...m.payload, voicePath: make(m.payload.id) } };
    const r = await push(s, [bad]);
    expect(r.results[0]).toEqual({ id: bad.id, status: 'rejected', reason: 'invalid_voice_path' });
    expect(repo.checkIns.size).toBe(0);
    expect(repo.ledger).toHaveLength(0);
    expect((await push(s, [bad])).results[0]).toMatchObject({ status: 'rejected', reason: 'invalid_voice_path' });
  });

  it('an invalid voicePath on an edit leaves the stored check-in untouched', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const c = withVoice('<own>');
    await push(s, [c]);
    const r = await push(s, [edit(c, { moodId: 'joyful', voicePath: voiceOf(c.payload.id, OTHER) })]);
    expect(r.results[0]).toMatchObject({ status: 'rejected', reason: 'invalid_voice_path' });
    expect(repo.checkIns.get(c.payload.id)).toMatchObject({ moodId: 'calm', voicePath: voiceOf(c.payload.id) });
  });

  it('edits: absent keeps the voice note, the same path keeps it, a later edit can add it — no deletes', async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const s = makeService(repo, true, media);
    const c = withVoice('<own>');
    const plain = checkIn();
    await push(s, [c, plain]);
    const { voicePath: _drop, ...noVoice } = c.payload;
    const r = await push(s, [
      { ...c, id: uuidv7(), payload: { ...noVoice, moodId: 'joyful' } },
      edit(c, { voicePath: voiceOf(c.payload.id) }),
      edit(plain, { voicePath: voiceOf(plain.payload.id) }), // upload finished after the first push
    ]);
    expect(r.results.map((x) => x.status)).toEqual(['applied', 'applied', 'applied']);
    expect(repo.checkIns.get(c.payload.id)?.voicePath).toBe(voiceOf(c.payload.id));
    expect(repo.checkIns.get(plain.payload.id)?.voicePath).toBe(voiceOf(plain.payload.id));
    expect(media.removed).toEqual([]);
    expect(repo.ledger).toHaveLength(2); // edits never re-credit
  });

  it('an edit to null clears the reference and deletes the object after commit', async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const s = makeService(repo, true, media);
    const c = withVoice('<own>');
    const other = withVoice('<own>');
    await push(s, [c, other]);
    const r = await push(s, [edit(c, { voicePath: null })]);
    expect(r.results[0].status).toBe('applied');
    expect(repo.checkIns.get(c.payload.id)?.voicePath).toBeNull();
    expect(media.removed).toEqual([[voiceOf(c.payload.id)]]);
    // null again (nothing referenced) → no second storage call
    await push(s, [edit(c, { voicePath: null })]);
    expect(media.removed).toHaveLength(1);
    expect(repo.checkIns.get(other.payload.id)?.voicePath).toBe(voiceOf(other.payload.id));
  });

  it('op: delete removes the voice object; deleting a check-in without voice (or not ours) calls nothing', async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const s = makeService(repo, true, media);
    const c = withVoice('<own>');
    const plain = checkIn();
    await push(s, [c, plain]);
    const theirs = await push(s, [del('check_in', c.payload.id)], OTHER);
    expect(theirs.results[0].status).toBe('applied'); // scoped by user_id → silent no-op
    expect(media.removed).toEqual([]);
    const r = await push(s, [del('check_in', c.payload.id), del('check_in', plain.payload.id), del('check_in', uuidv7())]);
    expect(r.results.map((x) => x.status)).toEqual(['applied', 'applied', 'applied']);
    expect(media.removed).toEqual([[voiceOf(c.payload.id)]]);
    expect(repo.total()).toBe(12); // Starlight is never removed
  });

  it('a later mutation in the same push that references the path again cancels the delete', async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const s = makeService(repo, true, media);
    const c = withVoice('<own>');
    await push(s, [c]);
    const r = await push(s, [edit(c, { voicePath: null }), edit(c, { voicePath: voiceOf(c.payload.id) })]);
    expect(r.results.map((x) => x.status)).toEqual(['applied', 'applied']);
    expect(repo.checkIns.get(c.payload.id)?.voicePath).toBe(voiceOf(c.payload.id));
    expect(media.removed).toEqual([]);
  });

  it('a push that fails (rolled back) never deletes objects', async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const c = withVoice('<own>');
    await push(makeService(repo, true, media), [c]);
    const failing = makeService(repo, true, media, { recompute: () => Promise.reject(new Error('db down')) });
    await expect(push(failing, [del('check_in', c.payload.id)])).rejects.toThrow('db down');
    expect(media.removed).toEqual([]);
  });

  it('no service key: voicePath is still stored, cleanup is skipped with a warning (no ids)', async () => {
    const warn = jest.spyOn(Logger.prototype, 'warn');
    const repo = new MemRepo();
    const media = new FakeMedia(false);
    const s = makeService(repo, true, media);
    const c = withVoice('<own>');
    expect((await push(s, [c])).results[0].status).toBe('applied');
    expect(repo.checkIns.get(c.payload.id)?.voicePath).toBe(voiceOf(c.payload.id));
    const r = await push(s, [del('check_in', c.payload.id)]);
    expect(r.results[0].status).toBe('applied');
    expect(media.removed).toEqual([]);
    const lines = warn.mock.calls.map((a) => String(a[0]));
    expect(lines).toEqual([expect.stringContaining('voice cleanup skipped for 1 object(s)')]);
    expect(lines.join('\n')).not.toContain(USER);
    expect(lines.join('\n')).not.toContain(c.payload.id);
  });

  it.each([
    ['a Storage error reply', new MediaStoreError(500)],
    ['a network failure', new TypeError('fetch failed')],
  ])('%s never fails the push; the warning carries no path', async (_, failure) => {
    const warn = jest.spyOn(Logger.prototype, 'warn');
    const repo = new MemRepo();
    const s = makeService(repo, true, new FakeMedia(true, failure));
    const c = withVoice('<own>');
    await push(s, [c]);
    const r = await push(s, [del('check_in', c.payload.id)]);
    expect(r.results[0].status).toBe('applied');
    expect(repo.checkIns.size).toBe(0);
    const lines = warn.mock.calls.map((a) => String(a[0]));
    expect(lines).toHaveLength(1);
    expect(lines[0]).toMatch(/^voice cleanup failed for 1 object\(s\): (storage delete failed: HTTP 500|TypeError)$/);
  });

  it('payload schema passes voicePath through untouched (the path rule needs the caller)', () => {
    const id = uuidv7();
    expect(checkInPayloadSchema.parse({ id, moodId: 'calm' }).voicePath).toBeUndefined();
    expect(checkInPayloadSchema.parse({ id, moodId: 'calm', voicePath: null }).voicePath).toBeNull();
    expect(checkInPayloadSchema.parse({ id, moodId: 'calm', voicePath: 'x' }).voicePath).toBe('x');
  });
});

describe('SyncService text limits (grapheme clusters) and the 24 h edit window', () => {
  beforeAll(() => Logger.overrideLogger(false));

  const TELUGU = 'స్త్రీ'; // one character (grapheme cluster), 6 UTF-16 units
  const FAMILY = '👨🏻‍👩🏻‍👧🏻‍👦🏻'; // one character, 19 UTF-16 units
  const withTags = (tags: string[]) => {
    const m = checkIn('calm');
    return { ...m, payload: { ...m.payload, tags } };
  };
  const named = (name: string, kind: 'custom' | 'preset' = 'custom') => {
    const id = uuidv7();
    const m = habit(id, kind === 'preset' ? 'breathe' : null);
    return { ...m, payload: { ...m.payload, name } };
  };

  it('graphemeCount / fitsChars count what people see, with a UTF-16 safety cap', () => {
    expect(graphemeCount(TELUGU.repeat(20))).toBe(20);
    expect(graphemeCount(FAMILY.repeat(3))).toBe(3);
    expect(fitsChars('x'.repeat(20), 20)).toBe(true);
    expect(fitsChars('x'.repeat(21), 20)).toBe(false);
    expect(fitsChars(TELUGU.repeat(20), 20)).toBe(true);
    expect(fitsChars(FAMILY.repeat(16), 20)).toBe(true); // 304 units
    expect(fitsChars(`a${'́'.repeat(400)}`, 20)).toBe(false); // one "character", 401 units
    expect(MAX_UTF16_UNITS_PER_CHAR).toBe(16);
  });

  it('tags: ≤ 20 characters each (Telugu / emoji count as one) → else tag_too_long; still ≤ 10 tags', async () => {
    expect(MAX_TAG_CHARS).toBe(20);
    const repo = new MemRepo();
    const s = makeService(repo);
    const ok = [withTags(['x'.repeat(20)]), withTags([TELUGU.repeat(20)]), withTags([FAMILY.repeat(10), 'study'])];
    const bad = [withTags(['x'.repeat(21)]), withTags(['ok', TELUGU.repeat(21)]), withTags([`a${'́'.repeat(400)}`])];
    const r = await push(s, [...ok, ...bad, withTags(Array.from({ length: 11 }, (_, i) => `t${i}`))]);
    expect(r.results.map((x) => x.reason ?? x.status)).toEqual([
      'applied',
      'applied',
      'applied',
      'tag_too_long',
      'tag_too_long',
      'tag_too_long',
      'invalid_payload',
    ]);
    expect(repo.checkIns.get(ok[1].payload.id)?.tags).toEqual([TELUGU.repeat(20)]);
  });

  it('a too-long tag on an edit is rejected and leaves the check-in untouched', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const c = checkIn('calm');
    await push(s, [c]);
    const r = await push(s, [{ ...c, id: uuidv7(), payload: { ...c.payload, moodId: 'joyful', tags: ['y'.repeat(21)] } }]);
    expect(r.results[0]).toMatchObject({ status: 'rejected', reason: 'tag_too_long' });
    expect(repo.checkIns.get(c.payload.id)).toMatchObject({ moodId: 'calm', tags: ['study'] });
  });

  it('habit names: ≤ 30 characters (custom and preset) → else habit_name_too_long', async () => {
    expect(MAX_HABIT_NAME_CHARS).toBe(30);
    const repo = new MemRepo();
    const s = makeService(repo);
    const telugu30 = named(TELUGU.repeat(30)); // 180 UTF-16 units: the app accepts it
    const r = await push(s, [
      named('x'.repeat(30)),
      telugu30,
      named('x'.repeat(31)),
      named(TELUGU.repeat(31)),
      named('y'.repeat(31), 'preset'),
    ]);
    expect(r.results.map((x) => x.reason ?? x.status)).toEqual([
      'applied',
      'applied',
      'habit_name_too_long',
      'habit_name_too_long',
      'habit_name_too_long',
    ]);
    expect(repo.habits.get((telugu30.payload as { id: string }).id)?.name).toBe(TELUGU.repeat(30));
  });

  // ---- edit window: judged by the edit's own deviceTs against the stored device_ts
  const H = 3600_000;
  const at = (ms: number) => new Date(NOW.getTime() + ms);
  const pushAt = (s: SyncService, mutations: unknown[], now: Date) =>
    s.push(USER, { deviceId: '0192f0c2-7a4e-7c1a-9b3d-5e6f7a8b9caa', mutations }, now);
  const editAt = (c: ReturnType<typeof checkIn>, deviceTs: Date | undefined, payload: Record<string, unknown> = { moodId: 'joyful' }) => ({
    ...c,
    id: uuidv7(),
    deviceTs: deviceTs?.toISOString(),
    payload: { ...c.payload, ...payload },
  });
  const seeded = async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const s = makeService(repo, true, media);
    const c = checkIn('calm'); // deviceTs = NOW
    await push(s, [c]);
    return { repo, media, s, c };
  };

  it('an edit made offline at 23 h and synced at 30 h still applies (no re-credit)', async () => {
    expect(CHECK_IN_EDIT_WINDOW_MS).toBe(24 * H);
    const { repo, s, c } = await seeded();
    const r = await pushAt(s, [editAt(c, at(23 * H))], at(30 * H));
    expect(r.results[0].status).toBe('applied');
    expect(repo.checkIns.get(c.payload.id)?.moodId).toBe('joyful');
    expect(repo.ledger).toHaveLength(1);
  });

  it('exactly 24 h is still inside; 24 h + 1 ms (either side) → edit_window_closed, row untouched', async () => {
    const { repo, s, c } = await seeded();
    expect((await pushAt(s, [editAt(c, at(24 * H))], at(24 * H))).results[0].status).toBe('applied');
    const late = await pushAt(s, [editAt(c, at(24 * H + 1), { moodId: 'anxious' })], at(24 * H + 1));
    expect(late.results[0]).toMatchObject({ status: 'rejected', reason: 'edit_window_closed' });
    const early = await pushAt(s, [editAt(c, at(-24 * H - 1), { moodId: 'anxious' })], NOW);
    expect(early.results[0]).toMatchObject({ status: 'rejected', reason: 'edit_window_closed' });
    expect(repo.checkIns.get(c.payload.id)?.moodId).toBe('joyful');
  });

  it('an edit stamped > 5 min ahead of server time (the ledger bound) → edit_window_closed; 4 min ahead is fine', async () => {
    expect(EDIT_MAX_FUTURE_SKEW_MS).toBe(5 * 60_000);
    expect(EDIT_MAX_FUTURE_SKEW_MS).toBe(MAX_FUTURE_SKEW_MS);
    const { s, c } = await seeded();
    expect((await pushAt(s, [editAt(c, at(6 * 60_000))], NOW)).results[0]).toMatchObject({ reason: 'edit_window_closed' });
    expect((await pushAt(s, [editAt(c, at(4 * 60_000))], NOW)).results[0].status).toBe('applied');
  });

  // ---- payload.editedAt: the app keeps deviceTs = the original check-in time and sends when the edit was made
  /** An edit as the app sends it: deviceTs = the ORIGINAL time (NOW), editedAt = when the user edited. */
  const editedAt = (c: ReturnType<typeof checkIn>, when: unknown, moodId = 'joyful') => ({
    ...c,
    id: uuidv7(),
    payload: { ...c.payload, moodId, editedAt: when instanceof Date ? when.toISOString() : when },
  });

  it('editedAt decides the window: 23 h → applied, 25 h → edit_window_closed (deviceTs stays the original)', async () => {
    const { repo, s, c } = await seeded();
    const ok = await pushAt(s, [editedAt(c, at(23 * H))], at(30 * H));
    expect(ok.results[0].status).toBe('applied');
    expect(repo.checkIns.get(c.payload.id)).toMatchObject({ moodId: 'joyful', deviceTs: c.deviceTs });
    const late = await pushAt(s, [editedAt(c, at(25 * H), 'anxious')], at(25 * H));
    expect(late.results[0]).toMatchObject({ status: 'rejected', reason: 'edit_window_closed' });
    expect(repo.checkIns.get(c.payload.id)?.moodId).toBe('joyful');
    expect(repo.ledger).toHaveLength(1);
  });

  it('editedAt more than 5 min ahead of server time → edit_window_closed', async () => {
    const { s, c } = await seeded();
    expect((await pushAt(s, [editedAt(c, at(6 * 60_000))], NOW)).results[0]).toMatchObject({ reason: 'edit_window_closed' });
    expect((await pushAt(s, [editedAt(c, at(4 * 60_000))], NOW)).results[0].status).toBe('applied');
  });

  it('editedAt must be an ISO timestamp (else invalid_payload); null / absent fall back to deviceTs', async () => {
    const { s, c } = await seeded();
    for (const bad of ['yesterday', '2026-10-08', 42, '2026-10-08T10:00:00']) {
      expect((await push(s, [editedAt(c, bad)])).results[0]).toMatchObject({ status: 'rejected', reason: 'invalid_payload' });
    }
    expect((await pushAt(s, [editedAt(c, null)], at(30 * H))).results[0].status).toBe('applied'); // deviceTs = original
    expect(checkInPayloadSchema.parse({ id: uuidv7(), moodId: 'calm', editedAt: null }).editedAt).toBeUndefined();
  });

  it('an "edit" that arrives as the first insert ignores editedAt: stored and credited as the original event', async () => {
    const repo = new MemRepo();
    const s = makeService(repo);
    const c = checkIn('calm'); // deviceTs = NOW, localDay = TODAY: the original event
    const firstSeen = editedAt(c, at(-48 * H)); // even an absurd editedAt is ignored on insert
    const r = await pushAt(s, [firstSeen], at(H));
    expect(r.results[0].status).toBe('applied');
    expect(repo.checkIns.get(c.payload.id)).toMatchObject({ moodId: 'joyful', deviceTs: c.deviceTs, localDay: TODAY, backfill: false });
    expect(repo.ledger).toEqual([expect.objectContaining({ reason: 'checkin', amount: 10, localDay: TODAY })]);
  });

  it('an edit without deviceTs → invalid_payload; a rejected edit stays rejected on replay', async () => {
    const { s, c } = await seeded();
    expect((await push(s, [editAt(c, undefined)])).results[0]).toMatchObject({ reason: 'invalid_payload' });
    const late = editAt(c, at(25 * H));
    expect((await pushAt(s, [late], at(25 * H))).results[0]).toMatchObject({ reason: 'edit_window_closed' });
    expect((await pushAt(s, [late], at(25 * H))).results[0]).toMatchObject({ status: 'rejected', reason: 'edit_window_closed' });
  });

  it('a closed window also blocks voice changes (no cleanup); deletes work any time; inserts are unaffected', async () => {
    const repo = new MemRepo();
    const media = new FakeMedia();
    const s = makeService(repo, true, media);
    const m = checkIn('calm');
    const c = { ...m, payload: { ...m.payload, voicePath: `${USER}/voice/${m.payload.id}` } };
    await push(s, [c]);
    const clear = await pushAt(s, [editAt(c, at(48 * H), { voicePath: null })], at(48 * H));
    expect(clear.results[0]).toMatchObject({ reason: 'edit_window_closed' });
    expect(repo.checkIns.get(c.payload.id)?.voicePath).toBe(`${USER}/voice/${c.payload.id}`);
    expect(media.removed).toEqual([]);
    const d = await pushAt(s, [del('check_in', c.payload.id)], at(30 * 24 * H));
    expect(d.results[0].status).toBe('applied');
    expect(media.removed).toEqual([[`${USER}/voice/${c.payload.id}`]]);
    // a first insert of an old event is still judged by the backfill rules, not the edit window
    const old = checkIn('calm', { deviceTs: at(-3 * 24 * H).toISOString(), localDay: addDays(TODAY, -3) });
    expect((await push(s, [old])).results[0].status).toBe('applied');
  });
});
