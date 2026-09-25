import type { GestureType } from '../rooms/room-types';

/**
 * F16 Quiet Together vocabulary (PRD 06b "F16 Quiet Together"; contracts/api/v1-quiet.md). Other people exist only as a
 * number: no member list, pseudonym, member id, account id, age, mood or silhouette ever leaves the server
 * (DS-10, REQ-QUIET-01).
 */
export const QUIET_MODES = ['study', 'read', 'rest'] as const;
export type QuietMode = (typeof QUIET_MODES)[number];

/** Kill switches (public.feature_flags; contracts §0). A missing flag counts as on; `payload.pausedRegions` pauses regions. */
export const QUIET_FLAG = 'quiet_enabled';
export const WIND_DOWN_FLAG = 'lantern_wind_down_enabled';

/** Realtime topic (private Broadcast channel, server → client only, contracts §3). */
export const quietTopic = (sessionId: string): string => `quiet:${sessionId}`;

export type QuietEvent = 'count' | 'gesture';

/** The 25/5 focus rhythm only exists for Study (PRD: "Optional 25/5 focus rhythm (Study)"). */
export const RHYTHM_MODES: ReadonlySet<QuietMode> = new Set<QuietMode>(['study']);

export type QuietGestureDrop = 'over_limit' | 'shadow_muted';

export type { GestureType };
