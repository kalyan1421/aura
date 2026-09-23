import { Injectable, Logger } from '@nestjs/common';
import { QueuesService } from '../queues/queues.service';
import { auditConsole } from './admin-audit';
import { AdminConfig } from './admin-config';
import { AdminDb } from './admin-db';
import { AdminErrors } from './admin-errors';
import type { StaffUser } from './admin-types';

/**
 * PRD 19 "Single operator and on-call": "Queue sessions capped at 2 h" — a wellbeing limit on continuous review work
 * (opening report items and acting on them). A session runs while the reviewer keeps working; `breakMinutes` without
 * review work ends it. Once a session reaches `maxMinutes`, non-urgent items stay closed to that staff member until
 * they have been away for `breakMinutes` [ASSUMPTION: 15 min]. Urgent items — the crisis lane and anything that pages
 * (L0 in Lantern Hour, L1 sexual / grooming involving a minor) — always stay open: safety work is never locked, and it
 * doesn't postpone the break. The queue list and the "Now" dashboard are never capped (they carry deadlines, legal
 * orders and pages). State lives in Redis per staff member; if Redis is down the cap fails open (logged).
 */
export interface QueueSessionConfig {
  maxMinutes: number;
  breakMinutes: number;
}

export interface QueueSessionState {
  startedAt: number;
  lastAt: number;
  cappedAt: number | null;
}

export interface QueueStep {
  next: QueueSessionState | null;
  allowed: boolean;
  capped: boolean;
  /** First refusal of this session (audited once). */
  newlyCapped: boolean;
  breakUntil: number | null;
  startedAt: number | null;
  minutesLeft: number;
}

const MIN = 60_000;

/**
 * Pure step (unit-tested): `touch` = this request is review work (a peek only reads); `urgent` = a paging / crisis item.
 */
export function stepQueueSession(
  prev: QueueSessionState | null,
  now: number,
  cfg: QueueSessionConfig,
  opts: { touch: boolean; urgent: boolean },
): QueueStep {
  const maxMs = cfg.maxMinutes * MIN;
  const breakMs = cfg.breakMinutes * MIN;
  const live = prev !== null && now - prev.lastAt < breakMs;
  if (!live) {
    const next = opts.touch && !opts.urgent ? { startedAt: now, lastAt: now, cappedAt: null } : null;
    return { next, allowed: true, capped: false, newlyCapped: false, breakUntil: null, startedAt: next?.startedAt ?? null, minutesLeft: cfg.maxMinutes };
  }
  const s = prev as QueueSessionState;
  const capped = now - s.startedAt >= maxMs;
  if (capped) {
    const breakUntil = s.lastAt + breakMs;
    if (opts.urgent || !opts.touch) {
      return { next: s, allowed: true, capped: true, newlyCapped: false, breakUntil, startedAt: s.startedAt, minutesLeft: 0 };
    }
    return {
      next: { ...s, cappedAt: s.cappedAt ?? now },
      allowed: false,
      capped: true,
      newlyCapped: s.cappedAt === null,
      breakUntil,
      startedAt: s.startedAt,
      minutesLeft: 0,
    };
  }
  const next = opts.touch && !opts.urgent ? { ...s, lastAt: now } : s;
  return {
    next,
    allowed: true,
    capped: false,
    newlyCapped: false,
    breakUntil: null,
    startedAt: s.startedAt,
    minutesLeft: Math.max(0, Math.ceil((maxMs - (now - s.startedAt)) / MIN)),
  };
}

export interface QueueSessionView {
  active: boolean;
  startedAt: string | null;
  minutesLeft: number;
  capped: boolean;
  breakUntil: string | null;
  maxMinutes: number;
  breakMinutes: number;
}

/** Minimal Redis surface (QueuesService.redis; a fake in unit tests). */
export interface QueueSessionStore {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, mode: 'EX', seconds: number): Promise<unknown>;
}

@Injectable()
export class QueueSessionService {
  private readonly logger = new Logger('QueueSession');
  /** Swappable in tests. */
  clock: () => number = () => Date.now();
  private readonly store: QueueSessionStore;

  constructor(
    queues: QueuesService,
    private readonly config: AdminConfig,
    private readonly adminDb: AdminDb,
  ) {
    this.store = queues.redis as unknown as QueueSessionStore;
  }

  private key(staff: StaffUser): string {
    return `aura:admin:queue-session:${staff.id}`;
  }

  private async load(staff: StaffUser): Promise<QueueSessionState | null | undefined> {
    try {
      const raw = await this.store.get(this.key(staff));
      if (!raw) return null;
      const v = JSON.parse(raw) as QueueSessionState;
      return typeof v.startedAt === 'number' && typeof v.lastAt === 'number' ? v : null;
    } catch (e) {
      this.logger.warn(`queue-session store unavailable (${(e as Error).name}); not capping`);
      return undefined;
    }
  }

  private async save(staff: StaffUser, s: QueueSessionState): Promise<void> {
    const ttl = (this.config.queueSession.maxMinutes + this.config.queueSession.breakMinutes) * 60 + 60;
    await this.store.set(this.key(staff), JSON.stringify(s), 'EX', ttl).catch(() => undefined);
  }

  private view(step: QueueStep): QueueSessionView {
    return {
      active: step.startedAt !== null,
      startedAt: step.startedAt !== null ? new Date(step.startedAt).toISOString() : null,
      minutesLeft: step.minutesLeft,
      capped: step.capped,
      breakUntil: step.breakUntil !== null ? new Date(step.breakUntil).toISOString() : null,
      maxMinutes: this.config.queueSession.maxMinutes,
      breakMinutes: this.config.queueSession.breakMinutes,
    };
  }

  /** Read-only: where this staff member's session stands (for the console header and the queue page). */
  async peek(staff: StaffUser): Promise<QueueSessionView> {
    const prev = await this.load(staff);
    return this.view(stepQueueSession(prev ?? null, this.clock(), this.config.queueSession, { touch: false, urgent: false }));
  }

  /** Before review work: counts it, or refuses a non-urgent item with 423 once the session is over its limit. */
  async gate(staff: StaffUser, opts: { urgent: boolean }): Promise<QueueSessionView> {
    const prev = await this.load(staff);
    if (prev === undefined) return this.view(stepQueueSession(null, this.clock(), this.config.queueSession, { touch: false, urgent: false }));
    const step = stepQueueSession(prev, this.clock(), this.config.queueSession, { touch: true, urgent: opts.urgent });
    if (step.next && step.next !== prev) await this.save(staff, step.next);
    if (step.newlyCapped) {
      await auditConsole(this.adminDb, staff.actor, {
        action: 'queue_session_capped',
        reasonCode: 'session_limit',
        detail: { maxMinutes: this.config.queueSession.maxMinutes, breakMinutes: this.config.queueSession.breakMinutes },
      }).catch(() => undefined);
    }
    if (!step.allowed) throw AdminErrors.queueSessionCap(new Date(step.breakUntil as number).toISOString());
    return this.view(step);
  }
}
