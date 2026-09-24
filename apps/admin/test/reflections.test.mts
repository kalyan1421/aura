/** F6 reflections in the console: labels, score highlighting, crisis wording and the decision form → API body. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  HOLD_REASON_LABEL,
  REJECT_REASON_LABEL,
  STATUS_LABEL,
  decisionBody,
  decisionLabel,
  decisionResultText,
  defaultReasonCode,
  formatScore,
  isCrisis,
  isPool,
  isUuid,
  listHref,
  reasonCodeFrom,
  scoreRows,
  statusTab,
  supportSheetShown,
  type DecisionResult,
  type ReviewView,
} from '../src/lib/reflections.ts';
import { label } from '../src/lib/format.ts';

const form = (entries: Record<string, string>): FormData => {
  const fd = new FormData();
  for (const [k, v] of Object.entries(entries)) fd.set(k, v);
  return fd;
};
const ALL = ['approve', 'remove', 'escalate'] as const;
const ctx = { allowed: [...ALL], canStrike: true, crisis: false };

test('status tabs default to held; unknown values fall back', () => {
  assert.equal(statusTab(undefined), 'held');
  assert.equal(statusTab('crisis_diverted'), 'crisis_diverted');
  assert.equal(statusTab('all'), 'all');
  assert.equal(statusTab('deleted'), 'held');
  assert.equal(statusTab(['held', 'all']), 'held');
  assert.equal(listHref('held'), '/reflections');
  assert.equal(listHref('removed'), '/reflections?status=removed');
});

test('labels cover every status, hold reason and reject reason in the contract', () => {
  for (const s of ['pending', 'published', 'held', 'rejected', 'crisis_diverted', 'removed', 'deleted', 'expired']) assert.ok(STATUS_LABEL[s], s);
  for (const h of ['uncertain', 'strict_threshold', 'overnight', 'provider_unavailable', 'timeout', 'hold_all', 'active_strike', 'sanction', 'near_duplicate', 'reported']) {
    assert.ok(HOLD_REASON_LABEL[h], h);
  }
  assert.deepEqual(Object.keys(REJECT_REASON_LABEL), ['contact_details', 'link', 'personal_questions', 'hurtful', 'sexual', 'other']);
  assert.equal(label(HOLD_REASON_LABEL, 'new_reason'), 'new reason');
});

test('scores: highest first, formatted, highlighted at 0.4 and above', () => {
  assert.deepEqual(scoreRows(null), []);
  const rows = scoreRows({ harassment: 0.12, 'self-harm': 0.4, sexual: 0.873, violence: 0.00004, bad: Number.NaN });
  assert.deepEqual(
    rows.map((r) => [r.category, r.text, r.high]),
    [
      ['sexual', '0.87', true],
      ['self-harm', '0.40', true],
      ['harassment', '0.12', false],
      ['violence', '<0.01', false],
    ],
  );
  assert.equal(formatScore(0), '0.00');
  assert.equal(formatScore(1), '1.00');
  assert.equal(formatScore(Number.POSITIVE_INFINITY), '—');
  assert.equal(scoreRows({ a: 0.5 }, 0.6)[0].high, false);
});

const view = (over: Partial<ReviewView>): Pick<ReviewView, 'status' | 'ruleHits' | 'reports'> => ({ status: 'held', ruleHits: [], reports: [], ...over });
const report = (over: Partial<ReviewView['reports'][number]>): ReviewView['reports'][number] => ({
  reportId: '018f0000-0000-7000-8000-000000000001',
  lane: 'harassment',
  reasonKey: 'harassment',
  source: 'user',
  autoSignal: null,
  status: 'open',
  createdAt: '2026-09-24T10:00:00.000Z',
  slaDueAt: '2026-09-24T14:00:00.000Z',
  pages: false,
  ...over,
});

test('crisis items (US-42): detection, support sheet and wording', () => {
  assert.equal(isCrisis(view({})), false);
  assert.equal(isCrisis(view({ status: 'crisis_diverted' })), true);
  assert.equal(isCrisis(view({ ruleHits: ['crisis_lexicon'] })), true);
  assert.equal(isCrisis(view({ status: 'published', reports: [report({ lane: 'crisis', reasonKey: 'in_danger' })] })), true);
  // A person's "in danger" report on a published reflection: crisis lane, but the author never saw the sheet.
  assert.equal(supportSheetShown(view({ status: 'published', reports: [report({ lane: 'crisis', reasonKey: 'in_danger' })] })), false);
  assert.equal(supportSheetShown(view({ status: 'crisis_diverted' })), true);
  assert.equal(supportSheetShown(view({ status: 'published', reports: [report({ source: 'auto', autoSignal: 'reflection_crisis', lane: 'crisis' })] })), true);

  assert.equal(decisionLabel('approve', { status: 'crisis_diverted', crisis: true }), 'Release as a false positive');
  assert.equal(decisionLabel('remove', { status: 'crisis_diverted', crisis: true }), 'Keep unpublished');
  assert.equal(decisionLabel('remove', { status: 'published', crisis: true }), 'Take down');
  assert.equal(decisionLabel('remove', { status: 'held', crisis: false }), 'Reject');
  assert.equal(decisionLabel('approve', { status: 'held', crisis: false }), 'Approve and publish');
  assert.equal(decisionLabel('escalate', { status: 'held', crisis: false }), 'Escalate');
  assert.equal(defaultReasonCode({ status: 'crisis_diverted', rejectReason: null }), 'crisis_support');
  assert.equal(defaultReasonCode({ status: 'rejected', rejectReason: 'hurtful' }), 'harassment');
  assert.equal(defaultReasonCode({ status: 'held', rejectReason: null }), 'no_violation');
});

test('decision form: approve and reason codes (select or custom)', () => {
  assert.deepEqual(decisionBody(form({ decision: 'approve', reasonCode: 'no_violation' }), ctx), {
    ok: true,
    body: { decision: 'approve', reasonCode: 'no_violation' },
  });
  assert.deepEqual(decisionBody(form({ decision: 'approve', reasonCode: 'custom', customReason: ' exam_idiom ' }), ctx), {
    ok: true,
    body: { decision: 'approve', reasonCode: 'exam_idiom' },
  });
  assert.equal(reasonCodeFrom(form({ reasonCode: 'custom' })), '');
  for (const bad of ['', 'Has Caps', 'with-dash', 'x'.repeat(41)]) {
    const r = decisionBody(form({ decision: 'approve', reasonCode: 'custom', customReason: bad }), ctx);
    assert.equal(r.ok, false, bad);
  }
});

test('decision form: only the allowed decisions', () => {
  assert.deepEqual(decisionBody(form({ reasonCode: 'x' }), ctx), { ok: false, message: 'Choose a decision.' });
  assert.equal(decisionBody(form({ decision: 'ban', reasonCode: 'x' }), ctx).ok, false);
  assert.equal(decisionBody(form({ decision: 'escalate', reasonCode: 'x', lane: 'crisis' }), { ...ctx, allowed: ['approve', 'remove'] }).ok, false);
});

test('decision form: remove with the reason the author sees and an optional strike', () => {
  assert.deepEqual(decisionBody(form({ decision: 'remove', reasonCode: 'harassment', rejectReason: 'hurtful', strike: 'yes' }), ctx), {
    ok: true,
    body: { decision: 'remove', reasonCode: 'harassment', rejectReason: 'hurtful', strike: true },
  });
  assert.deepEqual(decisionBody(form({ decision: 'remove', reasonCode: 'other' }), ctx), { ok: true, body: { decision: 'remove', reasonCode: 'other' } });
  assert.equal(decisionBody(form({ decision: 'remove', reasonCode: 'other', rejectReason: 'rude' }), ctx).ok, false);
  // A strike needs an open report, never goes with a crisis flag, and only goes with removing.
  assert.equal(decisionBody(form({ decision: 'remove', reasonCode: 'other', strike: 'yes' }), { ...ctx, canStrike: false }).ok, false);
  const crisis = decisionBody(form({ decision: 'remove', reasonCode: 'crisis_support', strike: 'yes' }), { ...ctx, crisis: true, canStrike: true });
  assert.deepEqual(crisis, { ok: false, message: 'A crisis-flagged reflection never adds a strike.' });
  assert.equal(decisionBody(form({ decision: 'approve', reasonCode: 'other', strike: 'yes' }), ctx).ok, false);
  // Keep unpublished (crisis): no strike, no author-facing reason.
  assert.deepEqual(decisionBody(form({ decision: 'remove', reasonCode: 'crisis_support' }), { ...ctx, crisis: true, canStrike: false }), {
    ok: true,
    body: { decision: 'remove', reasonCode: 'crisis_support' },
  });
});

test('decision form: escalate needs a higher lane', () => {
  assert.deepEqual(decisionBody(form({ decision: 'escalate', reasonCode: 'grooming', lane: 'minors_grooming' }), ctx), {
    ok: true,
    body: { decision: 'escalate', reasonCode: 'grooming', lane: 'minors_grooming' },
  });
  assert.equal(decisionBody(form({ decision: 'escalate', reasonCode: 'grooming' }), ctx).ok, false);
  assert.equal(decisionBody(form({ decision: 'escalate', reasonCode: 'grooming', lane: 'spam' }), ctx).ok, false);
});

test('decision result in one line', () => {
  const base: DecisionResult = {
    reflectionId: '018f0000-0000-7000-8000-000000000002',
    previousStatus: 'held',
    status: 'published',
    hidden: false,
    reportsResolved: 1,
    sanctionsLifted: 0,
    strike: null,
    escalated: null,
  };
  assert.equal(decisionResultText(base), 'Held for review → published. 1 report closed.');
  assert.equal(
    decisionResultText({ ...base, status: 'rejected', reportsResolved: 2, strike: { activeStrikes: 2, autoBan: false } }),
    'Held for review → rejected. 2 reports closed. Strike recorded (2 active).',
  );
  assert.match(decisionResultText({ ...base, status: 'removed', strike: { activeStrikes: 4, autoBan: true } }), /4th active strike/);
  assert.equal(
    decisionResultText({ ...base, previousStatus: 'crisis_diverted', status: 'crisis_diverted', reportsResolved: 0, escalated: { reportId: 'r', lane: 'minors_grooming', pages: true } }),
    'Status stays crisis-diverted. Report moved to L1 Minors & grooming; the Owner is paged.',
  );
  assert.match(decisionResultText({ ...base, sanctionsLifted: 1, hidden: true }), /1 automatic sanction lifted/);
});

test('ids and pools', () => {
  assert.equal(isUuid('018f0000-0000-7000-8000-000000000002'), true);
  assert.equal(isUuid('../reports'), false);
  assert.equal(isPool('te'), true);
  assert.equal(isPool('ta'), false);
});
