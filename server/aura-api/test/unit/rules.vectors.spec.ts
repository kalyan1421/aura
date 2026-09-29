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
  decayEligible,
  growthStage,
  habitVitality,
  isResting,
  stageFor,
  starlightAwards,
  traitLevel,
  type Quadrant,
  type StarlightEvent,
  type StreakState,
  type VitalityInput,
} from '../../src/rules';
import { isValidUnlockDate, pickTrigger, unlockAt, type TriggerCapsule, type TriggerCheckIn } from '../../src/capsules/capsule-rules';
import {
  dayStar,
  findPatterns,
  isLive,
  monthRecap,
  monthWindow,
  partOf,
  patternGate,
  restDays,
  showCareCard,
  weeklyInsight,
  weeklyWindow,
  type InsightCheckIn,
  type InsightHabitLog,
} from '../../src/rules/insights';
import { addMonthsClamped, lookBackGate, lookBackSky, lookBackWindows, type LookBackEntry } from '../../src/rules/look-back';
import { capsuleYears, earnedKeepsakes, sharePrompt, type KeepsakeSources } from '../../src/keepsakes/keepsake-rules';
import { compareAppVersions, parseAppVersion } from '../../src/remote-config/app-version';

const VECTORS_DIR = resolve(__dirname, '..', '..', '..', '..', 'contracts', 'rules', 'vectors');

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any
type Runner = (c: Json, file: Json) => void;

const runners: Record<string, Runner> = {
  // RULES.md §12 (MASVS F-6 minimum app version).
  'app_version.json': (c) => {
    switch (c.kind) {
      case 'parse': {
        const v = parseAppVersion(c.input);
        return expect(v ? { major: v.parts[0], minor: v.parts[1], patch: v.parts[2], build: v.build } : null).toEqual(c.expect);
      }
      case 'compare':
        return expect(Math.sign(compareAppVersions(parseAppVersion(c.a)!, parseAppVersion(c.b)!))).toBe(c.expect);
      case 'required': {
        const installed = parseAppVersion(c.installed);
        const minimum = parseAppVersion(c.minimum);
        return expect(installed !== null && minimum !== null && compareAppVersions(installed, minimum) < 0).toBe(c.expect);
      }
      default:
        throw new Error(`app_version.json: unknown kind ${String(c.kind)}`);
    }
  },
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
  // RULES.md §13 (world objects; presentation-only).
  'world.json': (c) => {
    if (c.kind === 'stage') return expect(growthStage(c.days)).toBe(c.expect);
    if (c.kind === 'eligible') return expect(decayEligible(c.optedIn, c.ageYears)).toBe(c.expect);
    if (c.kind === 'vitality') return expect(habitVitality(c as unknown as VitalityInput)).toBe(c.expect);
    throw new Error(`world.json: unknown kind ${String(c.kind)}`);
  },
  'nebula.json': (c) => expect(isResting(c.lastActiveDay, c.currentAuraDay)).toBe(c.expect),
  // RULES.md §9 (F4). One file, three pure rules told apart by `kind`.
  'capsules.json': (c) => {
    if (c.kind === 'window') return expect(isValidUnlockDate(c.sealedAt, c.tz, c.unlockLocalDate)).toBe(c.expect);
    if (c.kind === 'unlock_at') return expect(unlockAt(c.localDate, c.tz).toISOString()).toBe(new Date(c.expect).toISOString());
    if (c.kind === 'trigger') {
      return expect(pickTrigger(c.capsules as TriggerCapsule[], c.checkIn as TriggerCheckIn)).toEqual(c.expect);
    }
    throw new Error(`capsules.json: unknown kind ${String(c.kind)}`);
  },
  // RULES.md §10 (F10 Insights). Several pure rules told apart by `kind`.
  'insights.json': (c) => {
    const cs = (c.checkIns ?? []) as InsightCheckIn[];
    const logs = (c.habitLogs ?? []) as InsightHabitLog[];
    const today = () => auraDay(c.now, c.tz);
    switch (c.kind) {
      case 'part':
        return expect({ live: isLive(c.checkIn), part: partOf(c.checkIn) }).toEqual(c.expect);
      case 'day_star':
        return expect(dayStar(c.quadrants as Quadrant[], c.rest)).toEqual(c.expect);
      case 'rest_days':
        return expect(restDays(c.days)).toEqual(c.expect);
      case 'week':
        return expect(weeklyWindow(today(), c.weekStartsOn ?? 1)).toEqual(c.expect);
      case 'month':
        return expect(monthWindow(today())).toEqual(c.expect);
      case 'gate':
        return expect(patternGate(cs, c.from, c.to)).toEqual(c.expect);
      case 'patterns':
        return expect(
          findPatterns({ checkIns: cs, habitLogs: logs, from: c.from, to: c.to, includeHabits: c.includeHabits }),
        ).toEqual(c.expect);
      case 'weekly':
        return expect(
          weeklyInsight({
            checkIns: cs,
            habitLogs: logs,
            today: today(),
            weekStartsOn: c.weekStartsOn ?? 1,
            includeHabits: c.includeHabits,
          }),
        ).toEqual(c.expect);
      case 'month_recap':
        return expect(monthRecap(cs, today())).toEqual(c.expect);
      case 'care':
        return expect(showCareCard(cs, today())).toBe(c.expect);
      default:
        throw new Error(`insights.json: unknown kind ${String(c.kind)}`);
    }
  },
  // RULES.md §10.1 (F10 Look back).
  'look_back.json': (c) => {
    switch (c.kind) {
      case 'add_months':
        return expect(addMonthsClamped(c.day, c.months)).toBe(c.expect);
      case 'windows': {
        const today = auraDay(c.now, c.tz);
        return expect({ today, windows: lookBackWindows(today, c.weekStartsOn ?? 1) }).toEqual(c.expect);
      }
      case 'gate': {
        const g = lookBackGate({ now: c.now, checkIns: c.checkIns, helpAt: c.helpAt, hidden: c.hidden });
        expect(g.status).toBe(c.expect.status);
        return expect(g.until === null ? null : new Date(g.until).getTime()).toBe(
          c.expect.until === null ? null : new Date(c.expect.until).getTime(),
        );
      }
      case 'sky':
        return expect(lookBackSky(c.from, c.to, c.entries as LookBackEntry[], c.restDays)).toEqual(c.expect);
      default:
        throw new Error(`look_back.json: unknown kind ${String(c.kind)}`);
    }
  },
  // RULES.md §11 (F13 keepsakes and share milestones).
  'keepsakes.json': (c) => {
    switch (c.kind) {
      case 'earned': {
        const { glowDaysRange, ...rest } = c.sources as Json;
        const sources = rest as KeepsakeSources;
        if (glowDaysRange) {
          const from = new Date(`${glowDaysRange.from as string}T00:00:00Z`).getTime();
          sources.glowDays = Array.from({ length: glowDaysRange.count as number }, (_, i) => ({
            day: new Date(from + i * 86_400_000).toISOString().slice(0, 10),
            amount: 1,
          }));
        }
        return expect(earnedKeepsakes(sources)).toEqual(c.expect);
      }
      case 'capsule_years':
        return expect(capsuleYears(c.firstSealed, c.today)).toBe(c.expect);
      case 'share_prompt':
        return expect(sharePrompt(c.state)).toEqual(c.expect);
      default:
        throw new Error(`keepsakes.json: unknown kind ${String(c.kind)}`);
    }
  },
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
