import { Injectable } from '@nestjs/common';
import { profileRequired } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import type { Queryable, Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { addBreathCyclesToRoomLantern } from '../rooms/lanterns';
import { assertGuidelinesAccepted } from '../safety/guidelines';
import { assertRoomAccess } from '../safety/safety.queries';
import { echoRow, insertEcho, validTrace } from './echoes';
import { nextPollMs } from './matcher';
import { RippleBroadcast } from './ripple-broadcast';
import { loadRippleConfig, type RippleConfig } from './ripple-config';
import {
  dbNow,
  echoesOn,
  findSession,
  findTicket,
  groupInvite,
  groupQuickQueue,
  inviteHumans,
  leaveActiveSeats,
  leaveSeat,
  lockInvite,
  logEvent,
  viewFor,
  type InviteRow,
  type TicketRow,
} from './ripple-core';
import { ECHO_CONSENT_POLICY, ECHO_CONSENT_PURPOSE } from './ripple-types';
import type { InviteView, SessionView } from './ripple-views';
import { completeRequestSchema, echoConsentSchema, notFound, parseMatchRequest, pathId, ticketConflict, type MatchRequest } from './ripples.schema';

export type MatchResponse =
  | { status: 'waiting'; ticketId: string; pollAfterMs: number; serverTime: string; serverTimeMs: number; invite?: InviteView }
  | { status: 'matched'; ticketId: string; serverTime: string; serverTimeMs: number; session: SessionView };

/**
 * F7 Breath Ripples (contracts/api/v1-ripples.md §1–§2.3, §2.7): the queue (quick-match and room invites), sessions,
 * silent leave, completion + echo recording, echo consent. Stranger-facing output is built only by ripple-views.ts
 * and ripple-broadcast.ts (DS-10). Never logs ids, pseudonyms or traces.
 */
@Injectable()
export class RipplesService {
  constructor(private readonly db: DbService) {}

  // ------------------------------------------------------------------ §1.1 match / poll
  async match(userId: string, body: unknown): Promise<MatchResponse> {
    const req = parseMatchRequest(body);
    if (!(await this.hasProfile(userId))) throw profileRequired();
    await assertRoomAccess(this.db, userId);
    await assertGuidelinesAccepted(this.db, userId); // REQ-SAFE-04: guidelines before any stranger surface
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId); // one account's polls serialise; grouping never waits on other phones
      const cfg = await loadRippleConfig(tx);
      const now = await dbNow(tx);

      const seen = await findTicket(tx, req.ticketId);
      if (seen && seen.user_id !== userId) throw ticketConflict();
      let ticket: TicketRow;
      let invite: InviteRow | null = null;
      if (seen) {
        if (seen.invite_id) invite = await lockInvite(tx, seen.invite_id); // invite before tickets (lock order)
        const locked = await findTicket(tx, seen.id, true);
        if (!locked || locked.status === 'cancelled') throw notFound();
        ticket = locked;
        if (ticket.status === 'waiting' || ticket.status === 'expired') {
          // A ticket that went quiet (> 6 s) comes back with its original place in the queue.
          await tx.query(`update public.ripple_tickets set status = 'waiting', last_poll_at = $2 where id = $1`, [ticket.id, now]);
          ticket = { ...ticket, status: 'waiting', last_poll_at: now };
        }
      } else {
        ({ ticket, invite } = await this.enqueue(tx, userId, req, cfg, now));
      }

      if (ticket.status === 'waiting') {
        if (invite) await groupInvite(tx, invite, cfg, now);
        else await groupQuickQueue(tx, cfg, now);
        ticket = (await findTicket(tx, ticket.id)) ?? ticket;
      }

      const serverTime = { serverTime: now.toISOString(), serverTimeMs: now.getTime() };
      if (ticket.status === 'matched') {
        const session = ticket.session_id ? await viewFor(tx, ticket.session_id, userId, cfg, now) : null;
        if (!session) throw notFound(); // purged, or the seat was left since
        return { status: 'matched', ticketId: ticket.id, ...serverTime, session };
      }
      const deadlines = invite
        ? [invite.starts_at.getTime()]
        : [ticket.enqueued_at.getTime() + cfg.earlyStartS * 1000, ticket.enqueued_at.getTime() + cfg.maxWaitS * 1000];
      return {
        status: 'waiting',
        ticketId: ticket.id,
        pollAfterMs: nextPollMs(now.getTime(), deadlines, cfg),
        ...serverTime,
        ...(invite ? { invite: await this.inviteView(tx, invite, userId) } : {}),
      };
    });
  }

  /**
   * A new ticket. One waiting ticket per account (older ones are cancelled) and one seat at a time (older unfinished
   * seats are left silently). A room entry joins the room's open invite, or opens one (1 per person per 10 min);
   * past the limit with nothing open it simply joins the global queue.
   */
  private async enqueue(tx: Tx, userId: string, req: MatchRequest, cfg: RippleConfig, now: Date): Promise<{ ticket: TicketRow; invite: InviteRow | null }> {
    const cancelled = await tx.query<{ invite_id: string | null; room_id: string | null }>(
      `update public.ripple_tickets set status = 'cancelled' where user_id = $1 and status in ('waiting','expired') returning invite_id, room_id`,
      [userId],
    );
    for (const c of cancelled.rows) if (c.invite_id && c.room_id) await RippleBroadcast.invite(tx, c.room_id, c.invite_id, now);
    await leaveActiveSeats(tx, userId, now);

    let invite: InviteRow | null = null;
    let memberId: string | null = null;
    if (req.entry === 'room') {
      const roomId = req.roomId as string;
      const m = await tx.query<{ member_id: string }>(
        `select m.member_id from public.room_members m join public.rooms r on r.id = m.room_id
          where m.room_id = $1 and m.user_id = $2 and m.left_at is null and r.memory_at > $3`,
        [roomId, userId, now],
      );
      memberId = m.rows[0]?.member_id ?? null;
      if (!memberId) throw notFound();
      const open = await tx.query<InviteRow>(
        `select * from public.ripple_invites where room_id = $1 and status = 'open' and starts_at > $2
          order by created_at limit 1 for update`,
        [roomId, now],
      );
      invite = open.rows[0] ?? null;
      if (!invite) {
        const recent = await tx.query<{ n: number }>(
          `select count(*)::int as n from public.ripple_invites where inviter_user_id = $1 and created_at > $2::timestamptz - make_interval(mins => $3)`,
          [userId, now, cfg.inviteLimitWindowMin],
        );
        if ((recent.rows[0]?.n ?? 0) < cfg.invitesPerWindow) {
          const ins = await tx.query<InviteRow>(
            `insert into public.ripple_invites (room_id, inviter_user_id, inviter_member_id, created_at, starts_at)
             values ($1, $2, $3, $4, $4::timestamptz + make_interval(secs => $5)) returning *`,
            [roomId, userId, memberId, now, cfg.inviteWindowS],
          );
          invite = ins.rows[0];
        }
      }
    }

    const r = await tx.query<TicketRow>(
      `insert into public.ripple_tickets (id, user_id, entry, room_id, room_member_id, invite_id, enqueued_at, last_poll_at)
       values ($1, $2, $3, $4, $5, $6, $7, $7)
       returning id, user_id, entry, room_id, room_member_id, invite_id, status, enqueued_at, last_poll_at, session_id, seat`,
      invite
        ? [req.ticketId, userId, 'room', invite.room_id, memberId, invite.id, now]
        : [req.ticketId, userId, 'quick', null, null, null, now], // past the invite limit: the global queue, silently
    );
    if (invite) await RippleBroadcast.invite(tx, invite.room_id, invite.id, now);
    return { ticket: r.rows[0], invite };
  }

  // ------------------------------------------------------------------ §1.2 cancel
  async cancel(userId: string, ticketIdParam: string): Promise<void> {
    const ticketId = pathId(ticketIdParam);
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const r = await tx.query<{ invite_id: string | null; room_id: string | null }>(
        `update public.ripple_tickets set status = 'cancelled'
          where id = $1 and user_id = $2 and status in ('waiting','expired') returning invite_id, room_id`,
        [ticketId, userId],
      );
      const c = r.rows[0];
      if (c?.invite_id && c.room_id) await RippleBroadcast.invite(tx, c.room_id, c.invite_id, await dbNow(tx));
    });
  }

  // ------------------------------------------------------------------ §1.3 the room's invite banner
  async roomInvite(userId: string, roomIdParam: string): Promise<{ invite: InviteView | null }> {
    const roomId = pathId(roomIdParam);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      const now = await dbNow(tx);
      const member = await tx.query(
        `select 1 from public.room_members m join public.rooms r on r.id = m.room_id
          where m.room_id = $1 and m.user_id = $2 and m.left_at is null and r.memory_at > $3`,
        [roomId, userId, now],
      );
      if (!member.rowCount) throw notFound();
      const r = await tx.query<InviteRow>(
        `select i.* from public.ripple_invites i
          where i.room_id = $1 and i.status = 'open' and i.starts_at > $2
            -- the blocker never sees the blocked person's invite; the blocked side sees no change
            and not exists (select 1 from public.blocks b where b.blocker_user_id = $3 and b.blocked_user_id = i.inviter_user_id)
          order by i.created_at limit 1`,
        [roomId, now, userId],
      );
      return { invite: r.rows[0] ? await this.inviteView(tx, r.rows[0], userId) : null };
    });
  }

  private async inviteView(q: Queryable, invite: InviteRow, userId: string): Promise<InviteView> {
    const cfg = await loadRippleConfig(q);
    const from = await q.query<{ pseudonym: string }>('select pseudonym from public.room_members where member_id = $1', [invite.inviter_member_id]);
    return {
      inviteId: invite.id,
      fromPseudonym: from.rows[0]?.pseudonym ?? '',
      humans: Math.max(1, await inviteHumans(q, invite.id)),
      capacity: cfg.seatCount,
      startsAt: invite.starts_at.toISOString(),
      startsAtMs: invite.starts_at.getTime(),
      mine: invite.inviter_user_id === userId,
    };
  }

  // ------------------------------------------------------------------ §2.1 session
  async session(userId: string, sessionIdParam: string): Promise<SessionView> {
    const sessionId = pathId(sessionIdParam);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      const view = await viewFor(tx, sessionId, userId, await loadRippleConfig(tx), await dbNow(tx));
      if (!view) throw notFound();
      return view;
    });
  }

  // ------------------------------------------------------------------ §2.2 leave (silent)
  async leave(userId: string, sessionIdParam: string): Promise<void> {
    const sessionId = pathId(sessionIdParam);
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const now = await dbNow(tx);
      const r = await tx.query<{ id: string; seat: number }>(
        `select id, seat from public.ripple_seats where session_id = $1 and user_id = $2 and kind = 'human' for update`,
        [sessionId, userId],
      );
      if (!r.rows[0]) throw notFound();
      await leaveSeat(tx, sessionId, r.rows[0], now);
    });
  }

  // ------------------------------------------------------------------ §2.3 complete (+ echo)
  async complete(userId: string, sessionIdParam: string, body: unknown): Promise<void> {
    const sessionId = pathId(sessionIdParam);
    const req = parseOrThrow(completeRequestSchema, body);
    const echo = await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadRippleConfig(tx);
      const now = await dbNow(tx);
      const seat = (
        await tx.query<{ id: string; seat: number; completed_at: Date | null }>(
          `select id, seat, completed_at from public.ripple_seats
            where session_id = $1 and user_id = $2 and kind = 'human' for update`,
          [sessionId, userId],
        )
      ).rows[0];
      const session = seat ? await findSession(tx, sessionId) : null;
      if (!seat || !session) throw notFound();
      if (seat.completed_at) return null; // once per seat

      // The server's own clock caps what a phone may claim.
      const cycleMs = session.inhale_ms + session.exhale_ms;
      const breathing = Math.min(now.getTime(), session.ends_at.getTime()) - session.t0.getTime() - session.settle_ms;
      const allowed = Math.max(0, Math.min(session.cycles, Math.floor(breathing / cycleMs)));
      const cycles = Math.min(req.cycles, allowed);
      await tx.query(`update public.ripple_seats set cycles_done = $2, completed = $3, completed_at = $4 where id = $1`, [
        seat.id,
        cycles,
        cycles >= session.cycles,
        now,
      ]);
      await logEvent(tx, sessionId, seat, 'completed');
      // F5 room lanterns: human cycles in a session started from the room add light (Lantern Hour only; the lantern
      // owns the rule, src/rooms/lanterns.ts). One call per human seat = the session's human total.
      if (session.entry === 'room' && session.room_id && cycles > 0) await addBreathCyclesToRoomLantern(tx, session.room_id, cycles, now);

      const trace = req.trace ?? null;
      const eligible =
        cycles >= cfg.echoMinCycles &&
        session.pacer_version === cfg.pacerVersion &&
        trace !== null &&
        validTrace(trace, session.cycles) &&
        (await echoesOn(tx)) &&
        (await this.echoConsent(tx, userId));
      return eligible && trace ? echoRow(trace, session.cycles, cfg, now) : null;
    });
    // REQ-GAME-07: written in its own transaction, after the seat's, with nothing that points back at it.
    if (echo) await this.db.withTx((tx) => insertEcho(tx, echo));
  }

  // ------------------------------------------------------------------ §2.7 echo consent
  async getEchoConsent(userId: string): Promise<{ enabled: boolean }> {
    return { enabled: await this.echoConsent(this.db, userId) };
  }

  async setEchoConsent(userId: string, body: unknown): Promise<{ enabled: boolean }> {
    const { enabled } = parseOrThrow(echoConsentSchema, body);
    if (!(await this.hasProfile(userId))) throw profileRequired();
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      if (enabled) {
        if (!(await this.echoConsent(tx, userId))) {
          await tx.query(`insert into public.user_consents (user_id, purpose, policy_version, granted_at) values ($1, $2, $3, clock_timestamp())`, [
            userId,
            ECHO_CONSENT_PURPOSE,
            ECHO_CONSENT_POLICY,
          ]);
        }
      } else {
        const r = await tx.query(
          `update public.user_consents set withdrawn_at = clock_timestamp() where user_id = $1 and purpose = $2 and withdrawn_at is null`,
          [userId, ECHO_CONSENT_PURPOSE],
        );
        if (!r.rowCount && (await this.echoConsent(tx, userId))) {
          // On by default (no row yet): record the withdrawal itself.
          await tx.query(
            `insert into public.user_consents (user_id, purpose, policy_version, granted_at, withdrawn_at)
             values ($1, $2, $3, clock_timestamp(), clock_timestamp())`,
            [userId, ECHO_CONSENT_PURPOSE, ECHO_CONSENT_POLICY],
          );
        }
      }
      return { enabled: await this.echoConsent(tx, userId) };
    });
  }

  /** On by default; the latest consent event for `echoes` decides. */
  private async echoConsent(q: Queryable, userId: string): Promise<boolean> {
    const r = await q.query<{ withdrawn_at: Date | null }>(
      `select withdrawn_at from public.user_consents where user_id = $1 and purpose = $2
        order by coalesce(withdrawn_at, granted_at) desc, granted_at desc limit 1`,
      [userId, ECHO_CONSENT_PURPOSE],
    );
    const last = r.rows[0];
    return !last || last.withdrawn_at === null;
  }

  private async hasProfile(userId: string): Promise<boolean> {
    const r = await this.db.query('select 1 from public.profiles where user_id = $1', [userId]);
    return (r.rowCount ?? 0) > 0;
  }
}
