import { Injectable } from '@nestjs/common';
import { DbService } from '../db/db.service';
import { guidelinesStatus, type GuidelinesStatus } from './guidelines';
import { roomAccess } from './safety.queries';

/**
 * One visible notice. Deliberately without a reason code or lane (19 admin console, Minors & grooming SOP step 4 "no
 * tipping off"): the person learns THAT they were warned, suspended or closed, and when it ends — never why. The app
 * shows the calm generic line and how to ask for a review (Grievance Officer, `POST /v1/grievances` category
 * `moderation_appeal`).
 */
export interface Notice {
  noticeId: string;
  kind: 'warning' | 'suspension' | 'account_closed';
  createdAt: string;
  until: string | null;
}

export interface SafetyStanding {
  rooms: 'available' | 'suspended' | 'closed';
  until: string | null;
  notices: Notice[];
  /** Community guidelines (REQ-SAFE-04): the version rooms require and whether the caller accepted it. */
  guidelines: GuidelinesStatus;
}

/** Sanction kinds the person may see (as a coarse kind only). Shadow-mutes are never listed anywhere. */
const NOTICE_KIND: Readonly<Record<string, Notice['kind']>> = {
  warning: 'warning',
  room_suspension: 'suspension',
  rooms_pause: 'suspension',
  social_ban: 'suspension',
  account_ban: 'account_closed',
};
const VISIBLE_KINDS = Object.keys(NOTICE_KIND);

/**
 * `GET /v1/safety/me` (contracts/api/v1-rooms.md §2.3): the caller's own standing, visible notices and guidelines
 * status. Shadow-mutes (`gesture_shadow_mute`, `shadow_mute`) are never shown — by design they are invisible to the
 * person. No reason code, lane, report or moderator detail ever leaves here.
 */
@Injectable()
export class SafetyService {
  constructor(private readonly db: DbService) {}

  async me(userId: string): Promise<SafetyStanding> {
    const access = await roomAccess(this.db, userId);
    const r = await this.db.query<{ id: string; kind: string; created_at: Date; ends_at: Date | null }>(
      `select id, kind, created_at, ends_at from public.sanctions
        where user_id = $1 and lifted_at is null and kind = any($2::text[])
          and created_at > now() - interval '180 days'
        order by created_at desc, id limit 50`,
      [userId, VISIBLE_KINDS],
    );
    return {
      rooms: access.state,
      until: access.until ? access.until.toISOString() : null,
      notices: r.rows.map((x) => ({
        noticeId: x.id,
        kind: NOTICE_KIND[x.kind] ?? 'warning',
        createdAt: x.created_at.toISOString(),
        until: x.ends_at ? x.ends_at.toISOString() : null,
      })),
      guidelines: await guidelinesStatus(this.db, userId),
    };
  }
}
