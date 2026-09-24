import { z } from 'zod';
import { OMNI_CATEGORIES, type OmniCategory, type ProviderResult, type Scores } from './decide';

/**
 * The one external classifier (PRD F6 REQ-REF-07, F9 L2): OpenAI omni-moderation, behind an interface so tests use a
 * fake and so "unset key" is an explicit, fail-closed provider. Text only; nothing else about the author or room is
 * sent. Zero data retention is an OpenAI account setting (see docs/setup, external item). Never logs the text.
 */
export const MODERATION_PROVIDER = Symbol('MODERATION_PROVIDER');

export interface ModerationProvider {
  /** Short name for logs and the console ("openai", "unavailable", "fake"). */
  readonly name: string;
  /** False when calls can't succeed (no key): the pipeline holds everything it would have classified. */
  readonly available: boolean;
  moderate(text: string, timeoutMs: number): Promise<ProviderResult>;
}

export interface ReflectionsSettings {
  openAiApiKey: string | null;
  openAiModerationUrl: string;
  openAiModerationModel: string;
}

const blank = (v: unknown): unknown => (typeof v === 'string' && v.trim() === '' ? undefined : v);
const envSchema = z.object({
  OPENAI_API_KEY: z.preprocess(blank, z.string().min(20).optional()),
  OPENAI_MODERATION_URL: z.preprocess(blank, z.string().url().default('https://api.openai.com/v1/moderations')),
  OPENAI_MODERATION_MODEL: z.preprocess(blank, z.string().min(1).max(80).default('omni-moderation-latest')),
});

export class ReflectionsSettingsError extends Error {}

/** Env → settings; a malformed value fails at boot naming the variable, never its value. */
export function parseReflectionsSettings(env: Record<string, string | undefined>): ReflectionsSettings {
  const r = envSchema.safeParse(env);
  if (!r.success) {
    const lines = r.error.issues.map((i) => `  - ${i.path.join('.')}: ${i.message}`);
    throw new ReflectionsSettingsError(`Invalid reflections environment:\n${lines.join('\n')}`);
  }
  return {
    openAiApiKey: r.data.OPENAI_API_KEY ?? null,
    openAiModerationUrl: r.data.OPENAI_MODERATION_URL,
    openAiModerationModel: r.data.OPENAI_MODERATION_MODEL,
  };
}

/** No key configured: every call "fails", so every reflection that reaches the classifier is held (fail closed). */
export class UnavailableModerationProvider implements ModerationProvider {
  readonly name = 'unavailable';
  readonly available = false;
  async moderate(): Promise<ProviderResult> {
    return { ok: false, reason: 'unavailable', latencyMs: 0 };
  }
}

const responseSchema = z.object({
  results: z.array(z.object({ category_scores: z.record(z.string(), z.number()) })).min(1),
});

/** Picks the known categories out of an omni-moderation `category_scores`, clamped to [0, 1]. */
export function scoresFrom(raw: Record<string, number>): Scores {
  const out: Scores = {};
  for (const c of OMNI_CATEGORIES) {
    const v = raw[c];
    if (typeof v === 'number' && Number.isFinite(v)) out[c as OmniCategory] = Math.min(1, Math.max(0, v));
  }
  return out;
}

export type FetchLike = (url: string, init: { method: string; headers: Record<string, string>; body: string; signal: AbortSignal }) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
}>;

export class OpenAiModerationProvider implements ModerationProvider {
  readonly name = 'openai';
  readonly available = true;

  constructor(
    private readonly settings: ReflectionsSettings & { openAiApiKey: string },
    private readonly fetchImpl: FetchLike = fetch as unknown as FetchLike,
  ) {}

  async moderate(text: string, timeoutMs: number): Promise<ProviderResult> {
    const started = Date.now();
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    try {
      const res = await this.fetchImpl(this.settings.openAiModerationUrl, {
        method: 'POST',
        headers: { Authorization: `Bearer ${this.settings.openAiApiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: this.settings.openAiModerationModel, input: text }),
        signal: ctl.signal,
      });
      if (!res.ok) return { ok: false, reason: 'error', latencyMs: Date.now() - started };
      const parsed = responseSchema.safeParse(await res.json());
      if (!parsed.success) return { ok: false, reason: 'error', latencyMs: Date.now() - started };
      return { ok: true, scores: scoresFrom(parsed.data.results[0].category_scores), latencyMs: Date.now() - started };
    } catch {
      return { ok: false, reason: ctl.signal.aborted ? 'timeout' : 'error', latencyMs: Date.now() - started };
    } finally {
      clearTimeout(timer);
    }
  }
}

/**
 * Deterministic fake for tests and local demos: scores come from `rules` (the first rule whose `includes` is in the
 * lower-cased text), else all zero. `delayMs` simulates a slow provider; `fail` an outage.
 */
export class StaticModerationProvider implements ModerationProvider {
  readonly name = 'fake';
  available = true;
  delayMs = 0;
  fail: 'error' | 'timeout' | null = null;
  calls = 0;

  constructor(public rules: Array<{ includes: string; scores: Scores }> = []) {}

  async moderate(text: string, timeoutMs: number): Promise<ProviderResult> {
    this.calls += 1;
    const started = Date.now();
    if (this.delayMs > 0) await new Promise((r) => setTimeout(r, Math.min(this.delayMs, timeoutMs)));
    if (this.delayMs >= timeoutMs || this.fail === 'timeout') return { ok: false, reason: 'timeout', latencyMs: Date.now() - started };
    if (this.fail === 'error') return { ok: false, reason: 'error', latencyMs: Date.now() - started };
    const lower = text.toLowerCase();
    const rule = this.rules.find((r) => lower.includes(r.includes));
    return { ok: true, scores: rule ? { ...rule.scores } : {}, latencyMs: Date.now() - started };
  }
}

export function providerFrom(settings: ReflectionsSettings): ModerationProvider {
  return settings.openAiApiKey
    ? new OpenAiModerationProvider({ ...settings, openAiApiKey: settings.openAiApiKey })
    : new UnavailableModerationProvider();
}
