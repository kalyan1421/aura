import { Injectable } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { roomAccess } from './safety.queries';

export interface Notice {
  noticeId: string;
  kind: 'warning' | 'suspension' | 'account_closed';
  reasonCode: string;
  createdAt: string;
  until: string | null;
}

export interface SafetyStanding {
  rooms: 'available' | 'suspended' | 'closed';
  until: string | null;
  notices: Notice[];
}

const NOTICE_KIND: Record<string, Notice['kind']> = {
  warning: 'warning',
  room_suspension: 'suspension',
  rooms_pause: 'suspension',
  social_ban: 'suspension',
  account_ban: 'account_closed',
};

/**
 * `GET /v1/safety/me` (contracts/api/v1-rooms.md §2.3): the caller's own standing and visible notices. Shadow-mutes
 * (`gesture_shadow_mute`, `shadow_mute`) are never shown — by design they are invisible to the person.
 */
@Injectable()
export class SafetyService {
  constructor(private readonly db: DbService) {}

  async me(userId: string): Promise<SafetyStanding> {
    const access = await roomAccess(this.db, userId);
    const r = await this.db.query<{ id: string; kind: string; reason_code: string; created_at: Date; ends_at: Date | null }>(
      `select id, kind, reason_code, created_at, ends_at from public.sanctions
        where user_id = $1 and lifted_at is null
          and kind in ('warning','room_suspension','rooms_pause','social_ban','account_ban')
          and created_at > now() - interval '180 days'
        order by created_at desc, id limit 50`,
      [userId],
    );
    return {
      rooms: access.state,
      until: access.until ? access.until.toISOString() : null,
      notices: r.rows.map((x) => ({
        noticeId: x.id,
        kind: NOTICE_KIND[x.kind] ?? 'warning',
        reasonCode: x.reason_code,
        createdAt: x.created_at.toISOString(),
        until: x.ends_at ? x.ends_at.toISOString() : null,
      })),
    };
  }
}
