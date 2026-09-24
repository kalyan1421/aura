import type { Quadrant, Stage } from '../rules';

/** The 8 preset gestures (PRD F5 / brief). Keys are what the app localises ("Warm Tea" → "Oka cup chai"). */
export const GESTURE_TYPES = [
  'warm_tea',
  'light_a_candle',
  'hug',
  'me_too',
  'soft_rain',
  'stargaze',
  'deep_breath',
  'youre_not_alone',
] as const;
export type GestureType = (typeof GESTURE_TYPES)[number];

/** `reflection` (F6): a published reflection; the recipient is its author (contracts/api/v1-reflections.md §1.5). */
export const GESTURE_TARGETS = ['member', 'room', 'reflection'] as const;
export type GestureTarget = (typeof GESTURE_TARGETS)[number];

/** Why a gesture was not delivered. The sender never learns it (every drop answers like a delivery). */
export type GestureDrop = 'over_limit' | 'shadow_muted' | 'blocked' | 'muted' | 'hidden';

export const ROOM_STATES = ['forming', 'open', 'lantern_hour', 'closing', 'memory'] as const;
export type RoomState = (typeof ROOM_STATES)[number];

export const THEMES = ['lighthouse', 'rain_sanctuary', 'midnight_observatory', 'sunrise_deck'] as const;
export type Theme = (typeof THEMES)[number];

/** Room theme by quadrant (brief: The Lighthouse, The Rain Sanctuary, The Midnight Observatory, The Sunrise Deck). */
export const THEME_BY_QUADRANT: Readonly<Record<Quadrant, Theme>> = {
  storm: 'lighthouse',
  rain: 'rain_sanctuary',
  moonlight: 'midnight_observatory',
  sunrise: 'sunrise_deck',
};

/**
 * Ladder step 3 merges only on the same pleasantness side: Storm↔Rain (unpleasant), Moonlight↔Sunrise (pleasant).
 * **Never pleasant with unpleasant** (REQ-ROOM-03).
 */
export const ADJACENT_QUADRANT: Readonly<Record<Quadrant, Quadrant>> = {
  storm: 'rain',
  rain: 'storm',
  moonlight: 'sunrise',
  sunrise: 'moonlight',
};

export const LANGUAGE_POOLS = ['en', 'te', 'hi'] as const;
export type LanguagePool = (typeof LANGUAGE_POOLS)[number];

/** Feature flag (client-readable) that opens Hindi + Hinglish rooms. Off until moderation is ready. */
export const HI_POOL_FLAG = 'rooms_pool_hi';

/** Silhouettes are not fingerprints: stage, a 30°-bucketed hue and at most one standard cosmetic (null until F12). */
export interface Silhouette {
  stage: Stage;
  hue: number | null;
  cosmetic: string | null;
}

export const HUE_BUCKET_DEG = 30;

/** Avatar hue (0–360, or null) → the bucket shown to strangers (0, 30, … 330). */
export function bucketHue(hue: number | null | undefined): number | null {
  if (hue === null || hue === undefined || !Number.isFinite(hue)) return null;
  const normalised = ((hue % 360) + 360) % 360;
  return (Math.round(normalised / HUE_BUCKET_DEG) * HUE_BUCKET_DEG) % 360;
}

/** Realtime topics (private Broadcast channels, contracts/api/v1-rooms.md §3). */
export const roomTopic = (roomId: string): string => `room:${roomId}`;
export const memberTopic = (memberId: string): string => `member:${memberId}`;
