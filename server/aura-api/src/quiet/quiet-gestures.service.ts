import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { parseOrThrow } from '../common/zod';
import { AppConfig } from '../config/app-config';
import type { Queryable, Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { gestureLimitBreach, shouldShadowMute, type GestureLimitConfig, type SenderHistory } from '../rooms/gesture-limits';
import { appendAudit, subjectHash } from '../safety/audit';
import { assertRoomAccess, isShadowMuted, loadSafetyConfig } from '../safety/safety.queries';
import type { QuietConfig } from './quiet-config';
import { loadQuietConfig } from './quiet-config';
import { QuietBroadcast } from './quiet-broadcast';
import { fileQuietReport } from './quiet-reports';
import type { GestureType, QuietGestureDrop } from './quiet-types';
import { blockOver, gestureRequestSchema, notFound, pathId } from './quiet.schema';

export interface GestureAccepted {
  gestureId: string;
  at: string;
}

interface MeRow {
  member_id: string;
  session_id: string;
  ends_at: Date;
}

/** The F5 limit rule with Quiet Together's numbers: 1 per 10 s (per account), 20 per session hour; no per-target rule. */
export function quietLimitConfig(cfg: QuietConfig): GestureLimitConfig {
  return {
    minIntervalMs: cfg.gestures.minIntervalMs,
    roomHourMax: cfg.gestures.hourMax,
    sameTargetMax: Number.MAX_SAFE_INTEGER,
    sameTargetWindowMin: 1,
    limitHitsToMute: cfg.gestures.limitHitsToMute,
    shadowMuteHours: cfg.gestures.shadowMuteHours,
  };
}

/**
 * `POST /v1/quiet/sessions/:sessionId/gestures` (contracts/api/v1-quiet.md §1.4; REQ-QUIET-02). A preset to the whole
 * session, shown to everyone as an unnamed animation. One answer for delivered and dropped gestures, so nobody can
 * probe limits or their own shadow-mute. Limits run under the account's advisory lock; over-limit attempts are stored
 * as `dropped = 'over_limit'` (the "limit hits") until the account is shadow-muted, after which nothing more is stored.
 */
@Injectable()
export class QuietGesturesService {
  constructor(
    private readonly db: DbService,
    private readonly config: AppConfig,
  ) {}

  async send(userId: string, sessionIdParam: string, body: unknown, now = new Date()): Promise<GestureAccepted> {
    const sessionId = pathId(sessionIdParam);
    const { type } = parseOrThrow(gestureRequestSchema, body);
    await assertRoomAccess(this.db, userId);

    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadQuietConfig(tx);
      const me = (
        await tx.query<MeRow>(
          `select m.member_id, m.session_id, s.ends_at from public.quiet_members m join public.quiet_sessions s on s.id = m.session_id
            where m.session_id = $1 and m.user_id = $2 and m.left_at is null`,
          [sessionId, userId],
        )
      ).rows[0];
      if (!me) throw notFound();
      if (now.getTime() >= me.ends_at.getTime()) throw blockOver();

      const limits = quietLimitConfig(cfg);
      const shadowMuted = await isShadowMuted(tx, userId);
      const breach = gestureLimitBreach(await this.history(tx, userId, me.member_id, now), limits);
      if (breach) {
        if (shadowMuted) return { gestureId: randomUUID(), at: now.toISOString() }; // no trace for a flooding client
        const g = await this.insert(tx, me, type, 'over_limit', now);
        if (shouldShadowMute(await this.limitHits24h(tx, userId, now), false, limits)) await this.shadowMuteForFlooding(tx, userId, me, cfg, now);
        return { gestureId: g.id, at: g.created_at.toISOString() };
      }

      const dropped: QuietGestureDrop | null = shadowMuted ? 'shadow_muted' : null;
      const g = await this.insert(tx, me, type, dropped, now);
      // Sending is being here.
      await tx.query('update public.quiet_members set last_seen_at = greatest(last_seen_at, $2::timestamptz) where member_id = $1', [me.member_id, now]);
      if (!dropped) await QuietBroadcast.gesture(tx, sessionId, { gestureId: g.id, type }, g.created_at);
      return { gestureId: g.id, at: g.created_at.toISOString() };
    });
  }

  /** Over-limit attempts never count toward the limits. The interval is per account, across sessions. */
  private async history(q: Queryable, userId: string, memberId: string, now: Date): Promise<SenderHistory> {
    const r = await q.query<{ ms_since_last: number | null; hour: number }>(
      `select (select extract(epoch from ($3::timestamptz - max(g.created_at))) * 1000
                 from public.quiet_gestures g join public.quiet_members m on m.member_id = g.member_id
                where m.user_id = $1 and g.dropped is distinct from 'over_limit')::float8 as ms_since_last,
              (select count(*) from public.quiet_gestures g
                where g.member_id = $2 and g.created_at > $3::timestamptz - interval '1 hour'
                  and g.dropped is distinct from 'over_limit')::int as hour`,
      [userId, memberId, now],
    );
    const x = r.rows[0];
    return {
      msSinceLast: x?.ms_since_last === null || x?.ms_since_last === undefined ? null : Number(x.ms_since_last),
      roomLastHour: x?.hour ?? 0,
      sameTargetRecent: 0,
    };
  }

  private async limitHits24h(q: Queryable, userId: string, now: Date): Promise<number> {
    const r = await q.query<{ n: number }>(
      `select count(*)::int as n from public.quiet_gestures g join public.quiet_members m on m.member_id = g.member_id
        where m.user_id = $1 and g.dropped = 'over_limit' and g.created_at > $2::timestamptz - interval '24 hours'`,
      [userId, now],
    );
    return r.rows[0]?.n ?? 0;
  }

  private async insert(q: Queryable, me: MeRow, type: GestureType, dropped: QuietGestureDrop | null, now: Date): Promise<{ id: string; created_at: Date }> {
    const r = await q.query<{ id: string; created_at: Date }>(
      `insert into public.quiet_gestures (session_id, member_id, type, dropped, created_at) values ($1, $2, $3, $4, $5) returning id, created_at`,
      [me.session_id, me.member_id, type, dropped, now],
    );
    return r.rows[0];
  }

  /**
   * 3 limit hits in 24 h: shadow-mute the account's gestures for 24 h (invisible to them; the same sanction as rooms, so
   * it covers every gesture surface) and queue a spam-lane item for a moderator (the F9 strike signal). Audited as
   * `system`.
   */
  private async shadowMuteForFlooding(tx: Tx, userId: string, me: MeRow, cfg: QuietConfig, now: Date): Promise<void> {
    const sanction = await tx.query<{ id: string }>(
      `insert into public.sanctions (user_id, kind, reason_code, source, ends_at, created_by)
       values ($1, 'gesture_shadow_mute', 'gesture_flood', 'auto', $2::timestamptz + make_interval(hours => $3), 'system')
       returning id`,
      [userId, now, cfg.gestures.shadowMuteHours],
    );
    const safety = await loadSafetyConfig(tx);
    const report = await fileQuietReport(
      tx,
      { source: 'auto', reporterUserId: null, reason: 6, sessionId: me.session_id, note: null, subjects: [userId], now },
      safety,
    );
    await tx.query('update public.sanctions set report_id = $2 where id = $1', [sanction.rows[0].id, report.id]);
    await appendAudit(tx, {
      actor: 'system',
      action: 'auto_gesture_shadow_mute',
      reportId: report.id,
      subjectHash: subjectHash(this.config.masterKey, userId),
      reasonCode: 'gesture_flood',
      detail: { hours: cfg.gestures.shadowMuteHours, limitHits: cfg.gestures.limitHitsToMute, surface: 'quiet' },
    });
  }
}
