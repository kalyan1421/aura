/**
 * F5 room lanterns and Tonight's intention (Milestone B): REQ-ROOM-13 "the lantern never dims" and REQ-ROOM-14, at
 * the rule level, plus the `room_state` shape (room totals only — never a member id or a per-member value) and the
 * SQL helper's gates (kill switch, Lantern Hour only, broadcast only when the level rises). The live-stack version is
 * test/e2e/room-lanterns.e2e-spec.ts.
 */
import type { Queryable } from '../../src/db/db';
import {
  addProgress,
  breathLightUnits,
  DEFAULT_LANTERN_CONFIG,
  intentionView,
  LANTERN_MAX_PROGRESS,
  lanternView,
  levelOf,
  nightIndex,
  pickIntention,
  progressFor,
  takesLight,
  unitsPerLevel,
} from '../../src/rooms/lantern-rules';
import { addBreathCyclesToRoomLantern, addLanternLight } from '../../src/rooms/lanterns';
import { DEFAULT_MATCHING_CONFIG, loadMatchingConfig, type MatchingConfig } from '../../src/rooms/matching-config';
import { lanternWindow } from '../../src/rooms/regions';
import { ROOM_STATES } from '../../src/rooms/room-types';
import { roomInfo, roomStateView } from '../../src/rooms/room-views';
import type { RoomRow } from '../../src/rooms/rooms.repository';

const CFG = DEFAULT_LANTERN_CONFIG;
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;

describe('scaled to the room', () => {
  it('a level needs max(3, ceil(1.5 × live)) units — a room of 3 can light it too', () => {
    expect(unitsPerLevel(0, CFG)).toBe(3); // never fewer than one member
    expect(unitsPerLevel(1, CFG)).toBe(3);
    expect(unitsPerLevel(2, CFG)).toBe(3);
    expect(unitsPerLevel(3, CFG)).toBe(5);
    expect(unitsPerLevel(12, CFG)).toBe(18);
    expect(unitsPerLevel(24, CFG)).toBe(36);
    // A room of 3: 25 gestures light all 5 levels (~8 each over two hours, well inside 40 per room per hour).
    let p = 0;
    for (let i = 0; i < 25; i++) p = addProgress(p, progressFor(1, 3, CFG));
    expect(levelOf(p)).toBe(5);
  });

  it('exactly unitsPerLevel units complete a level (progress rounds up, never stalls at 0.999)', () => {
    const tuned = { ...CFG, minUnitsPerLevel: 3, unitsPerMember: 1 };
    let p = 0;
    for (let i = 0; i < 3; i++) p = addProgress(p, progressFor(1, 3, tuned)); // 1/3 + 1/3 + 1/3
    expect(levelOf(p)).toBe(1);
    expect(progressFor(5, 3, CFG)).toBe(1000);
  });

  it('breath cycles: human cycles × weight (a 16-cycle Ripples session = 4 units); nothing for ≤ 0', () => {
    expect(breathLightUnits(16, CFG)).toBe(4);
    expect(breathLightUnits(0, CFG)).toBe(0);
    expect(breathLightUnits(-5, CFG)).toBe(0);
    expect(breathLightUnits(Number.NaN, CFG)).toBe(0);
    expect(progressFor(0, 3, CFG)).toBe(0);
    expect(progressFor(-1, 3, CFG)).toBe(0);
  });
});

describe('REQ-ROOM-13: additive only — the lantern never dims', () => {
  it('addProgress never lowers the total, whatever the delta, and caps at a fully lit lantern', () => {
    expect(addProgress(1500, -700)).toBe(1500);
    expect(addProgress(1500, Number.NaN)).toBe(1500);
    expect(addProgress(1500, 0)).toBe(1500);
    expect(addProgress(4900, 500)).toBe(LANTERN_MAX_PROGRESS);
    expect(levelOf(LANTERN_MAX_PROGRESS)).toBe(5);
    expect(levelOf(99_999)).toBe(5);
    expect(levelOf(-3)).toBe(0);
    expect(levelOf(undefined)).toBe(0);
  });

  it('a night of joins, leaves, blocks, removals and quiet members: the level only ever rises', () => {
    // Deterministic pseudo-random night. Only light events touch progress; everything else only changes "live".
    let seed = 42;
    const rand = (): number => ((seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31);
    let live = 3;
    let progress = 0;
    let lastLevel = 0;
    for (let step = 0; step < 2000; step++) {
      const r = rand();
      if (r < 0.15) live = Math.min(24, live + 1); // joins / someone comes back
      else if (r < 0.3) live = Math.max(0, live - 1); // leaves, goes quiet, blocked, hidden
      else if (r < 0.35) {
        /* a reflection (and the gestures on it) is removed: nothing is recomputed */
      } else if (r < 0.9) progress = addProgress(progress, progressFor(1, live, CFG)); // a delivered gesture
      else progress = addProgress(progress, progressFor(breathLightUnits(Math.floor(rand() * 17), CFG), live, CFG)); // Ripples
      const level = levelOf(progress);
      expect(level).toBeGreaterThanOrEqual(lastLevel);
      lastLevel = level;
    }
    expect(lastLevel).toBe(5);
  });

  it('light is taken only in Lantern Hour (open rooms), never in forming, open, closing or memory', () => {
    for (const s of ROOM_STATES) expect(takesLight(s)).toBe(s === 'lantern_hour');
    expect(takesLight('purged')).toBe(false);
  });
});

describe("REQ-ROOM-14: tonight's intention", () => {
  const keys = ['sleep_before_midnight', 'gentle_with_myself', 'phone_down_10'];

  it('rotates nightly from the list; the same night gives the same preset everywhere', () => {
    expect(pickIntention(keys, '2026-10-08')).toBe(pickIntention(keys, '2026-10-08'));
    const week = ['2026-10-08', '2026-10-09', '2026-10-10'].map((d) => pickIntention(keys, d));
    expect(new Set(week).size).toBe(3);
    expect(nightIndex('2026-10-09') - nightIndex('2026-10-08')).toBe(1);
    expect(pickIntention([], '2026-10-08')).toBeNull();
  });
});

// ------------------------------------------------------------------ views

const T0 = new Date('2026-10-08T15:45:00Z'); // 21:15 IST
function room(over: Partial<RoomRow> = {}): RoomRow {
  return {
    id: '0192f0c2-7a4e-7c1a-9b3d-00000000a001',
    language_pool: 'en',
    quadrant: 'storm',
    tz_region: 'south_asia',
    seed_mood_id: 'anxious',
    theme: 'lighthouse',
    capacity: 24,
    status: 'lantern_hour',
    here_now_broadcast: 3,
    created_at: new Date(T0.getTime() - 3_600_000),
    opened_at: new Date(T0.getTime() - 3_000_000),
    joins_close_at: new Date(T0.getTime() + 19 * 3_600_000),
    memory_at: new Date(T0.getTime() + 23 * 3_600_000),
    purge_at: new Date(T0.getTime() + (23 + 168) * 3_600_000),
    lantern_progress: 2400,
    lantern_hour_at: lanternWindow('south_asia', T0).startsAt,
    intention_key: 'gentle_with_myself',
    intention_holds: 12,
    ...over,
  };
}
const cfgWith = (lanterns: Partial<MatchingConfig['lanterns']> = {}): MatchingConfig => ({
  ...DEFAULT_MATCHING_CONFIG,
  lanterns: { ...DEFAULT_MATCHING_CONFIG.lanterns, ...lanterns },
});

describe('views: room totals only', () => {
  it('in Lantern Hour: level and hold count, taking light and open for holding', () => {
    const info = roomInfo(room(), T0, cfgWith());
    expect(info.state).toBe('lantern_hour');
    expect(info.lantern).toEqual({ level: 2, maxLevel: 5, active: true });
    expect(info.intention).toEqual({ key: 'gentle_with_myself', holds: 12, open: true });
  });

  it('after 23:00 and in the memory: "Tonight\'s lantern" keeps its level; the intention is read-only', () => {
    const after = new Date(lanternWindow('south_asia', T0).endsAt.getTime() + 60_000);
    const open = roomInfo(room(), after, cfgWith());
    expect(open.state).toBe('open');
    expect(open.lantern).toEqual({ level: 2, maxLevel: 5, active: false });
    expect(open.intention).toEqual({ key: 'gentle_with_myself', holds: 12, open: false });
    const memory = roomInfo(room(), new Date(T0.getTime() + 24 * 3_600_000), cfgWith());
    expect(memory.state).toBe('memory');
    expect(memory.lantern).toEqual({ level: 2, maxLevel: 5, active: false });
  });

  it('no lantern before the room has had a Lantern Hour; a level-0 lantern while one runs', () => {
    const noon = new Date('2026-10-08T06:30:00Z'); // 12:00 IST
    const fresh = room({ lantern_progress: 0, lantern_hour_at: null, intention_key: null, intention_holds: 0, created_at: new Date(noon.getTime() - 60_000), opened_at: new Date(noon.getTime() - 30_000) });
    expect(roomInfo(fresh, noon, cfgWith()).lantern).toBeNull();
    expect(roomInfo(fresh, noon, cfgWith()).intention).toBeNull();
    expect(lanternView({}, 'lantern_hour', CFG)).toEqual({ level: 0, maxLevel: 5, active: true });
    expect(intentionView({}, 'lantern_hour', CFG)).toBeNull(); // set by the first touch of the night
  });

  it('kill switches hide them everywhere (the stored totals are kept)', () => {
    expect(roomInfo(room(), T0, cfgWith({ enabled: false })).lantern).toBeNull();
    expect(roomInfo(room(), T0, cfgWith({ intentionEnabled: false })).intention).toBeNull();
    expect(roomInfo(room(), T0, cfgWith({ enabled: false })).intention).not.toBeNull();
  });

  it('room_state carries exactly the room fields + the two totals — never a member id or per-member value', () => {
    // A row that (wrongly) carried member-level data must not leak it through the view.
    const polluted = {
      ...room(),
      user_id: '0192f0c2-7a4e-7c1a-9b3d-00000000beef',
      member_id: '0192f0c2-7a4e-7c1a-9b3d-00000000cafe',
      holds_intention: true,
      holders: ['Quiet Comet'],
      contributions: { 'Quiet Comet': 3 },
    } as unknown as RoomRow;
    const view = roomStateView(roomInfo(polluted, T0, cfgWith()));
    expect(Object.keys(view).sort()).toEqual(['intention', 'joinsCloseAt', 'lantern', 'memoryAt', 'purgeAt', 'readOnly', 'state']);
    expect(Object.keys(view.lantern!).sort()).toEqual(['active', 'level', 'maxLevel']);
    expect(Object.keys(view.intention!).sort()).toEqual(['holds', 'key', 'open']);
    const json = JSON.stringify(view);
    expect(json).not.toMatch(UUID); // not even the room id
    expect(json).not.toMatch(/member|user|pseudonym|Quiet Comet|holder|contribution|share|holdsIntention|holding/i);
  });
});

// ------------------------------------------------------------------ SQL helper gates (fake Queryable)

interface Call {
  text: string;
  params: unknown[];
}

function fakeDb(r: RoomRow, live = 3): { q: Queryable; calls: Call[]; progress: () => number } {
  let progress = r.lantern_progress ?? 0;
  const calls: Call[] = [];
  const q = {
    async query(text: string, params: unknown[] = []) {
      calls.push({ text, params });
      if (/^select .* from public\.rooms r where r\.id = \$1/s.test(text)) return { rows: [{ ...r, lantern_progress: progress }], rowCount: 1 };
      if (/from public\.room_members m where m\.room_id = \$1/.test(text)) return { rows: [{ here_now: live, today: live }], rowCount: 1 };
      if (/update public\.rooms r set lantern_progress/.test(text)) {
        const before = progress;
        progress = Math.min(Number(params[2]), before + Number(params[1]));
        return { rows: [{ ...r, before_progress: before, lantern_progress: progress }], rowCount: 1 };
      }
      if (/realtime\.send/.test(text)) return { rows: [], rowCount: 1 };
      if (/from public\.matching_config/.test(text)) return { rows: [], rowCount: 0 };
      throw new Error(`unexpected SQL: ${text.slice(0, 80)}`);
    },
  } as unknown as Queryable;
  return { q, calls, progress: () => progress };
}
const broadcasts = (calls: Call[]) => calls.filter((c) => /realtime\.send/.test(c.text));

describe('addLanternLight', () => {
  it('adds scaled light in Lantern Hour and broadcasts room_state only when the level rises', async () => {
    const db = fakeDb(room({ lantern_progress: 0 }), 3); // 5 units per level
    for (let i = 0; i < 4; i++) expect(await addLanternLight(db.q, room().id, 1, T0, cfgWith())).toEqual({ before: 0, after: 0 });
    expect(broadcasts(db.calls)).toHaveLength(0);
    expect(await addLanternLight(db.q, room().id, 1, T0, cfgWith())).toEqual({ before: 0, after: 1 });
    const sent = broadcasts(db.calls);
    expect(sent).toHaveLength(1);
    expect(sent[0].params[1]).toBe('room_state');
    const payload = JSON.parse(String(sent[0].params[0])) as Record<string, unknown>;
    expect(payload.lantern).toEqual({ level: 1, maxLevel: 5, active: true });
    expect(JSON.stringify(payload)).not.toMatch(UUID);
  });

  it('adds nothing outside Lantern Hour, with the kill switch off, for no units, or once fully lit', async () => {
    const noon = new Date('2026-10-08T06:30:00Z');
    const outside = fakeDb(room({ created_at: new Date(noon.getTime() - 60_000), opened_at: new Date(noon.getTime() - 30_000), joins_close_at: new Date(noon.getTime() + 19 * 3_600_000), memory_at: new Date(noon.getTime() + 23 * 3_600_000), purge_at: new Date(noon.getTime() + 190 * 3_600_000) }));
    expect(await addLanternLight(outside.q, room().id, 1, noon, cfgWith())).toBeNull();
    const off = fakeDb(room());
    expect(await addLanternLight(off.q, room().id, 1, T0, cfgWith({ enabled: false }))).toBeNull();
    expect(off.calls).toHaveLength(0);
    const none = fakeDb(room());
    expect(await addLanternLight(none.q, room().id, 0, T0, cfgWith())).toBeNull();
    const full = fakeDb(room({ lantern_progress: LANTERN_MAX_PROGRESS }));
    expect(await addLanternLight(full.q, room().id, 1, T0, cfgWith())).toBeNull();
    for (const db of [outside, off, none, full]) expect(db.calls.some((c) => /update public\.rooms/.test(c.text))).toBe(false);
  });

  it('closing rooms keep what they have (no light after the 20 h join cutoff, even inside the window)', async () => {
    const closing = fakeDb(room({ joins_close_at: new Date(T0.getTime() - 60_000) }));
    expect(await addLanternLight(closing.q, room().id, 1, T0, cfgWith())).toBeNull();
  });

  it('the Breath Ripples hook turns human cycles into light (16 cycles in a room of 3 ≈ most of a level)', async () => {
    const db = fakeDb(room({ lantern_progress: 0 }), 3);
    expect(await addBreathCyclesToRoomLantern(db.q, room().id, 16, T0)).toEqual({ level: 0 });
    expect(db.progress()).toBe(800); // 4 units of 5
    expect(await addBreathCyclesToRoomLantern(db.q, room().id, 4, T0)).toEqual({ level: 1 });
    expect(await addBreathCyclesToRoomLantern(db.q, room().id, 0, T0)).toBeNull();
  });
});

describe('matching_config: lantern tunables and kill switches', () => {
  const row = {
    step1_exact_mood: false, live_window_s: 120, partition_live_window_min: 15, partition_live_min: 3, adjacent_live_min: 3,
    spawn_live_threshold: 12, thin_join_threshold: 12, default_region: 'south_asia', room_capacity: 24, join_cutoff_h: 20,
    memory_after_h: 24, purge_after_d: 7, joins_per_quadrant_24h: 3, gesture_min_interval_ms: 2000, gesture_room_hour_max: 40,
    gesture_same_target_max: 3, gesture_same_target_window_min: 10, gesture_limit_hits_to_mute: 3, gesture_shadow_mute_h: 24,
    lantern_start: '21:00:00', lantern_end: '23:00:00',
  };
  const load = (extra: Record<string, unknown>) =>
    loadMatchingConfig({ query: async () => ({ rows: [{ ...row, ...extra }], rowCount: 1 }) } as unknown as Queryable);

  it('numeric columns (strings from pg) are parsed; flags default to on', async () => {
    const c = await load({ lantern_units_per_member: '2.00', lantern_min_units_per_level: 4, lantern_breath_cycle_weight: '0.50', lanterns_flag: null, intention_flag: null });
    expect(c.lanterns).toEqual({ enabled: true, intentionEnabled: true, unitsPerMember: 2, minUnitsPerLevel: 4, breathCycleWeight: 0.5 });
  });

  it('a flag set to false switches its feature off; missing columns fall back to the defaults', async () => {
    const c = await load({ lanterns_flag: false, intention_flag: false });
    expect(c.lanterns).toEqual({ ...DEFAULT_LANTERN_CONFIG, enabled: false, intentionEnabled: false });
  });
});
