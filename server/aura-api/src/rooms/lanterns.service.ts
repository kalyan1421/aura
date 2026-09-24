import { Injectable } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { assertRoomAccess } from '../safety/safety.queries';
import { Broadcast } from './broadcast';
import type { IntentionView } from './lantern-rules';
import { ensureLanternNight, holdIntentionFor } from './lanterns';
import { loadMatchingConfig } from './matching-config';
import { countsView, roomInfo, roomStateView, stateOf } from './room-views';
import { RoomsRepository } from './rooms.repository';
import { intentionClosed, intentionPaused, pathId, roomNotFound } from './rooms.schema';

export interface HoldResponse {
  intention: IntentionView;
  holding: true;
}

/**
 * Tonight's intention (PRD F5, REQ-ROOM-14; contracts/api/v1-rooms.md §1.9): one tap holds the room's preset for
 * the night. Only the room total changes and is broadcast (`room_state`); holders are never named or listed, there
 * is no free text, no pairing, no reminder and no follow-up. Holding is final for the night and idempotent.
 */
@Injectable()
export class LanternsService {
  constructor(
    private readonly db: DbService,
    private readonly repo: RoomsRepository,
  ) {}

  async hold(userId: string, roomIdParam: string, now = new Date()): Promise<HoldResponse> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadMatchingConfig(tx);
      const me = await this.repo.membership(tx, roomId, userId);
      const locked = me ? await this.repo.lockRoom(tx, roomId) : null;
      if (!me || !locked) throw roomNotFound();
      const state = stateOf(locked, now, cfg);
      if (state === 'purged') throw roomNotFound();
      if (!cfg.lanterns.intentionEnabled) throw intentionPaused();
      if (state !== 'lantern_hour') throw intentionClosed();

      const room = await ensureLanternNight(tx, locked, now, cfg);
      if (!room.intention_key) throw intentionClosed(); // no preset enabled for this pool tonight
      const held = await holdIntentionFor(tx, room, me.member_id);

      // Holding is being here.
      const touched = await this.repo.touch(tx, me.member_id, cfg.liveWindowS);
      if (touched && !touched.wasLive) {
        const counts = countsView(await this.repo.counts(tx, roomId, cfg.liveWindowS));
        await Broadcast.presence(tx, roomId, counts, now);
        await tx.query('update public.rooms set here_now_broadcast = $2 where id = $1', [roomId, counts.hereNow]);
      }
      const info = roomInfo(held.room, now, cfg);
      if (held.added) await Broadcast.roomState(tx, roomId, roomStateView(info), now);
      const intention = info.intention;
      if (!intention) throw intentionClosed();
      return { intention, holding: true };
    });
  }
}
