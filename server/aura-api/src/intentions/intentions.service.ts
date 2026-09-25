import { createHash } from 'node:crypto';
import { HttpStatus, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { auditConsole } from '../admin/admin-audit';
import { AdminDb } from '../admin/admin-db';
import { AdminErrors } from '../admin/admin-errors';
import { reasonCode } from '../admin/admin.schemas';
import { parseOrThrow } from '../common/zod';
import type { Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { pickIntention } from '../rooms/lantern-rules';
import { localDate } from '../rules';
import {
  INTENTION_LOCALES,
  INTENTION_MAX_CHARS,
  describeIntentionProblem,
  lintIntentionTexts,
  type IntentionLocale,
  type IntentionTexts,
} from './intention-lint';

/**
 * Tonight's intention list per language pool (PRD 19 "Configuration": "the Tonight's intention list per language";
 * PRD 06b "Tonight's intention"; contracts/api/v1-rooms.md §1.9–1.10; migration 20261005000025).
 * - Console (`/admin/intentions*`): the Owner adds a preset to a pool, words it in all five languages, reorders,
 *   retires and restores it; a Moderator reads. Every change is audited (hash-chained `moderation_actions`, same
 *   transaction) with a reason code; the audit holds keys, pools and which languages changed, never the words.
 * - Words are linted (intention-lint.ts): no guilt, clinical or scoring words, no treatment claims, no quadrant or
 *   theme names, no links or contacts, one short line in the right script.
 * - Retire, never delete: a retired preset leaves the rotation for rooms whose Lantern Hour starts after the change;
 *   a room that already pinned it tonight keeps it (write-once `rooms.intention_key`), and its words stay served.
 * - App (`GET /v1/intentions`, public): every key's words (retired ones included), so a phone can show a preset its
 *   build doesn't bundle.
 * Console reads and writes run as `aura_admin` (AdminDb); the public read as the API's own role.
 */
export const INTENTION_POOLS = ['en', 'te', 'hi'] as const;
export type IntentionPool = (typeof INTENTION_POOLS)[number];

/** How many nights the console previews. */
export const ROTATION_PREVIEW_NIGHTS = 14;
/** The preview's calendar (the south_asia region clock; other regions' nights run on the same date sequence). */
export const PREVIEW_TIMEZONE = 'Asia/Kolkata';

const KEY_RE = /^[a-z][a-z0-9_]{1,47}$/;

const line = z
  .string()
  .transform((s) => s.normalize('NFC').trim())
  .pipe(z.string().min(1, 'is empty').max(INTENTION_MAX_CHARS * 2));
const textsSchema = z.object({ en: line, te: line, 'te-Latn': line, hi: line, 'hi-Latn': line }).strict();

const createSchema = z
  .object({
    pool: z.enum(INTENTION_POOLS),
    key: z.string().regex(KEY_RE, 'must be a key ([a-z][a-z0-9_], 2–48 characters)'),
    texts: textsSchema.optional(),
    position: z.number().int().min(0).max(100_000).optional(),
    enabled: z.boolean().optional(),
    reasonCode,
  })
  .strict();

const wordsSchema = z.object({ texts: textsSchema, reasonCode }).strict();

const updateSchema = z
  .object({
    enabled: z.boolean().optional(),
    position: z.number().int().min(0).max(100_000).optional(),
    reasonCode,
  })
  .strict()
  .refine((b) => b.enabled !== undefined || b.position !== undefined, 'give enabled and/or position');

export interface PresetView {
  pool: IntentionPool;
  key: string;
  position: number;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
  /** Rooms showing this preset for a night that started in the last 24 h (a room count, never who). */
  inUseTonight: number;
}

export interface WordsView {
  key: string;
  texts: IntentionTexts;
  updatedAt: string;
  /** Pools the key is a preset in (enabled or retired). */
  pools: IntentionPool[];
}

export interface RotationNight {
  /** Region-local date of the night (YYYY-MM-DD). */
  date: string;
  key: string | null;
}

export interface IntentionsOverview {
  locales: readonly IntentionLocale[];
  maxChars: number;
  previewTimezone: string;
  pools: Array<{ pool: IntentionPool; presets: PresetView[]; rotation: RotationNight[] }>;
  words: WordsView[];
  /** The latest changes to the list (newest first), from the audit log. */
  history: Array<{ id: number; createdAt: string; actor: string; action: string; reasonCode: string | null; detail: Record<string, unknown> }>;
}

export interface AppIntentionCopy {
  /** Changes whenever any key's words change (also the ETag). */
  version: string;
  intentions: Array<{ key: string; texts: IntentionTexts }>;
}

/** 422 with the lint's lines (served with `details`, like the lexicon's refusals). */
export class IntentionRejectedError extends Error {
  readonly status = HttpStatus.UNPROCESSABLE_ENTITY;
  readonly code = 'intention_words_rejected';
  constructor(readonly details: string[]) {
    super('These words can’t be used for an intention.');
    this.name = 'IntentionRejectedError';
  }
}

interface PresetRow {
  language_pool: IntentionPool;
  key: string;
  position: number;
  enabled: boolean;
  created_at: Date;
  updated_at: Date;
}

interface TextRow {
  key: string;
  text_en: string;
  text_te: string;
  text_te_latn: string;
  text_hi: string;
  text_hi_latn: string;
  updated_at: Date;
}

const TEXT_COLS: Readonly<Record<IntentionLocale, keyof TextRow>> = {
  en: 'text_en',
  te: 'text_te',
  'te-Latn': 'text_te_latn',
  hi: 'text_hi',
  'hi-Latn': 'text_hi_latn',
};

const textsOf = (r: TextRow): IntentionTexts => ({
  en: r.text_en,
  te: r.text_te,
  'te-Latn': r.text_te_latn,
  hi: r.text_hi,
  'hi-Latn': r.text_hi_latn,
});

const iso = (d: Date): string => new Date(d).toISOString();

/** The next `nights` region-local dates from `now` (today first). */
export function previewDates(now: Date, nights = ROTATION_PREVIEW_NIGHTS, tz = PREVIEW_TIMEZONE): string[] {
  const first = Date.parse(`${localDate(now, tz)}T00:00:00Z`);
  return Array.from({ length: nights }, (_, i) => new Date(first + i * 86_400_000).toISOString().slice(0, 10));
}

/** Which preset each night gets, with the pool's enabled keys in rotation order (the rule rooms use: lantern-rules). */
export function rotationPreview(enabledKeys: readonly string[], dates: readonly string[]): RotationNight[] {
  return dates.map((date) => ({ date, key: pickIntention(enabledKeys, date) }));
}

/** Lint → 422 with one line per problem. */
function assertWords(texts: IntentionTexts): void {
  const problems = lintIntentionTexts(texts);
  if (problems.length > 0) throw new IntentionRejectedError(problems.map(describeIntentionProblem));
}

const ACTIVE_ROOMS_SQL = `
  select r.intention_key as key, r.language_pool as pool, count(*)::int as n
    from public.rooms r
   where r.intention_key is not null and r.lantern_hour_at > now() - interval '24 hours'
   group by 1, 2`;

@Injectable()
export class IntentionsService {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly db: DbService,
  ) {}

  // ------------------------------------------------------------------ console reads (Owner + Moderator)

  async overview(now = new Date()): Promise<IntentionsOverview> {
    return this.adminDb.withTx(async (tx) => {
      const presets = (await tx.query<PresetRow>(
        `select language_pool, key, position, enabled, created_at, updated_at
           from public.room_intention_presets order by language_pool, position, key`,
      )).rows;
      const texts = (await tx.query<TextRow>(
        'select key, text_en, text_te, text_te_latn, text_hi, text_hi_latn, updated_at from public.room_intention_texts order by key',
      )).rows;
      const inUse = new Map((await tx.query<{ key: string; pool: string; n: number }>(ACTIVE_ROOMS_SQL)).rows.map((r) => [`${r.pool}:${r.key}`, r.n]));
      const dates = previewDates(now);
      const pools = INTENTION_POOLS.map((pool) => {
        const rows = presets.filter((p) => p.language_pool === pool);
        return {
          pool,
          presets: rows.map((p) => this.presetView(p, inUse.get(`${pool}:${p.key}`) ?? 0)),
          rotation: rotationPreview(
            rows.filter((p) => p.enabled).map((p) => p.key),
            dates,
          ),
        };
      });
      const words = texts.map((t) => ({
        key: t.key,
        texts: textsOf(t),
        updatedAt: iso(t.updated_at),
        pools: presets.filter((p) => p.key === t.key).map((p) => p.language_pool),
      }));
      const history = (await tx.query<{ id: string; created_at: Date; actor: string; action: string; reason_code: string | null; detail: Record<string, unknown> }>(
        `select a.id, a.created_at, coalesce(s.display_name, a.actor) as actor, a.action, a.reason_code, a.detail
           from public.moderation_actions a
           left join public.admin_staff s on a.actor = 'staff:' || s.staff_id::text
          where a.action like 'intention\\_%'
          order by a.id desc limit 20`,
      )).rows.map((r) => ({ id: Number(r.id), createdAt: iso(r.created_at), actor: r.actor, action: r.action, reasonCode: r.reason_code, detail: r.detail }));
      return { locales: INTENTION_LOCALES, maxChars: INTENTION_MAX_CHARS, previewTimezone: PREVIEW_TIMEZONE, pools, words, history };
    });
  }

  // ------------------------------------------------------------------ console writes (Owner, audited)

  /** Adds a preset to a pool: a new key needs its words (all five languages); an existing key reuses its words. */
  async create(actor: string, body: unknown): Promise<{ preset: PresetView; newWords: boolean }> {
    const b = parseOrThrow(createSchema, body);
    if (b.texts) assertWords(b.texts);
    return this.adminDb.withTx(async (tx) => {
      const existing = (await tx.query<TextRow>('select * from public.room_intention_texts where key = $1 for update', [b.key])).rows[0];
      if (existing && b.texts) {
        throw AdminErrors.conflict('intention_key_exists', 'That key already has words. Add it without words, or edit its words.');
      }
      if (!existing && !b.texts) throw AdminErrors.badRequest('A new key needs its words in all five languages.', 'intention_words_required');
      if (!existing && b.texts) {
        await tx.query(
          `insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
           values ($1, $2, $3, $4, $5, $6)`,
          [b.key, b.texts.en, b.texts.te, b.texts['te-Latn'], b.texts.hi, b.texts['hi-Latn']],
        );
      }
      const enabled = b.enabled ?? true;
      if (existing && enabled) assertWords(textsOf(existing)); // e.g. a placeholder the migration made
      const position =
        b.position ??
        (await tx.query<{ next: number }>(
          'select coalesce(max(position), 0) + 10 as next from public.room_intention_presets where language_pool = $1',
          [b.pool],
        )).rows[0].next;
      const inserted = await tx.query<PresetRow>(
        `insert into public.room_intention_presets (language_pool, key, position, enabled) values ($1, $2, $3, $4)
         on conflict do nothing
         returning language_pool, key, position, enabled, created_at, updated_at`,
        [b.pool, b.key, position, enabled],
      );
      const row = inserted.rows[0];
      if (!row) throw AdminErrors.conflict('intention_preset_exists', 'That key is already in this pool’s list (restore it if it is retired).');
      await auditConsole(tx, actor, {
        action: 'intention_preset_add',
        reasonCode: b.reasonCode,
        detail: { pool: b.pool, key: b.key, position, enabled, newWords: !existing },
      });
      return { preset: this.presetView(row, 0), newWords: !existing };
    });
  }

  /** Rewords a key in all five languages (every pool using the key; rooms showing it tonight get the new words). */
  async editWords(actor: string, key: string, body: unknown): Promise<{ words: WordsView; changed: IntentionLocale[] }> {
    if (!KEY_RE.test(key)) throw AdminErrors.notFound('That intention does not exist.');
    const b = parseOrThrow(wordsSchema, body);
    assertWords(b.texts);
    return this.adminDb.withTx(async (tx) => {
      const before = (await tx.query<TextRow>('select * from public.room_intention_texts where key = $1 for update', [key])).rows[0];
      if (!before) throw AdminErrors.notFound('That intention does not exist.');
      const changed = INTENTION_LOCALES.filter((l) => before[TEXT_COLS[l]] !== b.texts[l]);
      let row = before;
      if (changed.length > 0) {
        row = (await tx.query<TextRow>(
          `update public.room_intention_texts
              set text_en = $2, text_te = $3, text_te_latn = $4, text_hi = $5, text_hi_latn = $6
            where key = $1
            returning key, text_en, text_te, text_te_latn, text_hi, text_hi_latn, updated_at`,
          [key, b.texts.en, b.texts.te, b.texts['te-Latn'], b.texts.hi, b.texts['hi-Latn']],
        )).rows[0];
        await auditConsole(tx, actor, { action: 'intention_words_edit', reasonCode: b.reasonCode, detail: { key, changed } });
      }
      const pools = (await tx.query<{ language_pool: IntentionPool }>(
        'select language_pool from public.room_intention_presets where key = $1 order by language_pool',
        [key],
      )).rows.map((r) => r.language_pool);
      return { words: { key, texts: textsOf(row), updatedAt: iso(row.updated_at), pools }, changed };
    });
  }

  /**
   * Retire (enabled false), restore (true) and/or move (position) one preset of a pool. Retiring takes it out of the
   * rotation for rooms whose Lantern Hour starts later; rooms showing it tonight keep it. The last enabled preset of a
   * pool can't be retired (switch Tonight's intention off with its kill switch instead). Restoring re-checks its words.
   */
  async update(actor: string, pool: string, key: string, body: unknown): Promise<{ preset: PresetView; previous: { enabled: boolean; position: number } }> {
    if (!(INTENTION_POOLS as readonly string[]).includes(pool) || !KEY_RE.test(key)) throw AdminErrors.notFound('That preset does not exist.');
    const b = parseOrThrow(updateSchema, body);
    return this.adminDb.withTx(async (tx) => {
      // Lock the pool's list: two retirements at once can't leave it empty.
      const rows = (await tx.query<PresetRow>(
        `select language_pool, key, position, enabled, created_at, updated_at from public.room_intention_presets
          where language_pool = $1 order by position, key for update`,
        [pool],
      )).rows;
      const before = rows.find((r) => r.key === key);
      if (!before) throw AdminErrors.notFound('That preset does not exist.');
      const enabled = b.enabled ?? before.enabled;
      const position = b.position ?? before.position;
      if (before.enabled && !enabled && rows.filter((r) => r.enabled).length <= 1) {
        throw AdminErrors.conflict(
          'last_intention',
          'This is the pool’s last intention in rotation. Add or restore another first, or switch Tonight’s intention off with its kill switch.',
        );
      }
      if (!before.enabled && enabled) {
        const words = (await tx.query<TextRow>('select * from public.room_intention_texts where key = $1', [key])).rows[0];
        if (words) assertWords(textsOf(words));
      }
      if (enabled === before.enabled && position === before.position) {
        return { preset: this.presetView(before, await this.inUse(tx, pool, key)), previous: { enabled: before.enabled, position: before.position } };
      }
      const row = (await tx.query<PresetRow>(
        `update public.room_intention_presets set enabled = $3, position = $4
          where language_pool = $1 and key = $2
          returning language_pool, key, position, enabled, created_at, updated_at`,
        [pool, key, enabled, position],
      )).rows[0];
      const action = enabled !== before.enabled ? (enabled ? 'intention_preset_restore' : 'intention_preset_retire') : 'intention_preset_move';
      const inUseTonight = await this.inUse(tx, pool, key);
      await auditConsole(tx, actor, {
        action,
        reasonCode: b.reasonCode,
        detail: { pool, key, enabled, position, previousEnabled: before.enabled, previousPosition: before.position, inUseTonight },
      });
      return { preset: this.presetView(row, inUseTonight), previous: { enabled: before.enabled, position: before.position } };
    });
  }

  // ------------------------------------------------------------------ app (public)

  /** Every key's words (retired keys too: a room may still show one tonight). */
  async appCopy(): Promise<AppIntentionCopy> {
    const rows = (await this.db.query<TextRow>(
      'select key, text_en, text_te, text_te_latn, text_hi, text_hi_latn, updated_at from public.room_intention_texts order by key',
    )).rows;
    const intentions = rows.map((r) => ({ key: r.key, texts: textsOf(r) }));
    const version = createHash('sha256').update(JSON.stringify(intentions)).digest('base64url').slice(0, 16);
    return { version, intentions };
  }

  // ------------------------------------------------------------------ helpers

  private async inUse(tx: Tx, pool: string, key: string): Promise<number> {
    const r = await tx.query<{ n: number }>(
      `select count(*)::int as n from public.rooms r
        where r.language_pool = $1 and r.intention_key = $2 and r.lantern_hour_at > now() - interval '24 hours'`,
      [pool, key],
    );
    return r.rows[0]?.n ?? 0;
  }

  private presetView(p: PresetRow, inUseTonight: number): PresetView {
    return {
      pool: p.language_pool,
      key: p.key,
      position: p.position,
      enabled: p.enabled,
      createdAt: iso(p.created_at),
      updatedAt: iso(p.updated_at),
      inUseTonight,
    };
  }
}
