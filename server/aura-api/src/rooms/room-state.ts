import type { RoomState } from './room-types';

export interface RoomClock {
  openedAt: Date | null;
  joinsCloseAt: Date;
  memoryAt: Date;
  purgeAt: Date;
}

/**
 * PRD F5 state machine, derived from timestamps on the server clock (the stored `rooms.status` is only the
 * worker's cache for broadcasting transitions once):
 * forming (1st member) → open (2nd member ever) ⇄ lantern_hour (21–23 region clock, open rooms only)
 * → closing at 20 h → memory at 24 h → purged at 24 h + 7 d.
 */
export function deriveRoomState(r: RoomClock, now: Date, lanternActive: boolean): RoomState | 'purged' {
  const t = now.getTime();
  if (t >= r.purgeAt.getTime()) return 'purged';
  if (t >= r.memoryAt.getTime()) return 'memory';
  if (t >= r.joinsCloseAt.getTime()) return 'closing';
  if (!r.openedAt) return 'forming';
  return lanternActive ? 'lantern_hour' : 'open';
}

/** Gestures work until the room becomes a memory; memories are read-only. */
export const acceptsGestures = (state: RoomState | 'purged'): boolean =>
  state === 'forming' || state === 'open' || state === 'lantern_hour' || state === 'closing';
