/**
 * F6 reflection decision (src/reflections/decide.ts): the order of the pipeline (PRD F6 "Moderation pipeline", F9
 * "Reflection pipeline"), fail closed, the invisible stricter thresholds (REQ-REF-08), the overnight rule, and the
 * queue items each outcome raises. Plus the overnight window and threshold parsing.
 */
import { DEFAULT_THRESHOLDS, decide, isOvernight, parseThresholds, topCategory, type DecisionInput, type ProviderResult } from '../../src/reflections/decide';

const ok = (scores: Record<string, number>): ProviderResult => ({ ok: true, scores, latencyMs: 12 });
const base: Omit<DecisionInput, 'provider'> = {
  lexicon: 'none',
  grooming: false,
  contact: 'none',
  strict: false,
  overnight: false,
  forcedHold: null,
  thresholds: DEFAULT_THRESHOLDS,
};
const run = (patch: Partial<DecisionInput>) => decide({ ...base, provider: ok({}), ...patch });

describe('reflection decision order', () => {
  it('clean text publishes, with no queue item', () => {
    const d = run({});
    expect(d).toMatchObject({ outcome: 'published', store: true, stage: 'provider', queue: null, minorSafety: false });
  });

  it('crisis lexicon wins over everything, even a phone number (F9 edge case "crisis wins")', () => {
    const d = run({ lexicon: 'crisis', contact: 'contact_details', grooming: true, forcedHold: 'hold_all', provider: null });
    expect(d).toMatchObject({ outcome: 'crisis_diverted', store: true, stage: 'rules', queue: { reason: 1, signal: 'reflection_crisis' } });
  });

  it('a soft idiom is not a crisis', () => {
    expect(run({ lexicon: 'soft' }).outcome).toBe('published');
  });

  it('omni self-harm → crisis_diverted (never a rejection, never a strike reason)', () => {
    const d = run({ provider: ok({ 'self-harm/intent': 0.5 }) });
    expect(d).toMatchObject({ outcome: 'crisis_diverted', stage: 'provider', rejectReason: null, queue: { reason: 1 } });
  });

  it('grooming phrase → rejected (personal_questions), Minors & grooming, shadow-mute', () => {
    const d = run({ grooming: true, contact: 'contact_details' });
    expect(d).toMatchObject({ outcome: 'rejected', store: true, rejectReason: 'personal_questions', minorSafety: true, queue: { reason: 9, signal: 'reflection_minor_safety' } });
  });

  it('sexual/minors → rejected to Minors & grooming', () => {
    const d = run({ provider: ok({ 'sexual/minors': 0.3, sexual: 0.3 }) });
    expect(d).toMatchObject({ outcome: 'rejected', rejectReason: 'sexual', minorSafety: true, queue: { reason: 3, signal: 'reflection_minor_safety' } });
  });

  it('contact details / links are rejected and never stored (REQ-REF-02)', () => {
    expect(run({ contact: 'contact_details', provider: null })).toMatchObject({ outcome: 'rejected', store: false, rejectReason: 'contact_details', queue: null });
    expect(run({ contact: 'link', provider: null })).toMatchObject({ outcome: 'rejected', store: false, rejectReason: 'link' });
  });

  it('high scores reject (stored, a lane item for a strike decision)', () => {
    expect(run({ provider: ok({ harassment: 0.9 }) })).toMatchObject({ outcome: 'rejected', rejectReason: 'hurtful', queue: { reason: 2, signal: 'reflection_violation' } });
    expect(run({ provider: ok({ hate: 0.95 }) })).toMatchObject({ rejectReason: 'hurtful', queue: { reason: 4 } });
    expect(run({ provider: ok({ sexual: 0.9 }) })).toMatchObject({ rejectReason: 'sexual', queue: { reason: 3 } });
    expect(run({ provider: ok({ illicit: 0.9 }) })).toMatchObject({ rejectReason: 'other', queue: { reason: 8 } });
  });

  it('medium scores hold (uncertain)', () => {
    expect(run({ provider: ok({ harassment: 0.5 }) })).toMatchObject({ outcome: 'held', holdReason: 'uncertain', queue: { reason: 8, signal: 'reflection_hold' } });
  });

  it('forced holds win over publishing, not over rejections or crisis', () => {
    expect(run({ forcedHold: 'hold_all' })).toMatchObject({ outcome: 'held', holdReason: 'hold_all' });
    expect(run({ forcedHold: 'active_strike' })).toMatchObject({ outcome: 'held', holdReason: 'active_strike' });
    expect(run({ forcedHold: 'near_duplicate' })).toMatchObject({ outcome: 'held', holdReason: 'near_duplicate', queue: { reason: 6 } });
    expect(run({ forcedHold: 'hold_all', provider: ok({ hate: 0.99 }) }).outcome).toBe('rejected');
    expect(run({ forcedHold: 'hold_all', provider: ok({ 'self-harm': 0.9 }) }).outcome).toBe('crisis_diverted');
  });
});

describe('fail closed (REQ-REF-03)', () => {
  it('provider error → held (provider_unavailable)', () => {
    expect(run({ provider: { ok: false, reason: 'error', latencyMs: 30 } })).toMatchObject({ outcome: 'held', holdReason: 'provider_unavailable' });
  });
  it('provider unavailable (no key) → held', () => {
    expect(run({ provider: { ok: false, reason: 'unavailable', latencyMs: 0 } })).toMatchObject({ outcome: 'held', holdReason: 'provider_unavailable' });
  });
  it('timeout → held (timeout); nothing is released by a timeout', () => {
    expect(run({ provider: { ok: false, reason: 'timeout', latencyMs: 5000 } })).toMatchObject({ outcome: 'held', holdReason: 'timeout' });
  });
  it('no classification at all → held', () => {
    expect(run({ provider: null })).toMatchObject({ outcome: 'held', holdReason: 'provider_unavailable' });
  });
  it('the crisis lexicon still diverts while the provider is down', () => {
    expect(run({ lexicon: 'crisis', provider: { ok: false, reason: 'error', latencyMs: 1 } }).outcome).toBe('crisis_diverted');
  });
});

describe('invisible stricter thresholds (REQ-REF-08)', () => {
  it('a borderline sexual score publishes in an all-adult room and holds with an under-18 involved', () => {
    const borderline = ok({ sexual: 0.25 });
    expect(run({ provider: borderline, strict: false }).outcome).toBe('published');
    expect(run({ provider: borderline, strict: true })).toMatchObject({ outcome: 'held', holdReason: 'strict_threshold' });
  });
  it('strict also rejects earlier for sexual and harassment, never for other categories', () => {
    expect(run({ provider: ok({ harassment: 0.7 }), strict: true }).outcome).toBe('rejected');
    expect(run({ provider: ok({ harassment: 0.7 }), strict: false }).outcome).toBe('held');
    expect(run({ provider: ok({ violence: 0.3 }), strict: true }).outcome).toBe('published');
  });
});

describe('overnight (PRD F6 step 4, 19 "only high-confidence clean text")', () => {
  it('holds anything not rated clean with high confidence; clean text still publishes', () => {
    expect(run({ overnight: true, provider: ok({ harassment: 0.2 }) })).toMatchObject({ outcome: 'held', holdReason: 'overnight' });
    expect(run({ overnight: true, provider: ok({ harassment: 0.05 }) }).outcome).toBe('published');
    expect(run({ overnight: false, provider: ok({ harassment: 0.2 }) }).outcome).toBe('published');
  });

  it('isOvernight: 00:30–07:30 IST, including a window that wraps midnight', () => {
    const at = (iso: string) => new Date(iso);
    const s = { hour: 0, minute: 30 };
    const e = { hour: 7, minute: 30 };
    expect(isOvernight(at('2026-10-08T19:00:00Z'), s, e, 'Asia/Kolkata')).toBe(true); // 00:30 IST
    expect(isOvernight(at('2026-10-08T18:59:00Z'), s, e, 'Asia/Kolkata')).toBe(false); // 00:29 IST
    expect(isOvernight(at('2026-10-09T01:59:00Z'), s, e, 'Asia/Kolkata')).toBe(true); // 07:29 IST
    expect(isOvernight(at('2026-10-09T02:00:00Z'), s, e, 'Asia/Kolkata')).toBe(false); // 07:30 IST
    expect(isOvernight(at('2026-10-08T17:45:00Z'), { hour: 23, minute: 0 }, { hour: 7, minute: 0 }, 'Asia/Kolkata')).toBe(true); // 23:15 IST
  });
});

describe('thresholds', () => {
  it('config overrides merge over the defaults; invalid shapes fall back', () => {
    expect(parseThresholds({ selfHarm: 0.2 }).selfHarm).toBe(0.2);
    expect(parseThresholds({ selfHarm: 0.2 }).standard).toEqual(DEFAULT_THRESHOLDS.standard);
    expect(parseThresholds({ standard: { reject: 0.3, hold: 0.6 } })).toEqual(DEFAULT_THRESHOLDS); // hold > reject
    expect(parseThresholds('nope')).toEqual(DEFAULT_THRESHOLDS);
  });
  it('top category', () => {
    expect(topCategory({ hate: 0.2, sexual: 0.3 })).toBe('sexual');
    expect(topCategory({})).toBeNull();
  });
});
