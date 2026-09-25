import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import type { Queryable, Tx } from '../db/db';
import { DbService } from '../db/db.service';
import { lockUser } from '../db/locks';
import { RemoteConfigService } from '../remote-config/remote-config.service';
import { loadMatchingConfig } from '../rooms/matching-config';
import { stateOf } from '../rooms/room-views';
import { RoomsRepository, type MemberRow, type RoomRow } from '../rooms/rooms.repository';
import { pathId, roomNotFound, roomReadOnly } from '../rooms/rooms.schema';
import { appendAudit, subjectHash } from '../safety/audit';
import { anyMinor, assertRoomAccess } from '../safety/safety.queries';
import { URGENT_PAGER, type UrgentPager } from '../safety/urgent-pager';
import { decide, isOvernight, type Decision, type DecisionInput, type ForcedHold, type ProviderResult } from './decide';
import { checkReflectionText, type FilterResult } from './filter/reflection-filter';
import { ReflectionBroadcast } from './reflection-broadcast';
import { corpusLabel, feedCorpus } from './corpus';
import { sealReflection, textHash } from './reflection-cipher';
import { ReflectionCrisisLexicon, composerPaused, flagsFrom, loadReflectionConfig, type ReflectionConfig, type ReflectionFlags } from './reflection-config';
import { queueReflection } from './reflection-queue';
import { reflectionView, type ComposerView, type ReflectionView, type SendOutcome, type SendStatus } from './reflection-views';
import { ReflectionsRepository, type ReflectionRow } from './reflections.repository';
import { dailyLimit, parseSendRequest, reflectionIdConflict, reflectionNotFound, reflectionsPaused, roomLimit } from './reflections.schema';
import { MODERATION_PROVIDER, type ModerationProvider } from './moderation-provider';

/**
 * F6 Reflections for the app (contracts/api/v1-reflections.md §1): list / one / send / delete, and the moderation
 * pipeline (§3: crisis lexicon → grooming → contact rules → OpenAI omni-moderation → forced holds → thresholds →
 * published). Stranger reads go only through here (DS-10). The text is decrypted only to build a response and is never
 * logged; log lines carry outcomes, reasons, pools and latencies.
 *
 * Send runs in phases so no transaction is held open across the network call: (A) under the author's advisory lock —
 * membership, room state, kill switches, limits, the text rules, then insert (final for crisis / grooming, `pending`
 * otherwise); (B) the classifier (≤ `provider_timeout_ms`, outside any transaction); (C) the decision applied to the
 * still-pending row, broadcasts and queue items in one transaction. The request waits up to `respond_within_ms`
 * for C; after that it answers `pending` and C finishes in the background (the author gets `reflection_status`).
 * A pending row whose process died is held by the worker after `pending_timeout_s` — nothing is released by timeout.
 */
interface Viewer {
  member: MemberRow;
  room: RoomRow;
  readOnly: boolean;
}

interface PendingWork {
  row: ReflectionRow;
  text: string;
  input: Omit<DecisionInput, 'provider'>;
  filter: FilterResult;
  cfg: ReflectionConfig;
}

type PhaseA =
  | { kind: 'replay'; row: ReflectionRow }
  | { kind: 'rejected'; decision: Decision }
  | { kind: 'final'; row: ReflectionRow; decision: Decision; pages: string | null }
  | { kind: 'pending'; work: PendingWork };

const FAILURE_WINDOW_MS = 5 * 60_000;

@Injectable()
export class ReflectionsService {
  private readonly logger = new Logger('Reflections');
  private readonly repo = new ReflectionsRepository();
  private readonly lexicon = new ReflectionCrisisLexicon();
  private readonly inflight = new Set<Promise<unknown>>();
  private lastProviderFailureAt = 0;
  /** The clock for the overnight window and broadcasts (tests pin it). */
  clock: () => Date = () => new Date();

  constructor(
    private readonly db: DbService,
    private readonly rooms: RoomsRepository,
    private readonly app: AppConfig,
    private readonly remoteConfig: RemoteConfigService,
    @Inject(MODERATION_PROVIDER) private provider: ModerationProvider,
    @Optional() @Inject(URGENT_PAGER) private readonly pager?: UrgentPager,
  ) {}

  /** Tests: swap the classifier (e.g. a StaticModerationProvider). */
  useProvider(p: ModerationProvider): void {
    this.provider = p;
  }

  /** Tests: resolves when every background decision has been applied. */
  async idle(): Promise<void> {
    while (this.inflight.size) await Promise.allSettled([...this.inflight]);
  }

  // ------------------------------------------------------------------------------------------------ reads
  private async viewer(q: Queryable, userId: string, roomId: string): Promise<Viewer> {
    const member = await this.rooms.membership(q, roomId, userId);
    const room = member ? await this.rooms.findRoom(q, roomId) : null;
    if (!member || !room) throw roomNotFound();
    const state = stateOf(room, this.clock(), await loadMatchingConfig(q));
    if (state === 'purged') throw roomNotFound();
    return { member, room, readOnly: state === 'memory' };
  }

  private async flags(): Promise<ReflectionFlags> {
    return flagsFrom((await this.remoteConfig.current()).flags);
  }

  private overnight(cfg: ReflectionConfig, now: Date): boolean {
    return isOvernight(now, cfg.overnightStart, cfg.overnightEnd, cfg.overnightTz);
  }

  /** "Reflections are slower right now": no classifier configured, or it failed in the last 5 minutes. */
  private slow(now: number): boolean {
    return !this.provider.available || now - this.lastProviderFailureAt < FAILURE_WINDOW_MS;
  }

  private async composer(q: Queryable, userId: string, v: Viewer, cfg: ReflectionConfig, flags: ReflectionFlags): Promise<ComposerView> {
    const sent = await this.repo.sentCounts(q, userId, v.room.id);
    const remainingInRoom = Math.max(0, cfg.perRoom24h - sent.room);
    const remainingToday = Math.max(0, cfg.perAccount24h - sent.account);
    const state = v.readOnly
      ? 'read_only'
      : composerPaused(flags, v.room.language_pool)
        ? 'paused'
        : remainingInRoom === 0 || remainingToday === 0
          ? 'limit_reached'
          : 'open';
    return { state, maxChars: cfg.maxChars, perRoom: cfg.perRoom24h, remainingInRoom, remainingToday, slow: this.slow(Date.now()) };
  }

  async list(userId: string, roomIdParam: string): Promise<{ reflections: ReflectionView[]; composer: ComposerView }> {
    const roomId = pathId(roomIdParam, roomNotFound);
    await assertRoomAccess(this.db, userId);
    const flags = await this.flags();
    return this.db.withTx(async (tx) => {
      const v = await this.viewer(tx, userId, roomId);
      const cfg = await loadReflectionConfig(tx);
      const overnight = this.overnight(cfg, this.clock());
      const rows = await this.repo.visible(tx, roomId, { userId, memberId: v.member.member_id });
      const reflections = rows.map((r) => reflectionView(r, userId, this.app.masterKey, overnight)).filter((x): x is ReflectionView => x !== null);
      return { reflections, composer: await this.composer(tx, userId, v, cfg, flags) };
    });
  }

  async one(userId: string, roomIdParam: string, reflectionIdParam: string): Promise<ReflectionView> {
    const roomId = pathId(roomIdParam, roomNotFound);
    const id = pathId(reflectionIdParam, reflectionNotFound);
    await assertRoomAccess(this.db, userId);
    return this.db.withTx(async (tx) => {
      const v = await this.viewer(tx, userId, roomId);
      const cfg = await loadReflectionConfig(tx);
      const row = (await this.repo.visible(tx, roomId, { userId, memberId: v.member.member_id }, id, 1))[0];
      const view = row ? reflectionView(row, userId, this.app.masterKey, this.overnight(cfg, this.clock())) : null;
      if (!view) throw reflectionNotFound();
      return view;
    });
  }

  // ------------------------------------------------------------------------------------------------ send
  async send(userId: string, roomIdParam: string, body: unknown): Promise<{ created: boolean; outcome: SendOutcome }> {
    const roomId = pathId(roomIdParam, roomNotFound);
    const cfg = await loadReflectionConfig(this.db);
    const req = parseSendRequest(body, cfg.maxChars);
    await assertRoomAccess(this.db, userId);
    const flags = await this.flags();
    const now = this.clock();

    const a = await this.db.withTx((tx) => this.phaseA(tx, userId, roomId, req, cfg, flags, now));
    if (a.kind === 'final' && a.pages) this.pager?.reportFiled(a.pages);

    let status: SendStatus;
    let rejectReason: SendOutcome['rejectReason'] = null;
    let reflectionId = req.reflectionId;
    let created = true;
    if (a.kind === 'replay') {
      created = false;
      status = replayStatus(a.row);
      rejectReason = a.row.status === 'rejected' || a.row.status === 'removed' ? (a.row.reject_reason ?? 'other') : null;
    } else if (a.kind === 'rejected') {
      created = false;
      status = 'rejected';
      rejectReason = a.decision.rejectReason;
      this.logDecision(a.decision, cfg, null, 'rules');
    } else if (a.kind === 'final') {
      status = a.decision.outcome;
      rejectReason = a.decision.rejectReason;
      reflectionId = a.row.id;
      this.logDecision(a.decision, cfg, a.row.language_pool, 'rules');
    } else {
      const work = a.work;
      const done = this.track(this.phaseBC(work));
      const raced = await Promise.race([done, sleep(cfg.respondWithinMs).then(() => null)]);
      status = raced ? raced.outcome : 'pending';
      rejectReason = raced ? raced.rejectReason : null;
    }
    return { created, outcome: await this.outcome(userId, roomId, reflectionId, status, rejectReason, flags) };
  }

  private async outcome(
    userId: string,
    roomId: string,
    reflectionId: string,
    status: SendStatus,
    rejectReason: SendOutcome['rejectReason'],
    flags: ReflectionFlags,
  ): Promise<SendOutcome> {
    return this.db.withTx(async (tx) => {
      const v = await this.viewer(tx, userId, roomId);
      const cfg = await loadReflectionConfig(tx);
      const overnight = this.overnight(cfg, this.clock());
      const row = status === 'crisis_diverted' ? undefined : (await this.repo.visible(tx, roomId, { userId, memberId: v.member.member_id }, reflectionId, 1))[0];
      const reflection = row ? reflectionView(row, userId, this.app.masterKey, overnight) : null;
      const waiting = status === 'pending' || status === 'held';
      return {
        reflectionId,
        status,
        rejectReason: status === 'rejected' ? (rejectReason ?? 'other') : null,
        review: waiting ? (reflection?.review ?? (overnight ? 'overnight' : 'soon')) : null,
        showSupport: status === 'crisis_diverted',
        reflection,
        composer: await this.composer(tx, userId, v, cfg, flags),
      };
    });
  }

  private async phaseA(
    tx: Tx,
    userId: string,
    roomId: string,
    req: { reflectionId: string; text: string },
    cfg: ReflectionConfig,
    flags: ReflectionFlags,
    now: Date,
  ): Promise<PhaseA> {
    await lockUser(tx, userId);
    const v = await this.viewer(tx, userId, roomId);
    const existing = await this.repo.find(tx, req.reflectionId);
    if (existing) {
      if (existing.member_id !== v.member.member_id) throw reflectionIdConflict();
      return { kind: 'replay', row: existing };
    }
    if (v.readOnly) throw roomReadOnly();
    if (composerPaused(flags, v.room.language_pool)) throw reflectionsPaused();
    const sent = await this.repo.sentCounts(tx, userId, roomId);
    if (sent.room >= cfg.perRoom24h) throw roomLimit();
    if (sent.account >= cfg.perAccount24h) throw dailyLimit();

    const involvesMinor = await anyMinor(tx, [userId, ...(await this.repo.roomAccounts(tx, roomId))]);
    const strict = involvesMinor || v.room.language_pool !== 'en';
    const lexicon = (await this.lexicon.matcher(tx)).verdict(req.text);
    const filter = checkReflectionText(req.text, { strict });
    const overnight = this.overnight(cfg, now);
    const hash = textHash(this.app.masterKey, req.text);

    let forcedHold: ForcedHold | null = null;
    if (flags.holdAll) forcedHold = 'hold_all';
    else if (await this.repo.hasActiveStrike(tx, userId)) forcedHold = 'active_strike';
    else if (await this.repo.hasShadowMute(tx, userId)) forcedHold = 'sanction';
    else if ((await this.repo.duplicateRooms(tx, userId, hash, roomId)) >= cfg.nearDuplicateRooms) forcedHold = 'near_duplicate';

    const input: Omit<DecisionInput, 'provider'> = {
      lexicon,
      grooming: filter.grooming,
      contact: filter.contact,
      strict,
      overnight,
      forcedHold,
      thresholds: cfg.thresholds,
    };
    const ruleHits = [...(lexicon === 'crisis' ? ['crisis_lexicon'] : []), ...filter.hits];
    const decidedByRules = lexicon === 'crisis' || filter.grooming || filter.contact !== 'none';
    const sealed = sealReflection(this.app.masterKey, req.reflectionId, req.text);
    const base = {
      id: req.reflectionId,
      roomId,
      memberId: v.member.member_id,
      userId,
      bodyCt: sealed.bodyCt,
      bodyKey: sealed.bodyKey,
      charCount: graphemes(req.text),
      textHash: hash,
      languagePool: v.room.language_pool,
      involvesMinor,
      strict,
      overnight,
      ruleHits,
    };

    if (decidedByRules) {
      const decision = decide({ ...input, provider: null });
      if (!decision.store) return { kind: 'rejected', decision }; // contact details: nothing is stored (REQ-REF-02)
      const row = await this.repo.insert(tx, {
        ...base,
        status: decision.outcome,
        stage: decision.stage,
        holdReason: decision.holdReason,
        rejectReason: decision.rejectReason,
        scores: null,
        decided: true,
      });
      const q = await queueReflection(tx, row, decision, this.app.masterKey, now);
      return { kind: 'final', row, decision, pages: q?.pages ? q.reportId : null };
    }
    const row = await this.repo.insert(tx, {
      ...base,
      status: 'pending',
      stage: null,
      holdReason: null,
      rejectReason: null,
      scores: null,
      decided: false,
    });
    return { kind: 'pending', work: { row, text: req.text, input, filter, cfg } };
  }

  private track<T>(p: Promise<T>): Promise<T> {
    const t = p.finally(() => this.inflight.delete(t));
    this.inflight.add(t);
    return t;
  }

  /** B + C: classify outside any transaction, then apply. Any failure holds the item (fail closed). */
  private async phaseBC(work: PendingWork): Promise<{ outcome: SendStatus; rejectReason: SendOutcome['rejectReason'] }> {
    let result: ProviderResult;
    try {
      result = await this.provider.moderate(work.text, work.cfg.providerTimeoutMs);
    } catch {
      result = { ok: false, reason: 'error', latencyMs: 0 };
    }
    if (!result.ok) this.lastProviderFailureAt = Date.now();
    const decision = decide({ ...work.input, provider: result });
    try {
      const applied = await this.apply(work.row, decision, result);
      if (!applied) return { outcome: 'pending', rejectReason: null }; // withdrawn or already decided meanwhile
      this.logDecision(decision, work.cfg, work.row.language_pool, result.ok ? 'provider' : result.reason, result.latencyMs);
      await this.feedCorpus(work.row, decision, work.text);
      return { outcome: decision.outcome, rejectReason: decision.rejectReason };
    } catch (err) {
      this.logger.warn(`reflection decision failed (${(err as Error).name}); holding for review`);
      await this.holdStuck(work.row.id, 'timeout').catch(() => undefined);
      return { outcome: 'held', rejectReason: null };
    }
  }

  private async apply(row: ReflectionRow, decision: Decision, result: ProviderResult): Promise<boolean> {
    let pages: string | null = null;
    const ok = await this.db.withTx(async (tx) => {
      const now = this.clock();
      const updated = await this.repo.decidePending(tx, row.id, {
        status: decision.outcome,
        stage: decision.stage,
        holdReason: decision.holdReason,
        rejectReason: decision.rejectReason,
        scores: result.ok ? result.scores : null,
        overnight: null,
        ruleHits: null,
      });
      if (!updated) return false;
      if (decision.outcome === 'published') await ReflectionBroadcast.published(tx, row.room_id, row.id, now);
      await ReflectionBroadcast.status(tx, row.member_id, row.id, decision.outcome, now);
      const q = await queueReflection(tx, updated, decision, this.app.masterKey, now);
      if (q?.pages) pages = q.reportId;
      return true;
    });
    if (pages) this.pager?.reportFiled(pages);
    return ok;
  }

  /**
   * REQ-SAFE-16: a final automatic decision joins the de-identified corpus when it may (src/reflections/corpus.ts).
   * After the decision committed, on its own statement: a failure here never changes the outcome.
   */
  private async feedCorpus(row: ReflectionRow, decision: Decision, text: string): Promise<void> {
    try {
      await feedCorpus(this.db, this.app.masterKey, {
        authorId: row.user_id,
        languagePool: row.language_pool,
        text,
        label: corpusLabel(decision.outcome, decision.rejectReason, { minorSafety: decision.minorSafety }),
        source: 'auto',
        decidedAt: this.clock(),
      });
    } catch (err) {
      this.logger.warn(`corpus: not added (${(err as Error).name})`);
    }
  }

  /** Fail closed: a pending reflection that could not be decided is held for a human (also used by the worker). */
  async holdStuck(reflectionId: string, reason: 'timeout' | 'provider_unavailable'): Promise<boolean> {
    return holdPending(this.db, reflectionId, reason, this.app.masterKey, this.clock());
  }

  private logDecision(d: Decision, cfg: ReflectionConfig, pool: string | null, via: string, latencyMs?: number): void {
    // Outcomes only: never the text, never ids (PRD 13 "Never sent", CLAUDE.md).
    const line =
      `reflection ${d.outcome}${d.holdReason ? ` hold=${d.holdReason}` : ''}${d.rejectReason ? ` reject=${d.rejectReason}` : ''} ` +
      `stage=${d.stage} via=${via}${pool ? ` pool=${pool}` : ''}${latencyMs !== undefined ? ` latencyMs=${latencyMs}` : ''}` +
      `${d.topCategory ? ` top=${d.topCategory}` : ''}`;
    if (d.holdReason === 'provider_unavailable') {
      this.logger.warn(`${line} (fail closed: OPENAI_API_KEY is not set, so every reflection waits for a human)`);
    } else if (d.holdReason === 'timeout' || via === 'error') {
      this.logger.warn(`${line} (fail closed: omni-moderation error or over ${cfg.providerTimeoutMs} ms)`);
    } else {
      this.logger.log(line);
    }
  }

  // ------------------------------------------------------------------------------------------------ delete
  async remove(userId: string, roomIdParam: string, reflectionIdParam: string): Promise<void> {
    const roomId = pathId(roomIdParam, roomNotFound);
    const id = pathId(reflectionIdParam, reflectionNotFound);
    await assertRoomAccess(this.db, userId);
    await this.db.withTx(async (tx) => {
      await lockUser(tx, userId);
      const row = await this.repo.find(tx, id, true);
      if (!row || row.room_id !== roomId || row.user_id !== userId) throw reflectionNotFound();
      if (row.status === 'deleted' || row.status === 'expired' || row.status === 'crisis_diverted') return; // idempotent; crisis items stay for the crisis lane
      const now = this.clock();
      const wasVisible = row.status === 'published' && row.hidden_at === null;
      await tx.query(
        `update public.reflections
            set status = 'deleted', body_ct = null, body_key = null, text_hash = null, stage = 'author',
                decided_at = now(), decided_by = 'author', removed_at = coalesce(removed_at, now())
          where id = $1`,
        [id],
      );
      // A hold waiting for review has nothing left to review; reports about behaviour (users', crisis, minors,
      // violations) stay open — their evidence snapshot already holds the text.
      const closed = await tx.query<{ id: string }>(
        `update public.reports set status = 'dismissed', resolved_at = now(), resolved_by = 'system:author_withdrew'
          where target_reflection_id = $1 and status = 'open' and source = 'auto' and auto_signal = 'reflection_hold'
          returning id`,
        [id],
      );
      if (closed.rows.length) {
        await appendAudit(tx, {
          actor: 'system',
          action: 'auto_reflection_withdrawn',
          reportId: closed.rows[0].id,
          subjectHash: subjectHash(this.app.masterKey, userId),
          reasonCode: 'author_withdrew',
          detail: { reflectionId: id, reportsClosed: closed.rows.length },
        });
      }
      if (wasVisible) await ReflectionBroadcast.removed(tx, roomId, id, now);
    });
  }
}

function replayStatus(row: ReflectionRow): SendStatus {
  switch (row.status) {
    case 'published':
    case 'pending':
    case 'held':
    case 'rejected':
    case 'crisis_diverted':
      return row.status;
    case 'removed':
      return 'rejected';
    default:
      return 'held'; // deleted / expired: never published; the app shows nothing new
  }
}

const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
function graphemes(s: string): number {
  let n = 0;
  for (const _ of segmenter.segment(s)) n++;
  return n;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => {
    const t = setTimeout(r, ms);
    t.unref?.();
  });
}

/**
 * Holds a still-pending reflection for a human with a queue item (API fallback and the worker's stuck-pending sweep).
 * Returns false when it was no longer pending.
 */
export async function holdPending(
  db: { withTx<T>(fn: (tx: Tx) => Promise<T>): Promise<T> },
  reflectionId: string,
  reason: 'timeout' | 'provider_unavailable',
  masterKey: Buffer,
  now: Date,
): Promise<boolean> {
  return db.withTx(async (tx) => {
    const repo = new ReflectionsRepository();
    const updated = await repo.decidePending(tx, reflectionId, {
      status: 'held',
      stage: 'system',
      holdReason: reason,
      rejectReason: null,
      scores: null,
      overnight: null,
      ruleHits: null,
    });
    if (!updated) return false;
    await ReflectionBroadcast.status(tx, updated.member_id, updated.id, 'held', now);
    await queueReflection(
      tx,
      updated,
      { outcome: 'held', store: true, stage: 'provider', holdReason: reason, rejectReason: null, queue: { reason: 8, signal: 'reflection_hold' }, minorSafety: false, topCategory: null },
      masterKey,
      now,
    );
    return true;
  });
}
