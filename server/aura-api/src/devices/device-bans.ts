import { HttpStatus } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import type { Queryable } from '../db/db';
import { appendAudit, subjectHash } from '../safety/audit';
import type { Platform } from './devices.schema';
import { installHash, type InstallInfo } from './install-id';

/**
 * Device bans (PRD 19 REQ-ADM-14 "One confirm action bans account and device"; 06c F9 "instant ban … device also
 * banned"; contracts/api/v1.md "Device bans"). Plain SQL helpers that take any Queryable, so the Minors & grooming
 * instant ban can run them inside its own transaction (no DI needed, like src/safety/safety.queries.ts).
 *
 *  - `public.device_installs` — which install ids (hashed) each account used, recorded after successful
 *    profile / device / room-match calls. Personal (it has `user_id`): the account purge deletes it.
 *  - `public.device_bans` — banned install hashes. No account column or FK, so a ban outlives the account (a banned
 *    person who deletes the account and signs up again on the same phone is still refused); `subject_hash` is the
 *    audit log's HMAC of the account, never the id.
 *
 * A banned install gets `403 device_banned` ("This device can't use Aura.") on every route except the public ones
 * (config, grievance form) and those a closed account keeps (`/v1/account*` — status, deletion — and the safety
 * reads), so the person can still delete their account and ask for a review. The message never says why.
 */
export const DEVICE_BANNED = 'device_banned';
export const deviceBanned = (): ApiError => ApiError.forbidden(DEVICE_BANNED, "This device can't use Aura.");

export const DEVICE_BAN_ACTIONS = { ban: 'device_ban', lift: 'device_ban_lift' } as const;

/** Installs kept per account; the least recently seen goes first (keeps a flood of made-up ids bounded). */
export const MAX_INSTALLS_PER_ACCOUNT = 20;

const REASON_CODE_RE = /^[a-z0-9_]{1,40}$/;

export async function isInstallBanned(q: Queryable, hash: string): Promise<boolean> {
  const r = await q.query('select 1 from public.device_bans where install_hash = $1 and lifted_at is null limit 1', [hash]);
  return (r.rowCount ?? 0) > 0;
}

/** Records (or refreshes) that `userId` used this install. Keeps at most MAX_INSTALLS_PER_ACCOUNT per account. */
export async function recordInstall(q: Queryable, masterKey: Buffer, userId: string, install: InstallInfo): Promise<void> {
  const hash = installHash(masterKey, install.id);
  await q.query(
    `with seen as (
       insert into public.device_installs (user_id, install_hash, platform) values ($1, $2, $3)
       on conflict (user_id, install_hash) do update
         set last_seen_at = now(), platform = coalesce(excluded.platform, public.device_installs.platform)
       returning install_hash)
     delete from public.device_installs d
      where d.user_id = $1 and d.install_hash not in (select install_hash from seen)
        and d.install_hash in (select x.install_hash from public.device_installs x where x.user_id = $1
                                order by x.last_seen_at desc offset $4)`,
    [userId, hash, install.platform, MAX_INSTALLS_PER_ACCOUNT - 1],
  );
}

export interface BanOptions {
  reasonCode: string;
  /** Who did it: `staff:<id>` from the console, `system:…` for automatic bans. */
  actor: string;
  reportId?: string | null;
}

export interface AccountBanResult {
  /** Installs seen for the account. */
  devices: number;
  /** Of those, newly banned now (the rest were already banned). */
  newlyBanned: number;
}

function checkOptions(o: BanOptions): void {
  if (!REASON_CODE_RE.test(o.reasonCode)) throw ApiError.badRequest('invalid_request', 'reasonCode must be [a-z0-9_]{1,40}.');
  if (!o.actor || o.actor.length > 120) throw ApiError.badRequest('invalid_request', 'actor is required.');
}

/**
 * Bans every install seen for the account, writes one audit row, returns counts. Idempotent (already-banned installs
 * are left as they are). Run it in the same transaction as the account ban so "one confirm action" is atomic.
 */
export async function banDevicesForAccount(q: Queryable, masterKey: Buffer, userId: string, o: BanOptions): Promise<AccountBanResult> {
  checkOptions(o);
  const subject = subjectHash(masterKey, userId);
  const installs = await q.query<{ install_hash: string }>('select install_hash from public.device_installs where user_id = $1', [userId]);
  const inserted = await q.query<{ install_hash: string }>(
    `insert into public.device_bans (install_hash, reason_code, subject_hash, report_id, created_by)
     select i.install_hash, $2, $3, $4, $5 from public.device_installs i where i.user_id = $1
     on conflict (install_hash) where lifted_at is null do nothing
     returning install_hash`,
    [userId, o.reasonCode, subject, o.reportId ?? null, o.actor],
  );
  const result = { devices: installs.rows.length, newlyBanned: inserted.rows.length };
  await appendAudit(q, {
    actor: o.actor,
    action: DEVICE_BAN_ACTIONS.ban,
    reportId: o.reportId ?? null,
    subjectHash: subject,
    reasonCode: o.reasonCode,
    detail: { scope: 'account', devices: result.devices, newlyBanned: result.newlyBanned },
  });
  return result;
}

/** Bans one install (by its hash, as the console lists it). Returns the active ban's id and whether it already existed. */
export async function banInstall(
  q: Queryable,
  hash: string,
  o: BanOptions & { subjectHash?: string | null },
): Promise<{ banId: string; alreadyBanned: boolean }> {
  checkOptions(o);
  const inserted = await q.query<{ id: string }>(
    `insert into public.device_bans (install_hash, reason_code, subject_hash, report_id, created_by)
     values ($1, $2, $3, $4, $5)
     on conflict (install_hash) where lifted_at is null do nothing
     returning id`,
    [hash, o.reasonCode, o.subjectHash ?? null, o.reportId ?? null, o.actor],
  );
  if (inserted.rows[0]) {
    await appendAudit(q, {
      actor: o.actor,
      action: DEVICE_BAN_ACTIONS.ban,
      reportId: o.reportId ?? null,
      subjectHash: o.subjectHash ?? null,
      reasonCode: o.reasonCode,
      detail: { scope: 'device', banId: inserted.rows[0].id },
    });
    return { banId: inserted.rows[0].id, alreadyBanned: false };
  }
  const existing = await q.query<{ id: string }>('select id from public.device_bans where install_hash = $1 and lifted_at is null', [hash]);
  return { banId: existing.rows[0].id, alreadyBanned: true };
}

/** Lifts an active ban (appeal upheld, mistake). The row stays, with who lifted it and why. */
export async function liftDeviceBan(q: Queryable, banId: string, o: { actor: string; reasonCode: string }): Promise<{ banId: string; liftedAt: string }> {
  checkOptions(o);
  const r = await q.query<{ id: string; lifted_at: Date; report_id: string | null; subject_hash: string | null }>(
    `update public.device_bans set lifted_at = now(), lifted_by = $2, lift_reason = $3
      where id = $1 and lifted_at is null returning id, lifted_at, report_id, subject_hash`,
    [banId, o.actor, o.reasonCode],
  );
  const row = r.rows[0];
  if (!row) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That device ban does not exist or was already lifted.');
  await appendAudit(q, {
    actor: o.actor,
    action: DEVICE_BAN_ACTIONS.lift,
    reportId: row.report_id,
    subjectHash: row.subject_hash,
    reasonCode: o.reasonCode,
    detail: { banId: row.id },
  });
  return { banId: row.id, liftedAt: row.lifted_at.toISOString() };
}

export interface DeviceView {
  /** The install hash (not reversible): what the console bans by. */
  deviceId: string;
  platform: Platform | null;
  firstSeenAt: string;
  lastSeenAt: string;
  /** The active ban on this install, if any. */
  banId: string | null;
}

export async function devicesForAccount(q: Queryable, userId: string): Promise<DeviceView[]> {
  const r = await q.query<{ install_hash: string; platform: Platform | null; first_seen_at: Date; last_seen_at: Date; ban_id: string | null }>(
    `select i.install_hash, i.platform, i.first_seen_at, i.last_seen_at,
            (select b.id from public.device_bans b where b.install_hash = i.install_hash and b.lifted_at is null) as ban_id
       from public.device_installs i where i.user_id = $1 order by i.last_seen_at desc`,
    [userId],
  );
  return r.rows.map((x) => ({
    deviceId: x.install_hash,
    platform: x.platform,
    firstSeenAt: x.first_seen_at.toISOString(),
    lastSeenAt: x.last_seen_at.toISOString(),
    banId: x.ban_id,
  }));
}

/** Install hashes of an account — for an evidence snapshot (REQ-ADM-14 "account and device IDs"). */
export async function installHashesForAccount(q: Queryable, userId: string): Promise<string[]> {
  const r = await q.query<{ install_hash: string }>('select install_hash from public.device_installs where user_id = $1 order by first_seen_at', [userId]);
  return r.rows.map((x) => x.install_hash);
}

export interface BanView {
  banId: string;
  deviceId: string;
  reasonCode: string;
  reportId: string | null;
  subjectHash: string | null;
  createdAt: string;
  createdBy: string;
  liftedAt: string | null;
  liftedBy: string | null;
  liftReason: string | null;
}

export async function listDeviceBans(q: Queryable, status: 'active' | 'lifted' | 'all', limit = 200): Promise<BanView[]> {
  const r = await q.query<{
    id: string;
    install_hash: string;
    reason_code: string;
    report_id: string | null;
    subject_hash: string | null;
    created_at: Date;
    created_by: string;
    lifted_at: Date | null;
    lifted_by: string | null;
    lift_reason: string | null;
  }>(
    `select id, install_hash, reason_code, report_id, subject_hash, created_at, created_by, lifted_at, lifted_by, lift_reason
       from public.device_bans
      where ($1 = 'all' or ($1 = 'active' and lifted_at is null) or ($1 = 'lifted' and lifted_at is not null))
      order by created_at desc limit $2`,
    [status, Math.min(Math.max(limit, 1), 500)],
  );
  return r.rows.map((x) => ({
    banId: x.id,
    deviceId: x.install_hash,
    reasonCode: x.reason_code,
    reportId: x.report_id,
    subjectHash: x.subject_hash,
    createdAt: x.created_at.toISOString(),
    createdBy: x.created_by,
    liftedAt: x.lifted_at?.toISOString() ?? null,
    liftedBy: x.lifted_by,
    liftReason: x.lift_reason,
  }));
}
