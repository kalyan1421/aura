import type { SanctionKind } from './safety-types';

/**
 * Strike ladder (06c F9; 19 admin console "Actions and strikes"): 1 = warning (+ removal) → 2 = 24 h shadow-mute →
 * 3 = 7-day room suspension → 4 = permanent social ban (applied automatically, audited as `system:strike_ladder`, with
 * the evidence behind the strikes held 180 days from the ban). Strikes stop counting 90 days after issue (REQ-ADM-07).
 * Crisis flags never strike (REQ-SAFE-08) — enforced by ModerationService and, whoever inserts, by the database
 * trigger `strikes_never_crisis` (migration 20261005000016).
 */
export interface StrikeConsequence {
  kind: Extract<SanctionKind, 'warning' | 'shadow_mute' | 'room_suspension' | 'social_ban'>;
  /** Duration; null = until lifted (the ban) or not applicable (the warning notice). */
  hours: number | null;
}

export function consequenceForActiveStrikes(activeStrikes: number): StrikeConsequence {
  if (activeStrikes <= 1) return { kind: 'warning', hours: null };
  if (activeStrikes === 2) return { kind: 'shadow_mute', hours: 24 };
  if (activeStrikes === 3) return { kind: 'room_suspension', hours: 7 * 24 };
  return { kind: 'social_ban', hours: null };
}

export const STRIKE_TTL_DAYS = 90;
