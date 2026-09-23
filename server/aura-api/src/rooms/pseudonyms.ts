import { randomInt } from 'node:crypto';

/**
 * Room pseudonyms (DS-2): adjective + celestial noun ("Quiet Comet"), fresh per membership, unique within a room,
 * different from the person's pseudonyms in their other rooms. Built only from these curated lists, so a pseudonym
 * can never carry digits, handles, contact details or free text. Words avoid bodies, looks, age, gender, faith,
 * caste and moods (nothing can mock how a room feels). The admin console will own per-language lists later.
 */
export const ADJECTIVES = [
  'Quiet', 'Gentle', 'Soft', 'Calm', 'Still', 'Warm', 'Kind', 'Bright',
  'Silver', 'Golden', 'Hidden', 'Distant', 'Drifting', 'Glowing', 'Hushed', 'Tender',
  'Patient', 'Brave', 'Hopeful', 'Dreaming', 'Wandering', 'Steady', 'Humble', 'Misty',
  'Velvet', 'Amber', 'Azure', 'Coral', 'Ivory', 'Jade', 'Lunar', 'Solar',
  'Starry', 'Twilight', 'Dawn', 'Evening', 'Morning', 'Midnight', 'Northern', 'Southern',
  'Faraway', 'Shining', 'Wistful', 'Peaceful', 'Serene', 'Radiant', 'Silent', 'Mellow',
] as const;

export const NOUNS = [
  'Comet', 'Star', 'Moon', 'Nova', 'Nebula', 'Orbit', 'Meteor', 'Aurora',
  'Galaxy', 'Planet', 'Eclipse', 'Horizon', 'Lantern', 'Ember', 'Spark', 'Sky',
  'Cloud', 'Tide', 'Quasar', 'Pulsar', 'Cosmos', 'Zenith', 'Equinox', 'Solstice',
  'Crescent', 'Halo', 'Beacon', 'Glimmer', 'Starlight', 'Moonbeam', 'Sunbeam', 'Firefly',
  'Satellite', 'Asteroid', 'Voyager', 'Stardust', 'Dusk', 'Twinkle', 'Glow', 'Shimmer',
  'Starfall', 'Moonrise', 'Skylight', 'Daybreak', 'Nightfall', 'Lightyear', 'Parallax', 'Borealis',
] as const;

/** Offensive, awkward or redundant combinations that must never be generated (admin-configurable later). */
export const BLOCKED_PSEUDONYMS: ReadonlySet<string> = new Set([
  'Lunar Moon',
  'Lunar Moonbeam',
  'Lunar Moonrise',
  'Solar Sunbeam',
  'Solar Solstice',
  'Shining Shimmer',
  'Dawn Daybreak',
  'Morning Daybreak',
  'Midnight Nightfall',
  'Evening Nightfall',
  'Dawn Dusk',
  'Morning Dusk',
  'Evening Dusk',
  'Midnight Dusk',
  'Twilight Dusk',
  'Northern Borealis',
]);

/** Two capitalised words of letters only — the DB CHECK `room_members.pseudonym` is the backstop. */
export const PSEUDONYM_RE = /^[A-Z][a-z]{1,14} [A-Z][a-z]{1,14}$/;

/** Same stem ("Starry Star", "Glowing Glow", "Shining Shimmer") reads as a stutter: skip. */
const sharesStem = (adjective: string, noun: string): boolean =>
  adjective.slice(0, 4).toLowerCase() === noun.slice(0, 4).toLowerCase();

export function isAllowedPseudonym(p: string): boolean {
  if (!PSEUDONYM_RE.test(p) || BLOCKED_PSEUDONYMS.has(p)) return false;
  const [adjective, noun] = p.split(' ');
  return (ADJECTIVES as readonly string[]).includes(adjective) && (NOUNS as readonly string[]).includes(noun) && !sharesStem(adjective, noun);
}

/** Every allowed combination, in list order (computed once). */
export const ALL_PSEUDONYMS: readonly string[] = ADJECTIVES.flatMap((a) => NOUNS.map((n) => `${a} ${n}`)).filter(isAllowedPseudonym);

export class PseudonymsExhaustedError extends Error {
  constructor() {
    super('no pseudonym left for this room');
    this.name = 'PseudonymsExhaustedError';
  }
}

/**
 * A random allowed pseudonym not in `taken` (the room's pseudonyms plus the joiner's pseudonyms in other rooms).
 * `rng(n)` returns an integer in [0, n) — crypto-random by default.
 */
export function generatePseudonym(taken: ReadonlySet<string>, rng: (n: number) => number = randomInt): string {
  const pool = ALL_PSEUDONYMS;
  for (let i = 0; i < 64; i++) {
    const p = pool[rng(pool.length)];
    if (!taken.has(p)) return p;
  }
  const start = rng(pool.length);
  for (let i = 0; i < pool.length; i++) {
    const p = pool[(start + i) % pool.length];
    if (!taken.has(p)) return p;
  }
  throw new PseudonymsExhaustedError();
}
