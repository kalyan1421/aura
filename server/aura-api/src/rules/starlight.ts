/** RULES.md §3 — Starlight per aura day. */
export const DAILY_CAP = 60;
export const CHECKIN_AWARDS = [10, 2, 2] as const; // #1, #2, #3; #4+ → 0
export const HABIT_AWARD = 5;

export type StarlightEvent =
  | { type: 'checkin'; eligible?: boolean }
  | { type: 'habit'; habitId: string; eligible?: boolean };

/** What has already been credited on one aura day (eligible events only). */
export interface DayLedgerState {
  /** eligible check-ins already credited (each consumed a slot, even at 0). */
  checkIns: number;
  /** habit ids already credited today. */
  creditedHabitIds: ReadonlySet<string>;
  /** Starlight already awarded today. */
  total: number;
}

export const emptyDayState = (): DayLedgerState => ({ checkIns: 0, creditedHabitIds: new Set(), total: 0 });

/** Uncapped base award for the next event given the day so far. */
function baseAward(state: DayLedgerState, event: StarlightEvent): number {
  if (event.type === 'checkin') return CHECKIN_AWARDS[state.checkIns] ?? 0;
  return state.creditedHabitIds.has(event.habitId) ? 0 : HABIT_AWARD;
}

/**
 * Award for one more event on a day, after the daily cap. Ineligible events
 * award 0 and do not consume a slot. Pure; see {@link applyAward} for the fold.
 */
export function awardFor(state: DayLedgerState, event: StarlightEvent): number {
  if (event.eligible === false) return 0;
  return Math.max(0, Math.min(baseAward(state, event), DAILY_CAP - state.total));
}

/** Day state after crediting `event` with `award`. */
export function applyAward(state: DayLedgerState, event: StarlightEvent, award: number): DayLedgerState {
  if (event.eligible === false) return state;
  if (event.type === 'checkin') return { ...state, checkIns: state.checkIns + 1, total: state.total + award };
  const ids = new Set(state.creditedHabitIds);
  ids.add(event.habitId);
  return { ...state, creditedHabitIds: ids, total: state.total + award };
}

/** Awards for one aura day's events, already in `deviceTs` order. */
export function starlightAwards(events: readonly StarlightEvent[]): number[] {
  let state = emptyDayState();
  return events.map((e) => {
    const award = awardFor(state, e);
    state = applyAward(state, e, award);
    return award;
  });
}
