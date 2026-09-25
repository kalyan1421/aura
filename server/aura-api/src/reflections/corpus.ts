import { createCipheriv, createDecipheriv, randomBytes, randomUUID } from 'node:crypto';
import type { Queryable } from '../db/db';
import { generateDataKey, unwrapDataKey, wrapDataKey } from '../keys/envelope';
import { anyMinor } from '../safety/safety.queries';
import type { RejectReason } from './decide';

/**
 * REQ-SAFE-16 — the de-identified moderation corpus (PRD 06c F9 "Training corpus"; migration 20261005000031;
 * contracts/api/v1-reflections.md §7). Final decisions on reflections are kept as text + language + label + ISO week,
 * with no link to any person, room or reflection, for a future in-house classifier. "Privacy-notice disclosure plus
 * Settings opt-out": on by default, `user_consents` purpose `moderation_corpus`.
 *
 * Never enters it (the calm, privacy-preserving reading of the PRD; recorded in docs/status/pending.md):
 *  - under-18 authors (PRD `[ASSUMPTION]`), by stored DOB or the platform signal (`user_is_minor`);
 *  - authors who opted out — checked at the moment of each decision, so their later items never enter it;
 *  - crisis-diverted text (DS-7: crisis records are aggregate only);
 *  - Minors & grooming items ("stay in the evidence store, never the F9 training corpus");
 *  - contact details, links and personal questions (the text itself carries personal data or a grooming ask);
 *  - held items until a human decides.
 * Best effort: a failure here never changes a moderation outcome (callers catch and count it).
 */
export const CORPUS_CONSENT_PURPOSE = 'moderation_corpus';
/** The privacy-notice version the default (opted in) and each change refer to. */
export const CORPUS_POLICY_VERSION = 'privacy-2026-10';

export const CORPUS_LANGUAGES = ['en', 'te', 'te-Latn', 'hi', 'hi-Latn'] as const;
export type CorpusLanguage = (typeof CORPUS_LANGUAGES)[number];
export type CorpusLabel =
  | 'allow'
  | 'reject_hurtful'
  | 'reject_sexual'
  | 'reject_other'
  | 'removed_hurtful'
  | 'removed_sexual'
  | 'removed_other';
export type CorpusSource = 'auto' | 'human';

/** Reject reasons whose text may be kept: the others carry personal data (contact, link) or a grooming ask. */
const KEEPABLE_REJECTS: ReadonlySet<RejectReason> = new Set(['hurtful', 'sexual', 'other']);

/**
 * The label for a final decision, or null when the item must not enter the corpus. Pure (unit-tested).
 * `removed`: a published reflection a moderator removed after reports.
 */
export function corpusLabel(
  outcome: 'published' | 'rejected' | 'removed' | string,
  rejectReason: RejectReason | null,
  opts: { minorSafety?: boolean } = {},
): CorpusLabel | null {
  if (opts.minorSafety) return null;
  if (outcome === 'published') return 'allow';
  if (outcome !== 'rejected' && outcome !== 'removed') return null; // held, crisis_diverted, deleted, expired…
  const reason = rejectReason ?? 'other';
  if (!KEEPABLE_REJECTS.has(reason)) return null;
  return `${outcome === 'rejected' ? 'reject' : 'removed'}_${reason}` as CorpusLabel;
}

const TELUGU = /[ఀ-౿]/u;
const DEVANAGARI = /[ऀ-ॿ]/u;

/** The language of the text as written: the pool's language, in its script (romanized → `-Latn`). */
export function corpusLanguage(pool: string, text: string): CorpusLanguage {
  if (TELUGU.test(text)) return 'te';
  if (DEVANAGARI.test(text)) return 'hi';
  if (pool === 'te') return 'te-Latn';
  if (pool === 'hi') return 'hi-Latn';
  return 'en';
}

/** The Monday (UTC) of `d`'s ISO week, `YYYY-MM-DD` — the only time a corpus row keeps. */
export function isoWeekStart(d: Date): string {
  const day = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dow = day.getUTCDay() || 7; // Sunday → 7
  day.setUTCDate(day.getUTCDate() - (dow - 1));
  return day.toISOString().slice(0, 10);
}

// ------------------------------------------------------------------------------------------------ sealing
const IV = 12;
const TAG = 16;
const keyContext = (id: string): string => `corpus:${id}`;
const aad = (id: string): Buffer => Buffer.from(`aura:corpus:v1:${id}`, 'utf8');

export function sealCorpusText(masterKey: Buffer, id: string, text: string): { textCt: string; textKey: string } {
  const dek = generateDataKey();
  try {
    const iv = randomBytes(IV);
    const c = createCipheriv('aes-256-gcm', dek, iv);
    c.setAAD(aad(id));
    const ct = Buffer.concat([c.update(Buffer.from(text, 'utf8')), c.final()]);
    return { textCt: Buffer.concat([iv, ct, c.getAuthTag()]).toString('base64'), textKey: wrapDataKey(masterKey, dek, keyContext(id)) };
  } finally {
    dek.fill(0);
  }
}

/** For the Owner's future training export (and tests). Throws on tamper or a row moved to another id. */
export function openCorpusText(masterKey: Buffer, id: string, sealed: { textCt: string; textKey: string }): string {
  const dek = unwrapDataKey(masterKey, sealed.textKey, keyContext(id));
  try {
    const buf = Buffer.from(sealed.textCt, 'base64');
    const d = createDecipheriv('aes-256-gcm', dek, buf.subarray(0, IV));
    d.setAAD(aad(id));
    d.setAuthTag(buf.subarray(buf.length - TAG));
    return Buffer.concat([d.update(buf.subarray(IV, buf.length - TAG)), d.final()]).toString('utf8');
  } finally {
    dek.fill(0);
  }
}

// ------------------------------------------------------------------------------------------------ consent
/** On by default (privacy notice); the latest consent event for the purpose decides. */
export async function corpusConsent(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query<{ withdrawn_at: Date | null }>(
    `select withdrawn_at from public.user_consents where user_id = $1 and purpose = $2
      order by coalesce(withdrawn_at, granted_at) desc, granted_at desc limit 1`,
    [userId, CORPUS_CONSENT_PURPOSE],
  );
  const last = r.rows[0];
  return !last || last.withdrawn_at === null;
}

/** Records the choice as a consent event (append-only history, like the echo opt-out). Caller holds the user lock. */
export async function setCorpusConsent(q: Queryable, userId: string, enabled: boolean): Promise<boolean> {
  const current = await corpusConsent(q, userId);
  if (enabled && !current) {
    await q.query(
      `insert into public.user_consents (user_id, purpose, policy_version, granted_at) values ($1, $2, $3, clock_timestamp())`,
      [userId, CORPUS_CONSENT_PURPOSE, CORPUS_POLICY_VERSION],
    );
  } else if (!enabled && current) {
    const r = await q.query(
      `update public.user_consents set withdrawn_at = clock_timestamp() where user_id = $1 and purpose = $2 and withdrawn_at is null`,
      [userId, CORPUS_CONSENT_PURPOSE],
    );
    if (!r.rowCount) {
      // On by default (no row yet): record the opt-out itself.
      await q.query(
        `insert into public.user_consents (user_id, purpose, policy_version, granted_at, withdrawn_at)
         values ($1, $2, $3, clock_timestamp(), clock_timestamp())`,
        [userId, CORPUS_CONSENT_PURPOSE, CORPUS_POLICY_VERSION],
      );
    }
  }
  return corpusConsent(q, userId);
}

// ------------------------------------------------------------------------------------------------ feed
export interface CorpusItem {
  authorId: string;
  languagePool: string;
  text: string;
  label: CorpusLabel | null;
  source: CorpusSource;
  decidedAt: Date;
}

/**
 * Adds one decision to the corpus when it may enter it (see the header). Returns whether a row was written. Runs on
 * the service-role connection (never as `aura_admin`). The author id is used only for the consent and age checks.
 */
export async function feedCorpus(q: Queryable, masterKey: Buffer, item: CorpusItem): Promise<boolean> {
  if (!item.label || !item.text.trim()) return false;
  if (await anyMinor(q, [item.authorId])) return false;
  if (!(await corpusConsent(q, item.authorId))) return false;
  const id = randomUUID();
  const sealed = sealCorpusText(masterKey, id, item.text);
  await q.query(
    `insert into public.moderation_corpus (id, language, label, source, week, text_ct, text_key)
     values ($1, $2, $3, $4, $5::date, $6, $7)`,
    [id, corpusLanguage(item.languagePool, item.text), item.label, item.source, isoWeekStart(item.decidedAt), sealed.textCt, sealed.textKey],
  );
  return true;
}
