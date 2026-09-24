import { z } from 'zod';
import type { ContactVerdict } from './filter/reflection-filter';

/**
 * The reflection decision (PRD F6 "Moderation pipeline" and state machine; 06c F9 "Reflection pipeline"; 19 admin
 * console; contracts/api/v1-reflections.md §3). Pure: every input is gathered by ReflectionPipeline; unit-tested in
 * test/unit/reflections.decide.spec.ts. The first rule that decides wins:
 *
 *  1. crisis lexicon → crisis_diverted (crisis lane, never a strike, support sheet)
 *  2. omni self-harm ≥ selfHarm → crisis_diverted
 *  3. grooming phrase → rejected (personal_questions), Minors & grooming lane, shadow-mute until review
 *  4. omni sexual/minors ≥ sexualMinors → rejected (sexual), Minors & grooming lane, shadow-mute until review
 *  5. contact details / link → rejected (nothing stored)
 *  6. any category ≥ its reject threshold → rejected (stored; a lane item so a human can confirm a strike)
 *  7. forced hold (hold_all, active strike, shadow-mute, near-duplicate) → held
 *  8. provider unavailable / timeout → held (fail closed)
 *  9. any category ≥ its hold threshold → held (strict_threshold when only the stricter under-18 / language values hold it)
 * 10. overnight and any category ≥ overnightClean → held (overnight: only high-confidence clean text publishes)
 * 11. published
 */
export type ReflectionOutcome = 'published' | 'held' | 'rejected' | 'crisis_diverted';
export type HoldReason =
  | 'uncertain'
  | 'strict_threshold'
  | 'overnight'
  | 'provider_unavailable'
  | 'timeout'
  | 'hold_all'
  | 'active_strike'
  | 'sanction'
  | 'near_duplicate'
  | 'reported';
export type RejectReason = 'contact_details' | 'link' | 'personal_questions' | 'hurtful' | 'sexual' | 'other';
export type ForcedHold = Extract<HoldReason, 'hold_all' | 'active_strike' | 'sanction' | 'near_duplicate'>;

/** OpenAI omni-moderation categories (category_scores keys). */
export const OMNI_CATEGORIES = [
  'harassment',
  'harassment/threatening',
  'hate',
  'hate/threatening',
  'illicit',
  'illicit/violent',
  'self-harm',
  'self-harm/intent',
  'self-harm/instructions',
  'sexual',
  'sexual/minors',
  'violence',
  'violence/graphic',
] as const;
export type OmniCategory = (typeof OMNI_CATEGORIES)[number];
export type Scores = Partial<Record<OmniCategory, number>>;

const SELF_HARM: readonly OmniCategory[] = ['self-harm', 'self-harm/intent', 'self-harm/instructions'];
/** Categories with stricter values when an under-18 is involved or the pool is Telugu / Hindi (REQ-REF-08). */
const STRICT_CATEGORIES: readonly OmniCategory[] = ['sexual', 'harassment', 'harassment/threatening'];

export type ProviderResult =
  | { ok: true; scores: Scores; latencyMs: number }
  | { ok: false; reason: 'unavailable' | 'timeout' | 'error'; latencyMs: number };

const band = z.object({ reject: z.number().min(0).max(1), hold: z.number().min(0).max(1) }).refine((b) => b.hold <= b.reject, 'hold ≤ reject');

export const thresholdsSchema = z.object({
  /** Any self-harm category at or above → crisis_diverted. */
  selfHarm: z.number().min(0).max(1),
  /** sexual/minors at or above → rejected to the Minors & grooming lane. */
  sexualMinors: z.number().min(0).max(1),
  /** Every other category. */
  standard: band,
  /** sexual and harassment when stricter thresholds apply. */
  strict: band,
  /** Overnight: any category at or above → held until morning. */
  overnightClean: z.number().min(0).max(1),
});
export type Thresholds = z.infer<typeof thresholdsSchema>;

/** Defaults [ASSUMPTION: tuned weekly from beta data] — `reflection_config.thresholds` overrides any of them. */
export const DEFAULT_THRESHOLDS: Thresholds = {
  selfHarm: 0.35,
  sexualMinors: 0.2,
  standard: { reject: 0.85, hold: 0.4 },
  strict: { reject: 0.6, hold: 0.15 },
  overnightClean: 0.15,
};

/** `reflection_config.thresholds` (partial JSON) over the defaults; anything invalid → the defaults. */
export function parseThresholds(raw: unknown): Thresholds {
  const merged = { ...DEFAULT_THRESHOLDS, ...(raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : {}) };
  const r = thresholdsSchema.safeParse(merged);
  return r.success ? r.data : DEFAULT_THRESHOLDS;
}

export interface DecisionInput {
  lexicon: 'none' | 'soft' | 'crisis';
  grooming: boolean;
  contact: ContactVerdict;
  provider: ProviderResult | null;
  /** Stricter thresholds: an under-18 author or room member, or the te / hi pool. */
  strict: boolean;
  overnight: boolean;
  forcedHold: ForcedHold | null;
  thresholds: Thresholds;
}

/** Report reason for the queue item (the F9 codes: 1 in danger, 2 harassment, 3 sexual, 4 hate, 6 spam, 8 other, 9 targeting a young person). */
export type QueueReason = 1 | 2 | 3 | 4 | 6 | 8 | 9;

export interface Decision {
  outcome: ReflectionOutcome;
  /** Stored at all (false only for contact-detail rejections: nothing leaves the rules stage). */
  store: boolean;
  stage: 'rules' | 'provider';
  holdReason: HoldReason | null;
  rejectReason: RejectReason | null;
  /** A queue item is raised (crisis, minors, violation, hold) with this F9 reason and automatic signal. */
  queue: { reason: QueueReason; signal: 'reflection_crisis' | 'reflection_minor_safety' | 'reflection_violation' | 'reflection_hold' } | null;
  /** Grooming / sexual-minors: the author is shadow-muted until a human reviews. */
  minorSafety: boolean;
  /** The highest-scoring category (analytics enum), or null. */
  topCategory: OmniCategory | null;
}

function max(scores: Scores, cats: readonly OmniCategory[]): number {
  let m = 0;
  for (const c of cats) m = Math.max(m, scores[c] ?? 0);
  return m;
}

export function topCategory(scores: Scores): OmniCategory | null {
  let best: OmniCategory | null = null;
  let v = 0;
  for (const c of OMNI_CATEGORIES) {
    const s = scores[c] ?? 0;
    if (s > v) {
      v = s;
      best = c;
    }
  }
  return best;
}

function bandFor(c: OmniCategory, strict: boolean, t: Thresholds): { reject: number; hold: number } {
  return strict && STRICT_CATEGORIES.includes(c) ? t.strict : t.standard;
}

function rejectReasonFor(c: OmniCategory): RejectReason {
  if (c.startsWith('sexual')) return 'sexual';
  if (c.startsWith('harassment') || c.startsWith('hate') || c.startsWith('violence')) return 'hurtful';
  return 'other';
}

function queueReasonFor(c: OmniCategory | null): QueueReason {
  if (!c) return 8;
  if (c.startsWith('harassment')) return 2;
  if (c.startsWith('sexual')) return 3;
  if (c.startsWith('hate')) return 4;
  return 8;
}

const held = (holdReason: HoldReason, stage: Decision['stage'], top: OmniCategory | null): Decision => ({
  outcome: 'held',
  store: true,
  stage,
  holdReason,
  rejectReason: null,
  // Held items are L3 "other" (L1 when an under-18 is involved, by laneFor) — never a paging reason: a hold is not a
  // finding. Near-duplicates are spam.
  queue: { reason: holdReason === 'near_duplicate' ? 6 : 8, signal: 'reflection_hold' },
  minorSafety: false,
  topCategory: top,
});

export function decide(i: DecisionInput): Decision {
  const t = i.thresholds;
  const scores = i.provider?.ok ? i.provider.scores : null;
  const top = scores ? topCategory(scores) : null;
  const crisis = (stage: Decision['stage']): Decision => ({
    outcome: 'crisis_diverted',
    store: true,
    stage,
    holdReason: null,
    rejectReason: null,
    queue: { reason: 1, signal: 'reflection_crisis' },
    minorSafety: false,
    topCategory: top,
  });
  const minors = (stage: Decision['stage'], reason: QueueReason, rejectReason: RejectReason): Decision => ({
    outcome: 'rejected',
    store: true,
    stage,
    holdReason: null,
    rejectReason,
    queue: { reason, signal: 'reflection_minor_safety' },
    minorSafety: true,
    topCategory: top,
  });

  if (i.lexicon === 'crisis') return crisis('rules');
  if (scores && max(scores, SELF_HARM) >= t.selfHarm) return crisis('provider');
  if (i.grooming) return minors('rules', 9, 'personal_questions');
  if (scores && (scores['sexual/minors'] ?? 0) >= t.sexualMinors) return minors('provider', 3, 'sexual');
  if (i.contact !== 'none') {
    return {
      outcome: 'rejected',
      store: false,
      stage: 'rules',
      holdReason: null,
      rejectReason: i.contact === 'link' ? 'link' : 'contact_details',
      queue: null,
      minorSafety: false,
      topCategory: null,
    };
  }
  if (scores) {
    let worst: OmniCategory | null = null;
    let worstScore = 0;
    for (const c of OMNI_CATEGORIES) {
      if (SELF_HARM.includes(c) || c === 'sexual/minors') continue;
      const s = scores[c] ?? 0;
      if (s >= bandFor(c, i.strict, t).reject && s > worstScore) {
        worst = c;
        worstScore = s;
      }
    }
    if (worst) {
      return {
        outcome: 'rejected',
        store: true,
        stage: 'provider',
        holdReason: null,
        rejectReason: rejectReasonFor(worst),
        queue: { reason: queueReasonFor(worst), signal: 'reflection_violation' },
        minorSafety: false,
        topCategory: top,
      };
    }
  }
  if (i.forcedHold) return held(i.forcedHold, i.provider?.ok ? 'provider' : 'rules', top);
  if (!i.provider || !i.provider.ok) return held(i.provider?.ok === false && i.provider.reason === 'timeout' ? 'timeout' : 'provider_unavailable', 'provider', null);
  const s = i.provider.scores;
  let standardHold = false;
  let strictHold = false;
  for (const c of OMNI_CATEGORIES) {
    const v = s[c] ?? 0;
    if (v >= t.standard.hold) standardHold = true;
    else if (i.strict && STRICT_CATEGORIES.includes(c) && v >= t.strict.hold) strictHold = true;
  }
  if (standardHold) return held('uncertain', 'provider', top);
  if (strictHold) return held('strict_threshold', 'provider', top);
  if (i.overnight && top !== null && (s[top] ?? 0) >= t.overnightClean) return held('overnight', 'provider', top);
  return { outcome: 'published', store: true, stage: 'provider', holdReason: null, rejectReason: null, queue: null, minorSafety: false, topCategory: top };
}

/** Minutes since local midnight in `tz` at `now`. */
function minutesIn(tz: string, now: Date): number {
  const parts = new Intl.DateTimeFormat('en-GB', { timeZone: tz, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(now);
  const h = Number(parts.find((p) => p.type === 'hour')?.value ?? '0');
  const m = Number(parts.find((p) => p.type === 'minute')?.value ?? '0');
  return h * 60 + m;
}

/** "While he sleeps (00:30–07:30 IST)" — also handles a window that wraps midnight (e.g. 23:00–07:00). */
export function isOvernight(now: Date, start: { hour: number; minute: number }, end: { hour: number; minute: number }, tz: string): boolean {
  const t = minutesIn(tz, now);
  const s = start.hour * 60 + start.minute;
  const e = end.hour * 60 + end.minute;
  return s <= e ? t >= s && t < e : t >= s || t < e;
}
