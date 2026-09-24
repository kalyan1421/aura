/**
 * F6 building blocks without a database: DS-1 envelope for reflection text, the near-duplicate hash, the OpenAI
 * omni-moderation client (fake fetch: request shape, timeout, errors — never the key or text in results), the settings
 * parser, request validation (no replies, grapheme counting) and the app view (DS-10 shape).
 */
import { randomBytes } from 'node:crypto';
import { ApiError } from '../../src/common/api-error';
import { OpenAiModerationProvider, StaticModerationProvider, UnavailableModerationProvider, parseReflectionsSettings, providerFrom, scoresFrom, type FetchLike } from '../../src/reflections/moderation-provider';
import { composerPaused, flagsFrom } from '../../src/reflections/reflection-config';
import { openReflection, sealReflection, textHash, tryOpen } from '../../src/reflections/reflection-cipher';
import { reflectionView } from '../../src/reflections/reflection-views';
import type { ListedRow } from '../../src/reflections/reflections.repository';
import { parseSendRequest } from '../../src/reflections/reflections.schema';

const MASTER = randomBytes(32);
const ID = '0192f0c4-8b5e-7c1a-9d3e-2f4a6b8c0d1e';
const OTHER = '0192f0c4-8b5e-7c1a-9d3e-2f4a6b8c0d1f';

describe('reflection text envelope (DS-1)', () => {
  it('round-trips Telugu and emoji; the ciphertext holds no plaintext', () => {
    const text = 'నమస్తే 🙏🏽 first Diwali alone';
    const s = sealReflection(MASTER, ID, text);
    expect(openReflection(MASTER, ID, s)).toBe(text);
    expect(Buffer.from(s.bodyCt, 'base64').toString('utf8')).not.toContain('Diwali');
    expect(s.bodyKey).not.toEqual(sealReflection(MASTER, ID, text).bodyKey); // a fresh data key every time
  });

  it('fails for another id, another master key or a tampered body', () => {
    const s = sealReflection(MASTER, ID, 'hello');
    expect(() => openReflection(MASTER, OTHER, s)).toThrow();
    expect(() => openReflection(randomBytes(32), ID, s)).toThrow();
    const buf = Buffer.from(s.bodyCt, 'base64');
    buf[15] ^= 1;
    expect(() => openReflection(MASTER, ID, { ...s, bodyCt: buf.toString('base64') })).toThrow();
    expect(tryOpen(MASTER, OTHER, s.bodyCt, s.bodyKey)).toBeNull();
    expect(tryOpen(MASTER, ID, null, null)).toBeNull();
  });

  it('near-duplicate hash ignores case, spacing and punctuation, and is keyed', () => {
    expect(textHash(MASTER, 'Buy  followers!!')).toBe(textHash(MASTER, 'buy followers'));
    expect(textHash(MASTER, 'buy followers')).not.toBe(textHash(MASTER, 'buy follower'));
    expect(textHash(randomBytes(32), 'buy followers')).not.toBe(textHash(MASTER, 'buy followers'));
    expect(textHash(MASTER, 'x')).toMatch(/^[0-9a-f]{64}$/);
  });
});

describe('OpenAI omni-moderation client', () => {
  const settings = { openAiApiKey: 'sk-test-0123456789abcdefghij', openAiModerationUrl: 'https://example.test/v1/moderations', openAiModerationModel: 'omni-moderation-latest' };

  it('posts the text and model with the bearer key and reads category scores', async () => {
    const calls: Array<{ url: string; body: string; auth: string }> = [];
    const fetchImpl: FetchLike = async (url, init) => {
      calls.push({ url, body: init.body, auth: init.headers.Authorization });
      return { ok: true, status: 200, json: async () => ({ results: [{ flagged: false, category_scores: { harassment: 0.2, 'self-harm': 0.01, unknown_future: 0.9 } }] }) };
    };
    const r = await new OpenAiModerationProvider(settings, fetchImpl).moderate('hello there', 1000);
    expect(r).toMatchObject({ ok: true, scores: { harassment: 0.2, 'self-harm': 0.01 } });
    expect(calls[0].url).toBe(settings.openAiModerationUrl);
    expect(JSON.parse(calls[0].body)).toEqual({ model: 'omni-moderation-latest', input: 'hello there' });
    expect(calls[0].auth).toBe(`Bearer ${settings.openAiApiKey}`);
  });

  it('HTTP errors and malformed bodies are errors; a slow call is a timeout', async () => {
    const bad: FetchLike = async () => ({ ok: false, status: 500, json: async () => ({}) });
    expect(await new OpenAiModerationProvider(settings, bad).moderate('x', 1000)).toMatchObject({ ok: false, reason: 'error' });
    const junk: FetchLike = async () => ({ ok: true, status: 200, json: async () => ({ results: [] }) });
    expect(await new OpenAiModerationProvider(settings, junk).moderate('x', 1000)).toMatchObject({ ok: false, reason: 'error' });
    const slow: FetchLike = (_url, init) =>
      new Promise((_resolve, reject) => init.signal.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' }))));
    expect(await new OpenAiModerationProvider(settings, slow).moderate('x', 30)).toMatchObject({ ok: false, reason: 'timeout' });
  });

  it('scores are clamped and only known categories kept', () => {
    expect(scoresFrom({ sexual: 1.4, hate: -1, nope: 0.5 })).toEqual({ sexual: 1, hate: 0 });
  });

  it('no key → the fail-closed provider; settings validate without echoing values', async () => {
    expect(providerFrom(parseReflectionsSettings({})).available).toBe(false);
    expect(await new UnavailableModerationProvider().moderate()).toMatchObject({ ok: false, reason: 'unavailable' });
    expect(providerFrom(parseReflectionsSettings({ OPENAI_API_KEY: settings.openAiApiKey })).name).toBe('openai');
    expect(() => parseReflectionsSettings({ OPENAI_API_KEY: 'short' })).toThrow(/OPENAI_API_KEY/);
    try {
      parseReflectionsSettings({ OPENAI_API_KEY: 'short' });
    } catch (e) {
      expect((e as Error).message).not.toContain('short');
    }
  });

  it('the static fake matches by substring, can fail and time out', async () => {
    const f = new StaticModerationProvider([{ includes: 'mean', scores: { harassment: 0.9 } }]);
    expect(await f.moderate('so MEAN', 100)).toMatchObject({ ok: true, scores: { harassment: 0.9 } });
    f.fail = 'error';
    expect(await f.moderate('x', 100)).toMatchObject({ ok: false, reason: 'error' });
    f.fail = null;
    f.delayMs = 50;
    expect(await f.moderate('x', 20)).toMatchObject({ ok: false, reason: 'timeout' });
  });
});

describe('send request (contracts/api/v1-reflections.md §1.3)', () => {
  const code = (fn: () => unknown): string => {
    try {
      fn();
    } catch (e) {
      return (e as ApiError).code;
    }
    return 'none';
  };

  it('refuses replies by name, whatever the value (REQ-REF-05)', () => {
    expect(code(() => parseSendRequest({ reflectionId: ID, text: 'hi', parentId: null }, 200))).toBe('replies_not_supported');
    expect(code(() => parseSendRequest({ reflectionId: ID, text: 'hi', parent_id: OTHER }, 200))).toBe('replies_not_supported');
  });

  it('counts characters as people see them: 200 ok, 201 refused', () => {
    const telugu = 'నా'.repeat(200); // 200 grapheme clusters, 400 UTF-16 units
    expect(parseSendRequest({ reflectionId: ID, text: telugu }, 200).text).toBe(telugu);
    expect(code(() => parseSendRequest({ reflectionId: ID, text: `${telugu}x` }, 200))).toBe('invalid_request');
    const emoji = '🙏🏽'.repeat(200);
    expect(parseSendRequest({ reflectionId: ID, text: emoji }, 200).text).toBe(emoji);
  });

  it('refuses empty text, bad ids and unknown keys; lower-cases the id', () => {
    expect(code(() => parseSendRequest({ reflectionId: ID, text: '   ' }, 200))).toBe('invalid_request');
    expect(code(() => parseSendRequest({ reflectionId: 'nope', text: 'hi' }, 200))).toBe('invalid_request');
    expect(code(() => parseSendRequest({ reflectionId: ID, text: 'hi', edit: true }, 200))).toBe('invalid_request');
    expect(parseSendRequest({ reflectionId: ID.toUpperCase(), text: ' hi ' }, 200)).toEqual({ reflectionId: ID, text: 'hi' });
  });
});

describe('kill switch flags', () => {
  it('composer paused by the flag, a paused pool or reduced mode; hold-all does not pause', () => {
    const f = flagsFrom({ reflections_composer: { enabled: true, payload: { pausedPools: ['te', 'xx'] } }, hold_all: { enabled: true } });
    expect(f).toEqual({ composerEnabled: true, pausedPools: ['te'], reducedMode: false, holdAll: true });
    expect(composerPaused(f, 'te')).toBe(true);
    expect(composerPaused(f, 'en')).toBe(false);
    expect(composerPaused(flagsFrom({ reduced_mode: { enabled: true } }), 'en')).toBe(true);
    expect(composerPaused(flagsFrom({ reflections_composer: { enabled: false } }), 'en')).toBe(true);
    expect(composerPaused(flagsFrom({}), 'en')).toBe(false); // a missing kill switch counts as on
  });
});

describe('app view (DS-10)', () => {
  const sealed = sealReflection(MASTER, ID, 'I am here too');
  const row = (patch: Partial<ListedRow>): ListedRow => ({
    id: ID,
    room_id: OTHER,
    member_id: OTHER,
    user_id: 'author-account',
    status: 'published',
    body_ct: sealed.bodyCt,
    body_key: sealed.bodyKey,
    char_count: 13,
    text_hash: 'f'.repeat(64),
    language_pool: 'en',
    involves_minor: true,
    strict: true,
    overnight: false,
    stage: 'provider',
    hold_reason: null,
    reject_reason: null,
    mod_scores: { sexual: 0.2 },
    rule_hits: [],
    created_at: new Date('2026-10-08T15:30:00Z'),
    decided_at: null,
    decided_by: null,
    published_at: new Date('2026-10-08T15:30:01Z'),
    removed_at: null,
    hidden_at: null,
    pseudonym: 'Quiet Comet',
    gesture_count: 4,
    ...patch,
  });

  it("a stranger's view carries the pseudonym and text only — no account, age, minor flag, scores or hash", () => {
    const v = reflectionView(row({}), 'viewer-account', MASTER, false);
    expect(v).toEqual({
      reflectionId: ID,
      status: 'published',
      author: { memberId: OTHER, pseudonym: 'Quiet Comet' },
      isMine: false,
      text: 'I am here too',
      createdAt: '2026-10-08T15:30:00.000Z',
      publishedAt: '2026-10-08T15:30:01.000Z',
      gestureCount: null,
      rejectReason: null,
      review: null,
    });
    const json = JSON.stringify(v);
    for (const leak of ['author-account', 'involves', 'minor', 'strict', 'score', 'hash', 'sexual']) expect(json).not.toContain(leak);
  });

  it('the author sees the gesture count on a published item and a calm review hint while held', () => {
    expect(reflectionView(row({}), 'author-account', MASTER, false)?.gestureCount).toBe(4);
    expect(reflectionView(row({ status: 'held', hold_reason: 'strict_threshold' }), 'author-account', MASTER, false)?.review).toBe('soon');
    expect(reflectionView(row({ status: 'held' }), 'author-account', MASTER, true)?.review).toBe('overnight');
    expect(reflectionView(row({ status: 'rejected', reject_reason: null }), 'author-account', MASTER, false)?.rejectReason).toBe('other');
  });
});
