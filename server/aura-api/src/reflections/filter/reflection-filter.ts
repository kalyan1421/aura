import { normalizeForLexicon } from '../../remote-config/lexicon/normalize';
import { REFLECTION_FILTER_DATA } from './reflection-filter.data';

/**
 * The reflection text rules (contracts/safety/reflection_filter.v1.json + README "Reflection filter"; PRD F6 "Not
 * allowed", F9 reflection pipeline steps 1–2). A line-by-line twin of the app's Dart implementation
 * (apps/mobile/lib/src/features/reflections/reflection_filter.dart): both must give the verdict of every case in
 * contracts/safety/reflection_filter.vectors.json.
 *
 * - `contact`: links, emails / UPI ids, @handles, "app: handle", phone numbers (spaced, dashed, +91, Telugu /
 *   Devanagari / fullwidth digits, spelled out in English, Telugu, Tenglish, Hindi or Hinglish words) and
 *   contact-swap phrases. The app blocks these before anything leaves the phone; the server repeats the check.
 * - `grooming`: asking someone's age, school, city or photos, secrecy, meeting up, moving to another app. Server-only
 *   routing to the Minors & grooming lane (the app does not block on it).
 *
 * `strict` (an under-18 involved, or the Telugu / Hindi pools): the phone-digit threshold drops from 7 to 6.
 * Text is never logged; `hits` holds rule ids only.
 */
export type ContactVerdict = 'none' | 'contact_details' | 'link';

export interface FilterResult {
  contact: ContactVerdict;
  grooming: boolean;
  /** Rule ids that matched (`link`, `email_or_upi`, `handle`, `app_handle`, `phone_digits`, `spelled_number`, phrase ids). */
  hits: string[];
}

interface PhraseEntry {
  id: string;
  forms: string[];
}

interface CompiledPhrases {
  /** Latin forms as word lists (also indexed joined into one word). */
  latin: Array<{ id: string; words: string[] }>;
  /** Other-script forms, matched as substrings. */
  script: Array<{ id: string; text: string }>;
}

const ASCII = /^[\x00-\x7f]*$/;
const LATIN_WORD = /[a-z0-9]+/g;
const TOKEN = /[\p{L}\p{M}\p{N}]+/gu;

const D = REFLECTION_FILTER_DATA;
const TLDS = D.tlds.join('|');
const APPS = D.contactApps.join('|');

const LINK_RULES: readonly RegExp[] = [
  /(https?:\/\/|www\.)/,
  new RegExp(`(^|[^a-z0-9@._%+-])[a-z0-9-]+\\.(${TLDS})\\b`),
  /\b[a-z0-9-]+\s*dot\s*(com|net|org)\b/,
];
const EMAIL_OR_UPI = /[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*/;
const HANDLE = /(^|[^a-z0-9._%+-])@[a-z0-9_.]+/;
const APP_HANDLE = new RegExp(`(^|[^a-z0-9])(${APPS})\\s*[:=\\-]\\s*@?[a-z0-9_.]+`);
const DATE = /(?<![0-9])[0-9]{1,2}[/.-][0-9]{1,2}[/.-]([0-9]{4}|[0-9]{2})(?![0-9])/g;
const DIGIT_RUN = /[0-9][0-9\s().\-/]*[0-9]|[0-9]/g;

/** Telugu (౦–౯), Devanagari (०–९) and fullwidth (０–９) digits read as 0–9; fullwidth ＠ as @. */
function asciiDigits(s: string): string {
  let out = '';
  for (const ch of s) {
    const cp = ch.codePointAt(0) as number;
    if (cp >= 0x0c66 && cp <= 0x0c6f) out += String.fromCharCode(0x30 + cp - 0x0c66);
    else if (cp >= 0x0966 && cp <= 0x096f) out += String.fromCharCode(0x30 + cp - 0x0966);
    else if (cp >= 0xff10 && cp <= 0xff19) out += String.fromCharCode(0x30 + cp - 0xff10);
    else if (cp === 0xff20) out += '@';
    else out += ch;
  }
  return out;
}

/** The text as the rules see it: the crisis lexicon's normalization, then ASCII digits. */
export function normalizeForFilter(text: string): string {
  return asciiDigits(normalizeForLexicon(text));
}

function compile(entries: ReadonlyArray<{ id: string; phrase: string; variants: readonly string[] }>): CompiledPhrases {
  const out: CompiledPhrases = { latin: [], script: [] };
  const list: PhraseEntry[] = entries.map((e) => ({ id: e.id, forms: [e.phrase, ...e.variants] }));
  for (const e of list) {
    for (const form of e.forms) {
      const n = normalizeForFilter(form).replace(/\n/g, ' ');
      if (n.length === 0) continue;
      if (!ASCII.test(n)) {
        out.script.push({ id: e.id, text: n });
        continue;
      }
      const words = n.match(LATIN_WORD) ?? [];
      if (words.length === 0) continue;
      out.latin.push({ id: e.id, words });
      if (words.length > 1) out.latin.push({ id: e.id, words: [words.join('')] });
    }
  }
  return out;
}

const CONTACT_PHRASES = compile(D.contactPhrases);
const GROOMING_PHRASES = compile(D.groomingPhrases);
const NUMBER_WORDS: ReadonlySet<string> = new Set(
  Object.values(D.numberWords)
    .flat()
    .map((w) => normalizeForFilter(w)),
);
const MULTIPLIERS: ReadonlyMap<string, number> = new Map(Object.entries(D.multipliers).map(([k, v]) => [normalizeForFilter(k), v]));

function phraseHits(normalized: string, phrases: CompiledPhrases): string[] {
  const hits = new Set<string>();
  const words = normalized.match(LATIN_WORD) ?? [];
  for (const p of phrases.latin) {
    const n = p.words.length;
    for (let i = 0; i + n <= words.length; i++) {
      let ok = true;
      for (let k = 0; k < n && ok; k++) ok = words[i + k] === p.words[k];
      if (ok) {
        hits.add(p.id);
        break;
      }
    }
  }
  const flat = normalized.replace(/\n/g, ' ');
  for (const p of phrases.script) if (flat.includes(p.text)) hits.add(p.id);
  return [...hits];
}

/** Longest digit count written as a run of digits with the separators people use (dates removed first). */
function hasPhoneDigits(normalized: string, threshold: number): boolean {
  const t = normalized.replace(DATE, ' ');
  for (const m of t.matchAll(DIGIT_RUN)) {
    if (m[0].replace(/[^0-9]/g, '').length >= threshold) return true;
  }
  return false;
}

/**
 * A run of consecutive tokens that are number words (any of the five languages), digit groups or multipliers
 * ("double nine" = 2 digits) that spells at least `threshold` digits and contains at least one word.
 */
function hasSpelledNumber(normalized: string, threshold: number): boolean {
  let run = 0;
  let hasWord = false;
  let mult = 1;
  for (const m of normalized.matchAll(TOKEN)) {
    const tok = m[0];
    if (/^[0-9]+$/.test(tok)) {
      run += mult > 1 && tok.length === 1 ? mult : tok.length;
      mult = 1;
    } else if (NUMBER_WORDS.has(tok)) {
      run += mult;
      mult = 1;
      hasWord = true;
    } else if (MULTIPLIERS.has(tok)) {
      mult = MULTIPLIERS.get(tok) as number;
      hasWord = true;
      continue;
    } else {
      run = 0;
      hasWord = false;
      mult = 1;
      continue;
    }
    if (hasWord && run >= threshold) return true;
  }
  return false;
}

export function checkReflectionText(text: string, opts: { strict?: boolean } = {}): FilterResult {
  const n = normalizeForFilter(text);
  const threshold = opts.strict ? D.phoneDigits.strict : D.phoneDigits.standard;
  const hits: string[] = [];
  let link = false;
  let contact = false;
  if (LINK_RULES.some((r) => r.test(n))) {
    link = true;
    hits.push('link');
  }
  if (EMAIL_OR_UPI.test(n)) {
    contact = true;
    hits.push('email_or_upi');
  }
  if (HANDLE.test(n)) {
    contact = true;
    hits.push('handle');
  }
  if (APP_HANDLE.test(n)) {
    contact = true;
    hits.push('app_handle');
  }
  if (hasPhoneDigits(n, threshold)) {
    contact = true;
    hits.push('phone_digits');
  }
  if (hasSpelledNumber(n, threshold)) {
    contact = true;
    hits.push('spelled_number');
  }
  const contactPhrases = phraseHits(n, CONTACT_PHRASES);
  if (contactPhrases.length) {
    contact = true;
    hits.push(...contactPhrases);
  }
  const groomingPhrases = phraseHits(n, GROOMING_PHRASES);
  hits.push(...groomingPhrases);
  return {
    contact: link ? 'link' : contact ? 'contact_details' : 'none',
    grooming: groomingPhrases.length > 0,
    hits,
  };
}

export const REFLECTION_MAX_CHARS: number = D.maxChars;
export const REFLECTION_FILTER_VERSION: number = D.version;
