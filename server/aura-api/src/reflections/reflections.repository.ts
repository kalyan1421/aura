import type { Queryable } from '../db/db';
import { HIDDEN_ACCOUNT_SQL } from '../safety/safety-types';
import type { HoldReason, RejectReason, Scores } from './decide';

/** Server-side reflection row (never returned as is: views in reflection-views.ts). */
export interface ReflectionRow {
  id: string;
  room_id: string;
  member_id: string;
  user_id: string;
  status: 'pending' | 'published' | 'held' | 'rejected' | 'crisis_diverted' | 'removed' | 'deleted' | 'expired';
  body_ct: string | null;
  body_key: string | null;
  char_count: number;
  text_hash: string | null;
  language_pool: 'en' | 'te' | 'hi';
  involves_minor: boolean;
  strict: boolean;
  overnight: boolean;
  stage: string | null;
  hold_reason: HoldReason | null;
  reject_reason: RejectReason | null;
  mod_scores: Scores | null;
  rule_hits: string[];
  created_at: Date;
  decided_at: Date | null;
  decided_by: string | null;
  published_at: Date | null;
  removed_at: Date | null;
  hidden_at: Date | null;
}

/** A row joined with its author's pseudonym and (for the author's own published items) the delivered gesture count. */
export interface ListedRow extends ReflectionRow {
  pseudonym: string;
  gesture_count: number;
}

const COLS = `r.id, r.room_id, r.member_id, r.user_id, r.status, r.body_ct, r.body_key, r.char_count, r.text_hash, r.language_pool,
              r.involves_minor, r.strict, r.overnight, r.stage, r.hold_reason, r.reject_reason, r.mod_scores, r.rule_hits,
              r.created_at, r.decided_at, r.decided_by, r.published_at, r.removed_at, r.hidden_at`;

/** Statuses the author sees in the list (crisis-diverted, deleted and expired never are). */
const MINE_LISTED = `('pending','held','rejected','removed','published')`;

/**
 * Visibility for a viewer (contracts/api/v1-reflections.md §1.1): own items in MINE_LISTED; others' only when
 * published, not hidden by reports, no block either way, not muted by the viewer in this room, not reported by the
 * viewer, and the author isn't hidden (suspended / paused / closed / pending deletion). `$2` viewer user, `$3` viewer
 * member.
 */
const VISIBLE_SQL = `(
  (r.user_id = $2 and r.status in ${MINE_LISTED})
  or (r.status = 'published' and r.hidden_at is null and r.user_id <> $2
      and not exists (select 1 from public.blocks b
                       where (b.blocker_user_id = $2 and b.blocked_user_id = r.user_id)
                          or (b.blocker_user_id = r.user_id and b.blocked_user_id = $2))
      and not exists (select 1 from public.room_mutes mu where mu.muter_member_id = $3 and mu.muted_member_id = r.member_id)
      and not exists (select 1 from public.reports rp where rp.target_reflection_id = r.id and rp.reporter_user_id = $2)
      and not ${HIDDEN_ACCOUNT_SQL('r.user_id')})
)`;

export class ReflectionsRepository {
  async find(q: Queryable, id: string, lock = false): Promise<ReflectionRow | null> {
    const r = await q.query<ReflectionRow>(`select ${COLS} from public.reflections r where r.id = $1 ${lock ? 'for update' : ''}`, [id]);
    return r.rows[0] ?? null;
  }

  /** What `viewer` may see in `roomId`, newest first. `onlyId` narrows to one reflection. */
  async visible(q: Queryable, roomId: string, viewer: { userId: string; memberId: string }, onlyId: string | null = null, limit = 200): Promise<ListedRow[]> {
    const r = await q.query<ListedRow>(
      `select ${COLS}, m.pseudonym,
              case when r.user_id = $2 and r.status = 'published'
                   then (select count(*) from public.room_gestures g where g.to_reflection_id = r.id and g.dropped is null)::int
                   else 0 end as gesture_count
         from public.reflections r join public.room_members m on m.member_id = r.member_id
        where r.room_id = $1 and ${VISIBLE_SQL} and ($4::uuid is null or r.id = $4)
        order by r.created_at desc, r.id desc
        limit $5`,
      [roomId, viewer.userId, viewer.memberId, onlyId, limit],
    );
    return r.rows;
  }

  /** Sent in the last 24 h (rejections and crisis diversions don't count; deleted ones do): in this room and overall. */
  async sentCounts(q: Queryable, userId: string, roomId: string): Promise<{ room: number; account: number }> {
    const r = await q.query<{ room: number; account: number }>(
      `select count(*) filter (where room_id = $2)::int as room, count(*)::int as account
         from public.reflections
        where user_id = $1 and created_at > now() - interval '24 hours'
          and status not in ('rejected','crisis_diverted')`,
      [userId, roomId],
    );
    return r.rows[0] ?? { room: 0, account: 0 };
  }

  /** Other rooms where this author posted the same words in the last 24 h (near-duplicate spam, PRD F6 step 5). */
  async duplicateRooms(q: Queryable, userId: string, textHash: string, roomId: string): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(distinct room_id)::int as n from public.reflections
        where user_id = $1 and text_hash = $2 and room_id <> $3 and created_at > now() - interval '24 hours'`,
      [userId, textHash, roomId],
    );
    return r.rows[0]?.n ?? 0;
  }

  /** An active strike (REQ: "all reflections held while an account has an active strike"). */
  async hasActiveStrike(q: Queryable, userId: string): Promise<boolean> {
    const r = await q.query('select 1 from public.strikes where user_id = $1 and revoked_at is null and expires_at > now() limit 1', [userId]);
    return (r.rowCount ?? 0) > 0;
  }

  /** A moderator's or the pipeline's shadow-mute (not the gesture-flood one): their reflections are held. */
  async hasShadowMute(q: Queryable, userId: string): Promise<boolean> {
    const r = await q.query(
      `select 1 from public.sanctions s where s.user_id = $1 and s.kind = 'shadow_mute'
          and s.lifted_at is null and s.starts_at <= now() and (s.ends_at is null or s.ends_at > now()) limit 1`,
      [userId],
    );
    return (r.rowCount ?? 0) > 0;
  }

  /** Every account currently in the room (not left), for the invisible under-18 check. */
  async roomAccounts(q: Queryable, roomId: string): Promise<string[]> {
    const r = await q.query<{ user_id: string }>('select user_id from public.room_members where room_id = $1 and left_at is null', [roomId]);
    return r.rows.map((x) => x.user_id);
  }

  async insert(
    q: Queryable,
    x: {
      id: string;
      roomId: string;
      memberId: string;
      userId: string;
      status: ReflectionRow['status'];
      bodyCt: string;
      bodyKey: string;
      charCount: number;
      textHash: string;
      languagePool: string;
      involvesMinor: boolean;
      strict: boolean;
      overnight: boolean;
      stage: string | null;
      holdReason: HoldReason | null;
      rejectReason: RejectReason | null;
      scores: Scores | null;
      ruleHits: string[];
      decided: boolean;
    },
  ): Promise<ReflectionRow> {
    const r = await q.query<ReflectionRow>(
      `insert into public.reflections as r (id, room_id, member_id, user_id, status, body_ct, body_key, char_count, text_hash, language_pool,
                                       involves_minor, strict, overnight, stage, hold_reason, reject_reason, mod_scores, rule_hits,
                                       decided_at, decided_by, published_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17::jsonb, $18::text[],
               case when $19 then now() end, case when $19 then 'system:pipeline' end,
               case when $5 = 'published' then now() end)
       returning ${COLS}`,
      [
        x.id,
        x.roomId,
        x.memberId,
        x.userId,
        x.status,
        x.bodyCt,
        x.bodyKey,
        x.charCount,
        x.textHash,
        x.languagePool,
        x.involvesMinor,
        x.strict,
        x.overnight,
        x.stage,
        x.holdReason,
        x.rejectReason,
        x.scores ? JSON.stringify(x.scores) : null,
        x.ruleHits,
        x.decided,
      ],
    );
    return r.rows[0];
  }

  /** Applies the pipeline's decision to a pending row (no-op when it is no longer pending, e.g. withdrawn). */
  async decidePending(
    q: Queryable,
    id: string,
    d: {
      status: ReflectionRow['status'];
      stage: string;
      holdReason: HoldReason | null;
      rejectReason: RejectReason | null;
      scores: Scores | null;
      /** null = keep what phase A stored. */
      overnight: boolean | null;
      ruleHits: string[] | null;
    },
  ): Promise<ReflectionRow | null> {
    const r = await q.query<ReflectionRow>(
      `update public.reflections r
          set status = $2, stage = $3, hold_reason = $4, reject_reason = $5, mod_scores = $6::jsonb,
              overnight = coalesce($7::boolean, r.overnight), rule_hits = coalesce($8::text[], r.rule_hits),
              decided_at = now(), decided_by = 'system:pipeline',
              published_at = case when $2 = 'published' then now() else r.published_at end
        where r.id = $1 and r.status = 'pending'
        returning ${COLS}`,
      [id, d.status, d.stage, d.holdReason, d.rejectReason, d.scores ? JSON.stringify(d.scores) : null, d.overnight, d.ruleHits],
    );
    return r.rows[0] ?? null;
  }
}
