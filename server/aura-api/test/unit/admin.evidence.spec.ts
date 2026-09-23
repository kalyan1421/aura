/**
 * Evidence for the console (PRD 19 "Item view and the privacy boundary", SOP step 3): subjects appear as an HMAC,
 * the reporter is never identified (no pseudonym, no member id), and the break-glass bundle keeps the subjects'
 * account ids with a stable SHA-256 over canonical JSON.
 */
import { canonicalJson, evidenceBundle, evidenceView, withoutReporter, type EvidenceHoldRow } from '../../src/admin/evidence-view';

const SUBJECT = '0192f0c2-7a4e-7c1a-9b3d-00000000aaaa';
const hash = (id: string): string => `h:${id.slice(-4)}`;

const snapshot = {
  capturedAt: '2026-10-12T21:30:00.000Z',
  report: { reportId: 'r1', reason: 5, lane: 'minors_grooming', reporterMemberId: 'm-rep', note: 'asked for my school' },
  room: { id: 'room1', quadrant: 'rain', language_pool: 'en', tz_region: 'south_asia', created_at: '2026-10-12T10:00:00.000Z', memory_at: 'x', purge_at: 'y' },
  members: [
    { memberId: 'm-sub', accountId: SUBJECT, isReporter: false, pseudonym: 'Quiet Comet', moodAtJoin: 'lonely', joinedAt: 'j1', leftAt: null },
    { memberId: 'm-rep', accountId: null, isReporter: true, pseudonym: 'Gentle Moon', moodAtJoin: 'numb', joinedAt: 'j2', leftAt: null },
  ],
  gestures: [
    { id: 'g1', type: 'hug', target: 'member', to_member_id: 'm-rep', to_pseudonym: 'Gentle Moon', dropped: null, created_at: 't1' },
    { id: 'g2', type: 'me_too', target: 'room', to_member_id: null, dropped: 'over_limit', created_at: 't2' },
  ],
};

const hold = (snap: unknown = snapshot): EvidenceHoldRow => ({
  id: 'e1',
  report_id: 'r1',
  item_kind: 'member',
  item_ref: 'm-sub',
  reason: 'minors_grooming:contact_info',
  account_ids: [SUBJECT],
  snapshot: snap,
  created_at: new Date('2026-10-12T21:30:00.000Z'),
  hold_until: new Date('2027-04-10T21:30:00.000Z'),
  mandatory_report_required: true,
  reported_to: null,
  report_ref: null,
  legal_reason: null,
});

describe('evidence view (console)', () => {
  const v = evidenceView(hold(), hash);

  it('subjects by pseudonym + HMAC; the reporter only as "Reporter"', () => {
    expect(v.people).toEqual([
      { label: 'Quiet Comet', role: 'subject', subjectHash: 'h:aaaa', moodAtJoin: 'lonely', joinedAt: 'j1', leftAt: null },
      { label: 'Reporter', role: 'reporter', subjectHash: null, moodAtJoin: null, joinedAt: null, leftAt: null },
    ]);
    const blob = JSON.stringify(v);
    expect(blob).not.toContain('Gentle Moon');
    expect(blob).not.toContain('m-rep');
    expect(blob).not.toContain(SUBJECT);
  });

  it('gestures: the subject’s own, with the reporter masked as recipient', () => {
    expect(v.gestures[0]).toEqual({ type: 'hug', target: 'member', from: 'Quiet Comet', to: 'Reporter', dropped: null, at: 't1' });
    expect(v.gestures[1]).toMatchObject({ to: null, dropped: 'over_limit' });
  });

  it('room context and the report note; mandatory-report state', () => {
    expect(v.room).toMatchObject({ quadrant: 'rain', languagePool: 'en', tzRegion: 'south_asia' });
    expect(v.note).toBe('asked for my school');
    expect(v).toMatchObject({ mandatoryReportRequired: true, mandatoryReportClosed: false, holdUntil: '2027-04-10T21:30:00.000Z' });
  });

  it('tolerates a malformed snapshot', () => {
    expect(evidenceView(hold(null), hash)).toMatchObject({ people: [], gestures: [], room: null, note: null });
  });
});

describe('break-glass bundle', () => {
  it('keeps the subject’s account id, withholds the reporter everywhere', () => {
    const s = JSON.stringify(withoutReporter(snapshot));
    expect(s).toContain(SUBJECT);
    expect(s).not.toContain('m-rep');
    expect(s).not.toContain('Gentle Moon');
    expect(s).toContain('"reporterMemberId":"withheld"');
    expect(JSON.stringify(snapshot)).toContain('m-rep'); // the input is not mutated
  });

  it('canonical JSON is key-order independent, so the hash is stable', () => {
    expect(canonicalJson({ b: 1, a: { d: [2, { z: 1, y: 2 }], c: null } })).toBe('{"a":{"c":null,"d":[2,{"y":2,"z":1}]},"b":1}');
    const one = evidenceBundle({ x: 1, y: { b: 2, a: 1 } });
    const two = evidenceBundle({ y: { a: 1, b: 2 }, x: 1 });
    expect(one.integrity.canonicalJsonSha256).toMatch(/^[0-9a-f]{64}$/);
    expect(one.integrity.canonicalJsonSha256).toBe(two.integrity.canonicalJsonSha256);
    expect(evidenceBundle({ x: 2 }).integrity.canonicalJsonSha256).not.toBe(one.integrity.canonicalJsonSha256);
  });
});
