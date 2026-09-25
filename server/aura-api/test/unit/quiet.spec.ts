/**
 * F16 Quiet Together + the Lantern Hour wind-down at the rule level (contracts/api/v1-quiet.md): placement (thin-region
 * merge, capacity, blocked pairs never together across 100 simulated joins), blocks on the region clock, the 25/5
 * rhythm, the view shapes (REQ-QUIET-01: counts only — exact keys pinned), base-stem soundscapes checked against the
 * stem manifest, per-region kill switches, the strict gesture schema (REQ-QUIET-02) and the wind-down window.
 * The live-stack version is test/e2e/quiet.e2e-spec.ts.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { pairKey } from '../../src/ripples/matcher';
import { blockFor, inBlock, rhythmAt } from '../../src/quiet/blocks';
import { DEFAULT_QUIET_CONFIG } from '../../src/quiet/quiet-config';
import { isPaused } from '../../src/quiet/quiet-flags';
import { quietLimitConfig } from '../../src/quiet/quiet-gestures.service';
import { QUIET_MODES } from '../../src/quiet/quiet-types';
import { sessionView, type QuietSessionRow } from '../../src/quiet/quiet-views';
import { gestureRequestSchema, joinRequestSchema } from '../../src/quiet/quiet.schema';
import { planQuietPlacement, type QuietCandidate } from '../../src/quiet/placement';
import { QUIET_SOUNDSCAPES, soundscapeFor, WIND_DOWN_CUES, WIND_DOWN_LINEUPS, windDownLineup } from '../../src/quiet/soundscapes';
import { gestureLimitBreach } from '../../src/rooms/gesture-limits';
import { DEFAULT_MATCHING_CONFIG } from '../../src/rooms/matching-config';
import { TZ_REGIONS, type TzRegion } from '../../src/rooms/regions';
import type { RoomRow } from '../../src/rooms/rooms.repository';
import { windDownStateAt, windDownView, windDownWindow } from '../../src/rooms/wind-down';
import { wallClock } from '../../src/rules';

const CFG = DEFAULT_QUIET_CONFIG;
const PCFG = { capacity: 50, thinLiveMin: 3, defaultRegion: 'south_asia' as TzRegion };
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;

const cand = (id: string, region: TzRegion, live: number, users: string[] = [], createdAtMs = 0): QuietCandidate => ({
  sessionId: id,
  region,
  live,
  memberUserIds: users,
  createdAtMs,
});

describe('placement (PRD F16 "Matching and realtime")', () => {
  it('home region when it is busy enough; the fullest session with room', () => {
    const p = planQuietPlacement(
      { userId: 'u', homeRegion: 'europe_africa' },
      [cand('a', 'europe_africa', 3, ['x', 'y', 'z']), cand('b', 'europe_africa', 5, ['p', 'q', 'r', 's', 't']), cand('c', 'south_asia', 40)],
      new Set(),
      PCFG,
    );
    expect(p).toEqual({ region: 'europe_africa', sessionId: 'b', merged: false });
  });

  it('a thin region (< 3 live) merges into the busiest one; ties go to south_asia', () => {
    expect(planQuietPlacement({ userId: 'u', homeRegion: 'americas' }, [cand('a', 'americas', 1, ['x']), cand('b', 'east_asia_pacific', 9)], new Set(), PCFG)).toEqual({
      region: 'east_asia_pacific',
      sessionId: 'b',
      merged: true,
    });
    // Nobody anywhere: a new session at home (never an empty merge).
    expect(planQuietPlacement({ userId: 'u', homeRegion: 'americas' }, [], new Set(), PCFG)).toEqual({ region: 'americas', sessionId: null, merged: false });
    // Tie between two busier regions → the default region first.
    expect(planQuietPlacement({ userId: 'u', homeRegion: 'americas' }, [cand('e', 'europe_africa', 4), cand('s', 'south_asia', 4)], new Set(), PCFG).region).toBe('south_asia');
  });

  it('full sessions are skipped; more open as needed', () => {
    const full = cand('f', 'south_asia', 2, ['a', 'b']);
    expect(planQuietPlacement({ userId: 'u', homeRegion: 'south_asia' }, [full], new Set(), { ...PCFG, capacity: 2, thinLiveMin: 0 })).toEqual({
      region: 'south_asia',
      sessionId: null,
      merged: false,
    });
  });

  it('a session holding someone the joiner has a block with (either direction) is never used', () => {
    const blocked = new Set([pairKey('u', 'x')]);
    const p = planQuietPlacement({ userId: 'u', homeRegion: 'south_asia' }, [cand('a', 'south_asia', 9, ['x', 'y']), cand('b', 'south_asia', 3, ['z'])], blocked, PCFG);
    expect(p.sessionId).toBe('b');
    const none = planQuietPlacement({ userId: 'u', homeRegion: 'south_asia' }, [cand('a', 'south_asia', 9, ['x', 'y'])], blocked, PCFG);
    expect(none.sessionId).toBeNull();
  });

  it('REQ-QUIET-06: a blocked pair is never placed together across 100 simulated joins', () => {
    // Deterministic pseudo-random run: 100 people join one mode across regions, with a web of blocks among them.
    let seed = 7;
    const rnd = (): number => {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    };
    const people = Array.from({ length: 100 }, (_, i) => `user-${i}`);
    const blocks = new Set<string>();
    for (let i = 0; i < 160; i++) {
      const a = people[Math.floor(rnd() * 100)];
      const b = people[Math.floor(rnd() * 100)];
      if (a !== b) blocks.add(pairKey(a, b));
    }
    const sessions: Array<{ id: string; region: TzRegion; members: string[] }> = [];
    for (const [i, u] of people.entries()) {
      const home = TZ_REGIONS[Math.floor(rnd() * TZ_REGIONS.length)];
      const mine = new Set([...blocks].filter((k) => k.split('|').includes(u)));
      const plan = planQuietPlacement(
        { userId: u, homeRegion: home },
        sessions.map((s, j) => cand(s.id, s.region, s.members.length, s.members, j)),
        mine,
        { ...PCFG, capacity: 8 },
      );
      let s = sessions.find((x) => x.id === plan.sessionId);
      if (!s) {
        s = { id: `s-${i}`, region: plan.region, members: [] };
        sessions.push(s);
      }
      s.members.push(u);
    }
    expect(sessions.reduce((n, s) => n + s.members.length, 0)).toBe(100);
    for (const s of sessions) {
      expect(s.members.length).toBeLessThanOrEqual(8);
      for (const a of s.members) for (const b of s.members) if (a < b) expect(blocks.has(pairKey(a, b))).toBe(false);
    }
  });
});

describe('blocks on the region clock and the 25/5 rhythm', () => {
  it('60-min blocks on the hour of the region clock (south_asia: hh:30 UTC; +5:30)', () => {
    const now = new Date('2027-03-10T13:40:12.345Z'); // 19:10 IST
    const b = blockFor('south_asia', now);
    expect(b.t0.toISOString()).toBe('2027-03-10T13:30:00.000Z');
    expect(b.endsAt.toISOString()).toBe('2027-03-10T14:30:00.000Z');
    expect(inBlock(b, now)).toBe(true);
    expect(blockFor('europe_africa', now).t0.toISOString()).toBe('2027-03-10T13:00:00.000Z');
    // Joining at :40 is inside the current block (REQ-QUIET-01 "joining at :40 works").
    const at40 = new Date('2027-03-10T14:10:00.000Z'); // 19:40 IST
    expect(blockFor('south_asia', at40).t0.toISOString()).toBe('2027-03-10T13:30:00.000Z');
  });

  it('every region and a DST change still give a whole wall-clock hour', () => {
    for (const region of TZ_REGIONS) {
      for (const iso of ['2027-03-14T07:59:59Z', '2027-03-14T08:30:00Z', '2027-10-31T00:30:00Z', '2027-10-31T01:30:00Z', '2027-11-07T06:59:00Z', '2027-11-07T07:10:00Z']) {
        const now = new Date(iso);
        const b = blockFor(region, now);
        expect(inBlock(b, now)).toBe(true);
        expect(b.endsAt.getTime() - b.t0.getTime()).toBe(3_600_000);
        const tz = { americas: 'America/Chicago', europe_africa: 'Europe/Berlin', south_asia: 'Asia/Kolkata', east_asia_pacific: 'Asia/Tokyo' }[region];
        const w = wallClock(b.t0, tz);
        expect([w.minute, w.second]).toEqual([0, 0]);
      }
    }
  });

  it('REQ-QUIET-05: focus :00–:25, break :25–:30, focus :30–:55, break :55–:00 (the next change as an instant)', () => {
    const t0 = Date.parse('2027-03-10T13:30:00Z');
    const at = (min: number) => rhythmAt(t0, t0 + min * 60_000, 25, 5);
    expect(at(0)).toEqual({ phase: 'focus', nextChangeMs: t0 + 25 * 60_000 });
    expect(at(24.9).phase).toBe('focus');
    expect(at(25)).toEqual({ phase: 'break', nextChangeMs: t0 + 30 * 60_000 });
    expect(at(30)).toEqual({ phase: 'focus', nextChangeMs: t0 + 55 * 60_000 });
    expect(at(56)).toEqual({ phase: 'break', nextChangeMs: t0 + 60 * 60_000 });
    expect(CFG.focusMin * 2 + CFG.breakMin * 2).toBe(CFG.blockMin);
  });
});

describe('REQ-QUIET-01: the session view is counts only', () => {
  const row: QuietSessionRow = {
    id: '0199a000-0000-7000-8000-000000000001',
    mode: 'study',
    tz_region: 'south_asia',
    t0: new Date('2027-03-10T13:30:00Z'),
    ends_at: new Date('2027-03-10T14:30:00Z'),
    soundscape_seed: 4,
    capacity: 50,
    created_at: new Date('2027-03-10T13:31:00Z'),
  };
  // A polluted row (as if a join spread a member into it): the view must not carry any of it.
  const polluted = { ...row, user_id: 'aaaaaaaa-0000-4000-8000-000000000000', member_id: 'bbbbbbbb-0000-4000-8000-000000000000', pseudonym: 'Quiet Comet', birth_date: '2010-01-01' } as QuietSessionRow;

  it('exact keys; no member, pseudonym, account, age, mood or silhouette', () => {
    const v = sessionView(polluted, 12, CFG, new Date('2027-03-10T14:10:00Z'));
    expect(Object.keys(v).sort()).toEqual(
      ['count', 'endsAt', 'endsAtMs', 'gestures', 'heartbeatMs', 'mode', 'realtime', 'rhythm', 'serverTime', 'serverTimeMs', 'sessionId', 'soundscape', 't0', 't0Ms'].sort(),
    );
    const text = JSON.stringify(v);
    expect(text).not.toMatch(/member|pseudonym|user|account|birth|age|minor|mood|silhouette|Quiet Comet/i);
    expect(text.match(UUID)).toEqual([row.id, row.id]); // the session id (and its topic) only
    expect(v.count).toBe(12);
    expect(v.rhythm).toEqual({ focusMin: 25, breakMin: 5 });
    expect(v.realtime).toEqual({ topic: `quiet:${row.id}` });
    expect(Object.keys(v.soundscape).sort()).toEqual(['seed', 'stems']);
  });

  it('the caller always counts ("Just you right now"): never 0; no rhythm outside Study', () => {
    expect(sessionView(row, 0, CFG, new Date()).count).toBe(1);
    expect(sessionView({ ...row, mode: 'read' }, 3, CFG, new Date()).rhythm).toBeNull();
    expect(sessionView({ ...row, mode: 'rest' }, 3, CFG, new Date()).rhythm).toBeNull();
  });
});

describe('shared soundscapes: base stems only (REQ-QUIET-03, REQ-PAY-11)', () => {
  const manifest = JSON.parse(readFileSync(join(__dirname, '../../../../contracts/sounds/stems.v1.json'), 'utf8')) as {
    stems: Array<{ id: string; tier: string; kind: string; status: string; fallback_generator: string | null }>;
  };
  const playable = new Set(
    manifest.stems.filter((s) => s.tier === 'free' && (s.kind === 'procedural' || s.status === 'available' || s.fallback_generator)).map((s) => s.id),
  );

  it('every quiet and wind-down stem is a free stem the app can play', () => {
    for (const mode of QUIET_MODES) for (const mix of QUIET_SOUNDSCAPES[mode]) for (const s of mix) expect(playable).toContain(s.id);
    for (const lineup of WIND_DOWN_LINEUPS) for (const id of lineup) expect(playable).toContain(id);
  });

  it('the seed picks the mix (same seed, same mix on every phone); gains are 0…1; ≤ 4 layers', () => {
    for (const mode of QUIET_MODES) {
      expect(soundscapeFor(mode, 7)).toEqual(soundscapeFor(mode, 7));
      for (let seed = 0; seed < 10; seed++) {
        const mix = soundscapeFor(mode, seed);
        expect(mix.length).toBeGreaterThan(0);
        expect(mix.length).toBeLessThanOrEqual(4);
        for (const s of mix) expect(s.gain).toBeGreaterThan(0);
        for (const s of mix) expect(s.gain).toBeLessThanOrEqual(1);
      }
    }
  });

  it('the wind-down lineup is the same all night in a region and rotates nightly; cue keys are presets', () => {
    expect(windDownLineup('2027-03-10')).toEqual(windDownLineup('2027-03-10'));
    expect(windDownLineup('2027-03-10')).not.toEqual(windDownLineup('2027-03-11'));
    expect(WIND_DOWN_CUES.map((c) => c.key)).toEqual(['arrive', 'day_quieter', 'shoulders', 'nothing_to_do', 'slower', 'rest_well']);
    for (const c of WIND_DOWN_CUES) expect(c.atS).toBeLessThan(20 * 60);
  });
});

describe('kill switches per region', () => {
  it('missing = on; off = every region; pausedRegions = those only', () => {
    expect(isPaused(undefined, 'south_asia')).toBe(false);
    expect(isPaused({ enabled: false, payload: {} }, 'south_asia')).toBe(true);
    expect(isPaused({ enabled: true, payload: { pausedRegions: ['americas'] } }, 'americas')).toBe(true);
    expect(isPaused({ enabled: true, payload: { pausedRegions: ['americas'] } }, 'south_asia')).toBe(false);
    expect(isPaused({ enabled: true, payload: null }, 'south_asia')).toBe(false);
  });
});

describe('REQ-QUIET-02: gestures to the whole session, presets only', () => {
  it('any text field or target is refused', () => {
    expect(gestureRequestSchema.safeParse({ type: 'light_a_candle' }).success).toBe(true);
    expect(gestureRequestSchema.safeParse({ type: 'light_a_candle', text: 'hi' }).success).toBe(false);
    expect(gestureRequestSchema.safeParse({ type: 'hug', toMemberId: '0199a000-0000-7000-8000-000000000001' }).success).toBe(false);
    expect(gestureRequestSchema.safeParse({ type: 'hug', target: 'member' }).success).toBe(false);
    expect(gestureRequestSchema.safeParse({ type: 'hello there' }).success).toBe(false);
    expect(joinRequestSchema.safeParse({ mode: 'study', note: 'x' }).success).toBe(false);
    expect(joinRequestSchema.safeParse({ mode: 'party' }).success).toBe(false);
  });

  it('limits: 1 per 10 s, 20 per session hour (the F5 rule with Quiet numbers)', () => {
    const l = quietLimitConfig(CFG);
    expect(gestureLimitBreach({ msSinceLast: 9_999, roomLastHour: 0, sameTargetRecent: 0 }, l)).toBe('interval');
    expect(gestureLimitBreach({ msSinceLast: 10_000, roomLastHour: 19, sameTargetRecent: 0 }, l)).toBeNull();
    expect(gestureLimitBreach({ msSinceLast: null, roomLastHour: 20, sameTargetRecent: 0 }, l)).toBe('room_hour');
    expect(l.limitHitsToMute).toBe(3);
    expect(l.shadowMuteHours).toBe(24);
  });
});

describe('Lantern Hour wind-down window (REQ-QUIET-07)', () => {
  const room = (region: TzRegion): RoomRow =>
    ({
      id: '0199a000-0000-7000-8000-00000000000a',
      language_pool: 'en',
      quadrant: 'rain',
      tz_region: region,
      seed_mood_id: 'lonely',
      theme: 'rain_sanctuary',
      capacity: 24,
      status: 'open',
      here_now_broadcast: 0,
      created_at: new Date('2027-03-10T10:00:00Z'),
      opened_at: new Date('2027-03-10T10:01:00Z'),
      joins_close_at: new Date('2027-03-11T06:00:00Z'),
      memory_at: new Date('2027-03-11T10:00:00Z'),
      purge_at: new Date('2027-03-18T10:00:00Z'),
    }) as RoomRow;

  it('22:30–22:50 on the region clock, inside Lantern Hour: soon before, open during, none after', () => {
    const r = room('south_asia');
    const at = (iso: string) => new Date(iso);
    // 21:10 IST = 15:40Z: Lantern Hour, before the wind-down.
    const soon = windDownWindow(r, at('2027-03-10T15:40:00Z'), DEFAULT_MATCHING_CONFIG, CFG);
    expect(soon?.startsAt.toISOString()).toBe('2027-03-10T17:00:00.000Z'); // 22:30 IST
    expect(soon?.endsAt.toISOString()).toBe('2027-03-10T17:20:00.000Z');
    expect(windDownStateAt(soon!, at('2027-03-10T15:40:00Z'))).toBe('soon');
    expect(windDownStateAt(soon!, at('2027-03-10T17:05:00Z'))).toBe('open');
    expect(windDownStateAt(soon!, at('2027-03-10T17:20:00Z'))).toBeNull();
    // Outside Lantern Hour: nothing.
    expect(windDownWindow(r, at('2027-03-10T12:00:00Z'), DEFAULT_MATCHING_CONFIG, CFG)).toBeNull();
    // A memory never offers it.
    expect(windDownWindow({ ...r, memory_at: at('2027-03-10T16:00:00Z') }, at('2027-03-10T17:05:00Z'), DEFAULT_MATCHING_CONFIG, CFG)).toBeNull();
  });

  it('a start outside the Lantern Hour window offers none (config mismatch)', () => {
    const late = { ...CFG, windDown: { ...CFG.windDown, start: { hour: 22, minute: 50 } } };
    expect(windDownWindow(room('south_asia'), new Date('2027-03-10T17:05:00Z'), DEFAULT_MATCHING_CONFIG, late)).toBeNull();
  });

  it('the view is a room total plus presets: exact keys, no member or account', () => {
    const w = windDownWindow(room('europe_africa'), new Date('2027-03-10T21:35:00Z'), DEFAULT_MATCHING_CONFIG, CFG)!;
    const v = windDownView(w, 'open', 3, true, CFG);
    expect(Object.keys(v).sort()).toEqual(['count', 'cues', 'endsAt', 'endsAtMs', 'joined', 'pacer', 'soundscape', 'startsAt', 'startsAtMs', 'state']);
    expect(v.pacer).toEqual({ pattern: 'calm', inhaleMs: 4000, exhaleMs: 6000 });
    expect(JSON.stringify(v)).not.toMatch(UUID);
    expect(JSON.stringify(v)).not.toMatch(/member|pseudonym|user|account|voice|narrat/i);
  });
});
