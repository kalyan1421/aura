import { Injectable } from '@nestjs/common';
import { ModerationService } from '../safety/moderation.service';
import { auditConsole } from './admin-audit';
import { AdminDb } from './admin-db';
import { AdminErrors } from './admin-errors';
import { auditQuerySchema, flagSchema, parse } from './admin.schemas';
import type { StaffUser } from './admin-types';

/**
 * Kill switches and the audit log (PRD 19 "Configuration", "Audit log"). v0 flips the feature flags that exist
 * (`feature_flags`, e.g. `rooms_pool_hi` — the Hindi + Hinglish pool); the app reads flags directly, so a change
 * reaches clients on their next flag fetch. `matching_config` / `safety_config` are shown read-only. Every flip is
 * audited with its reason and previous value.
 */
export interface AuditView {
  id: number;
  createdAt: string;
  actor: string;
  actorLabel: string;
  action: string;
  reportId: string | null;
  subjectHash: string | null;
  reasonCode: string | null;
  detail: Record<string, unknown>;
  rowHash: string;
}

@Injectable()
export class ConsoleConfigService {
  constructor(
    private readonly adminDb: AdminDb,
    private readonly moderation: ModerationService,
  ) {}

  async get(): Promise<{
    flags: Array<{ key: string; enabled: boolean; description: string | null; updatedAt: string | null }>;
    matching: Record<string, unknown>;
    safety: Record<string, unknown>;
  }> {
    return this.adminDb.withTx(async (tx) => {
      // `description` / `updated_at` arrive with the remote-config migration (20261005000017); read through to_jsonb so
      // this works with or without them.
      const flags = await tx.query<{ key: string; enabled: boolean; description: string | null; updatedAt: string | null }>(
        `select f.key, f.enabled, to_jsonb(f) ->> 'description' as description, to_jsonb(f) ->> 'updated_at' as "updatedAt"
           from public.feature_flags f order by f.key`,
      );
      const matching = (await tx.query<Record<string, unknown>>('select * from public.matching_config where id')).rows[0] ?? {};
      const safety = (await tx.query<Record<string, unknown>>('select * from public.safety_config where id')).rows[0] ?? {};
      delete matching.id;
      delete safety.id;
      return { flags: flags.rows, matching, safety };
    });
  }

  async setFlag(staff: StaffUser, key: string, body: unknown): Promise<{ key: string; enabled: boolean }> {
    const b = parse(flagSchema, body);
    if (!/^[a-z0-9_.-]{1,80}$/.test(key)) throw AdminErrors.notFound('That flag does not exist.');
    return this.adminDb.withTx(async (tx) => {
      const before = (await tx.query<{ enabled: boolean }>('select enabled from public.feature_flags where key = $1 for update', [key])).rows[0];
      if (!before) throw AdminErrors.notFound('That flag does not exist.');
      await tx.query('update public.feature_flags set enabled = $2 where key = $1', [key, b.enabled]);
      await auditConsole(tx, staff.actor, {
        action: 'config_flag',
        reasonCode: b.reasonCode,
        detail: { key, enabled: b.enabled, previous: before.enabled },
      });
      return { key, enabled: b.enabled };
    });
  }

  /** Newest first, with staff actors labelled by display name; the chain check is separate (it reads every row). */
  async audit(query: unknown): Promise<AuditView[]> {
    const q = parse(auditQuerySchema, query);
    const rows = await this.moderation.auditLog({ limit: q.limit ?? 100, beforeId: q.beforeId });
    const names = new Map(
      (await this.adminDb.query<{ staff_id: string; display_name: string }>('select staff_id, display_name from public.admin_staff')).rows.map((s) => [
        `staff:${s.staff_id}`,
        s.display_name,
      ]),
    );
    return rows.map((r) => ({
      id: r.id,
      createdAt: r.createdAt,
      actor: r.actor,
      actorLabel: names.get(r.actor) ?? r.actor,
      action: r.action,
      reportId: r.reportId,
      subjectHash: r.subjectHash,
      reasonCode: r.reasonCode,
      detail: r.detail,
      rowHash: r.rowHash,
    }));
  }

  async verifyChain(): Promise<{ ok: boolean; checkedAt: string }> {
    return { ok: await this.moderation.verifyAuditChain(), checkedAt: new Date().toISOString() };
  }
}
