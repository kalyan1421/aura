/**
 * F5 matching rules (PRD 06b "Matching and realtime"; contracts/api/v1-rooms.md §4.2): the fallback ladder 1→4 with the
 * spawn rules, step 3 adjacency (never pleasant with unpleasant) and the thin-partition merge (REQ-ROOM-03, -10).
 */
import { planLadder, resolvePartition, partitionKey, type Candidate, type LadderInput, type Partition } from '../../src/rooms/matching';
import { ADJACENT_QUADRANT } from '../../src/rooms/room-types';
import { QUADRANTS } from '../../src/rules';

const T0 = new Date('2026-10-08T15:00:00Z');
let seq = 0;
const room = (over: Partial<Candidate> = {}): Candidate => ({
  roomId: `room-${++seq}`,
  quadrant: 'storm',
  seedMoodId: 'anxious',
  live: 0,
  total: 1,
  createdAt: new Date(T0.getTime() - seq * 60_000),
  ...over,
});
const input = (over: Partial<LadderInput> = {}): LadderInput => ({
  moodId: 'anxious',
  partition: [],
  adjacent: [],
  partitionLive15: 10,
  lanternHour: false,
  config: { step1ExactMood: false, partitionLiveMin: 3, adjacentLiveMin: 3, spawnLiveThreshold: 12 },
  ...over,
});

describe('planLadder (steps 1–4)', () => {
  it('step 2: the partition room with the most live members comes first', () => {
    const a = room({ live: 2 });
    const b = room({ live: 5 });
    const c = room({ live: 0, total: 9 });
    const plan = planLadder(input({ partition: [a, b, c] }));
    expect(plan.ranked.slice(0, 2)).toEqual([
      { step: 2, roomId: b.roomId },
      { step: 2, roomId: a.roomId },
    ]);
    expect(plan.spawnStep).toBe(4);
  });

  it('step 1 is off by default (alpha) and, when on, prefers the seed mood with ≥ 1 live', () => {
    const other = room({ live: 6, seedMoodId: 'restless' });
    const same = room({ live: 1, seedMoodId: 'anxious' });
    const sameDead = room({ live: 0, seedMoodId: 'anxious' });
    expect(planLadder(input({ partition: [other, same, sameDead] })).ranked[0]).toEqual({ step: 2, roomId: other.roomId });
    const on = planLadder(input({ partition: [other, same, sameDead], config: { ...input().config, step1ExactMood: true } }));
    expect(on.ranked[0]).toEqual({ step: 1, roomId: same.roomId });
    expect(on.ranked[1]).toEqual({ step: 2, roomId: other.roomId });
    expect(on.ranked.filter((r) => r.roomId === same.roomId)).toHaveLength(1); // never listed twice
  });

  it('step 3 only when the partition had < 3 live over 15 min, and only rooms with ≥ 3 live', () => {
    const own = room({ live: 1 });
    const adjBusy = room({ quadrant: 'rain', live: 4 });
    const adjThin = room({ quadrant: 'rain', live: 2 });
    const busy = planLadder(input({ partition: [own], adjacent: [adjBusy, adjThin], partitionLive15: 3 }));
    expect(busy.ranked).toEqual([{ step: 2, roomId: own.roomId }]);
    const thin = planLadder(input({ partition: [own], adjacent: [adjBusy, adjThin], partitionLive15: 2 }));
    expect(thin.ranked).toEqual([
      { step: 3, roomId: adjBusy.roomId },
      { step: 2, roomId: own.roomId },
    ]);
  });

  it('step 4: nothing live → the room with the most people today; a new room only when nothing is joinable', () => {
    const quiet = room({ live: 0, total: 3 });
    const busierToday = room({ live: 0, total: 11 });
    const plan = planLadder(input({ partition: [quiet, busierToday], partitionLive15: 0 }));
    expect(plan.ranked).toEqual([
      { step: 4, roomId: busierToday.roomId },
      { step: 4, roomId: quiet.roomId },
    ]);
    expect(plan.spawnStep).toBe(4);
    expect(planLadder(input({ partition: [] }))).toEqual({ ranked: [], spawnStep: 4 }); // step 4 always yields a room: a new one
  });

  it('outside Lantern Hour a room with ≥ 12 live is full enough: prefer a smaller live room, else spawn', () => {
    const big = room({ live: 12 });
    const small = room({ live: 3 });
    const dead = room({ live: 0, total: 20 });
    expect(planLadder(input({ partition: [big, small, dead] })).ranked).toEqual([{ step: 2, roomId: small.roomId }]);
    const onlyBig = planLadder(input({ partition: [big, dead] }));
    expect(onlyBig.ranked).toEqual([]); // no async fallback: something IS live, it's just full enough
    expect(onlyBig.spawnStep).toBe(2);
  });

  it('in Lantern Hour rooms fill first: the biggest live room is not skipped', () => {
    const big = room({ live: 20 });
    const small = room({ live: 3 });
    expect(planLadder(input({ partition: [small, big], lanternHour: true })).ranked.map((r) => r.roomId)).toEqual([big.roomId, small.roomId]);
  });

  it('ties break on people today, then the newer room', () => {
    const older = room({ live: 2, total: 4, createdAt: new Date('2026-10-08T10:00:00Z') });
    const newer = room({ live: 2, total: 4, createdAt: new Date('2026-10-08T12:00:00Z') });
    const fuller = room({ live: 2, total: 6, createdAt: new Date('2026-10-08T09:00:00Z') });
    expect(planLadder(input({ partition: [older, newer, fuller] })).ranked.map((r) => r.roomId)).toEqual([
      fuller.roomId,
      newer.roomId,
      older.roomId,
    ]);
  });
});

describe('adjacency (step 3 never pairs pleasant with unpleasant)', () => {
  it('storm↔rain and moonlight↔sunrise only', () => {
    expect(ADJACENT_QUADRANT).toEqual({ storm: 'rain', rain: 'storm', moonlight: 'sunrise', sunrise: 'moonlight' });
    const unpleasant = new Set(['storm', 'rain']);
    for (const q of QUADRANTS) {
      expect(unpleasant.has(ADJACENT_QUADRANT[q])).toBe(unpleasant.has(q));
      expect(ADJACENT_QUADRANT[ADJACENT_QUADRANT[q]]).toBe(q);
    }
  });
});

describe('resolvePartition (thin-partition merge)', () => {
  const cfg = { thinJoinThreshold: 12, defaultRegion: 'south_asia' as const };
  const demand = (entries: Record<string, number>) => new Map(Object.entries(entries));

  it('REQ-ROOM-10: a Dallas Telugu partition with < 12 joins merges into south_asia; a busier one stays', () => {
    const d = demand({ 'te:americas': 5, 'te:south_asia': 40 });
    expect(resolvePartition({ pool: 'te', region: 'americas' }, d, cfg)).toEqual({ pool: 'te', region: 'south_asia', merged: true });
    const busy = demand({ 'te:americas': 12, 'te:south_asia': 40 });
    expect(resolvePartition({ pool: 'te', region: 'americas' }, busy, cfg)).toEqual({ pool: 'te', region: 'americas', merged: false });
  });

  it('still thin → non-English pools use English (home region first, then the busiest English region)', () => {
    const home = demand({ 'te:americas': 2, 'te:south_asia': 3, 'en:americas': 15 });
    expect(resolvePartition({ pool: 'te', region: 'americas' }, home, cfg)).toEqual({ pool: 'en', region: 'americas', merged: true });
    const busiest = demand({ 'te:americas': 2, 'te:south_asia': 3, 'en:americas': 4, 'en:europe_africa': 30 });
    expect(resolvePartition({ pool: 'te', region: 'americas' }, busiest, cfg)).toEqual({ pool: 'en', region: 'europe_africa', merged: true });
  });

  it('cold start (everything thin): everyone concentrates in en × south_asia', () => {
    const homes: Partition[] = [
      { pool: 'te', region: 'south_asia' },
      { pool: 'te', region: 'americas' },
      { pool: 'en', region: 'east_asia_pacific' },
      { pool: 'hi', region: 'europe_africa' },
    ];
    for (const home of homes) {
      const r = resolvePartition(home, new Map(), cfg);
      expect({ pool: r.pool, region: r.region }).toEqual({ pool: 'en', region: 'south_asia' });
      expect(r.merged).toBe(home.pool !== 'en' || home.region !== 'south_asia');
    }
  });

  it('English is never merged into another pool; a thin English region goes to the busiest English region', () => {
    const d = demand({ 'en:americas': 3, 'en:south_asia': 50 });
    expect(resolvePartition({ pool: 'en', region: 'americas' }, d, cfg)).toEqual({ pool: 'en', region: 'south_asia', merged: true });
  });

  it('demand is keyed by pool:region', () => {
    expect(partitionKey({ pool: 'te', region: 'americas' })).toBe('te:americas');
  });
});
