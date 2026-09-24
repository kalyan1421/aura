/**
 * F7 Breath Ripples vocabulary (PRD 06b "F7 Breath Ripples"; contracts/api/v1-ripples.md). Seat numbers, kinds and
 * pseudonyms are the only things other people ever see (DS-10).
 */
export const RIPPLE_ENTRIES = ['quick', 'room'] as const;
export type RippleEntry = (typeof RIPPLE_ENTRIES)[number];

export const SEAT_KINDS = ['human', 'echo', 'guide'] as const;
export type SeatKind = (typeof SEAT_KINDS)[number];

/** How a session started (contracts §1.1). */
export const START_RULES = ['full', 'early', 'timeout', 'invite'] as const;
export type StartRule = (typeof START_RULES)[number];

/** The 3 in-game gestures (PRD: "Hug, Deep Breath, You're Not Alone" [ASSUMPTION]). Client to client only. */
export const RIPPLE_GESTURES = ['hug', 'deep_breath', 'youre_not_alone'] as const;
export type RippleGesture = (typeof RIPPLE_GESTURES)[number];

/** Kill switches (public.feature_flags; contracts §0). A missing flag counts as on. */
export const RIPPLES_FLAG = 'ripples_enabled';
export const ECHOES_FLAG = 'ripples_echoes';

/** user_consents purpose for the echo opt-out ("Let my breathing become an echo", on by default). */
export const ECHO_CONSENT_PURPOSE = 'echoes';
export const ECHO_CONSENT_POLICY = 'ripples-echoes-1';

/** Realtime topics (private channels, contracts §3). */
export const gameTopic = (sessionId: string): string => `game:${sessionId}`;
export const roomInviteTopic = (roomId: string): string => `ripples:${roomId}`;

export type TicketStatus = 'waiting' | 'matched' | 'cancelled' | 'expired';
