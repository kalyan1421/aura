import type { Queryable, Tx } from '../db/db';
import { generatePseudonym } from '../rooms/pseudonyms';
import { eligibleEchoCount, pickEchoes } from './echoes';
import { blockSet, fillPlan, planInviteGroups, planQuickMatch, type PlannedGroup, type WaitingTicket } from './matcher';
import { RippleBroadcast } from './ripple-broadcast';
import { sessionLengthMs, type RippleConfig } from './ripple-config';
import { ECHOES_FLAG, type RippleEntry, type StartRule, type TicketStatus } from './ripple-types';
import { sessionPayload, sessionView, type SeatRow, type SessionRow, type SessionView } from './ripple-views';

/**
 * Breath Ripples SQL shared by the API (src/ripples/ripples.service.ts) and the worker tick (ripple-lifecycle.ts).
 * Lock order everywhere: the caller's per-user advisory lock → its own ticket → the invite row → other tickets with
 * `FOR UPDATE SKIP LOCKED` (grouping never waits on another phone's poll). Never logs ids or pseudonyms.
 */
export interface TicketRow {
  id: string;
  user_id: string;
  entry: RippleEntry;
  room_id: string | null;
  room_member_id: string | null;
  invite_id: string | null;
  status: TicketStatus;
  enqueued_at: Date;
  last_poll_at: Date;
  session_id: string | null;
  seat: number | null;
}

export interface InviteRow {
  id: string;
  room_id: string;
  /** Null once the inviter's account is deleted: the invite stays for the room. */
  inviter_user_id: string | null;
  inviter_member_id: string | null;
  created_at: Date;
  starts_at: Date;
  status: 'open' | 'started' | 'cancelled';
}

const TICKET_COLS = 'id, user_id, entry, room_id, room_member_id, invite_id, status, enqueued_at, last_poll_at, session_id, seat';
const SESSION_COLS = 'id, entry, room_id, start_rule, t0, settle_ms, inhale_ms, exhale_ms, cycles, fade_ms, pacer_version, ends_at, ended_at';
const SEAT_COLS = 'id, seat, kind, user_id, pseudonym, echo_id, left_at';

/** The DB clock (the transaction's start): every rule and every `serverTime` uses it. */
export async function dbNow(q: Queryable): Promise<Date> {
  return (await q.query<{ now: Date }>('select now() as now')).rows[0].now;
}

/** A kill switch or feature flag: missing = on (kill switches only ever take things away). */
export async function flagOn(q: Queryable, key: string): Promise<boolean> {
  const r = await q.query<{ enabled: boolean }>('select enabled from public.feature_flags where key = $1', [key]);
  return r.rows[0]?.enabled ?? true;
}

export const echoesOn = (q: Queryable): Promise<boolean> => flagOn(q, ECHOES_FLAG);

export async function findTicket(q: Queryable, id: string, lock = false): Promise<TicketRow | null> {
  const r = await q.query<TicketRow>(`select ${TICKET_COLS} from public.ripple_tickets where id = $1 ${lock ? 'for update' : ''}`, [id]);
  return r.rows[0] ?? null;
}

export async function lockInvite(q: Queryable, id: string): Promise<InviteRow | null> {
  const r = await q.query<InviteRow>('select * from public.ripple_invites where id = $1 for update', [id]);
  return r.rows[0] ?? null;
}

export async function findSession(q: Queryable, id: string): Promise<SessionRow | null> {
  const r = await q.query<SessionRow>(`select ${SESSION_COLS} from public.ripple_sessions where id = $1`, [id]);
  return r.rows[0] ?? null;
}

export async function seatsOf(q: Queryable, sessionId: string): Promise<SeatRow[]> {
  const r = await q.query<SeatRow>(`select ${SEAT_COLS} from public.ripple_seats where session_id = $1 order by seat`, [sessionId]);
  return r.rows;
}

export async function logEvent(q: Queryable, sessionId: string, seat: { seat: number; id: string } | null, event: string): Promise<void> {
  await q.query('insert into public.ripple_session_log (session_id, seat, seat_id, event) values ($1, $2, $3, $4)', [
    sessionId,
    seat?.seat ?? null,
    seat?.id ?? null,
    event,
  ]);
}

/** The session as `userId` sees it (their seat), or null when they hold no current seat in it. */
export async function viewFor(q: Queryable, sessionId: string, userId: string, cfg: RippleConfig, now: Date): Promise<SessionView | null> {
  const s = await findSession(q, sessionId);
  if (!s) return null;
  const seats = await seatsOf(q, sessionId);
  const mine = seats.find((x) => x.user_id === userId && x.kind === 'human' && x.left_at === null);
  if (!mine) return null;
  const echoIds = seats.map((x) => x.echo_id).filter((x): x is string => !!x);
  const traces = new Map<string, Array<number | null>>();
  if (echoIds.length) {
    const r = await q.query<{ id: string; offsets: Array<number | null> }>('select id, offsets from echo_library.recordings where id = any($1::uuid[])', [
      echoIds,
    ]);
    for (const x of r.rows) traces.set(x.id, x.offsets);
  }
  return sessionView(sessionPayload(s, seats, traces, cfg, now), mine.seat, now);
}

/** Blocked pairs (either direction) among these accounts. */
async function blocksAmong(q: Queryable, userIds: string[]): Promise<ReadonlySet<string>> {
  if (userIds.length < 2) return new Set();
  const r = await q.query<{ blocker: string; blocked: string }>(
    `select blocker_user_id as blocker, blocked_user_id as blocked from public.blocks
      where blocker_user_id = any($1::uuid[]) and blocked_user_id = any($1::uuid[])`,
    [userIds],
  );
  return blockSet(r.rows);
}

const waiting = (rows: TicketRow[]): WaitingTicket[] => rows.map((t) => ({ id: t.id, userId: t.user_id, enqueuedAtMs: t.enqueued_at.getTime() }));

/** One pass of the global quick-match queue. Returns how many sessions started. */
export async function groupQuickQueue(tx: Tx, cfg: RippleConfig, now: Date): Promise<number> {
  const r = await tx.query<TicketRow>(
    `select ${TICKET_COLS} from public.ripple_tickets
      where entry = 'quick' and status = 'waiting' and last_poll_at > $1::timestamptz - make_interval(secs => $2)
      order by enqueued_at, id
      limit 200
      for update skip locked`,
    [now, cfg.ticketStaleS],
  );
  if (r.rows.length === 0) return 0;
  const byId = new Map(r.rows.map((t) => [t.id, t]));
  const groups = planQuickMatch(waiting(r.rows), await blocksAmong(tx, r.rows.map((t) => t.user_id)), now.getTime(), cfg);
  for (const g of groups) await createSession(tx, { entry: 'quick', roomId: null, inviteId: null, rule: g.rule }, ticketsOf(g, byId), cfg, now);
  return groups.length;
}

/**
 * A room invite's tables. Before its deadline only full tables start; at the deadline everyone waiting starts (blocked
 * pairs in parallel sessions) and the invite closes. The caller holds the invite row lock.
 */
export async function groupInvite(tx: Tx, invite: InviteRow, cfg: RippleConfig, now: Date): Promise<number> {
  const due = invite.status !== 'open' || invite.starts_at.getTime() <= now.getTime();
  const r = await tx.query<TicketRow>(
    `select ${TICKET_COLS} from public.ripple_tickets
      where invite_id = $1 and status = 'waiting' and last_poll_at > $2::timestamptz - make_interval(secs => $3)
      order by enqueued_at, id
      for update skip locked`,
    [invite.id, now, cfg.ticketStaleS],
  );
  const byId = new Map(r.rows.map((t) => [t.id, t]));
  const groups = planInviteGroups(waiting(r.rows), await blocksAmong(tx, r.rows.map((t) => t.user_id)), due, cfg);
  for (const g of groups) {
    await createSession(tx, { entry: 'room', roomId: invite.room_id, inviteId: invite.id, rule: 'invite' }, ticketsOf(g, byId), cfg, now);
  }
  if (due && invite.status === 'open') {
    await tx.query(`update public.ripple_invites set status = 'started' where id = $1`, [invite.id]);
    await RippleBroadcast.inviteClosed(tx, invite.room_id, invite.id, now);
  } else if (groups.length) {
    await RippleBroadcast.invite(tx, invite.room_id, invite.id, now);
  }
  return groups.length;
}

function ticketsOf(g: PlannedGroup, byId: ReadonlyMap<string, TicketRow>): TicketRow[] {
  return g.ticketIds.map((id) => byId.get(id)).filter((t): t is TicketRow => !!t);
}

/** Pseudonyms the account shows in its current rooms: a fresh quick-match name never repeats one of them. */
async function roomPseudonymsOf(q: Queryable, userId: string): Promise<string[]> {
  const r = await q.query<{ pseudonym: string }>(
    `select m.pseudonym from public.room_members m join public.rooms r on r.id = m.room_id
      where m.user_id = $1 and m.left_at is null and r.purge_at > now()`,
    [userId],
  );
  return r.rows.map((x) => x.pseudonym);
}

interface SessionSpec {
  entry: RippleEntry;
  roomId: string | null;
  inviteId: string | null;
  rule: StartRule;
}

/**
 * Seats the group (humans first, in queue order), fills empty seats with echoes or guides, marks the tickets matched
 * and broadcasts `session_start`. t0 = now (+ lead): the 10 s settle-in covers the ≤ 2 s until every phone polls.
 */
export async function createSession(tx: Tx, spec: SessionSpec, tickets: TicketRow[], cfg: RippleConfig, now: Date): Promise<string> {
  const t0 = new Date(now.getTime() + cfg.startLeadMs);
  const endsAt = new Date(t0.getTime() + sessionLengthMs(cfg));
  const room = spec.roomId
    ? (await tx.query<{ tz_region: string; language_pool: string }>('select tz_region, language_pool from public.rooms where id = $1', [spec.roomId]))
        .rows[0]
    : undefined;
  const s = await tx.query<SessionRow>(
    `insert into public.ripple_sessions (entry, room_id, invite_id, tz_region, language_pool, start_rule, t0, settle_ms, inhale_ms,
                                         exhale_ms, cycles, fade_ms, pacer_version, ends_at, purge_at)
     values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $14::timestamptz + make_interval(days => $15))
     returning ${SESSION_COLS}`,
    [
      spec.entry,
      spec.roomId,
      spec.inviteId,
      room?.tz_region ?? null,
      room?.language_pool ?? null,
      spec.rule,
      t0,
      cfg.settleMs,
      cfg.inhaleMs,
      cfg.exhaleMs,
      cfg.cycles,
      cfg.fadeMs,
      cfg.pacerVersion,
      endsAt,
      cfg.sessionRetentionD,
    ],
  );
  const session = s.rows[0];

  const taken = new Set<string>();
  let seat = 0;
  for (const t of tickets) {
    seat += 1;
    let pseudonym: string;
    if (spec.entry === 'room' && t.room_member_id) {
      pseudonym = (await tx.query<{ pseudonym: string }>('select pseudonym from public.room_members where member_id = $1', [t.room_member_id])).rows[0]
        .pseudonym;
    } else {
      pseudonym = generatePseudonym(new Set([...taken, ...(await roomPseudonymsOf(tx, t.user_id))]));
    }
    taken.add(pseudonym);
    const ins = await tx.query<{ id: string }>(
      `insert into public.ripple_seats (session_id, seat, kind, user_id, room_member_id, pseudonym, waited_ms)
       values ($1, $2, 'human', $3, $4, $5, $6) returning id`,
      [session.id, seat, t.user_id, spec.entry === 'room' ? t.room_member_id : null, pseudonym, Math.max(0, now.getTime() - t.enqueued_at.getTime())],
    );
    await tx.query(`update public.ripple_tickets set status = 'matched', session_id = $2, seat = $3, matched_at = $4 where id = $1`, [
      t.id,
      session.id,
      seat,
      now,
    ]);
    await logEvent(tx, session.id, { seat, id: ins.rows[0].id }, 'seated');
  }

  const on = await echoesOn(tx);
  const fill = fillPlan(tickets.length, cfg, on, on ? await eligibleEchoCount(tx, cfg) : 0);
  const echoes = await pickEchoes(tx, cfg, fill.echoes);
  const guides = fill.guides + (fill.echoes - echoes.length); // library shrank between count and pick: guides instead
  for (const e of echoes) {
    seat += 1;
    await tx.query(`insert into public.ripple_seats (session_id, seat, kind, echo_id) values ($1, $2, 'echo', $3)`, [session.id, seat, e.id]);
  }
  for (let i = 0; i < guides; i++) {
    seat += 1;
    await tx.query(`insert into public.ripple_seats (session_id, seat, kind) values ($1, $2, 'guide')`, [session.id, seat]);
  }

  const seats = await seatsOf(tx, session.id);
  const traces = new Map(echoes.map((e) => [e.id, e.offsets]));
  await RippleBroadcast.sessionStart(tx, session.id, sessionPayload(session, seats, traces, cfg, now));
  return session.id;
}

/**
 * Silent leave: the light dims into an echo for the others (`seat_update`), nobody sees "left". The last human
 * leaving ends the session. Returns whether this call left the seat.
 */
export async function leaveSeat(tx: Tx, sessionId: string, seatRow: { id: string; seat: number }, now: Date): Promise<boolean> {
  const r = await tx.query('update public.ripple_seats set left_at = $2 where id = $1 and left_at is null', [seatRow.id, now]);
  if (!r.rowCount) return false;
  await logEvent(tx, sessionId, seatRow, 'left');
  await RippleBroadcast.seatUpdate(tx, sessionId, seatRow.seat, 'echo', now);
  const left = await tx.query<{ n: number }>(
    `select count(*)::int as n from public.ripple_seats where session_id = $1 and kind = 'human' and left_at is null`,
    [sessionId],
  );
  if ((left.rows[0]?.n ?? 0) === 0) {
    const ended = await tx.query('update public.ripple_sessions set ended_at = $2 where id = $1 and ended_at is null', [sessionId, now]);
    if (ended.rowCount) await RippleBroadcast.sessionEnd(tx, sessionId, now);
  }
  return true;
}

/** Re-matching while seated elsewhere silently leaves the older, unfinished seats. */
export async function leaveActiveSeats(tx: Tx, userId: string, now: Date): Promise<void> {
  const r = await tx.query<{ id: string; seat: number; session_id: string }>(
    `select s.id, s.seat, s.session_id from public.ripple_seats s join public.ripple_sessions x on x.id = s.session_id
      where s.user_id = $1 and s.kind = 'human' and s.left_at is null and x.ended_at is null and x.ends_at > $2
      for update of s`,
    [userId, now],
  );
  for (const x of r.rows) await leaveSeat(tx, x.session_id, x, now);
}

/** People who joined an invite (waiting or already seated): the banner's "2/4". */
export async function inviteHumans(q: Queryable, inviteId: string): Promise<number> {
  const r = await q.query<{ n: number }>(
    `select count(*)::int as n from public.ripple_tickets where invite_id = $1 and status in ('waiting','matched')`,
    [inviteId],
  );
  return r.rows[0]?.n ?? 0;
}
