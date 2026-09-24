import { BASELINE_HELPLINES } from './helplines-contract.data';

/**
 * The crisis helpline directory (contracts/safety/helplines.schema.json; PRD 06c F9, 18 "Helplines by country"): its
 * validation — the same rules as apps/mobile/tool/gen_helplines.py and the app's `compileHelplines` — the resolution
 * vectors every signed version carries, and the diff that gates removing a number phones use now. Problems name the
 * line id and the rule.
 */
export const HELPLINES_NAME = 'aura.helplines';
export const HELPLINE_LOCALES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export const HELPLINE_AUDIENCES = ['everyone', 'minors'] as const;

const COUNTRY = /^[A-Z]{2}$/;
const LINE_ID = /^[a-z]{2}\.[a-z0-9_]{1,40}$/;
const NUMBER = /^[0-9+() -]{2,24}$/;
const DIAL = /^[0-9]{2,15}$/;
// eslint-disable-next-line no-control-regex
const CONTROL = /[\u0000-\u001f\u007f]/;
const DAY = /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
/** A region that is never assigned (ISO 3166 user-assigned): its vector says "unlisted → the generic card". */
export const UNLISTED_REGION = 'ZZ';

export interface HelplineLine {
  id: string;
  number: string;
  dial: string;
  audience: (typeof HELPLINE_AUDIENCES)[number];
  names: Partial<Record<(typeof HELPLINE_LOCALES)[number], string>> & { en: string };
  [key: string]: unknown;
}

/** The whole document: `name`, `version`, `countries` are required; the rest (review notes, verifiedOn) is kept as is. */
export interface HelplinesDocument {
  name: string;
  version: number;
  verifiedOn?: string;
  countries: Record<string, HelplineLine[]>;
  [key: string]: unknown;
}

/** One entry of a signed payload's `vectors`: what the app's resolver must list for a region. */
export interface HelplineVector {
  country: string;
  minor: boolean;
  dials: string[];
}

export class HelplinesInvalidError extends Error {
  constructor(readonly problems: string[]) {
    super(`helpline directory is invalid: ${problems[0] ?? 'unknown problem'}`);
    this.name = 'HelplinesInvalidError';
  }
}

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

let baseline: HelplinesDocument | null = null;

/** contracts/safety/helplines.v1.json (the directory every app build bundles). */
export function baselineHelplines(): HelplinesDocument {
  baseline ??= parseHelplines(BASELINE_HELPLINES);
  return structuredClone(baseline);
}

/** Regions every published version must keep: the bundled ones (the app refuses a bundle without them). */
export function requiredCountries(): string[] {
  return Object.keys(parseHelplines(BASELINE_HELPLINES).countries);
}

/** Every problem found (empty = valid). */
export function helplinesProblems(doc: unknown, required: readonly string[] = requiredCountries()): string[] {
  const problems: string[] = [];
  if (!isObject(doc)) return ['the directory must be a JSON object'];
  if (doc.name !== HELPLINES_NAME) problems.push(`name must be '${HELPLINES_NAME}'`);
  const v = doc.version;
  if (typeof v !== 'number' || !Number.isInteger(v) || v < 1 || v > 1_000_000) problems.push('version must be a positive integer');
  if (doc.verifiedOn !== undefined && !(typeof doc.verifiedOn === 'string' && DAY.test(doc.verifiedOn))) {
    problems.push('verifiedOn must be YYYY-MM-DD');
  }
  const countries = doc.countries;
  if (!isObject(countries) || Object.keys(countries).length === 0 || Object.keys(countries).length > 250) {
    problems.push('countries must be an object with 1–250 regions');
    return problems;
  }
  const seen = new Set<string>();
  for (const [code, lines] of Object.entries(countries)) {
    if (!COUNTRY.test(code)) {
      problems.push(`${JSON.stringify(code)}: a region is an ISO 3166-1 alpha-2 code in capitals`);
      continue;
    }
    if (!Array.isArray(lines) || lines.length === 0 || lines.length > 10) {
      problems.push(`${code}: 1–10 lines`);
      continue;
    }
    if (!lines.some((l) => isObject(l) && l.audience === 'everyone')) problems.push(`${code}: needs at least one line for everyone`);
    lines.forEach((line, i) => {
      const where = `${code}[${i}]`;
      if (!isObject(line)) {
        problems.push(`${where}: a line must be an object`);
        return;
      }
      const id = line.id;
      if (typeof id !== 'string' || !LINE_ID.test(id) || !id.startsWith(`${code.toLowerCase()}.`)) {
        problems.push(`${where}: id must be '${code.toLowerCase()}.<snake_case>'`);
      } else if (seen.has(id)) {
        problems.push(`${id}: duplicate id`);
      } else {
        seen.add(id);
      }
      const label = typeof id === 'string' ? id : where;
      const { number, dial } = line;
      if (typeof number !== 'string' || !NUMBER.test(number)) problems.push(`${label}: number must be digits with spaces, dashes, + or ()`);
      if (typeof dial !== 'string' || !DIAL.test(dial)) problems.push(`${label}: dial must be 2–15 digits`);
      if (typeof number === 'string' && typeof dial === 'string' && number.replace(/[^0-9]/g, '') !== dial) {
        problems.push(`${label}: the digits of number must be exactly dial (what is shown is what is dialled)`);
      }
      if (!(HELPLINE_AUDIENCES as readonly unknown[]).includes(line.audience)) problems.push(`${label}: audience must be everyone or minors`);
      const names = line.names;
      if (!isObject(names) || typeof names.en !== 'string') {
        problems.push(`${label}: names needs en`);
        return;
      }
      for (const [locale, name] of Object.entries(names)) {
        if (!(HELPLINE_LOCALES as readonly string[]).includes(locale)) problems.push(`${label}: unknown locale ${JSON.stringify(locale)}`);
        if (typeof name !== 'string' || name.trim() === '' || name.length > 80 || CONTROL.test(name)) {
          problems.push(`${label}: names.${locale} must be 1–80 characters, no control characters`);
        }
      }
    });
  }
  for (const code of required) {
    if (!Object.prototype.hasOwnProperty.call(countries, code)) {
      problems.push(`${code}: every region the app bundles must stay listed (phones refuse a directory without it)`);
    }
  }
  return problems;
}

/** A valid document, or HelplinesInvalidError. */
export function parseHelplines(doc: unknown, required?: readonly string[]): HelplinesDocument {
  const problems = helplinesProblems(doc, required ?? []);
  if (problems.length) throw new HelplinesInvalidError(problems);
  return doc as HelplinesDocument;
}

/** The lines the app lists for a region (in order; `minors` lines only for a minor). */
export function resolveHelplines(doc: HelplinesDocument, country: string, minor: boolean): HelplineLine[] {
  return (doc.countries[country] ?? []).filter((l) => l.audience === 'everyone' || minor);
}

/**
 * The payload's `vectors`: every region × {adult, minor} → the dial list, plus an unlisted region → nothing (the app's
 * generic "call your local emergency number" card). The app re-derives each with its own resolver before it uses a
 * version, so both sides provably read the directory the same way.
 */
export function resolutionVectors(doc: HelplinesDocument): HelplineVector[] {
  const out: HelplineVector[] = [];
  for (const country of Object.keys(doc.countries).sort()) {
    for (const minor of [false, true]) out.push({ country, minor, dials: resolveHelplines(doc, country, minor).map((l) => l.dial) });
  }
  out.push({ country: UNLISTED_REGION, minor: false, dials: [] });
  return out;
}

export interface HelplinesDiff {
  from: number | null;
  /** Line ids added / removed / changed (number, dial, audience or a name). */
  added: string[];
  removed: string[];
  changed: string[];
  /** Regions no longer listed. */
  countriesRemoved: string[];
  /** Dial strings phones list today that the new version no longer lists (per region and audience). */
  numbersRemoved: number;
}

const lineKey = (country: string, l: HelplineLine): string =>
  JSON.stringify([country, l.number, l.dial, l.audience, Object.entries(l.names).sort(([a], [b]) => a.localeCompare(b))]);

export function diffHelplines(from: HelplinesDocument, to: HelplinesDocument, fromVersion: number | null): HelplinesDiff {
  const flat = (d: HelplinesDocument): Map<string, string> =>
    new Map(Object.entries(d.countries).flatMap(([c, lines]) => lines.map((l): [string, string] => [l.id, lineKey(c, l)])));
  const before = flat(from);
  const after = flat(to);
  let numbersRemoved = 0;
  for (const country of Object.keys(from.countries)) {
    for (const minor of [false, true]) {
      const now = new Set(resolveHelplines(to, country, minor).map((l) => l.dial));
      numbersRemoved += resolveHelplines(from, country, minor).filter((l) => !now.has(l.dial)).length;
    }
  }
  return {
    from: fromVersion,
    added: [...after.keys()].filter((id) => !before.has(id)),
    removed: [...before.keys()].filter((id) => !after.has(id)),
    changed: [...after.keys()].filter((id) => before.has(id) && before.get(id) !== after.get(id)),
    countriesRemoved: Object.keys(from.countries).filter((c) => !(c in to.countries)),
    numbersRemoved,
  };
}

/** Lines in a document (the console's version list). */
export const lineCount = (d: HelplinesDocument): number => Object.values(d.countries).reduce((n, l) => n + l.length, 0);
