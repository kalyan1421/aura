/**
 * REQ-ROOM-03 "concurrent joins never create a 25th member", at the service level: the real RoomsService runs against
 * an in-memory repository whose ONLY guard is the per-room row lock (an async mutex held until the transaction ends),
 * with a forced yield between every call so concurrent matches interleave. Capacity is not enforced by the fake insert,
 * so the test fails if the service ever checks capacity outside the lock. A second case simulates the DB trigger
 * refusing a seat (AR001) and expects the service to move on. The real DB version runs in test/e2e/rooms.e2e-spec.ts.
 */
import type { CatalogueService } from '../../src/catalogue/catalogue.service';
import type { DbService } from '../../src/db/db.service';
import type { Candidate } from '../../src/rooms/matching';
import type { LanguagePool } from '../../src/rooms/room-types';
import { RoomsRepository, type MemberRow, type RoomRow } from '../../src/rooms/rooms.repository';
import { RoomsService } from '../../src/rooms/rooms.service';
import type { Quadrant, Stage } from '../../src/rules';

const LANTERN_HOUR_IST = new Date('2026-10-08T16:00:00Z'); // 21:30 in Asia/Kolkata: rooms fill to capacity first
const yieldNow = (): Promise<void> => new Promise((r) => setImmediate(r));

class Mutex {
  private tail: Promise<void> = Promise.resolve();
  lock(): Promise<() => void> {
    let release!: () => void;
    const next = new Promise<void>((r) => (release = r));
    const acquired = this.tail.then(() => release);
    this.tail = this.tail.then(() => next);
    return acquired;
  }
}

class FakeTx {
  readonly releases: Array<() => void> = [];
  constructor(private readonly world: World) {}
  async query(text: string): Promise<{ rows: unknown[]; rowCount: number }> {
    await yieldNow();
    return this.world.sql(text);
  }
  async savepoint<T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> {
    return fn(this);
  }
}

class World {
  rooms = new Map<string, RoomRow>();
  members: MemberRow[] = [];
  locks = new Map<string, Mutex>();
  refuseSeatIn = new Set<string>(); // simulate the DB trigger (AR001) for these rooms
  private seq = 0;

  id(prefix: string): string {
    this.seq += 1;
    return `${prefix}-${String(this.seq).padStart(4, '0')}`;
  }

  sql(text: string): { rows: unknown[]; rowCount: number } {
    if (/pg_advisory_xact_lock|realtime\.send|here_now_broadcast|from public\.matching_config|from public\.sanctions|from public\.feature_flags/.test(text)) {
      return { rows: [], rowCount: 0 };
    }
    if (/from public\.guidelines_acceptances/.test(text)) {
      // Everyone here has accepted the community guidelines (the gate itself: test/unit/safety.guidelines.spec.ts).
      return { rows: [{ current: 1, accepted_version: 1, accepted_at: new Date(LANTERN_HOUR_IST) }], rowCount: 1 };
    }
    if (/from public\.profiles/.test(text)) return { rows: [{ language_pool: 'en', timezone: 'Asia/Kolkata' }], rowCount: 1 };
    throw new Error(`unexpected SQL in fake: ${text.slice(0, 80)}`);
  }

  active(roomId: string): MemberRow[] {
    return this.members.filter((m) => m.room_id === roomId && m.left_at === null);
  }

  addRoom(capacity = 24): RoomRow {
    const now = LANTERN_HOUR_IST.getTime();
    const room: RoomRow = {
      id: this.id('room'),
      language_pool: 'en',
      quadrant: 'storm',
      tz_region: 'south_asia',
      seed_mood_id: 'anxious',
      theme: 'lighthouse',
      capacity,
      status: 'open',
      here_now_broadcast: 0,
      created_at: new Date(now - 3_600_000),
      opened_at: new Date(now - 3_000_000),
      joins_close_at: new Date(now + 19 * 3_600_000),
      memory_at: new Date(now + 23 * 3_600_000),
      purge_at: new Date(now + (23 + 168) * 3_600_000),
    };
    this.rooms.set(room.id, room);
    return room;
  }

  seat(roomId: string, userId: string, pseudonym: string): MemberRow {
    const m: MemberRow = {
      member_id: this.id('member'),
      room_id: roomId,
      user_id: userId,
      pseudonym,
      mood_at_join: 'anxious',
      entry_quadrant: 'storm',
      stage: 'spark' as Stage,
      hue: null,
      cosmetic: null,
      joined_at: new Date(LANTERN_HOUR_IST),
      last_seen_at: new Date(LANTERN_HOUR_IST),
      left_at: null,
      survey_answered_at: null,
    };
    this.members.push(m);
    return m;
  }
}

/** In-memory RoomsRepository: stale-read candidates (like SQL outside the lock), a real async row lock. */
class FakeRepo extends RoomsRepository {
  constructor(private readonly w: World) {
    super();
  }
  override async activeRoomForQuadrant(): Promise<null> {
    await yieldNow();
    return null;
  }
  override async newJoins24h(): Promise<number> {
    return 0;
  }
  override async demand(): Promise<Map<string, number>> {
    return new Map([['en:south_asia', 500]]);
  }
  override async holdsRoomOfQuadrant(): Promise<boolean> {
    return false;
  }
  override async candidates(_q: unknown, p: { quadrants: Quadrant[]; userId: string }): Promise<Candidate[]> {
    await yieldNow();
    return [...this.w.rooms.values()]
      .filter((r) => p.quadrants.includes(r.quadrant))
      .filter((r) => !this.w.members.some((m) => m.room_id === r.id && m.user_id === p.userId))
      .filter((r) => this.w.active(r.id).length < r.capacity)
      .map((r) => ({
        roomId: r.id,
        quadrant: r.quadrant,
        seedMoodId: r.seed_mood_id,
        live: this.w.active(r.id).length,
        total: this.w.members.filter((m) => m.room_id === r.id).length,
        createdAt: r.created_at,
      }));
  }
  override async partitionLive(): Promise<number> {
    return 100;
  }
  override async lockRoom(q: unknown, roomId: string): Promise<RoomRow | null> {
    const tx = q as FakeTx;
    let mutex = this.w.locks.get(roomId);
    if (!mutex) {
      mutex = new Mutex();
      this.w.locks.set(roomId, mutex);
    }
    tx.releases.push(await mutex.lock());
    await yieldNow();
    return this.w.rooms.get(roomId) ?? null;
  }
  override async joinCheck(_q: unknown, roomId: string): Promise<{ active: number; total: number; blocked: boolean }> {
    await yieldNow();
    const all = this.w.members.filter((m) => m.room_id === roomId);
    return { active: all.filter((m) => m.left_at === null).length, total: all.length, blocked: false };
  }
  override async roomPseudonyms(_q: unknown, roomId: string): Promise<string[]> {
    await yieldNow();
    return this.w.members.filter((m) => m.room_id === roomId).map((m) => m.pseudonym);
  }
  override async activePseudonymsOf(): Promise<string[]> {
    return [];
  }
  override async avatarOf(): Promise<{ stage: Stage; hue: number | null }> {
    return { stage: 'glow', hue: 213 };
  }
  override async insertMember(_q: unknown, p: { roomId: string; userId: string; pseudonym: string }): Promise<MemberRow> {
    await yieldNow(); // the gap a racing joiner would exploit if the service checked capacity outside the lock
    if (this.w.refuseSeatIn.has(p.roomId)) throw Object.assign(new Error('room_full'), { code: 'AR001' });
    if (this.w.members.some((m) => m.room_id === p.roomId && m.pseudonym === p.pseudonym)) {
      throw Object.assign(new Error('dup'), { code: '23505', constraint: 'room_members_pseudonym_unique' });
    }
    return this.w.seat(p.roomId, p.userId, p.pseudonym);
  }
  override async markOpened(_q: unknown, roomId: string): Promise<RoomRow | null> {
    const r = this.w.rooms.get(roomId);
    if (!r || r.opened_at) return null;
    r.opened_at = new Date(LANTERN_HOUR_IST);
    return r;
  }
  override async createRoom(_q: unknown, p: { capacity: number; pool: LanguagePool }): Promise<RoomRow> {
    await yieldNow();
    const r = this.w.addRoom(p.capacity);
    r.opened_at = null;
    r.status = 'forming';
    return r;
  }
  override async counts(_q: unknown, roomId: string): Promise<{ here_now: number; today: number }> {
    return { here_now: this.w.active(roomId).length, today: this.w.members.filter((m) => m.room_id === roomId).length };
  }
  override async membersFor(): Promise<never[]> {
    return [];
  }
  override async gesturesReceived(): Promise<never[]> {
    return [];
  }
  override async gesturesSent(): Promise<never[]> {
    return [];
  }
  override async gesturesRecent(): Promise<never[]> {
    return [];
  }
  override async surveyEligible(): Promise<boolean> {
    return false;
  }
}

function service(world: World): RoomsService {
  const db = {
    query: (text: string) => Promise.resolve(world.sql(text)),
    withTx: async <T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> => {
      const tx = new FakeTx(world);
      try {
        return await fn(tx);
      } finally {
        for (const release of tx.releases) release();
      }
    },
  } as unknown as DbService;
  const catalogue = { moodQuadrant: async () => 'storm' } as unknown as CatalogueService;
  return new RoomsService(db, new FakeRepo(world), catalogue);
}

const users = (n: number, prefix: string) => Array.from({ length: n }, (_, i) => `${prefix}-${i}`);

describe('match under concurrency (row lock is the only guard)', () => {
  it('30 simultaneous joiners into a room with 20 of 24 seats taken: exactly 24, never a 25th', async () => {
    const world = new World();
    const r = world.addRoom(24);
    users(20, 'seated').forEach((u, i) => world.seat(r.id, u, `Seated ${i}`));
    const svc = service(world);

    const results = await Promise.all(
      users(30, 'joiner').map((u) => svc.match(u, { quadrant: 'storm', moodId: 'anxious', timezone: 'Asia/Kolkata' }, LANTERN_HOUR_IST)),
    );

    expect(world.active(r.id)).toHaveLength(24);
    for (const room of world.rooms.values()) expect(world.active(room.id).length).toBeLessThanOrEqual(room.capacity);
    expect(world.members.filter((m) => m.user_id.startsWith('joiner'))).toHaveLength(30); // everyone got a seat somewhere
    expect(results.filter((x) => x.room.roomId === r.id)).toHaveLength(4);
    expect(results.filter((x) => x.match.created).length).toBeGreaterThanOrEqual(1);
    // pseudonyms stay unique within every room
    for (const room of world.rooms.values()) {
      const names = world.members.filter((m) => m.room_id === room.id).map((m) => m.pseudonym);
      expect(new Set(names).size).toBe(names.length);
    }
  });

  it('when the DB guard refuses a seat (AR001), the service moves on instead of failing the request', async () => {
    const world = new World();
    const refused = world.addRoom(24);
    world.seat(refused.id, 'someone', 'Quiet Comet');
    world.refuseSeatIn.add(refused.id);
    const out = await service(world).match('late', { quadrant: 'storm', moodId: 'anxious' }, LANTERN_HOUR_IST);
    expect(out.room.roomId).not.toBe(refused.id);
    expect(out.match).toMatchObject({ created: true, reentry: false });
    expect(world.active(refused.id)).toHaveLength(1);
  });
});
