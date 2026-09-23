/**
 * Pseudonyms (DS-2: curated two-word names, filtered, no digits/contact-like strings, unique within a room) and
 * gesture limits (PRD F5: 1 per 2 s, 40 per room per hour, same gesture to the same member ≤ 3 per 10 min; 3 hits in
 * 24 h → 24 h shadow-mute).
 */
import { gestureLimitBreach, shouldShadowMute, type GestureLimitConfig } from '../../src/rooms/gesture-limits';
import { DEFAULT_MATCHING_CONFIG } from '../../src/rooms/matching-config';
import {
  ADJECTIVES,
  ALL_PSEUDONYMS,
  BLOCKED_PSEUDONYMS,
  generatePseudonym,
  isAllowedPseudonym,
  NOUNS,
  PseudonymsExhaustedError,
  PSEUDONYM_RE,
} from '../../src/rooms/pseudonyms';
import { bucketHue } from '../../src/rooms/room-types';

describe('pseudonyms', () => {
  it('every generated name is two capitalised words from the curated lists — no digits, handles or contact-like text', () => {
    expect(ALL_PSEUDONYMS.length).toBeGreaterThan(2000);
    for (const p of ALL_PSEUDONYMS) {
      expect(p).toMatch(PSEUDONYM_RE);
      expect(p).not.toMatch(/[0-9@#:/._+-]/);
      expect(isAllowedPseudonym(p)).toBe(true);
    }
    for (const w of [...ADJECTIVES, ...NOUNS]) expect(w).toMatch(/^[A-Z][a-z]{1,14}$/);
  });

  it('matches the DB CHECK on room_members.pseudonym', () => {
    const db = /^[A-Z][a-z]{1,14} [A-Z][a-z]{1,14}$/; // supabase/migrations/20261005000010_rooms_safety.sql
    for (const p of ALL_PSEUDONYMS) expect(db.test(p)).toBe(true);
  });

  it('the blocklist and same-stem stutters are never generated', () => {
    for (const b of BLOCKED_PSEUDONYMS) expect(ALL_PSEUDONYMS).not.toContain(b);
    for (const p of ['Starry Star', 'Starry Starlight', 'Glowing Glow', 'Lunar Moon', 'Solar Solstice']) {
      expect(isAllowedPseudonym(p)).toBe(false);
    }
    // Quadrant and room-theme words never appear (a name must not hint at how a room feels).
    for (const p of ALL_PSEUDONYMS) expect(p.toLowerCase()).not.toMatch(/storm|rain|moonlight|sunrise|lighthouse|sanctuary/);
    expect(isAllowedPseudonym('Quiet 98765')).toBe(false);
    expect(isAllowedPseudonym('Quiet Comet ')).toBe(false);
    expect(isAllowedPseudonym('Insta Comet')).toBe(false);
  });

  it('is unique within a room (and never one of the joiner’s other names)', () => {
    const taken = new Set<string>();
    for (let i = 0; i < 48; i++) {
      const p = generatePseudonym(taken);
      expect(taken.has(p)).toBe(false);
      taken.add(p);
    }
    expect(taken.size).toBe(48);
  });

  it('falls back to a scan when random picks keep colliding, and fails loudly only when truly exhausted', () => {
    const allButOne = new Set(ALL_PSEUDONYMS.slice(1));
    expect(generatePseudonym(allButOne, () => 5)).toBe(ALL_PSEUDONYMS[0]);
    expect(() => generatePseudonym(new Set(ALL_PSEUDONYMS), () => 0)).toThrow(PseudonymsExhaustedError);
  });

  it('silhouette hue is bucketed to 30° so it can’t fingerprint anyone across rooms', () => {
    expect(bucketHue(null)).toBeNull();
    expect(bucketHue(213.47)).toBe(210);
    expect(bucketHue(14.99)).toBe(0);
    expect(bucketHue(15)).toBe(30);
    expect(bucketHue(359)).toBe(0);
    expect(bucketHue(-10)).toBe(0);
    expect(bucketHue(Number.NaN)).toBeNull();
  });
});

describe('gesture limits', () => {
  const cfg: GestureLimitConfig = DEFAULT_MATCHING_CONFIG.gestures;
  const ok = { msSinceLast: null, roomLastHour: 0, sameTargetRecent: 0 };

  it('uses the PRD defaults', () => {
    expect(cfg).toEqual({
      minIntervalMs: 2000,
      roomHourMax: 40,
      sameTargetMax: 3,
      sameTargetWindowMin: 10,
      limitHitsToMute: 3,
      shadowMuteHours: 24,
    });
  });

  it('1 per 2 s across rooms', () => {
    expect(gestureLimitBreach(ok, cfg)).toBeNull();
    expect(gestureLimitBreach({ ...ok, msSinceLast: 1999 }, cfg)).toBe('interval');
    expect(gestureLimitBreach({ ...ok, msSinceLast: 2000 }, cfg)).toBeNull();
  });

  it('40 per room per hour', () => {
    expect(gestureLimitBreach({ ...ok, msSinceLast: 5000, roomLastHour: 39 }, cfg)).toBeNull();
    expect(gestureLimitBreach({ ...ok, msSinceLast: 5000, roomLastHour: 40 }, cfg)).toBe('room_hour');
  });

  it('same gesture to the same member ≤ 3 per 10 min', () => {
    expect(gestureLimitBreach({ ...ok, msSinceLast: 5000, sameTargetRecent: 2 }, cfg)).toBeNull();
    expect(gestureLimitBreach({ ...ok, msSinceLast: 5000, sameTargetRecent: 3 }, cfg)).toBe('same_target');
  });

  it('3 limit hits in 24 h → shadow-mute (once: not again while one is active)', () => {
    expect(shouldShadowMute(2, false, cfg)).toBe(false);
    expect(shouldShadowMute(3, false, cfg)).toBe(true);
    expect(shouldShadowMute(4, true, cfg)).toBe(false);
  });
});
