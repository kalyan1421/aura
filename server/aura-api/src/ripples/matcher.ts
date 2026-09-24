import type { RippleConfig } from './ripple-config';
import type { StartRule } from './ripple-types';

/**
 * Pure Breath Ripples matching (PRD 06b F7 "Matching and realtime"; contracts/api/v1-ripples.md §1.1). The SQL side
 * locks the waiting tickets (`FOR UPDATE SKIP LOCKED`) and the blocks among them; this decides who sits together.
 *
 * Quick-match is ONE global queue (no language pool, region or age split). Oldest ticket first, each anchor greedily
 * takes the next compatible tickets (never a blocked pair, either direction) up to the seat count, and the group
 * starts when:
 *   - `full`    — 4 humans;
 *   - `early`   — the anchor has waited ≥ 8 s and ≥ 2 humans can sit together (then echo-fill);
 *   - `timeout` — the anchor has waited 20 s: whoever waits, alone if need be (then echo-fill).
 * Max wait is 20 s by construction; there is no "no one found" state (REQ-GAME-01).
 */
export interface WaitingTicket {
  id: string;
  userId: string;
  /** When the ticket joined the queue, on the DB clock (ms). */
  enqueuedAtMs: number;
}

export interface PlannedGroup {
  ticketIds: string[];
  rule: StartRule;
}

export type MatcherConfig = Pick<RippleConfig, 'seatCount' | 'earlyStartS' | 'earlyStartMinHumans' | 'maxWaitS'>;

/** Unordered pair key for the block set. */
export const pairKey = (a: string, b: string): string => (a < b ? `${a}|${b}` : `${b}|${a}`);

/** A set of blocked pairs (either direction) built from `blocks` rows. */
export function blockSet(rows: ReadonlyArray<{ blocker: string; blocked: string }>): ReadonlySet<string> {
  return new Set(rows.map((r) => pairKey(r.blocker, r.blocked)));
}

const compatible = (t: WaitingTicket, group: readonly WaitingTicket[], blocked: ReadonlySet<string>): boolean =>
  group.every((g) => g.userId !== t.userId && !blocked.has(pairKey(g.userId, t.userId)));

/** Greedy group for `anchor` from `pool` (oldest first), never a blocked pair, at most `size`. */
function greedy(anchor: WaitingTicket, pool: readonly WaitingTicket[], blocked: ReadonlySet<string>, size: number): WaitingTicket[] {
  const group = [anchor];
  for (const t of pool) {
    if (group.length >= size) break;
    if (t.id === anchor.id) continue;
    if (compatible(t, group, blocked)) group.push(t);
  }
  return group;
}

const byAge = (a: WaitingTicket, b: WaitingTicket): number => a.enqueuedAtMs - b.enqueuedAtMs || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);

/** The quick-match groups that start now. Tickets not in any group keep waiting. */
export function planQuickMatch(tickets: readonly WaitingTicket[], blocked: ReadonlySet<string>, nowMs: number, cfg: MatcherConfig): PlannedGroup[] {
  const waiting = [...tickets].sort(byAge);
  const taken = new Set<string>();
  const groups: PlannedGroup[] = [];
  for (const anchor of waiting) {
    if (taken.has(anchor.id)) continue;
    const pool = waiting.filter((t) => !taken.has(t.id));
    const group = greedy(anchor, pool, blocked, cfg.seatCount);
    const waited = nowMs - anchor.enqueuedAtMs;
    let rule: StartRule | null = null;
    if (group.length >= cfg.seatCount) rule = 'full';
    else if (group.length >= cfg.earlyStartMinHumans && waited >= cfg.earlyStartS * 1000) rule = 'early';
    else if (waited >= cfg.maxWaitS * 1000) rule = 'timeout';
    if (!rule) continue; // the anchor waits; younger tickets may still form a full table among themselves
    for (const t of group) taken.add(t.id);
    groups.push({ ticketIds: group.map((t) => t.id), rule });
  }
  return groups;
}

/**
 * A room invite's tables: everyone who joined, split so no blocked pair shares a session (the parallel sessions start
 * together and nobody can tell). Before the deadline only full tables start; at the deadline every table starts.
 */
export function planInviteGroups(tickets: readonly WaitingTicket[], blocked: ReadonlySet<string>, due: boolean, cfg: Pick<RippleConfig, 'seatCount'>): PlannedGroup[] {
  const waiting = [...tickets].sort(byAge);
  const taken = new Set<string>();
  const groups: PlannedGroup[] = [];
  for (const anchor of waiting) {
    if (taken.has(anchor.id)) continue;
    const group = greedy(
      anchor,
      waiting.filter((t) => !taken.has(t.id)),
      blocked,
      cfg.seatCount,
    );
    if (!due && group.length < cfg.seatCount) continue;
    for (const t of group) taken.add(t.id);
    groups.push({ ticketIds: group.map((t) => t.id), rule: 'invite' });
  }
  return groups;
}

/**
 * When a waiting phone should poll again: every `pollMs` (2 s), or just after the next start deadline that concerns
 * it (8 s / 20 s from its own enqueue, or the invite's start), so a start is never late by a whole poll.
 */
export function nextPollMs(nowMs: number, deadlinesMs: readonly number[], cfg: Pick<RippleConfig, 'pollMs'>): number {
  const next = deadlinesMs.filter((d) => d > nowMs).sort((a, b) => a - b)[0];
  if (next === undefined) return Math.min(cfg.pollMs, 500);
  return Math.max(250, Math.min(cfg.pollMs, next - nowMs + 50));
}

export interface FillPlan {
  echoes: number;
  guides: number;
}

/**
 * Empty seats (up to the seat count): echoes while the library holds ≥ `echoLibraryMin` eligible recordings, else
 * guide lights on the pacer (never presented as people). With echoes switched off, empty seats stay empty
 * ("Breathing on your own this time").
 */
export function fillPlan(
  humans: number,
  cfg: Pick<RippleConfig, 'seatCount' | 'echoLibraryMin'>,
  echoesOn: boolean,
  eligibleEchoes: number,
): FillPlan {
  const empty = Math.max(0, cfg.seatCount - humans);
  if (!echoesOn || empty === 0) return { echoes: 0, guides: 0 };
  if (eligibleEchoes >= cfg.echoLibraryMin && eligibleEchoes >= empty) return { echoes: empty, guides: 0 };
  return { echoes: 0, guides: empty };
}

/** p-th percentile (0–1) of a list (nearest rank); tests use it for the match-time p50. */
export function percentile(values: readonly number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const rank = Math.min(sorted.length - 1, Math.max(0, Math.ceil(p * sorted.length) - 1));
  return sorted[rank];
}
