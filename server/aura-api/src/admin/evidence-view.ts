import { createHash } from 'node:crypto';

/**
 * Evidence for the console (pure; unit-tested). `evidence_holds.snapshot` (src/safety/evidence.ts) holds the reported
 * item, its room context, the pseudonym mapping with the SUBJECTS' account ids, gestures and timestamps.
 *
 * - `evidenceView` is what the item screen shows: subjects as an HMAC (`subjectHash`), everyone else by room pseudonym,
 *   and the reporter never identified (shown only as "Reporter", no pseudonym, no member id — PRD 19). There is no
 *   private content in a snapshot to begin with (no check-ins, notes, voice or capsules; DS-1: no decrypt route).
 * - `evidenceBundle` is the Owner's audited break-glass export for a mandatory report: the raw snapshot with the
 *   subjects' account ids (identifiers leave only this way, PRD 19 SOP step 3), the reporter still withheld, plus a
 *   SHA-256 over the canonical JSON for chain of custody.
 */
type Json = null | boolean | number | string | Json[] | { [k: string]: Json };
type Obj = { [k: string]: Json };

const isObj = (v: unknown): v is Obj => typeof v === 'object' && v !== null && !Array.isArray(v);
const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
const arr = (v: unknown): Json[] => (Array.isArray(v) ? (v as Json[]) : []);

export type PersonRole = 'subject' | 'reporter' | 'member';

export interface EvidencePerson {
  label: string;
  role: PersonRole;
  /** HMAC of the account id (subjects only) — matches the queue's `subject.hash`. */
  subjectHash: string | null;
  moodAtJoin: string | null;
  joinedAt: string | null;
  leftAt: string | null;
}

export interface EvidenceGesture {
  type: string | null;
  target: string | null;
  from: string | null;
  to: string | null;
  dropped: string | null;
  at: string | null;
}

export interface EvidenceView {
  evidenceHoldId: string;
  itemKind: string;
  reason: string;
  capturedAt: string | null;
  createdAt: string;
  holdUntil: string;
  mandatoryReportRequired: boolean;
  mandatoryReportClosed: boolean;
  room: { quadrant: string | null; languagePool: string | null; tzRegion: string | null; createdAt: string | null; memoryAt: string | null; purgeAt: string | null } | null;
  /** The reporter's note, if any (moderators only). */
  note: string | null;
  people: EvidencePerson[];
  gestures: EvidenceGesture[];
}

export interface EvidenceHoldRow {
  id: string;
  report_id: string | null;
  item_kind: string;
  item_ref: string | null;
  reason: string;
  account_ids: string[];
  snapshot: unknown;
  created_at: Date;
  hold_until: Date;
  mandatory_report_required: boolean;
  reported_to: string | null;
  report_ref: string | null;
  legal_reason: string | null;
}

const MAX_GESTURES = 200;

function reporterMemberIdOf(snap: Obj): string | null {
  const report = isObj(snap.report) ? snap.report : null;
  return report ? str(report.reporterMemberId) : null;
}

export function evidenceView(h: EvidenceHoldRow, hash: (accountId: string) => string): EvidenceView {
  const snap: Obj = isObj(h.snapshot) ? h.snapshot : {};
  const reporterMemberId = reporterMemberIdOf(snap);
  const labels = new Map<string, string>();
  if (reporterMemberId) labels.set(reporterMemberId, 'Reporter');

  const people: EvidencePerson[] = arr(snap.members).filter(isObj).map((m) => {
    const memberId = str(m.memberId);
    const isReporter = m.isReporter === true || (!!reporterMemberId && memberId === reporterMemberId);
    const accountId = str(m.accountId);
    const role: PersonRole = isReporter ? 'reporter' : accountId ? 'subject' : 'member';
    const label = isReporter ? 'Reporter' : (str(m.pseudonym) ?? 'Member');
    if (memberId) labels.set(memberId, label);
    return {
      label,
      role,
      subjectHash: !isReporter && accountId ? hash(accountId) : null,
      moodAtJoin: isReporter ? null : str(m.moodAtJoin),
      joinedAt: isReporter ? null : str(m.joinedAt),
      leftAt: isReporter ? null : str(m.leftAt),
    };
  });
  const subjectLabel = people.find((p) => p.role === 'subject')?.label ?? null;
  const labelOf = (memberId: unknown, fallback?: unknown): string | null => {
    const id = str(memberId);
    if (!id) return null;
    return labels.get(id) ?? str(fallback) ?? 'Member';
  };

  const gestures: EvidenceGesture[] = arr(snap.gestures)
    .filter(isObj)
    .slice(0, MAX_GESTURES)
    .map((g) => ({
      type: str(g.type),
      target: str(g.target),
      // Member reports snapshot the subject's own gestures (no sender column).
      from: 'from_member_id' in g ? labelOf(g.from_member_id) : h.item_kind === 'member' ? subjectLabel : null,
      to: labelOf(g.to_member_id, g.to_pseudonym),
      dropped: str(g.dropped),
      at: str(g.created_at),
    }));

  const room = isObj(snap.room) ? snap.room : null;
  const report = isObj(snap.report) ? snap.report : null;
  return {
    evidenceHoldId: h.id,
    itemKind: h.item_kind,
    reason: h.reason,
    capturedAt: str(snap.capturedAt),
    createdAt: h.created_at.toISOString(),
    holdUntil: h.hold_until.toISOString(),
    mandatoryReportRequired: h.mandatory_report_required,
    mandatoryReportClosed: !!h.report_ref || !!h.legal_reason,
    room: room
      ? {
          quadrant: str(room.quadrant),
          languagePool: str(room.language_pool),
          tzRegion: str(room.tz_region),
          createdAt: str(room.created_at),
          memoryAt: str(room.memory_at),
          purgeAt: str(room.purge_at),
        }
      : null,
    note: report ? str(report.note) : null,
    people,
    gestures,
  };
}

/** Deep copy of the snapshot with the reporter withheld (no member id, pseudonym or link from gestures). */
export function withoutReporter(snapshot: unknown): Json {
  const snap: Obj = isObj(snapshot) ? (JSON.parse(JSON.stringify(snapshot)) as Obj) : {};
  const reporterIds = new Set<string>();
  const rid = reporterMemberIdOf(snap);
  if (rid) reporterIds.add(rid);
  for (const m of arr(snap.members).filter(isObj)) {
    if (m.isReporter === true && typeof m.memberId === 'string') reporterIds.add(m.memberId);
  }
  if (isObj(snap.report) && 'reporterMemberId' in snap.report) snap.report.reporterMemberId = rid ? 'withheld' : null;
  snap.members = arr(snap.members)
    .filter(isObj)
    .map((m) =>
      m.isReporter === true || (typeof m.memberId === 'string' && reporterIds.has(m.memberId))
        ? { isReporter: true, memberId: 'withheld', pseudonym: 'withheld', accountId: null }
        : m,
    );
  snap.gestures = arr(snap.gestures)
    .filter(isObj)
    .map((g) => {
      const out: Obj = { ...g };
      for (const k of ['from_member_id', 'to_member_id']) {
        if (typeof out[k] === 'string' && reporterIds.has(out[k] as string)) out[k] = 'reporter';
      }
      if (typeof g.to_member_id === 'string' && reporterIds.has(g.to_member_id)) out.to_pseudonym = 'Reporter';
      return out;
    });
  return snap;
}

/** JSON with object keys sorted at every level: the same data always hashes the same. */
export function canonicalJson(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map((x) => canonicalJson(x)).join(',')}]`;
  if (v instanceof Date) return JSON.stringify(v.toISOString());
  if (isObj(v)) {
    return `{${Object.keys(v)
      .sort()
      .filter((k) => v[k] !== undefined)
      .map((k) => `${JSON.stringify(k)}:${canonicalJson(v[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(v ?? null);
}

export interface EvidenceBundle {
  bundle: 'aura-evidence/v1';
  integrity: { algorithm: 'sha256'; canonicalJsonSha256: string };
  content: Obj;
}

/** The export: `content` is hashed; `integrity` sits beside it. */
export function evidenceBundle(content: Obj): EvidenceBundle {
  const sha = createHash('sha256').update(canonicalJson(content), 'utf8').digest('hex');
  return { bundle: 'aura-evidence/v1', integrity: { algorithm: 'sha256', canonicalJsonSha256: sha }, content };
}
