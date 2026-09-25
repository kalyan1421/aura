import { nightIndex } from '../rooms/lantern-rules';
import type { QuietMode } from './quiet-types';

/**
 * The shared soundscapes (PRD F16 "Shared soundscape, played locally"): a mix of **base** Sounds stems (F15), chosen by
 * Aura per mode [ASSUMPTION], so it never leads to a paywall (REQ-PAY-11). Every id must be a free stem of
 * contracts/sounds/stems.v1.json that the app can play (a unit test checks the manifest). The phone plays them from its
 * own cache, positioned from the session's `t0` (no audio crosses the network, no microphone).
 */
export interface SoundscapeStem {
  id: string;
  gain: number;
}

export const QUIET_SOUNDSCAPES: Readonly<Record<QuietMode, ReadonlyArray<ReadonlyArray<SoundscapeStem>>>> = {
  study: [
    [
      { id: 'brown_noise', gain: 0.55 },
      { id: 'rain', gain: 0.3 },
    ],
    [
      { id: 'brown_noise', gain: 0.5 },
      { id: 'wind', gain: 0.3 },
    ],
    [
      { id: 'rain', gain: 0.5 },
      { id: 'brown_noise', gain: 0.25 },
    ],
  ],
  read: [
    [
      { id: 'rain', gain: 0.5 },
      { id: 'chimes', gain: 0.12 },
    ],
    [
      { id: 'ocean', gain: 0.45 },
      { id: 'wind', gain: 0.25 },
    ],
    [
      { id: 'rain', gain: 0.45 },
      { id: 'singing_bowl', gain: 0.12 },
    ],
  ],
  rest: [
    [
      { id: 'ocean', gain: 0.5 },
      { id: 'singing_bowl', gain: 0.15 },
    ],
    [
      { id: 'wind', gain: 0.45 },
      { id: 'night_insects', gain: 0.3 },
    ],
    [
      { id: 'ocean', gain: 0.45 },
      { id: 'wind', gain: 0.2 },
      { id: 'chimes', gain: 0.12 },
    ],
  ],
};

/** The session's mix from its seed. */
export function soundscapeFor(mode: QuietMode, seed: number): SoundscapeStem[] {
  const presets = QUIET_SOUNDSCAPES[mode];
  const i = ((Math.floor(seed) % presets.length) + presets.length) % presets.length;
  return presets[i].map((s) => ({ id: s.id, gain: s.gain }));
}

/** A fresh non-negative 31-bit seed. */
export const newSoundscapeSeed = (): number => Math.floor(Math.random() * 0x7fffffff);

/**
 * The Lantern Hour wind-down's one ambient track (PRD "one ambient track of base stems, played locally from a common
 * server t0"): a lineup, bed first, the same in every room of a region tonight (rotated by the region-local date).
 * The phone applies the F15 night wind-down envelope, so it thins out to silence at 20 minutes.
 */
export const WIND_DOWN_LINEUPS: ReadonlyArray<ReadonlyArray<string>> = [
  ['rain', 'wind', 'chimes'],
  ['ocean', 'night_insects', 'singing_bowl'],
  ['wind', 'rain', 'singing_bowl'],
  ['brown_noise', 'ocean', 'chimes'],
];

export function windDownLineup(localDay: string): string[] {
  const n = WIND_DOWN_LINEUPS.length;
  return [...WIND_DOWN_LINEUPS[((nightIndex(localDay) % n) + n) % n]];
}

/** Preset text cues (keys; the phone localizes them) at seconds from `t0`. No narration, no user voice. */
export const WIND_DOWN_CUES: ReadonlyArray<{ atS: number; key: string }> = [
  { atS: 0, key: 'arrive' },
  { atS: 120, key: 'day_quieter' },
  { atS: 330, key: 'shoulders' },
  { atS: 600, key: 'nothing_to_do' },
  { atS: 870, key: 'slower' },
  { atS: 1110, key: 'rest_well' },
];
