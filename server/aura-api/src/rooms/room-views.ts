import type { Quadrant } from '../rules';
import type { MatchingConfig } from './matching-config';
import { lanternWindow } from './regions';
import { deriveRoomState } from './room-state';
import {
  bucketHue,
  memberTopic,
  roomTopic,
  type GestureTarget,
  type GestureType,
  type RoomState,
  type Silhouette,
  type Theme,
} from './room-types';
import type {
  CountsRow,
  MemberRow,
  MemberViewRow,
  ReceivedGestureRow,
  RoomGestureRow,
  RoomRow,
  SentGestureRow,
} from './rooms.repository';

/**
 * Contract shapes (contracts/api/v1-rooms.md "Shared shapes"). Everything a client sees about a room is built here
 * from explicit fields — never by spreading DB rows — so no account id, age or DOB can leak (DS-10).
 */
export interface LanternHourView {
  timezone: string;
  active: boolean;
  startsAt: string;
  endsAt: string;
}

export interface RoomInfo {
  roomId: string;
  quadrant: Quadrant;
  theme: Theme;
  state: RoomState;
  readOnly: boolean;
  createdAt: string;
  joinsCloseAt: string;
  memoryAt: string;
  purgeAt: string;
  lanternHour: LanternHourView;
}

export type RoomStateView = Pick<RoomInfo, 'state' | 'readOnly' | 'joinsCloseAt' | 'memoryAt' | 'purgeAt'>;

export interface Counts {
  hereNow: number;
  today: number;
}

export interface PublicMember {
  memberId: string;
  pseudonym: string;
  silhouette: Silhouette;
  moodChip: string;
}

export interface Member extends PublicMember {
  live: boolean;
  muted: boolean;
  isMe: boolean;
}

export interface ReceivedGesture {
  gestureId: string;
  type: GestureType;
  fromMemberId: string;
  fromPseudonym: string;
  at: string;
}

export interface SentGesture {
  gestureId: string;
  type: GestureType;
  target: GestureTarget;
  toMemberId: string | null;
  at: string;
}

export interface RoomGesture {
  gestureId: string;
  type: GestureType;
  target: GestureTarget;
  at: string;
}

export interface RoomSummary {
  room: RoomInfo;
  me: { memberId: string; pseudonym: string; moodChip: string; joinedAt: string };
  counts: Counts;
}

export interface RoomDetail {
  room: RoomInfo;
  me: { memberId: string; pseudonym: string; moodChip: string; silhouette: Silhouette; joinedAt: string; surveyEligible: boolean };
  counts: Counts;
  members: Member[];
  gestures: { received: ReceivedGesture[]; sent: SentGesture[]; recent: RoomGesture[] };
  realtime: { roomTopic: string; memberTopic: string };
}

const iso = (d: Date): string => d.toISOString();

export function lanternView(room: Pick<RoomRow, 'tz_region'>, now: Date, cfg: MatchingConfig): LanternHourView {
  const w = lanternWindow(room.tz_region, now, cfg.lanternStart, cfg.lanternEnd);
  return { timezone: w.timezone, active: w.active, startsAt: iso(w.startsAt), endsAt: iso(w.endsAt) };
}

/** The derived state (purged rooms never reach a view: they are 404). */
export function stateOf(room: RoomRow, now: Date, cfg: MatchingConfig): RoomState | 'purged' {
  const w = lanternWindow(room.tz_region, now, cfg.lanternStart, cfg.lanternEnd);
  return deriveRoomState(
    { openedAt: room.opened_at, joinsCloseAt: room.joins_close_at, memoryAt: room.memory_at, purgeAt: room.purge_at },
    now,
    w.active,
  );
}

export function roomInfo(room: RoomRow, now: Date, cfg: MatchingConfig): RoomInfo {
  const derived = stateOf(room, now, cfg);
  const state: RoomState = derived === 'purged' ? 'memory' : derived;
  return {
    roomId: room.id,
    quadrant: room.quadrant,
    theme: room.theme,
    state,
    readOnly: state === 'memory',
    createdAt: iso(room.created_at),
    joinsCloseAt: iso(room.joins_close_at),
    memoryAt: iso(room.memory_at),
    purgeAt: iso(room.purge_at),
    lanternHour: lanternView(room, now, cfg),
  };
}

export function roomStateView(info: RoomInfo): RoomStateView {
  return { state: info.state, readOnly: info.readOnly, joinsCloseAt: info.joinsCloseAt, memoryAt: info.memoryAt, purgeAt: info.purgeAt };
}

export const countsView = (c: CountsRow): Counts => ({ hereNow: c.here_now, today: c.today });

export function silhouetteOf(m: Pick<MemberRow, 'stage' | 'hue' | 'cosmetic'>): Silhouette {
  // Standard cosmetics arrive with F12; until then nothing is shown (limited items would render generic anyway).
  return { stage: m.stage, hue: bucketHue(m.hue), cosmetic: null };
}

export function publicMember(m: Pick<MemberRow, 'member_id' | 'pseudonym' | 'mood_at_join' | 'stage' | 'hue' | 'cosmetic'>): PublicMember {
  return { memberId: m.member_id, pseudonym: m.pseudonym, silhouette: silhouetteOf(m), moodChip: m.mood_at_join };
}

export function memberView(m: MemberViewRow): Member {
  return {
    memberId: m.member_id,
    pseudonym: m.pseudonym,
    silhouette: silhouetteOf(m),
    moodChip: m.mood_at_join,
    live: m.live,
    muted: m.muted,
    isMe: m.is_me,
  };
}

export const receivedView = (g: ReceivedGestureRow): ReceivedGesture => ({
  gestureId: g.id,
  type: g.type,
  fromMemberId: g.from_member_id,
  fromPseudonym: g.from_pseudonym,
  at: iso(g.created_at),
});

export const sentView = (g: SentGestureRow): SentGesture => ({
  gestureId: g.id,
  type: g.type,
  target: g.target,
  toMemberId: g.to_member_id,
  at: iso(g.created_at),
});

export const recentView = (g: RoomGestureRow): RoomGesture => ({ gestureId: g.id, type: g.type, target: g.target, at: iso(g.created_at) });

export function summaryView(room: RoomRow, me: MemberRow, counts: CountsRow, now: Date, cfg: MatchingConfig): RoomSummary {
  return {
    room: roomInfo(room, now, cfg),
    me: { memberId: me.member_id, pseudonym: me.pseudonym, moodChip: me.mood_at_join, joinedAt: iso(me.joined_at) },
    counts: countsView(counts),
  };
}

export const realtimeTopics = (room: Pick<RoomRow, 'id'>, me: Pick<MemberRow, 'member_id'>): RoomDetail['realtime'] => ({
  roomTopic: roomTopic(room.id),
  memberTopic: memberTopic(me.member_id),
});
