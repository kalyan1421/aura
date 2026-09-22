import { computeSnapshot, hueWindow, type ProgressionInputs } from '../../src/progression/snapshot';

const inputs = (over: Partial<ProgressionInputs> = {}): ProgressionInputs => ({
  totalStarlight: 0,
  todayStarlight: 0,
  breatheCompletions: 0,
  sleepCompletions: 0,
  hueCounts: {},
  activeDays: [],
  equippedCosmetics: [],
  ...over,
});

describe('computeSnapshot', () => {
  const now = new Date('2026-10-08T10:00:00Z'); // 15:30 IST → aura day 2026-10-08
  const tz = 'Asia/Kolkata';

  it('new user: spark, null hue, welcome rest day, not resting', () => {
    expect(computeSnapshot(inputs(), now, tz)).toEqual({
      avatar: {
        stage: 'spark',
        hue: null,
        isResting: false,
        ringCount: 0,
        glowLevel: 0,
        constellationStars: 0,
        equippedCosmetics: [],
      },
      streak: { glowStreak: 0, lifetimeGlowDays: 0, restBank: 1, earnCounter: 0, lastActiveDay: null },
      starlight: { total: 0, today: 0 },
      serverTime: '2026-10-08T10:00:00.000Z',
      auraDay: '2026-10-08',
    });
  });

  it('derives stage, stars, traits, hue, streak and resting from the inputs', () => {
    const s = computeSnapshot(
      inputs({
        totalStarlight: 3600,
        todayStarlight: 0,
        breatheCompletions: 20,
        sleepCompletions: 5,
        hueCounts: { sunrise: 2, storm: 1 },
        activeDays: ['2026-10-05', '2026-10-04', '2026-10-05'],
        equippedCosmetics: ['halo'],
      }),
      now,
      tz,
    );
    expect(s.avatar).toMatchObject({ stage: 'constellation', constellationStars: 1, ringCount: 2, glowLevel: 1 });
    expect(s.avatar.hue).toBeCloseTo(15.559, 2);
    expect(s.avatar.equippedCosmetics).toEqual(['halo']);
    expect(s.streak).toEqual({ glowStreak: 2, lifetimeGlowDays: 2, restBank: 1, earnCounter: 2, lastActiveDay: '2026-10-05' });
    expect(s.avatar.isResting).toBe(true); // 10-05 → 10-08 is 3 days
  });

  it('hue window is the last 14 aura days including today', () => {
    expect(hueWindow('2026-10-08')).toEqual({ from: '2026-09-25', to: '2026-10-08' });
  });
});
