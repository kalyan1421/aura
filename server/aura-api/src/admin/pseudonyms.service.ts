import { Injectable } from '@nestjs/common';
import { z } from 'zod';
import { parseOrThrow } from '../common/zod';
import { DbService } from '../db/db.service';
import { ADJECTIVES, ALL_PSEUDONYMS, BLOCKED_PSEUDONYMS, NOUNS, isAllowedPseudonym } from '../rooms/pseudonyms';
import { auditConsole } from './admin-audit';
import { AdminErrors } from './admin-errors';
import { reasonCode } from './admin.schemas';
import type { StaffUser } from './admin-types';

/**
 * Room pseudonyms in the console (PRD 19 "Configuration: pseudonym word lists per language plus an
 * offensive-combination blocklist"; migration 20261005000034). The curated word lists and the code blocklist are
 * shown read-only (they change by review, like copy); the Owner adds a combination to the live blocklist or takes it
 * off again, with a reason, and new memberships never get a blocked name (src/rooms/pseudonym-blocklist.ts). Reading
 * is Owner + Moderator; changing is Owner only (PRD 19 Roles). The audit row keeps the reason and the list size, not
 * the name (audit details never hold pseudonyms); the table keeps who blocked it and when.
 */
export interface BlockedPseudonym {
  pseudonym: string;
  reasonCode: string;
  createdBy: string;
  createdAt: string;
}

export interface PseudonymConfig {
  adjectives: readonly string[];
  nouns: readonly string[];
  /** Built into the code (never generated, cannot be lifted here). */
  codeBlocked: string[];
  /** The Owner's live blocklist, newest first. */
  blocked: BlockedPseudonym[];
  /** Combinations still handed out. */
  available: number;
}

const changeSchema = z.object({ pseudonym: z.string().trim().min(3).max(40), reasonCode }).strict();

@Injectable()
export class PseudonymsService {
  constructor(private readonly db: DbService) {}

  async get(): Promise<PseudonymConfig> {
    // Service role: `aura_admin` keeps no grant outside the moderation tables (migration 20261005000034).
    const rows = await this.db.query<{ pseudonym: string; reason_code: string; created_by: string; created_at: Date }>(
      'select pseudonym, reason_code, created_by, created_at from public.pseudonym_blocklist order by created_at desc, pseudonym',
    );
    const blocked = new Set(rows.rows.map((r) => r.pseudonym));
    return {
      adjectives: ADJECTIVES,
      nouns: NOUNS,
      codeBlocked: [...BLOCKED_PSEUDONYMS].sort(),
      blocked: rows.rows.map((r) => ({ pseudonym: r.pseudonym, reasonCode: r.reason_code, createdBy: r.created_by, createdAt: r.created_at.toISOString() })),
      available: ALL_PSEUDONYMS.filter((p) => !blocked.has(p)).length,
    };
  }

  /** Owner: take a combination out of use (idempotent). Only names the generator can produce are accepted. */
  async block(staff: StaffUser, body: unknown): Promise<PseudonymConfig> {
    const b = parseOrThrow(changeSchema, body ?? {});
    const name = normalize(b.pseudonym);
    if (!isAllowedPseudonym(name)) {
      throw AdminErrors.badRequest('Not a pseudonym Aura hands out (adjective + noun from the lists below, or already blocked in code).');
    }
    await this.db.withTx(async (tx) => {
      const r = await tx.query(
        `insert into public.pseudonym_blocklist (pseudonym, reason_code, created_by) values ($1, $2, $3)
         on conflict (pseudonym) do nothing`,
        [name, b.reasonCode, staff.actor],
      );
      if (!r.rowCount) return;
      const size = (await tx.query<{ n: number }>('select count(*)::int as n from public.pseudonym_blocklist')).rows[0]?.n ?? 0;
      await auditConsole(tx, staff.actor, { action: 'config_pseudonym_block', reasonCode: b.reasonCode, detail: { list: 'pseudonym_blocklist', size } });
    });
    return this.get();
  }

  /** Owner: hand a combination out again (idempotent). */
  async unblock(staff: StaffUser, body: unknown): Promise<PseudonymConfig> {
    const b = parseOrThrow(changeSchema, body ?? {});
    const name = normalize(b.pseudonym);
    await this.db.withTx(async (tx) => {
      const r = await tx.query('delete from public.pseudonym_blocklist where pseudonym = $1', [name]);
      if (!r.rowCount) return;
      const size = (await tx.query<{ n: number }>('select count(*)::int as n from public.pseudonym_blocklist')).rows[0]?.n ?? 0;
      await auditConsole(tx, staff.actor, { action: 'config_pseudonym_unblock', reasonCode: b.reasonCode, detail: { list: 'pseudonym_blocklist', size } });
    });
    return this.get();
  }
}

/** "quiet  comet" → "Quiet Comet" (the generator's capitalisation). */
export function normalize(input: string): string {
  return input
    .trim()
    .split(/\s+/)
    .map((w) => (w ? w[0].toUpperCase() + w.slice(1).toLowerCase() : w))
    .join(' ');
}
