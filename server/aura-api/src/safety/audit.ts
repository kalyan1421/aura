import { createHmac, hkdfSync } from 'node:crypto';
import type { Queryable } from '../db/db';

/**
 * Moderation audit log (`public.moderation_actions`: append-only, hash-chained in the DB). Rows never hold raw account
 * ids or content: the subject is `subjectHash` = HMAC-SHA256 of the account id under a key derived from the DS-1
 * master key, so the console can find an account's history while it exists, and rows kept after the account purge
 * ("hashed audit rows", 19 admin console) point at nobody.
 */
const subjectKeys = new WeakMap<Buffer, Buffer>();

function subjectKey(masterKey: Buffer): Buffer {
  let k = subjectKeys.get(masterKey);
  if (!k) {
    k = Buffer.from(hkdfSync('sha256', masterKey, Buffer.alloc(0), 'aura/moderation-subject/v1', 32));
    subjectKeys.set(masterKey, k);
  }
  return k;
}

export function subjectHash(masterKey: Buffer, userId: string): string {
  return createHmac('sha256', subjectKey(masterKey)).update(userId.toLowerCase()).digest('hex');
}

export interface AuditEntry {
  /** `system` for automatic actions, else the staff identity (the admin console stage). */
  actor: string;
  action: string;
  reportId?: string | null;
  subjectHash?: string | null;
  reasonCode?: string | null;
  /** Counts, kinds, durations — never content, pseudonyms or raw ids. */
  detail?: Record<string, unknown>;
}

export async function appendAudit(q: Queryable, e: AuditEntry): Promise<number> {
  const r = await q.query<{ id: string }>(
    `insert into public.moderation_actions (actor, action, report_id, subject_hash, reason_code, detail)
     values ($1, $2, $3, $4, $5, $6::jsonb) returning id`,
    [e.actor, e.action, e.reportId ?? null, e.subjectHash ?? null, e.reasonCode ?? null, JSON.stringify(e.detail ?? {})],
  );
  return Number(r.rows[0].id);
}

export interface AuditRow {
  id: number;
  createdAt: string;
  actor: string;
  action: string;
  reportId: string | null;
  subjectHash: string | null;
  reasonCode: string | null;
  detail: Record<string, unknown>;
  prevHash: string | null;
  rowHash: string;
}

export async function readAudit(q: Queryable, opts: { limit?: number; beforeId?: number } = {}): Promise<AuditRow[]> {
  const r = await q.query<{
    id: string;
    created_at: Date;
    actor: string;
    action: string;
    report_id: string | null;
    subject_hash: string | null;
    reason_code: string | null;
    detail: Record<string, unknown>;
    prev_hash: string | null;
    row_hash: string;
  }>(
    `select id, created_at, actor, action, report_id, subject_hash, reason_code, detail, prev_hash, row_hash
       from public.moderation_actions where ($1::bigint is null or id < $1) order by id desc limit $2`,
    [opts.beforeId ?? null, Math.min(Math.max(opts.limit ?? 100, 1), 500)],
  );
  return r.rows.map((x) => ({
    id: Number(x.id),
    createdAt: x.created_at.toISOString(),
    actor: x.actor,
    action: x.action,
    reportId: x.report_id,
    subjectHash: x.subject_hash,
    reasonCode: x.reason_code,
    detail: x.detail,
    prevHash: x.prev_hash,
    rowHash: x.row_hash,
  }));
}

/** Recomputes the chain in SQL (same formula as the insert trigger); true when every link and hash holds. */
export async function verifyAuditChain(q: Queryable): Promise<boolean> {
  // After the retention job pruned the oldest rows (src/queues/retention.ts), the oldest remaining row links to the
  // last pruned row, whose hash `moderation_audit_anchor` keeps (migration 20261005000014). Read through
  // `admin_audit_anchor()` (migration 20261005000016) so the console can run this as aura_admin, which has no grant on
  // the anchor table itself.
  const r = await q.query<{ ok: boolean | null }>(
    `with anchor as (select x.last_pruned_hash from public.admin_audit_anchor() x),
     ordered as (
       select a.*, coalesce(lag(a.row_hash) over (order by a.id), (select last_pruned_hash from anchor)) as expected_prev
         from public.moderation_actions a)
     select bool_and(
              prev_hash is not distinct from expected_prev
              and row_hash = encode(sha256(convert_to(
                coalesce(prev_hash, '') || '|' || id::text || '|' ||
                to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US') || '|' || actor || '|' || action || '|' ||
                coalesce(report_id::text, '') || '|' || coalesce(subject_hash, '') || '|' || coalesce(reason_code, '') || '|' ||
                detail::text, 'UTF8')), 'hex')) as ok
       from ordered`,
  );
  return r.rows[0]?.ok ?? true;
}

/**
 * The chain check for one id range (the nightly export): every row's hash recomputes, each row links to the one before
 * it, and the first row links to whatever precedes the range (the previous row, or the retention anchor).
 */
export async function verifyAuditRange(q: Queryable, fromId: number, toId: number): Promise<boolean> {
  const r = await q.query<{ ok: boolean | null }>(
    `with before as (select coalesce((select a.row_hash from public.moderation_actions a where a.id < $1 order by a.id desc limit 1),
                                     (select x.last_pruned_hash from public.admin_audit_anchor() x)) as h),
     seg as (
       select a.*, coalesce(lag(a.row_hash) over (order by a.id), (select h from before)) as expected_prev
         from public.moderation_actions a where a.id between $1 and $2)
     select bool_and(
              prev_hash is not distinct from expected_prev
              and row_hash = encode(sha256(convert_to(
                coalesce(prev_hash, '') || '|' || id::text || '|' ||
                to_char(created_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US') || '|' || actor || '|' || action || '|' ||
                coalesce(report_id::text, '') || '|' || coalesce(subject_hash, '') || '|' || coalesce(reason_code, '') || '|' ||
                detail::text, 'UTF8')), 'hex')) as ok
       from seg`,
    [fromId, toId],
  );
  return r.rows[0]?.ok ?? true;
}
