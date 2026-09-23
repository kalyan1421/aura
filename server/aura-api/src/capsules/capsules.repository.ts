import { Injectable } from '@nestjs/common';
import { PRIVATE_MEDIA_BUCKET } from '../account/private-media';
import type { Queryable } from '../db/db';
import { capsuleObjectPrefix } from '../media/media-paths';
import type { Quadrant } from '../rules';

export interface CapsuleRow {
  id: string;
  userId: string;
  unlockType: 'date' | 'mood';
  unlockLocalDate: string | null;
  triggerMoodId: string | null;
  triggerQuadrant: Quadrant | null;
  payloadCt: string | null;
  sealedAt: Date;
  armedAt: Date | null;
  cycle: number;
  firedAt: Date | null;
  cooldownUntil: Date | null;
  openedAt: Date | null;
  openedDeviceTs: Date | null;
  deletedAt: Date | null;
}

export interface NewCapsule {
  id: string;
  userId: string;
  unlockType: 'date' | 'mood';
  unlockLocalDate: string | null;
  triggerMoodId: string | null;
  triggerQuadrant: Quadrant | null;
  payloadCt: string;
  sealedAt: Date;
  armedAt: Date | null;
}

interface Row {
  id: string;
  user_id: string;
  unlock_type: 'date' | 'mood';
  unlock_local_date: string | null;
  trigger_mood_id: string | null;
  trigger_quadrant: Quadrant | null;
  payload_ct: string | null;
  sealed_at: Date;
  armed_at: Date | null;
  cycle: number;
  fired_at: Date | null;
  cooldown_until: Date | null;
  opened_at: Date | null;
  opened_device_ts: Date | null;
  deleted_at: Date | null;
}

const COLS = `id, user_id, unlock_type, unlock_local_date, trigger_mood_id, trigger_quadrant, payload_ct, sealed_at,
  armed_at, cycle, fired_at, cooldown_until, opened_at, opened_device_ts, deleted_at`;

const toRow = (r: Row): CapsuleRow => ({
  id: r.id,
  userId: r.user_id,
  unlockType: r.unlock_type,
  unlockLocalDate: r.unlock_local_date,
  triggerMoodId: r.trigger_mood_id,
  triggerQuadrant: r.trigger_quadrant,
  payloadCt: r.payload_ct,
  sealedAt: r.sealed_at,
  armedAt: r.armed_at,
  cycle: r.cycle,
  firedAt: r.fired_at,
  cooldownUntil: r.cooldown_until,
  openedAt: r.opened_at,
  openedDeviceTs: r.opened_device_ts,
  deletedAt: r.deleted_at,
});

/** `%`, `_` and `\` are literal in a LIKE prefix (object names are ours, but never trust a pattern). */
const likePrefix = (prefix: string): string => `${prefix.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;

/** SQL for `public.capsules` (+ the server-only unlock schedule). Writes are scoped by the caller's own row. */
@Injectable()
export class CapsulesRepository {
  /** The row (any owner — callers check `userId`), locked for the rest of the push. */
  async lockById(q: Queryable, id: string): Promise<CapsuleRow | null> {
    const r = await q.query<Row>(`select ${COLS} from public.capsules where id = $1 for update`, [id]);
    return r.rows[0] ? toRow(r.rows[0]) : null;
  }

  async insert(q: Queryable, c: NewCapsule): Promise<void> {
    await q.query(
      `insert into public.capsules
         (id, user_id, unlock_type, unlock_local_date, trigger_mood_id, trigger_quadrant, payload_ct, sealed_at, armed_at)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [c.id, c.userId, c.unlockType, c.unlockLocalDate, c.triggerMoodId, c.triggerQuadrant, c.payloadCt, c.sealedAt, c.armedAt],
    );
  }

  /** Active trigger capsules (not deleted, not opened in their cycle), not counting `exceptId`. */
  async countActiveTriggers(q: Queryable, userId: string, exceptId: string | null = null): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(*)::int as n from public.capsules
        where user_id = $1 and unlock_type = 'mood' and deleted_at is null and opened_at is null
          and ($2::uuid is null or id <> $2::uuid)`,
      [userId, exceptId],
    );
    return r.rows[0]?.n ?? 0;
  }

  /** Pending date capsules (not deleted, not opened) — the fair-use cap. */
  async countPendingDates(q: Queryable, userId: string): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(*)::int as n from public.capsules
        where user_id = $1 and unlock_type = 'date' and deleted_at is null and opened_at is null`,
      [userId],
    );
    return r.rows[0]?.n ?? 0;
  }

  /** First open of the current cycle; `fired` is set when the open implies a trigger capsule's fire. */
  async markOpened(
    q: Queryable,
    id: string,
    openedAt: Date,
    openedDeviceTs: Date,
    fired: { firedAt: Date; cooldownUntil: Date } | null,
  ): Promise<void> {
    await q.query(
      `update public.capsules
          set opened_at = $2, opened_device_ts = $3,
              fired_at = coalesce($4::timestamptz, fired_at),
              cooldown_until = coalesce($5::timestamptz, cooldown_until),
              updated_at = now()
        where id = $1`,
      [id, openedAt, openedDeviceTs, fired?.firedAt ?? null, fired?.cooldownUntil ?? null],
    );
  }

  async setFired(q: Queryable, id: string, firedAt: Date, cooldownUntil: Date): Promise<void> {
    await q.query('update public.capsules set fired_at = $2, cooldown_until = $3, updated_at = now() where id = $1', [
      id,
      firedAt,
      cooldownUntil,
    ]);
  }

  /** "Keep for next time": a new cycle, armed from `armedAt`; the cooldown of the fire that just happened stays. */
  async rearm(q: Queryable, id: string, armedAt: Date): Promise<void> {
    await q.query(
      `update public.capsules
          set cycle = cycle + 1, armed_at = $2, fired_at = null, opened_at = null, opened_device_ts = null, updated_at = now()
        where id = $1`,
      [id, armedAt],
    );
  }

  /** Tombstone: content and unlock target erased; timestamps and the cooldown stay. */
  async tombstone(q: Queryable, id: string, deletedAt: Date): Promise<void> {
    await q.query(
      `update public.capsules
          set deleted_at = $2, payload_ct = null, unlock_local_date = null, trigger_mood_id = null, trigger_quadrant = null,
              updated_at = now()
        where id = $1`,
      [id, deletedAt],
    );
  }

  /** Server-only unlock bookkeeping of capsules that no longer need a push (opened / deleted). */
  async deleteSchedules(q: Queryable, capsuleIds: string[]): Promise<void> {
    if (capsuleIds.length === 0) return;
    await q.query('delete from public.capsule_unlock_schedule where capsule_id = any($1::uuid[])', [capsuleIds]);
  }

  /** `absent` (never sealed on the server for this user), `live` or `deleted`. */
  async state(q: Queryable, userId: string, id: string): Promise<'absent' | 'live' | 'deleted'> {
    const r = await q.query<{ deleted: boolean }>(
      'select deleted_at is not null as deleted from public.capsules where id = $1 and user_id = $2',
      [id, userId],
    );
    const row = r.rows[0];
    return !row ? 'absent' : row.deleted ? 'deleted' : 'live';
  }

  /** Whether the private-media object exists (Storage metadata, read with SQL like the purge does). */
  async objectExists(q: Queryable, name: string): Promise<boolean> {
    const r = await q.query('select 1 from storage.objects where bucket_id = $1 and name = $2', [PRIVATE_MEDIA_BUCKET, name]);
    return (r.rowCount ?? 0) > 0;
  }

  /** Every object under `<user_id>/capsules/<id>/` for the given capsules. */
  async listCapsuleObjects(q: Queryable, userId: string, capsuleIds: string[]): Promise<string[]> {
    if (capsuleIds.length === 0) return [];
    const patterns = capsuleIds.map((id) => likePrefix(capsuleObjectPrefix(userId, id)));
    const r = await q.query<{ name: string }>(
      `select name from storage.objects where bucket_id = $1 and name like any($2::text[]) order by name`,
      [PRIVATE_MEDIA_BUCKET, patterns],
    );
    return r.rows.map((x) => x.name);
  }
}
