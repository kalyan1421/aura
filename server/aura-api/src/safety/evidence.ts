import type { Queryable } from '../db/db';

/**
 * Evidence store (`public.evidence_holds`, DS-4 / REQ-ADM-10 / REQ-SAFE-14): a self-contained snapshot of a reported
 * item — the item, its room context, the pseudonym mapping of the people involved and timestamps — kept 180 days.
 * No FK to rooms or accounts, so it survives the room purge (24 h + 7 d) and, as the one documented legal-hold
 * exception, the account purge of the people the reported content is ABOUT (`LEGAL_HOLD_TABLES` in
 * src/account/account-purge.ts, [LEGAL]).
 *
 * Only the SUBJECTS' account ids are held (`account_ids`, and `accountId` inside the snapshot): the reported member,
 * the sender of a reported gesture, or — for a room report — the room's members other than the reporter. The
 * reporter's account id is never copied here (their link lives only in `reports.reporter_user_id`, which the account
 * purge nulls). Restricted: server-only table, never returned to app clients.
 */
export type EvidenceItemKind = 'member' | 'gesture' | 'room' | 'reflection';

export interface EvidenceInput {
  reportId: string | null;
  itemKind: EvidenceItemKind;
  roomId: string | null;
  memberId?: string | null;
  gestureId?: string | null;
  /** F6: the reflection (its text stays encrypted in the snapshot: ciphertext + master-key-wrapped data key, DS-1). */
  reflectionId?: string | null;
  /** `lane:reasonKey`, e.g. `harassment:harassment`. */
  reason: string;
  /** The reporter (null for automatic signals): never held, never given an accountId in the snapshot. */
  reporterUserId: string | null;
  /** The resolved subject when the room data is already gone (kept in `account_ids`). */
  fallbackSubjectUserId?: string | null;
  holdDays: number;
  /** Report metadata copied into the snapshot (reason, lane, note, source). Never account ids. */
  context: Record<string, unknown>;
}

interface MemberSnap {
  member_id: string;
  user_id: string;
  pseudonym: string;
  mood_at_join: string;
  joined_at: Date;
  left_at: Date | null;
}

const MEMBER_SNAP_COLS = 'member_id, user_id, pseudonym, mood_at_join, joined_at, left_at';

export async function createEvidenceHold(q: Queryable, input: EvidenceInput): Promise<string> {
  const room = input.roomId
    ? (
        await q.query(
          `select id, kind, language_pool, quadrant, tz_region, seed_mood_id, capacity, status, created_at, opened_at,
                  joins_close_at, memory_at, purge_at
             from public.rooms where id = $1`,
          [input.roomId],
        )
      ).rows[0] ?? null
    : null;

  let members: MemberSnap[] = [];
  let subjects = new Set<string>();
  let gestures: Array<Record<string, unknown>> = [];
  let reflection: Record<string, unknown> | null = null;
  if (input.itemKind === 'reflection' && input.reflectionId) {
    // The reflection itself (encrypted: NestJS alone can open it, for 180 days, even after the author's purge), its
    // author's membership (the subject) and the gestures sent to it.
    const x = (
      await q.query<{ id: string; member_id: string; status: string; body_ct: string | null; body_key: string | null; char_count: number;
        language_pool: string; involves_minor: boolean; strict: boolean; stage: string | null; hold_reason: string | null;
        reject_reason: string | null; mod_scores: unknown; rule_hits: string[]; created_at: Date; published_at: Date | null }>(
        `select id, member_id, status, body_ct, body_key, char_count, language_pool, involves_minor, strict, stage, hold_reason,
                reject_reason, mod_scores, rule_hits, created_at, published_at
           from public.reflections where id = $1`,
        [input.reflectionId],
      )
    ).rows[0];
    if (x) {
      reflection = {
        id: x.id, memberId: x.member_id, status: x.status, bodyCt: x.body_ct, bodyKey: x.body_key, charCount: x.char_count,
        languagePool: x.language_pool, involvesMinor: x.involves_minor, strict: x.strict, stage: x.stage, holdReason: x.hold_reason,
        rejectReason: x.reject_reason, scores: x.mod_scores, ruleHits: x.rule_hits, createdAt: x.created_at, publishedAt: x.published_at,
      };
      members = (await q.query<MemberSnap>(`select ${MEMBER_SNAP_COLS} from public.room_members where member_id = $1`, [x.member_id])).rows;
      subjects = new Set(members.map((m) => m.user_id));
      gestures = (
        await q.query(
          `select id, type, target, from_member_id, to_member_id, dropped, created_at
             from public.room_gestures where to_reflection_id = $1 order by created_at`,
          [x.id],
        )
      ).rows;
    }
  } else if (room && input.itemKind === 'member' && input.memberId) {
    members = (
      await q.query<MemberSnap>(`select ${MEMBER_SNAP_COLS} from public.room_members where room_id = $1 and member_id = $2`, [
        input.roomId,
        input.memberId,
      ])
    ).rows;
    subjects = new Set(members.map((m) => m.user_id));
    gestures = (
      await q.query(
        `select g.id, g.type, g.target, g.to_member_id, t.pseudonym as to_pseudonym, g.dropped, g.created_at
           from public.room_gestures g left join public.room_members t on t.member_id = g.to_member_id
          where g.room_id = $1 and g.from_member_id = $2 order by g.created_at`,
        [input.roomId, input.memberId],
      )
    ).rows;
  } else if (room && input.itemKind === 'gesture' && input.gestureId) {
    gestures = (
      await q.query(
        `select g.id, g.type, g.target, g.from_member_id, g.to_member_id, g.dropped, g.created_at
           from public.room_gestures g where g.room_id = $1 and g.id = $2`,
        [input.roomId, input.gestureId],
      )
    ).rows;
    const ids = gestures.flatMap((g) => [g.from_member_id, g.to_member_id]).filter((x): x is string => typeof x === 'string');
    if (ids.length) {
      members = (
        await q.query<MemberSnap>(`select ${MEMBER_SNAP_COLS} from public.room_members where member_id = any($1::uuid[])`, [ids])
      ).rows;
    }
    const senders = new Set(gestures.map((g) => g.from_member_id));
    subjects = new Set(members.filter((m) => senders.has(m.member_id)).map((m) => m.user_id));
  } else if (room) {
    members = (await q.query<MemberSnap>(`select ${MEMBER_SNAP_COLS} from public.room_members where room_id = $1 order by joined_at`, [input.roomId]))
      .rows;
    subjects = new Set(members.map((m) => m.user_id));
    gestures = (
      await q.query(
        `select id, type, target, from_member_id, to_member_id, dropped, created_at
           from public.room_gestures where room_id = $1 order by created_at desc limit 200`,
        [input.roomId],
      )
    ).rows;
  }
  if (input.reporterUserId) subjects.delete(input.reporterUserId);
  if (subjects.size === 0 && input.fallbackSubjectUserId && input.fallbackSubjectUserId !== input.reporterUserId) {
    subjects.add(input.fallbackSubjectUserId);
  }

  const snapshot = {
    capturedAt: new Date().toISOString(),
    report: { reportId: input.reportId, ...input.context },
    room,
    members: members.map((m) => ({
      memberId: m.member_id,
      accountId: subjects.has(m.user_id) ? m.user_id : null,
      isReporter: m.user_id === input.reporterUserId,
      pseudonym: m.pseudonym,
      moodAtJoin: m.mood_at_join,
      joinedAt: m.joined_at,
      leftAt: m.left_at,
    })),
    gestures,
    ...(reflection ? { reflection } : {}),
  };
  const itemRef =
    input.itemKind === 'member'
      ? input.memberId
      : input.itemKind === 'gesture'
        ? input.gestureId
        : input.itemKind === 'reflection'
          ? input.reflectionId
          : input.roomId;
  const r = await q.query<{ id: string }>(
    `insert into public.evidence_holds (report_id, item_kind, item_ref, reason, account_ids, snapshot, hold_until)
     values ($1, $2, $3, $4, $5::uuid[], $6::jsonb, now() + make_interval(days => $7))
     returning id`,
    [input.reportId, input.itemKind, itemRef ?? null, input.reason, [...subjects], JSON.stringify(snapshot), input.holdDays],
  );
  return r.rows[0].id;
}

/**
 * Room purge backstop: every report on the room gets its evidence copied before the room is deleted (reports snapshot
 * at filing time already, so this normally finds nothing). Returns how many holds were created.
 */
export async function ensureEvidenceForRoom(q: Queryable, roomId: string, holdDays: number): Promise<number> {
  const reports = await q.query<{
    id: string;
    target_kind: EvidenceItemKind;
    target_member_id: string | null;
    target_gesture_id: string | null;
    target_reflection_id: string | null;
    reporter_user_id: string | null;
    target_user_id: string | null;
    lane: string;
    reason: number;
    source: string;
  }>(
    `select id, target_kind, target_member_id, target_gesture_id, target_reflection_id, reporter_user_id, target_user_id, lane,
            reason, source
       from public.reports where room_id = $1 and evidence_hold_id is null`,
    [roomId],
  );
  for (const rp of reports.rows) {
    const holdId = await createEvidenceHold(q, {
      reportId: rp.id,
      itemKind: rp.target_kind,
      roomId,
      memberId: rp.target_member_id,
      gestureId: rp.target_gesture_id,
      reflectionId: rp.target_reflection_id,
      reason: `${rp.lane}:purge`,
      reporterUserId: rp.reporter_user_id,
      fallbackSubjectUserId: rp.target_user_id,
      holdDays,
      context: { lane: rp.lane, reason: rp.reason, source: rp.source, copiedAt: 'room_purge' },
    });
    await q.query('update public.reports set evidence_hold_id = $2 where id = $1', [rp.id, holdId]);
  }
  return reports.rows.length;
}

/** Evidence past its hold (and not extended) is deleted by the lifecycle worker. */
export async function purgeExpiredEvidence(q: Queryable, batch = 1000): Promise<number> {
  const r = await q.query(
    `delete from public.evidence_holds where id in (
       select id from public.evidence_holds where hold_until <= now() order by hold_until limit $1)`,
    [batch],
  );
  return r.rowCount ?? 0;
}
