import { Injectable } from '@nestjs/common';
import type { Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { loadQuietConfig, type QuietConfig } from '../quiet/quiet-config';
import { assertRoomAccess } from '../safety/safety.queries';
import { Broadcast } from './broadcast';
import { loadMatchingConfig, type MatchingConfig } from './matching-config';
import { countsView, stateOf } from './room-views';
import { RoomsRepository, type MemberRow, type RoomRow } from './rooms.repository';
import { pathId, roomNotFound } from './rooms.schema';
import {
  syncWindDownBroadcast,
  windDownClosed,
  windDownCount,
  windDownPaused,
  windDownPausedFor,
  windDownStateAt,
  windDownView,
  windDownWindow,
  type WindDownView,
} from './wind-down';

export interface WindDownResponse {
  windDown: WindDownView | null;
  serverTime: string;
  serverTimeMs: number;
}

/**
 * The Lantern Hour wind-down in a room (contracts/api/v1-quiet.md §2; REQ-QUIET-07): read it, opt in, opt out. Opting in
 * is being here (liveness). Every change sends the room total (`wind_down { state, count }`) — never who. Leaving costs
 * nothing. The clock is injectable (e2e: the room's Lantern Hour is simulated around it).
 */
@Injectable()
export class WindDownService {
  constructor(
    private readonly db: DbService,
    private readonly repo: RoomsRepository,
  ) {}

  async get(userId: string, roomIdParam: string, now = new Date()): Promise<WindDownResponse> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      const { mcfg, qcfg, room, me } = await this.context(tx, roomId, userId, now);
      return this.respond(tx, room, me, now, mcfg, qcfg);
    });
  }

  async join(userId: string, roomIdParam: string, now = new Date()): Promise<WindDownResponse> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const { mcfg, qcfg, room, me } = await this.context(tx, roomId, userId, now);
      if (await windDownPausedFor(tx, room.tz_region)) throw windDownPaused();
      const w = windDownWindow(room, now, mcfg, qcfg);
      if (!w || windDownStateAt(w, now) !== 'open') throw windDownClosed();
      await tx.query(
        `update public.room_members set wind_down_at = $2 where member_id = $1 and (wind_down_at is null or wind_down_at < $3)`,
        [me.member_id, now, w.startsAt],
      );
      // Winding down is being here.
      const touched = await this.repo.touch(tx, me.member_id, mcfg.liveWindowS);
      if (touched && !touched.wasLive) {
        const counts = countsView(await this.repo.counts(tx, roomId, mcfg.liveWindowS));
        await Broadcast.presence(tx, roomId, counts, now);
        await tx.query('update public.rooms set here_now_broadcast = $2 where id = $1', [roomId, counts.hereNow]);
      }
      const count = await windDownCount(tx, roomId, w, mcfg.liveWindowS);
      await syncWindDownBroadcast(tx, roomId, { state: 'open', count }, now);
      return this.respond(tx, room, { ...me, wind_down_at: now }, now, mcfg, qcfg);
    });
  }

  async leave(userId: string, roomIdParam: string, now = new Date()): Promise<void> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const { mcfg, qcfg, room, me } = await this.context(tx, roomId, userId, now);
      const r = await tx.query('update public.room_members set wind_down_at = null where member_id = $1 and wind_down_at is not null', [me.member_id]);
      if (!r.rowCount) return;
      const w = windDownWindow(room, now, mcfg, qcfg);
      if (w && windDownStateAt(w, now) === 'open' && !(await windDownPausedFor(tx, room.tz_region))) {
        await syncWindDownBroadcast(tx, roomId, { state: 'open', count: await windDownCount(tx, roomId, w, mcfg.liveWindowS) }, now);
      }
    });
  }

  /** A current member of a room that isn't a memory (else the same 404 for every case). */
  private async context(
    tx: Tx,
    roomId: string,
    userId: string,
    now: Date,
  ): Promise<{ mcfg: MatchingConfig; qcfg: QuietConfig; room: RoomRow; me: MemberRow & { wind_down_at: Date | null } }> {
    const mcfg = await loadMatchingConfig(tx);
    const qcfg = await loadQuietConfig(tx);
    const me = await this.repo.membership(tx, roomId, userId);
    const room = me ? await this.repo.findRoom(tx, roomId) : null;
    const state = room ? stateOf(room, now, mcfg) : 'purged';
    if (!me || !room || state === 'purged' || state === 'memory') throw roomNotFound();
    const wd = await tx.query<{ wind_down_at: Date | null }>('select wind_down_at from public.room_members where member_id = $1', [me.member_id]);
    return { mcfg, qcfg, room, me: { ...me, wind_down_at: wd.rows[0]?.wind_down_at ?? null } };
  }

  private async respond(
    tx: Tx,
    room: RoomRow,
    me: { wind_down_at: Date | null },
    now: Date,
    mcfg: MatchingConfig,
    qcfg: QuietConfig,
  ): Promise<WindDownResponse> {
    const base = { serverTime: now.toISOString(), serverTimeMs: now.getTime() };
    const w = windDownWindow(room, now, mcfg, qcfg);
    const state = w ? windDownStateAt(w, now) : null;
    if (!w || !state || (await windDownPausedFor(tx, room.tz_region))) return { windDown: null, ...base };
    const count = state === 'open' ? await windDownCount(tx, room.id, w, mcfg.liveWindowS) : 0;
    const joined = me.wind_down_at !== null && me.wind_down_at.getTime() >= w.startsAt.getTime();
    return { windDown: windDownView(w, state, count, joined, qcfg), ...base };
  }
}
