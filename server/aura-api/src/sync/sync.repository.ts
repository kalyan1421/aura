import { Injectable } from '@nestjs/common';
import type { Queryable } from '../db/db';
import { lockUser } from '../db/locks';
import type { Quadrant } from '../rules';
import type { CheckInPayload, HabitPayload, MutationStatus } from './sync.schema';

export type LedgerReason = 'checkin' | 'habit';

/** SQL for the sync write path. Every statement is scoped by `user_id`. */
@Injectable()
export class SyncRepository {
  /** Serialise writes per user so day-ledger reads → award → insert cannot race. */
  lockUser(q: Queryable, userId: string): Promise<void> {
    return lockUser(q, userId);
  }

  // ---------- idempotency ----------
  async findMutation(
    q: Queryable,
    userId: string,
    mutationId: string,
  ): Promise<{ status: Exclude<MutationStatus, 'duplicate'>; reason: string | null } | null> {
    const r = await q.query<{ status: 'applied' | 'rejected'; reason: string | null }>(
      'select status, reason from public.sync_mutations where user_id = $1 and mutation_id = $2',
      [userId, mutationId],
    );
    return r.rows[0] ?? null;
  }

  async recordMutation(
    q: Queryable,
    m: { userId: string; mutationId: string; entity: string; status: 'applied' | 'rejected'; reason: string | null },
  ): Promise<void> {
    await q.query(
      `insert into public.sync_mutations (user_id, mutation_id, entity, status, reason)
       values ($1, $2, $3, $4, $5) on conflict (user_id, mutation_id) do nothing`,
      [m.userId, m.mutationId, m.entity.slice(0, 64), m.status, m.reason],
    );
  }

  // ---------- check_ins ----------
  async checkInOwner(q: Queryable, id: string): Promise<string | null> {
    const r = await q.query<{ user_id: string }>('select user_id from public.check_ins where id = $1 for update', [id]);
    return r.rows[0]?.user_id ?? null;
  }

  async insertCheckIn(
    q: Queryable,
    c: { userId: string; p: CheckInPayload; quadrant: Quadrant; localDay: string; deviceTs: string; backfill: boolean },
  ): Promise<void> {
    await q.query(
      `insert into public.check_ins (id, user_id, mood_id, quadrant, tags, note_ct, local_day, device_ts, source, backfill)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [c.p.id, c.userId, c.p.moodId, c.quadrant, c.p.tags, c.p.noteCt, c.localDay, c.deviceTs, c.p.source, c.backfill],
    );
  }

  /** Edit: mood/tags/note/source only — the original aura day, timestamps and credit never change. */
  async updateCheckIn(q: Queryable, userId: string, p: CheckInPayload, quadrant: Quadrant): Promise<void> {
    await q.query(
      `update public.check_ins set mood_id = $3, quadrant = $4, tags = $5, note_ct = $6, source = $7, updated_at = now()
        where id = $1 and user_id = $2`,
      [p.id, userId, p.moodId, quadrant, p.tags, p.noteCt, p.source],
    );
  }

  async deleteCheckIn(q: Queryable, userId: string, id: string): Promise<void> {
    await q.query('delete from public.check_ins where id = $1 and user_id = $2', [id, userId]);
  }

  // ---------- habits ----------
  /** Upsert owned by `userId`; returns false when the id belongs to someone else. */
  async upsertHabit(q: Queryable, userId: string, h: HabitPayload): Promise<boolean> {
    const r = await q.query(
      `insert into public.habits (id, user_id, kind, preset_key, name, active)
       values ($1, $2, $3, $4, $5, $6)
       on conflict (id) do update set
         kind = excluded.kind, preset_key = excluded.preset_key, name = excluded.name,
         active = excluded.active, updated_at = now()
       where public.habits.user_id = excluded.user_id
       returning id`,
      [h.id, userId, h.kind, h.kind === 'preset' ? h.presetKey : null, h.name, h.active],
    );
    return (r.rowCount ?? 0) > 0;
  }

  /** Another habit of this user already uses `presetKey` (each preset exists at most once). */
  async presetHabitTaken(q: Queryable, userId: string, presetKey: string, exceptId: string): Promise<boolean> {
    const r = await q.query(
      `select 1 from public.habits where user_id = $1 and kind = 'preset' and preset_key = $2 and id <> $3`,
      [userId, presetKey, exceptId],
    );
    return (r.rowCount ?? 0) > 0;
  }

  /** Active custom habits of this user, not counting `exceptId` (the one being written). */
  async countActiveCustomHabits(q: Queryable, userId: string, exceptId: string): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(*)::int as n from public.habits where user_id = $1 and kind = 'custom' and active and id <> $2`,
      [userId, exceptId],
    );
    return r.rows[0]?.n ?? 0;
  }

  async findHabit(q: Queryable, userId: string, habitId: string): Promise<{ presetKey: string | null } | null> {
    const r = await q.query<{ preset_key: string | null }>(
      'select preset_key from public.habits where id = $1 and user_id = $2',
      [habitId, userId],
    );
    return r.rows[0] ? { presetKey: r.rows[0].preset_key } : null;
  }

  /** Hard delete; habit_logs cascade. Ledger rows and active days are untouched. */
  async deleteHabit(q: Queryable, userId: string, id: string): Promise<void> {
    await q.query('delete from public.habits where id = $1 and user_id = $2', [id, userId]);
  }

  // ---------- habit_logs ----------
  async habitLogOwner(q: Queryable, id: string): Promise<string | null> {
    const r = await q.query<{ user_id: string }>('select user_id from public.habit_logs where id = $1', [id]);
    return r.rows[0]?.user_id ?? null;
  }

  /** Returns false when this habit is already logged on that aura day (unique (habit_id, local_day)). */
  async insertHabitLog(
    q: Queryable,
    l: { id: string; userId: string; habitId: string; localDay: string; deviceTs: string },
  ): Promise<boolean> {
    const r = await q.query(
      `insert into public.habit_logs (id, user_id, habit_id, local_day, device_ts)
       values ($1, $2, $3, $4, $5) on conflict (habit_id, local_day) do nothing returning id`,
      [l.id, l.userId, l.habitId, l.localDay, l.deviceTs],
    );
    return (r.rowCount ?? 0) > 0;
  }

  async deleteHabitLog(q: Queryable, userId: string, id: string): Promise<void> {
    await q.query('delete from public.habit_logs where id = $1 and user_id = $2', [id, userId]);
  }

  // ---------- starlight ledger / active days (append-only) ----------
  async ledgerHas(q: Queryable, reason: LedgerReason, sourceId: string): Promise<boolean> {
    const r = await q.query('select 1 from public.starlight_ledger where reason = $1 and source_id = $2', [reason, sourceId]);
    return (r.rowCount ?? 0) > 0;
  }

  /** Eligible check-ins already credited + Starlight already awarded on one aura day. */
  async dayLedger(q: Queryable, userId: string, localDay: string): Promise<{ checkIns: number; total: number }> {
    const r = await q.query<{ check_ins: number; total: string }>(
      `select count(*) filter (where reason = 'checkin')::int as check_ins, coalesce(sum(amount), 0) as total
         from public.starlight_ledger where user_id = $1 and local_day = $2`,
      [userId, localDay],
    );
    return { checkIns: r.rows[0]?.check_ins ?? 0, total: Number(r.rows[0]?.total ?? 0) };
  }

  async insertLedger(
    q: Queryable,
    e: { userId: string; amount: number; reason: LedgerReason; sourceId: string; habitKey: string | null; localDay: string },
  ): Promise<void> {
    await q.query(
      `insert into public.starlight_ledger (user_id, amount, reason, source_id, habit_key, local_day)
       values ($1, $2, $3, $4, $5, $6) on conflict (reason, source_id) do nothing`,
      [e.userId, e.amount, e.reason, e.sourceId, e.habitKey, e.localDay],
    );
  }

  async markActive(q: Queryable, userId: string, localDay: string): Promise<void> {
    await q.query(
      'insert into public.active_days (user_id, local_day) values ($1, $2) on conflict do nothing',
      [userId, localDay],
    );
  }
}
