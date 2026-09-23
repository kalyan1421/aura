import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import type { Queryable, Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { appendAudit, subjectHash } from '../safety/audit';
import { insertReport } from '../safety/reports.core';
import { anyMinor, assertRoomAccess, blockBetween, isHiddenAccount, isShadowMuted, loadSafetyConfig } from '../safety/safety.queries';
import { Broadcast } from './broadcast';
import { gestureLimitBreach, shouldShadowMute, type SenderHistory } from './gesture-limits';
import { loadMatchingConfig, type MatchingConfig } from './matching-config';
import { acceptsGestures } from './room-state';
import type { GestureDrop } from './room-types';
import { countsView, stateOf } from './room-views';
import { RoomsRepository, type MemberRow, type RoomRow } from './rooms.repository';
import { invalidTarget, memberNotFound, parseGestureRequest, pathId, roomNotFound, roomReadOnly, type GestureRequest } from './rooms.schema';

export interface GestureAccepted {
  gestureId: string;
  at: string;
}

/**
 * `POST /v1/rooms/:roomId/gestures` (contracts/api/v1-rooms.md §1.5). One answer for delivered and silently dropped
 * gestures, so nobody can probe blocks, mutes or their own shadow-mute. Per-account limits run under the
 * account's advisory lock (race-free); over-limit attempts are stored as `dropped = 'over_limit'` (they are the
 * "limit hits") until the account is shadow-muted, after which nothing more is stored for them.
 */
@Injectable()
export class GesturesService {
  constructor(
    private readonly db: DbService,
    private readonly repo: RoomsRepository,
    private readonly config: AppConfig,
  ) {}

  async send(userId: string, roomIdParam: string, body: unknown, now = new Date()): Promise<GestureAccepted> {
    const roomId = pathId(roomIdParam, roomNotFound);
    const req = parseGestureRequest(body);
    await assertRoomAccess(this.db, userId);

    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadMatchingConfig(tx);
      const me = await this.repo.membership(tx, roomId, userId);
      const room = me ? await this.repo.findRoom(tx, roomId) : null;
      if (!me || !room) throw roomNotFound();
      const state = stateOf(room, now, cfg);
      if (state === 'purged') throw roomNotFound();
      if (!acceptsGestures(state)) throw roomReadOnly();

      let target: MemberRow | null = null;
      if (req.target === 'member' && req.toMemberId) {
        if (req.toMemberId === me.member_id) throw invalidTarget();
        target = await this.repo.memberInRoom(tx, roomId, req.toMemberId);
        if (!target || target.left_at) throw memberNotFound();
      }

      const shadowMuted = await isShadowMuted(tx, userId);
      const breach = gestureLimitBreach(await this.history(tx, userId, me, req, cfg), cfg.gestures);
      if (breach) {
        // Already muted: drop without a trace (bounds storage for a flooding client).
        if (shadowMuted) return { gestureId: randomUUID(), at: now.toISOString() };
        const g = await this.insert(tx, room, me, req, target, 'over_limit');
        if (shouldShadowMute(await this.limitHits24h(tx, userId), false, cfg.gestures)) {
          await this.shadowMuteForFlooding(tx, userId, me, room, cfg);
        }
        return { gestureId: g.id, at: g.created_at.toISOString() };
      }

      let dropped: GestureDrop | null = null;
      if (shadowMuted) dropped = 'shadow_muted';
      else if (target) {
        if (await isHiddenAccount(tx, target.user_id)) dropped = 'hidden';
        else if (await blockBetween(tx, userId, target.user_id)) dropped = 'blocked';
        else if (await this.mutedBy(tx, target.member_id, me.member_id)) dropped = 'muted';
      }
      const g = await this.insert(tx, room, me, req, target, dropped);

      // Sending is being here.
      const touched = await this.repo.touch(tx, me.member_id, cfg.liveWindowS);
      if (touched && !touched.wasLive) {
        await Broadcast.presence(tx, roomId, countsView(await this.repo.counts(tx, roomId, cfg.liveWindowS)), now);
      }
      if (!dropped) {
        await Broadcast.gestureSent(tx, roomId, { gestureId: g.id, type: req.type, target: req.target }, g.created_at);
        if (target) {
          await Broadcast.gestureReceived(
            tx,
            target.member_id,
            { gestureId: g.id, type: req.type, fromMemberId: me.member_id, fromPseudonym: me.pseudonym },
            g.created_at,
          );
        }
      }
      return { gestureId: g.id, at: g.created_at.toISOString() };
    });
  }

  /** Counts on the DB clock (the one that stamps gestures). Over-limit attempts never count toward the limits. */
  private async history(q: Queryable, userId: string, me: MemberRow, req: GestureRequest, cfg: MatchingConfig): Promise<SenderHistory> {
    const r = await q.query<{ ms_since_last: number | null; room_hour: number; same_target: number }>(
      `select (select extract(epoch from (now() - max(g.created_at))) * 1000
                 from public.room_gestures g join public.room_members m on m.member_id = g.from_member_id
                where m.user_id = $1 and g.dropped is distinct from 'over_limit')::float8 as ms_since_last,
              (select count(*) from public.room_gestures g
                where g.from_member_id = $2 and g.created_at > now() - interval '1 hour'
                  and g.dropped is distinct from 'over_limit')::int as room_hour,
              (select count(*) from public.room_gestures g
                where g.from_member_id = $2 and g.to_member_id = $3 and g.type = $4
                  and g.created_at > now() - make_interval(mins => $5)
                  and g.dropped is distinct from 'over_limit')::int as same_target`,
      [userId, me.member_id, req.toMemberId, req.type, cfg.gestures.sameTargetWindowMin],
    );
    const x = r.rows[0];
    return {
      msSinceLast: x?.ms_since_last === null || x?.ms_since_last === undefined ? null : Number(x.ms_since_last),
      roomLastHour: x?.room_hour ?? 0,
      sameTargetRecent: x?.same_target ?? 0,
    };
  }

  private async limitHits24h(q: Queryable, userId: string): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(*)::int as n from public.room_gestures g join public.room_members m on m.member_id = g.from_member_id
        where m.user_id = $1 and g.dropped = 'over_limit' and g.created_at > now() - interval '24 hours'`,
      [userId],
    );
    return r.rows[0]?.n ?? 0;
  }

  private async mutedBy(q: Queryable, muter: string, muted: string): Promise<boolean> {
    const r = await q.query('select 1 from public.room_mutes where muter_member_id = $1 and muted_member_id = $2', [muter, muted]);
    return (r.rowCount ?? 0) > 0;
  }

  private async insert(
    q: Queryable,
    room: RoomRow,
    me: MemberRow,
    req: GestureRequest,
    target: MemberRow | null,
    dropped: GestureDrop | null,
  ): Promise<{ id: string; created_at: Date }> {
    const r = await q.query<{ id: string; created_at: Date }>(
      `insert into public.room_gestures (room_id, from_member_id, to_member_id, type, target, dropped)
       values ($1, $2, $3, $4, $5, $6) returning id, created_at`,
      [room.id, me.member_id, target?.member_id ?? null, req.type, req.target, dropped],
    );
    return r.rows[0];
  }

  /**
   * 3 limit hits in 24 h: shadow-mute the account's gestures for 24 h (invisible to them) and queue a spam-lane item
   * for a moderator — the F9 strike signal (a human decides on a strike). Audited as `system`.
   */
  private async shadowMuteForFlooding(tx: Tx, userId: string, me: MemberRow, room: RoomRow, cfg: MatchingConfig): Promise<void> {
    const sanction = await tx.query<{ id: string }>(
      `insert into public.sanctions (user_id, kind, reason_code, source, ends_at, created_by)
       values ($1, 'gesture_shadow_mute', 'gesture_flood', 'auto', now() + make_interval(hours => $2), 'system')
       returning id`,
      [userId, cfg.gestures.shadowMuteHours],
    );
    const safety = await loadSafetyConfig(tx);
    const report = await insertReport(
      tx,
      {
        source: 'auto',
        autoSignal: 'gesture_flood',
        reporterUserId: null,
        reporterMemberId: null,
        reason: 6,
        targetKind: 'member',
        roomId: room.id,
        targetMemberId: me.member_id,
        targetGestureId: null,
        targetUserId: userId,
        targetRef: me.member_id,
        note: null,
        involvesMinor: await anyMinor(tx, [userId]),
      },
      safety,
    );
    await tx.query('update public.sanctions set report_id = $2 where id = $1', [sanction.rows[0].id, report.id]);
    await appendAudit(tx, {
      actor: 'system',
      action: 'auto_gesture_shadow_mute',
      reportId: report.id,
      subjectHash: subjectHash(this.config.masterKey, userId),
      reasonCode: 'gesture_flood',
      detail: { hours: cfg.gestures.shadowMuteHours, limitHits: cfg.gestures.limitHitsToMute },
    });
  }
}
