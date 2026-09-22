/**
 * Contract conformance: every case in contracts/rules/vectors/*.json must pass.
 * A new vector file without a runner here fails the suite loudly.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import {
  auraDay,
  constellationStars,
  foldStreak,
  hueFor,
  isEligible,
  isResting,
  stageFor,
  starlightAwards,
  traitLevel,
  type Quadrant,
  type StarlightEvent,
  type StreakState,
} from '../../src/rules';

const VECTORS_DIR = resolve(__dirname, '..', '..', '..', '..', 'contracts', 'rules', 'vectors');

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any
type Runner = (c: Json, file: Json) => void;

const runners: Record<string, Runner> = {
  'aura_day.json': (c) => expect(auraDay(c.utc, c.tz)).toBe(c.expect),
  'eligibility.json': (c) =>
    expect(isEligible({ deviceTs: c.deviceTs, serverNow: c.serverNow, tz: c.tz, localDay: c.localDay })).toBe(c.expect),
  'starlight.json': (c) => {
    const awards = starlightAwards(c.events as StarlightEvent[]);
    expect(awards).toEqual(c.expectAwards);
    expect(awards.reduce((a, b) => a + b, 0)).toBe(c.expectTotal);
  },
  'stage.json': (c) => {
    expect(stageFor(c.total)).toBe(c.expectStage);
    expect(constellationStars(c.total)).toBe(c.expectStars);
  },
  'traits.json': (c) => expect(traitLevel(c.completions)).toBe(c.expectLevel),
  'hue.json': (c, file) => {
    const hue = hueFor(c.counts as Partial<Record<Quadrant, number>>);
    if (c.expect === null) {
      expect(hue).toBeNull();
    } else {
      expect(hue).not.toBeNull();
      expect(Math.abs((hue as number) - c.expect)).toBeLessThanOrEqual(file.toleranceDeg);
    }
  },
  'streak.json': (c) => expect(foldStreak(c.initial as StreakState, c.days)).toEqual(c.expect),
  'nebula.json': (c) => expect(isResting(c.lastActiveDay, c.currentAuraDay)).toBe(c.expect),
};

const files = readdirSync(VECTORS_DIR).filter((f) => f.endsWith('.json')).sort();

describe('contracts/rules/vectors', () => {
  it('finds the vector files', () => {
    expect(files.length).toBeGreaterThanOrEqual(8);
  });

  it.each(files)('%s has a runner', (f) => {
    expect(Object.keys(runners)).toContain(f);
  });

  for (const f of files) {
    const file = JSON.parse(readFileSync(join(VECTORS_DIR, f), 'utf8')) as Json;
    const cases = (file.cases ?? []) as Json[];
    describe(f, () => {
      it('has cases', () => expect(cases.length).toBeGreaterThan(0));
      cases.forEach((c, i) => {
        const label = c.name ?? JSON.stringify(c).slice(0, 80);
        it(`#${i} ${label}`, () => {
          const run = runners[f];
          if (!run) throw new Error(`no runner for ${f}`);
          run(c, file);
        });
      });
    });
  }
});
