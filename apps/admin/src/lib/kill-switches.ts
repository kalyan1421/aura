/**
 * Kill switches in the console (PRD 19 "Configuration"). What each flag does is the database's
 * `feature_flags.description` (kept current by migrations), not console text; this file only maps PRD 19's list of
 * kill switches to the flag that implements each, so the page can say which exist, and labels the per-region pauses.
 */

/** PRD 19 "kill switches (…)", in its order, with the flag that implements each and where it is changed. */
export const PRD_KILL_SWITCHES: ReadonlyArray<{ what: string; key: string; where: string }> = [
  { what: 'Reflections per pool', key: 'reflections_composer', where: 'the flag here; single pools on the Reflections page (payload.pausedPools)' },
  { what: 'Hindi + Hinglish pool', key: 'rooms_pool_hi', where: 'the flag here' },
  { what: 'Breath Ripples', key: 'ripples_enabled', where: 'the flag here' },
  { what: 'Echoes', key: 'ripples_echoes', where: 'the flag here' },
  { what: 'Gifts', key: 'gifts_enabled', where: 'the flag here' },
  { what: 'Sign-ups', key: 'reduced_mode', where: 'throttled while reduced mode is on (payload.signupsPerHour)' },
  { what: 'Reduced mode', key: 'reduced_mode', where: 'the flag here' },
  { what: 'Room lanterns', key: 'room_lanterns_enabled', where: 'the flag here' },
  { what: 'Tonight’s intention', key: 'room_intention_enabled', where: 'the flag here' },
  { what: 'Quiet Together, per region', key: 'quiet_enabled', where: 'the flag here; single regions below (payload.pausedRegions)' },
  { what: 'Lantern Hour wind-down, per region', key: 'lantern_wind_down_enabled', where: 'the flag here; single regions below (payload.pausedRegions)' },
];

/** Each PRD kill switch with whether its flag exists in `public.feature_flags`. */
export function prdCoverage(flagKeys: Iterable<string>): Array<{ what: string; key: string; where: string; exists: boolean }> {
  const keys = new Set(flagKeys);
  return PRD_KILL_SWITCHES.map((s) => ({ ...s, exists: keys.has(s.key) }));
}

/** `GET /admin/config/regions` (Owner + Moderator). */
export interface RegionFlagState {
  key: string;
  enabled: boolean;
  pausedRegions: string[];
  updatedAt: string | null;
}

export interface RegionPauses {
  regions: string[];
  flags: RegionFlagState[];
}

/** The server's timezone regions (src/rooms/regions.ts), by the evening they share. */
export const REGION_LABEL: Record<string, string> = {
  americas: 'Americas',
  europe_africa: 'Europe & Africa',
  south_asia: 'South Asia & the Gulf',
  east_asia_pacific: 'East Asia & Pacific',
};

export const REGION_FLAG_LABEL: Record<string, string> = {
  quiet_enabled: 'Quiet Together',
  lantern_wind_down_enabled: 'Lantern Hour wind-down',
};

const REGION_FLAG_KEYS = ['quiet_enabled', 'lantern_wind_down_enabled'];
const REGION_RE = /^[a-z_]{1,40}$/;

export const isRegionFlag = (v: string): boolean => REGION_FLAG_KEYS.includes(v);
/** Shape only: the API checks the region against its own list (404 otherwise). */
export const isRegionName = (v: string): boolean => REGION_RE.test(v);

export type RegionState = 'open' | 'paused' | 'off';

/** A region's state for one flag: the flag off pauses every region, whatever the list says. */
export function regionState(flag: RegionFlagState, region: string): RegionState {
  if (!flag.enabled) return 'off';
  return flag.pausedRegions.includes(region) ? 'paused' : 'open';
}

export const REGION_STATE_LABEL: Record<RegionState, string> = {
  open: 'open',
  paused: 'paused',
  off: 'off everywhere',
};
