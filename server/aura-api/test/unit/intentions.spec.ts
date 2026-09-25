import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  INTENTION_LOCALES,
  describeIntentionProblem,
  lintIntentionText,
  lintIntentionTexts,
  type IntentionLocale,
  type IntentionTexts,
} from '../../src/intentions/intention-lint';
import { IntentionRejectedError, IntentionsService, previewDates, rotationPreview } from '../../src/intentions/intentions.service';
import { pickIntention } from '../../src/rooms/lantern-rules';

const ARB_DIR = join(__dirname, '../../../../apps/mobile/lib/l10n');
const ARB_FILE: Readonly<Record<IntentionLocale, string>> = {
  en: 'app_en.arb',
  te: 'app_te.arb',
  'te-Latn': 'app_te_Latn.arb',
  hi: 'app_hi.arb',
  'hi-Latn': 'app_hi_Latn.arb',
};

/** The intentions every app build bundles (`rooms_intention_<key>`), per locale. */
function bundled(): Map<string, Partial<Record<IntentionLocale, string>>> {
  const out = new Map<string, Partial<Record<IntentionLocale, string>>>();
  for (const locale of INTENTION_LOCALES) {
    const arb = JSON.parse(readFileSync(join(ARB_DIR, ARB_FILE[locale]), 'utf8')) as Record<string, unknown>;
    for (const [k, v] of Object.entries(arb)) {
      if (!k.startsWith('rooms_intention_') || typeof v !== 'string') continue;
      const key = k.slice('rooms_intention_'.length);
      out.set(key, { ...out.get(key), [locale]: v });
    }
  }
  return out;
}

const good: IntentionTexts = {
  en: 'Put the phone in another room',
  te: 'ఫోన్ వేరే గదిలో పెడతాను',
  'te-Latn': 'Phone vere gadilo pedataanu',
  hi: 'फ़ोन दूसरे कमरे में',
  'hi-Latn': 'Phone doosre kamre mein',
};

describe('Tonight’s intention words lint', () => {
  it('passes every intention the app bundles, in all five languages (the migration seeds these words)', () => {
    const b = bundled();
    expect([...b.keys()].sort()).toEqual(
      ['gentle_with_myself', 'one_kind_thought', 'phone_down_10', 'slow_breaths', 'sleep_before_midnight', 'water_before_bed'].sort(),
    );
    for (const [key, texts] of b) {
      const problems = lintIntentionTexts(texts);
      expect({ key, problems: problems.map(describeIntentionProblem) }).toEqual({ key, problems: [] });
    }
  });

  it('migration 20261005000025 seeds the bundled words, word for word', () => {
    const sql = readFileSync(join(__dirname, '../../../../supabase/migrations/20261005000025_gaps_b.sql'), 'utf8');
    const block = sql.slice(sql.indexOf('insert into public.room_intention_texts'), sql.indexOf('on conflict (key) do nothing'));
    const tuples = [...block.matchAll(/\(\s*'([a-z0-9_]+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)',\s*'([^']+)'\s*\)/g)];
    const b = bundled();
    expect(tuples).toHaveLength(b.size);
    for (const [, key, en, te, teLatn, hi, hiLatn] of tuples) {
      expect({ key, en, te, 'te-Latn': teLatn, hi, 'hi-Latn': hiLatn }).toEqual({ key, ...b.get(key) });
    }
  });

  it('passes calm, well-formed words', () => {
    expect(lintIntentionTexts(good)).toEqual([]);
  });

  it('needs every language', () => {
    const { hi: _hi, ...partial } = good;
    expect(lintIntentionTexts(partial)).toEqual([{ locale: 'hi', reason: 'empty' }]);
  });

  it.each<[IntentionLocale, string, string]>([
    ['en', "Don't miss tonight's calm", 'banned_word'],
    ['en', 'Keep your streak going', 'banned_word'],
    ['en', 'Hurry to bed', 'banned_word'],
    ['en', 'You should sleep early', 'guilt_word'],
    ['en', 'No excuses tonight', 'guilt_word'],
    ['en', 'Try not to fail again', 'guilt_word'],
    ['en', 'Ease your anxiety', 'clinical_word'],
    ['en', 'Take your medication', 'clinical_word'],
    ['en', 'Sleep better tonight', 'health_claim'],
    ['en', 'Heal before bed', 'health_claim'],
    ['en', 'Beat your best score', 'score_word'],
    ['en', 'Reach your goal', 'score_word'],
    ['en', 'Watch the rain', 'quadrant_name'],
    ['en', 'Meet at the lighthouse', 'theme_name'],
    ['te-Latn', 'Tondaraga padukondi', 'banned_word'],
    ['hi-Latn', 'Jaldi so jao', 'banned_word'],
    ['hi-Latn', 'Kal se behtar', 'score_word'],
    ['hi', 'आपको सोना चाहिए', 'guilt_word'],
    ['hi', 'डिप्रेशन से दूरी', 'clinical_word'],
    ['te', 'తొందరగా పడుకోండి', 'banned_word'],
  ])('%s "%s" → %s', (locale, text, reason) => {
    expect(lintIntentionText(locale, text).map((p) => p.reason)).toContain(reason);
  });

  it('refuses links, handles, addresses and phone numbers', () => {
    for (const t of ['See aura.app/help', 'Visit https://x.test', 'DM @quietcomet', 'Write to me@x.com', 'Call +91 98765 43210']) {
      expect(lintIntentionText('en', t).map((p) => p.reason)).toContain('link_or_contact');
    }
    expect(lintIntentionText('en', 'Phone down for 10 minutes')).toEqual([]);
  });

  it('refuses line breaks, over-long lines and the wrong script', () => {
    expect(lintIntentionText('en', 'One line\nTwo lines').map((p) => p.reason)).toContain('line_break');
    expect(lintIntentionText('en', 'a'.repeat(81)).map((p) => p.reason)).toContain('too_long');
    expect(lintIntentionText('en', 'a'.repeat(80))).toEqual([]);
    expect(lintIntentionText('te', 'Sleep before midnight').map((p) => p.reason)).toContain('script');
    expect(lintIntentionText('hi', 'నిద్ర').map((p) => p.reason)).toContain('script');
    expect(lintIntentionText('te-Latn', 'నిద్ర').map((p) => p.reason)).toContain('script');
  });

  it('describes a problem as one console line', () => {
    expect(describeIntentionProblem({ locale: 'te-Latn', reason: 'banned_word', term: 'tondara*' })).toBe(
      'te-Latn: has a guilt, loss or urgency word ("tondara*")',
    );
  });
});

describe('Tonight’s intention rotation preview', () => {
  it('lists 14 region-local nights from today (IST calendar)', () => {
    const dates = previewDates(new Date('2026-09-24T20:00:00Z')); // 01:30 IST on the 25th
    expect(dates).toHaveLength(14);
    expect(dates[0]).toBe('2026-09-25');
    expect(dates[13]).toBe('2026-10-08');
  });

  it('uses exactly the rule rooms use, so the preview is what rooms will show', () => {
    const keys = ['a_one', 'b_two', 'c_three'];
    const dates = previewDates(new Date('2026-09-24T06:00:00Z'), 7);
    const nights = rotationPreview(keys, dates);
    expect(nights.map((n) => n.key)).toEqual(dates.map((d) => pickIntention(keys, d)));
    // Consecutive nights walk the list in order.
    const i = keys.indexOf(nights[0].key as string);
    expect(nights.slice(0, 3).map((n) => n.key)).toEqual([0, 1, 2].map((k) => keys[(i + k) % keys.length]));
  });

  it('has no intention on a pool with nothing enabled', () => {
    expect(rotationPreview([], ['2026-09-25'])).toEqual([{ date: '2026-09-25', key: null }]);
  });
});

// ------------------------------------------------------------------ retire / restore / move (IntentionsService.update)

interface FakePreset {
  language_pool: 'en' | 'te' | 'hi';
  key: string;
  position: number;
  enabled: boolean;
  created_at: Date;
  updated_at: Date;
}

/** Just enough of `aura_admin`'s view for `update`: the pool's presets, a key's words, rooms tonight, the audit log. */
function fakeDb(presets: FakePreset[], words: Record<string, IntentionTexts>, roomsTonight = 0) {
  const audit: Array<{ action: string; reason: string; detail: Record<string, unknown> }> = [];
  const tx = {
    async query(sql: string, params: unknown[] = []) {
      if (sql.includes('from public.room_intention_presets') && sql.includes('for update')) {
        return { rows: presets.filter((p) => p.language_pool === params[0]).map((p) => ({ ...p })) };
      }
      if (sql.includes('from public.room_intention_texts')) {
        const t = words[params[0] as string];
        return {
          rows: t
            ? [{ key: params[0], text_en: t.en, text_te: t.te, text_te_latn: t['te-Latn'], text_hi: t.hi, text_hi_latn: t['hi-Latn'], updated_at: new Date() }]
            : [],
        };
      }
      if (sql.includes('update public.room_intention_presets')) {
        const p = presets.find((x) => x.language_pool === params[0] && x.key === params[1]) as FakePreset;
        p.enabled = params[2] as boolean;
        p.position = params[3] as number;
        return { rows: [{ ...p }] };
      }
      if (sql.includes('from public.rooms')) return { rows: [{ n: roomsTonight }] };
      if (sql.includes('insert into public.moderation_actions')) {
        audit.push({ action: params[1] as string, reason: params[4] as string, detail: JSON.parse(params[5] as string) });
        return { rows: [{ id: String(audit.length) }] };
      }
      throw new Error(`unexpected SQL: ${sql.slice(0, 60)}`);
    },
  };
  const adminDb = { withTx: <T>(fn: (t: typeof tx) => Promise<T>) => fn(tx) };
  return { service: new IntentionsService(adminDb as never, {} as never), audit, presets };
}

const preset = (key: string, position: number, enabled = true): FakePreset => ({
  language_pool: 'en',
  key,
  position,
  enabled,
  created_at: new Date('2026-09-01T00:00:00Z'),
  updated_at: new Date('2026-09-01T00:00:00Z'),
});

describe('IntentionsService.update: retire, restore, move', () => {
  const calm: IntentionTexts = {
    en: 'Put the phone in another room',
    te: 'ఫోన్ వేరే గదిలో పెడతాను',
    'te-Latn': 'Phone vere gadilo pedataanu',
    hi: 'फ़ोन दूसरे कमरे में',
    'hi-Latn': 'Phone doosre kamre mein',
  };

  it('retires a preset (audited with the rooms still showing it tonight, which keep it)', async () => {
    const { service, audit, presets } = fakeDb([preset('a_one', 10), preset('b_two', 20)], {}, 3);
    const out = await service.update('staff:owner', 'en', 'a_one', { enabled: false, reasonCode: 'seasonal' });
    expect(out.preset).toMatchObject({ key: 'a_one', enabled: false, inUseTonight: 3 });
    expect(out.previous).toEqual({ enabled: true, position: 10 });
    expect(presets[0].enabled).toBe(false);
    expect(audit).toEqual([
      {
        action: 'intention_preset_retire',
        reason: 'seasonal',
        detail: { pool: 'en', key: 'a_one', enabled: false, position: 10, previousEnabled: true, previousPosition: 10, inUseTonight: 3 },
      },
    ]);
  });

  it('never retires the pool’s last preset in rotation (the kill switch is the way to turn intentions off)', async () => {
    const { service, audit } = fakeDb([preset('a_one', 10), preset('b_two', 20, false)], {});
    await expect(service.update('staff:owner', 'en', 'a_one', { enabled: false, reasonCode: 'x' })).rejects.toMatchObject({ code: 'last_intention' });
    expect(audit).toEqual([]);
  });

  it('restores a preset only when its words pass the lint', async () => {
    const ok = fakeDb([preset('a_one', 10), preset('b_two', 20, false)], { b_two: calm });
    await expect(ok.service.update('staff:owner', 'en', 'b_two', { enabled: true, reasonCode: 'back' })).resolves.toMatchObject({ preset: { enabled: true } });
    expect(ok.audit.map((a) => a.action)).toEqual(['intention_preset_restore']);

    const placeholder = fakeDb([preset('a_one', 10), preset('b_two', 20, false)], {
      b_two: { en: 'b_two', te: 'b_two', 'te-Latn': 'b_two', hi: 'b_two', 'hi-Latn': 'b_two' },
    });
    await expect(placeholder.service.update('staff:owner', 'en', 'b_two', { enabled: true, reasonCode: 'back' })).rejects.toBeInstanceOf(IntentionRejectedError);
    expect(placeholder.audit).toEqual([]);
  });

  it('moves a preset; a change to nothing writes nothing', async () => {
    const { service, audit } = fakeDb([preset('a_one', 10), preset('b_two', 20)], {});
    await service.update('staff:owner', 'en', 'b_two', { position: 5, reasonCode: 'reorder' });
    expect(audit.map((a) => a.action)).toEqual(['intention_preset_move']);
    await service.update('staff:owner', 'en', 'b_two', { position: 5, reasonCode: 'reorder' });
    expect(audit).toHaveLength(1);
  });

  it('refuses unknown pools, keys and empty changes', async () => {
    const { service } = fakeDb([preset('a_one', 10)], {});
    await expect(service.update('staff:owner', 'xx', 'a_one', { enabled: false, reasonCode: 'x' })).rejects.toMatchObject({ status: 404 });
    await expect(service.update('staff:owner', 'en', 'nope_nope', { enabled: false, reasonCode: 'x' })).rejects.toMatchObject({ status: 404 });
    await expect(service.update('staff:owner', 'en', 'a_one', { reasonCode: 'x' })).rejects.toMatchObject({ status: 400 });
    await expect(service.update('staff:owner', 'en', 'a_one', { enabled: false })).rejects.toMatchObject({ status: 400 });
  });
});
