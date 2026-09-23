import { Injectable } from '@nestjs/common';
import { parseOrThrow } from '../common/zod';
import { isUuid } from '../common/uuid';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import type { Quadrant } from '../rules';
import { blockRequestSchema, invalidTarget, memberNotFound, notFound } from './safety.schema';
import { assertNotClosed } from './safety.queries';

export interface BlockView {
  blockId: string;
  quadrant: Quadrant | null;
  createdAt: string;
}

/**
 * Blocks (contracts/api/v1-rooms.md §2.2): account-level, both ways, never matched again. Resolved from a member id on
 * the server; no pseudonym or identity is stored for the list. The blocked person is never told and sees no change.
 */
@Injectable()
export class BlocksService {
  constructor(private readonly db: DbService) {}

  async create(userId: string, body: unknown): Promise<{ blockId: string; created: boolean }> {
    const { roomId, memberId } = parseOrThrow(blockRequestSchema, body);
    await assertNotClosed(this.db, userId);
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const mine = await tx.query<{ member_id: string; quadrant: Quadrant }>(
        `select m.member_id, r.quadrant from public.room_members m join public.rooms r on r.id = m.room_id
          where m.room_id = $1 and m.user_id = $2 and r.purge_at > now()`,
        [roomId, userId],
      );
      if (!mine.rows[0]) throw notFound();
      const target = await tx.query<{ member_id: string; user_id: string }>(
        'select member_id, user_id from public.room_members where room_id = $1 and member_id = $2',
        [roomId, memberId],
      );
      const t = target.rows[0];
      if (!t) throw memberNotFound();
      if (t.user_id === userId) throw invalidTarget();
      const ins = await tx.query<{ id: string }>(
        `insert into public.blocks (blocker_user_id, blocked_user_id, source_room_id, quadrant) values ($1, $2, $3, $4)
         on conflict (blocker_user_id, blocked_user_id) do nothing returning id`,
        [userId, t.user_id, roomId, mine.rows[0].quadrant],
      );
      if (ins.rows[0]) return { blockId: ins.rows[0].id, created: true };
      const existing = await tx.query<{ id: string }>('select id from public.blocks where blocker_user_id = $1 and blocked_user_id = $2', [
        userId,
        t.user_id,
      ]);
      return { blockId: existing.rows[0].id, created: false };
    });
  }

  async list(userId: string): Promise<{ blocks: BlockView[] }> {
    const r = await this.db.query<{ id: string; quadrant: Quadrant | null; created_at: Date }>(
      'select id, quadrant, created_at from public.blocks where blocker_user_id = $1 order by created_at desc, id',
      [userId],
    );
    return { blocks: r.rows.map((x) => ({ blockId: x.id, quadrant: x.quadrant, createdAt: x.created_at.toISOString() })) };
  }

  /** Idempotent: unknown ids and other people's blocks are a silent no-op. */
  async remove(userId: string, blockId: string): Promise<void> {
    if (!isUuid(blockId)) return;
    await this.db.query('delete from public.blocks where id = $1 and blocker_user_id = $2', [blockId.toLowerCase(), userId]);
  }
}
