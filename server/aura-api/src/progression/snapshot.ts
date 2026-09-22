import {
  addDays,
  auraDay,
  constellationStars,
  foldStreak,
  HUE_WINDOW_DAYS,
  hueFor,
  initialStreak,
  isResting,
  stageFor,
  traitLevel,
  type Quadrant,
  type Stage,
  type StreakState,
} from '../rules';

/** contracts/api/v1.md `Snapshot`. */
export interface Snapshot {
  avatar: {
    stage: Stage;
    hue: number | null;
    isResting: boolean;
    ringCount: 0 | 1 | 2 | 3;
    glowLevel: 0 | 1 | 2 | 3;
    constellationStars: number;
    equippedCosmetics: string[];
  };
  streak: StreakState;
  starlight: { total: number; today: number };
  serverTime: string;
  auraDay: string;
}

/** Everything the snapshot is derived from (DS-5: ledgers + active days are the truth). */
export interface ProgressionInputs {
  totalStarlight: number;
  todayStarlight: number;
  /** lifetime Breathe completions (distinct credited aura days) */
  breatheCompletions: number;
  /** lifetime Sleep-on-time completions (distinct credited aura days) */
  sleepCompletions: number;
  /** check-in quadrant counts over the hue window */
  hueCounts: Partial<Record<Quadrant, number>>;
  activeDays: readonly string[];
  equippedCosmetics: readonly string[];
}

/** Inclusive `[from, to]` aura-day window used for hue: the last 14 aura days including today. */
export function hueWindow(today: string): { from: string; to: string } {
  return { from: addDays(today, -(HUE_WINDOW_DAYS - 1)), to: today };
}

/** Pure: inputs + clock + tz → Snapshot. */
export function computeSnapshot(inputs: ProgressionInputs, now: Date, tz: string): Snapshot {
  const today = auraDay(now, tz);
  const streak = foldStreak(initialStreak(), inputs.activeDays);
  const hue = hueFor(inputs.hueCounts);
  return {
    avatar: {
      stage: stageFor(inputs.totalStarlight),
      hue: hue === null ? null : Math.round(hue * 1000) / 1000, // 0.001° is far below the ±0.5° contract tolerance
      isResting: isResting(streak.lastActiveDay, today),
      ringCount: traitLevel(inputs.breatheCompletions),
      glowLevel: traitLevel(inputs.sleepCompletions),
      constellationStars: constellationStars(inputs.totalStarlight),
      equippedCosmetics: [...inputs.equippedCosmetics],
    },
    streak,
    starlight: { total: inputs.totalStarlight, today: inputs.todayStarlight },
    serverTime: now.toISOString(),
    auraDay: today,
  };
}
