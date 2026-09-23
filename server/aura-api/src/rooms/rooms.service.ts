import { Injectable } from '@nestjs/common';
import { CatalogueService } from '../catalogue/catalogue.service';
import { ApiError, profileRequired } from '../common/api-error';
import { parseOrThrow } from '../common/zod';
import { pgCode, pgConstraint, type Queryable, type Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import type { Quadrant } from '../rules';
import { assertGuidelinesAccepted } from '../safety/guidelines';
import { assertRoomAccess } from '../safety/safety.queries';
import { Broadcast } from './broadcast';
import { loadMatchingConfig, type MatchingConfig } from './matching-config';
import { planLadder, resolvePartition, type LadderStep } from './matching';
import { generatePseudonym } from './pseudonyms';
import { isLanternHour, regionForTimeZone, type TzRegion } from './regions';
import { ADJACENT_QUADRANT, bucketHue, HI_POOL_FLAG, THEME_BY_QUADRANT, type LanguagePool } from './room-types';
import {
  countsView,
  memberView,
  publicMember,
  realtimeTopics,
  receivedView,
  recentView,
  roomInfo,
  roomStateView,
  sentView,
  silhouetteOf,
  stateOf,
  summaryView,
  type Counts,
  type RoomDetail,
  type RoomInfo,
  type RoomSummary,
} from './room-views';
import { lockPartition, RoomsRepository, type MemberRow, type RoomRow } from './rooms.repository';
import {
  invalidTarget,
  joinLimit,
  languagePoolUnavailable,
  matchRequestSchema,
  memberNotFound,
  muteRequestSchema,
  pathId,
  roomNotFound,
  surveyRequestSchema,
} from './rooms.schema';

export interface MatchInfo {
  step: 0 | LadderStep;
  reentry: boolean;
  created: boolean;
  merged: boolean;
}

export type MatchResponse = RoomDetail & { match: MatchInfo };

interface JoinContext {
  userId: string;
  moodId: string;
  entryQuadrant: Quadrant;
  homePool: LanguagePool;
  homeRegion: TzRegion;
}

/**
 * F5 Mood Rooms (contracts/api/v1-rooms.md §1): matching ladder, membership, liveness, leave, survey, mutes.
 * Stranger-facing output is built only by room-views.ts / broadcast.ts (DS-10). Never logs ids or pseudonyms.
 */
@Injectable()
export class RoomsService {
  constructor(
    private readonly db: DbService,
    private readonly repo: RoomsRepository,
    private readonly catalogue: CatalogueService,
  ) {}

  // ------------------------------------------------------------------ match
  async match(userId: string, body: unknown, now = new Date()): Promise<MatchResponse> {
    const req = parseOrThrow(matchRequestSchema, body);
    const moodQuadrant = await this.catalogue.moodQuadrant(req.moodId);
    if (moodQuadrant !== req.quadrant) {
      throw ApiError.badRequest('invalid_request', 'moodId: must be a catalogue mood in the given quadrant');
    }
    const profile = await this.profileOf(this.db, userId);
    if (!profile) throw profileRequired();
    await assertRoomAccess(this.db, userId);
    // REQ-SAFE-04: the community guidelines (current version or newer) come before any room → 409 + version.
    await assertGuidelinesAccepted(this.db, userId);

    const homeRegion = regionForTimeZone(req.timezone ?? profile.timezone, now);
    const homePool = profile.language_pool;
    let matchPool: LanguagePool = homePool;
    if (homePool === 'hi' && !(await this.flagEnabled(HI_POOL_FLAG))) {
      if (!req.allowPoolFallback) throw languagePoolUnavailable();
      matchPool = 'en';
    }

    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId); // one room per quadrant per account: concurrent matches of one user serialise
      const cfg = await loadMatchingConfig(tx);

      // Step 0 — return to the room held for this quadrant (same seat, pseudonym and member id).
      const held = await this.repo.activeRoomForQuadrant(tx, userId, req.quadrant);
      if (held) {
        await this.markHere(tx, held.room, held.member, cfg, now);
        const detail = await this.buildDetail(tx, held.room, held.member, userId, cfg, now);
        return { ...detail, match: { step: 0, reentry: true, created: false, merged: false } };
      }

      if ((await this.repo.newJoins24h(tx, userId, req.quadrant)) >= cfg.joinsPerQuadrant24h) throw joinLimit();

      const partition = resolvePartition({ pool: matchPool, region: homeRegion }, await this.repo.demand(tx, req.quadrant), cfg.partition);
      await lockPartition(tx, partition.pool, req.quadrant, partition.region);

      const adjacentQuadrant = ADJACENT_QUADRANT[req.quadrant];
      const skipAdjacent = await this.repo.holdsRoomOfQuadrant(tx, userId, adjacentQuadrant);
      const base = { pool: partition.pool, region: partition.region, userId, liveWindowS: cfg.liveWindowS };
      const plan = planLadder({
        moodId: req.moodId,
        partition: await this.repo.candidates(tx, { ...base, quadrants: [req.quadrant] }),
        adjacent: skipAdjacent ? [] : await this.repo.candidates(tx, { ...base, quadrants: [adjacentQuadrant] }),
        partitionLive15: await this.repo.partitionLive(tx, partition.pool, req.quadrant, partition.region, cfg.partitionLiveWindowMin),
        lanternHour: isLanternHour(partition.region, now, cfg.lanternStart, cfg.lanternEnd),
        config: cfg.ladder,
      });

      const ctx: JoinContext = { userId, moodId: req.moodId, entryQuadrant: req.quadrant, homePool, homeRegion };
      for (const choice of plan.ranked) {
        const joined = await this.tryJoin(tx, choice.roomId, choice.step, ctx, cfg, now);
        if (joined) {
          const detail = await this.buildDetail(tx, joined.room, joined.member, userId, cfg, now);
          const merged = partition.merged || choice.step === 3;
          return { ...detail, match: { step: choice.step, reentry: false, created: false, merged } };
        }
      }

      // Nothing joinable (or every live room is full enough outside Lantern Hour): a new room for the partition.
      const room = await this.repo.createRoom(tx, {
        pool: partition.pool,
        quadrant: req.quadrant,
        region: partition.region,
        seedMoodId: req.moodId,
        theme: THEME_BY_QUADRANT[req.quadrant],
        capacity: cfg.roomCapacity,
        joinCutoffH: cfg.joinCutoffH,
        memoryAfterH: cfg.memoryAfterH,
        purgeAfterD: cfg.purgeAfterD,
      });
      const member = await this.insertMember(tx, room, plan.spawnStep, ctx);
      if (!member) throw new Error('could not seat the first member of a new room');
      const detail = await this.buildDetail(tx, room, member, userId, cfg, now);
      return { ...detail, match: { step: plan.spawnStep, reentry: false, created: true, merged: partition.merged } };
    });
  }

  /** Under the room's row lock: re-check capacity and blocks, seat the joiner, open the room at its 2nd member. */
  private async tryJoin(
    tx: Tx,
    roomId: string,
    step: LadderStep,
    ctx: JoinContext,
    cfg: MatchingConfig,
    now: Date,
  ): Promise<{ room: RoomRow; member: MemberRow } | null> {
    const locked = await this.repo.lockRoom(tx, roomId);
    if (!locked || locked.joins_close_at.getTime() <= now.getTime()) return null;
    const check = await this.repo.joinCheck(tx, roomId, ctx.userId);
    if (check.active >= locked.capacity || check.blocked) return null;
    const member = await this.insertMember(tx, locked, step, ctx);
    if (!member) return null;

    let room = locked;
    if (!locked.opened_at && check.total + 1 >= 2) {
      const provisional = { ...locked, opened_at: now };
      const state = stateOf(provisional, now, cfg);
      const opened = await this.repo.markOpened(tx, roomId, state === 'purged' ? 'memory' : state);
      if (opened) {
        room = opened;
        const info = roomInfo(room, now, cfg);
        await Broadcast.roomState(tx, roomId, roomStateView(info), now);
        if (info.state === 'lantern_hour') await Broadcast.lanternHour(tx, roomId, info.lanternHour, now);
      }
    }
    const counts = countsView(await this.repo.counts(tx, roomId, cfg.liveWindowS));
    await Broadcast.memberJoined(tx, roomId, publicMember(member), counts, now);
    await this.rememberPresence(tx, roomId, counts);
    return { room, member };
  }

  /** Seat with a fresh pseudonym (unique in the room, unlike the joiner's other rooms). null = the DB guard refused. */
  private async insertMember(tx: Tx, room: RoomRow, step: LadderStep, ctx: JoinContext): Promise<MemberRow | null> {
    const taken = new Set([...(await this.repo.roomPseudonyms(tx, room.id)), ...(await this.repo.activePseudonymsOf(tx, ctx.userId))]);
    const avatar = await this.repo.avatarOf(tx, ctx.userId);
    for (let attempt = 0; attempt < 5; attempt++) {
      const pseudonym = generatePseudonym(taken);
      try {
        return await tx.savepoint((sp) =>
          this.repo.insertMember(sp, {
            roomId: room.id,
            userId: ctx.userId,
            pseudonym,
            moodId: ctx.moodId,
            entryQuadrant: ctx.entryQuadrant,
            homePool: ctx.homePool,
            homeRegion: ctx.homeRegion,
            step,
            stage: avatar.stage,
            hue: bucketHue(avatar.hue),
          }),
        );
      } catch (err) {
        const code = pgCode(err);
        if (code === '23505' && pgConstraint(err) === 'room_members_pseudonym_unique') {
          taken.add(pseudonym);
          continue;
        }
        // AR001 room_full · AR002 one_room_per_quadrant · AR003 room_closed_to_joins · already a member
        if (code === 'AR001' || code === 'AR002' || code === 'AR003' || (code === '23505' && pgConstraint(err) === 'room_members_one_seat')) {
          return null;
        }
        throw err;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------ reads
  async list(userId: string, now = new Date()): Promise<{ rooms: RoomSummary[] }> {
    await assertRoomAccess(this.db, userId);
    const cfg = await loadMatchingConfig(this.db);
    const mine = await this.repo.myRooms(this.db, userId);
    const counts = await this.repo.countsFor(
      this.db,
      mine.map((x) => x.room.id),
      cfg.liveWindowS,
    );
    const rooms = mine
      .filter((x) => stateOf(x.room, now, cfg) !== 'purged')
      .map((x) => summaryView(x.room, x.member, counts.get(x.room.id) ?? { here_now: 0, today: 0 }, now, cfg));
    return { rooms };
  }

  async detail(userId: string, roomIdParam: string, now = new Date()): Promise<RoomDetail> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      const cfg = await loadMatchingConfig(tx);
      const { room, member } = await this.requireMembership(tx, roomId, userId, now, cfg);
      await this.markHere(tx, room, member, cfg, now); // opening the room counts as being here
      return this.buildDetail(tx, room, member, userId, cfg, now);
    });
  }

  async heartbeat(userId: string, roomIdParam: string, now = new Date()): Promise<{ room: RoomInfo; counts: Counts }> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      const cfg = await loadMatchingConfig(tx);
      const { room, member } = await this.requireMembership(tx, roomId, userId, now, cfg);
      await this.markHere(tx, room, member, cfg, now);
      return { room: roomInfo(room, now, cfg), counts: countsView(await this.repo.counts(tx, roomId, cfg.liveWindowS)) };
    });
  }

  // ------------------------------------------------------------------ leave, survey
  async leave(userId: string, roomIdParam: string, now = new Date()): Promise<{ surveyEligible: boolean }> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadMatchingConfig(tx);
      const member = await this.repo.membership(tx, roomId, userId, true);
      const room = member ? await this.repo.findRoom(tx, roomId) : null;
      if (!member || !room || stateOf(room, now, cfg) === 'purged') throw roomNotFound();
      if (await this.repo.leave(tx, member.member_id)) {
        const counts = countsView(await this.repo.counts(tx, roomId, cfg.liveWindowS));
        await Broadcast.memberLeft(tx, roomId, member.member_id, counts, now);
        await this.rememberPresence(tx, roomId, counts);
      }
      return { surveyEligible: await this.repo.surveyEligible(tx, { memberId: member.member_id, userId }) };
    });
  }

  /** Aggregate only; answers that aren't eligible (< 30 s, or already answered in 24 h) are ignored. */
  async survey(userId: string, roomIdParam: string, body: unknown, now = new Date()): Promise<void> {
    const roomId = pathId(roomIdParam, roomNotFound);
    const { answer } = parseOrThrow(surveyRequestSchema, body);
    await assertRoomAccess(this.db, userId);
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const cfg = await loadMatchingConfig(tx);
      const member = await this.repo.membership(tx, roomId, userId, true);
      const room = member ? await this.repo.findRoom(tx, roomId) : null;
      if (!member || !room || stateOf(room, now, cfg) === 'purged') throw roomNotFound();
      if (await this.repo.surveyEligible(tx, { memberId: member.member_id, userId })) {
        await this.repo.recordSurvey(tx, member.member_id, room, answer);
      }
    });
  }

  // ------------------------------------------------------------------ mutes (per membership, for you only)
  async mute(userId: string, roomIdParam: string, body: unknown, now = new Date()): Promise<void> {
    const roomId = pathId(roomIdParam, roomNotFound);
    const { memberId } = parseOrThrow(muteRequestSchema, body);
    await assertRoomAccess(this.db, userId);
    await this.db.withTx(async (tx) => {
      const cfg = await loadMatchingConfig(tx);
      const { member } = await this.requireMembership(tx, roomId, userId, now, cfg);
      if (memberId === member.member_id) throw invalidTarget();
      if (!(await this.repo.memberInRoom(tx, roomId, memberId))) throw memberNotFound();
      await this.repo.mute(tx, roomId, member.member_id, memberId);
    });
  }

  async unmute(userId: string, roomIdParam: string, memberIdParam: string, now = new Date()): Promise<void> {
    const roomId = pathId(roomIdParam, roomNotFound);
    const memberId = pathId(memberIdParam, memberNotFound);
    await assertRoomAccess(this.db, userId);
    await this.db.withTx(async (tx) => {
      const cfg = await loadMatchingConfig(tx);
      const { member } = await this.requireMembership(tx, roomId, userId, now, cfg);
      if (memberId === member.member_id) throw invalidTarget();
      if (!(await this.repo.memberInRoom(tx, roomId, memberId))) throw memberNotFound();
      await this.repo.unmute(tx, member.member_id, memberId);
    });
  }

  // ------------------------------------------------------------------ helpers
  /** A current (not left) membership of a room that isn't purged, else the same 404 for every case. */
  private async requireMembership(q: Queryable, roomId: string, userId: string, now: Date, cfg: MatchingConfig): Promise<{ room: RoomRow; member: MemberRow }> {
    const member = await this.repo.membership(q, roomId, userId);
    const room = member ? await this.repo.findRoom(q, roomId) : null;
    if (!member || !room || stateOf(room, now, cfg) === 'purged') throw roomNotFound();
    return { room, member };
  }

  /** Liveness: in a room that isn't a memory, mark the member here; a quiet → live change is broadcast. */
  private async markHere(tx: Tx, room: RoomRow, member: MemberRow, cfg: MatchingConfig, now: Date): Promise<void> {
    if (stateOf(room, now, cfg) === 'memory') return;
    const touched = await this.repo.touch(tx, member.member_id, cfg.liveWindowS);
    if (touched && !touched.wasLive) {
      const counts = countsView(await this.repo.counts(tx, room.id, cfg.liveWindowS));
      await Broadcast.presence(tx, room.id, counts, now);
      await this.rememberPresence(tx, room.id, counts);
    }
  }

  /** The lifecycle sweep only re-broadcasts "here now" when it differs from the last value pushed. */
  private async rememberPresence(q: Queryable, roomId: string, counts: Counts): Promise<void> {
    await q.query('update public.rooms set here_now_broadcast = $2 where id = $1', [roomId, counts.hereNow]);
  }

  private async buildDetail(q: Queryable, room: RoomRow, me: MemberRow, userId: string, cfg: MatchingConfig, now: Date): Promise<RoomDetail> {
    const viewer = { memberId: me.member_id, userId };
    const counts = await this.repo.counts(q, room.id, cfg.liveWindowS);
    const members = await this.repo.membersFor(q, room.id, viewer, cfg.liveWindowS);
    const received = await this.repo.gesturesReceived(q, viewer);
    const sent = await this.repo.gesturesSent(q, me.member_id);
    const recent = await this.repo.gesturesRecent(q, room.id, userId);
    const surveyEligible = await this.repo.surveyEligible(q, viewer);
    return {
      room: roomInfo(room, now, cfg),
      me: {
        memberId: me.member_id,
        pseudonym: me.pseudonym,
        moodChip: me.mood_at_join,
        silhouette: silhouetteOf(me),
        joinedAt: me.joined_at.toISOString(),
        surveyEligible,
      },
      counts: countsView(counts),
      members: members.map(memberView),
      gestures: { received: received.map(receivedView), sent: sent.map(sentView), recent: recent.map(recentView) },
      realtime: realtimeTopics(room, me),
    };
  }

  private async profileOf(q: Queryable, userId: string): Promise<{ language_pool: LanguagePool; timezone: string } | null> {
    const r = await q.query<{ language_pool: LanguagePool; timezone: string }>(
      'select language_pool, timezone from public.profiles where user_id = $1',
      [userId],
    );
    return r.rows[0] ?? null;
  }

  private async flagEnabled(key: string): Promise<boolean> {
    const r = await this.db.query<{ enabled: boolean }>('select enabled from public.feature_flags where key = $1', [key]);
    return r.rows[0]?.enabled ?? false;
  }
}

