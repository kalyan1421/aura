import { HttpStatus, Injectable } from '@nestjs/common';
import { ApiError } from '../common/api-error';
import { isUuid } from '../common/uuid';
import { AppConfig } from '../config/app-config';
import type { Queryable } from '../db/db';
import { DbService } from '../db/db.service';
import { subjectHash } from '../safety/audit';
import {
  banDevicesForAccount,
  banInstall,
  devicesForAccount,
  installHashesForAccount,
  isInstallBanned,
  liftDeviceBan,
  listDeviceBans,
  recordInstall,
  type AccountBanResult,
  type BanView,
  type DeviceView,
} from './device-bans';
import { INSTALL_HASH_RE, installHash, type InstallInfo } from './install-id';

/**
 * Device bans for the admin console and the moderation actions (PRD 19 REQ-ADM-14). Moderation actions run as the
 * service role like ModerationService (src/safety); the console adds staff auth, roles and audit around them.
 *
 * For the instant ban ("one confirm action bans account and device"): call
 * `banDevicesForAccount(userId, reasonCode, { actor, reportId, tx })` with the SAME transaction that inserts the
 * `account_ban` sanction, so both land or neither does. Or, without DI, the plain function in ./device-bans.ts.
 */
@Injectable()
export class DeviceBansService {
  constructor(
    private readonly db: DbService,
    private readonly config: AppConfig,
  ) {}

  /** Bans every install seen for the account (idempotent; audited). */
  banDevicesForAccount(
    userId: string,
    reasonCode: string,
    opts: { actor: string; reportId?: string | null; tx?: Queryable },
  ): Promise<AccountBanResult> {
    if (!isUuid(userId)) throw ApiError.badRequest('invalid_request', 'userId must be a UUID.');
    const run = (q: Queryable): Promise<AccountBanResult> =>
      banDevicesForAccount(q, this.config.masterKey, userId.toLowerCase(), { reasonCode, actor: opts.actor, reportId: opts.reportId ?? null });
    return opts.tx ? run(opts.tx) : this.db.withTx(run);
  }

  /** The install hashes an account used (for an evidence hold snapshot). */
  installHashesForAccount(userId: string, tx?: Queryable): Promise<string[]> {
    return installHashesForAccount(tx ?? this.db, userId);
  }

  isBanned(install: InstallInfo): Promise<boolean> {
    return isInstallBanned(this.db, installHash(this.config.masterKey, install.id));
  }

  record(userId: string, install: InstallInfo): Promise<void> {
    return recordInstall(this.db, this.config.masterKey, userId, install);
  }

  // ---------------------------------------------------------------- console (Owner only; src/devices/devices-admin.controller.ts)

  /** The devices of the account a report is about, with any active ban. */
  async devicesForReport(reportId: string): Promise<{ reportId: string; subjectHash: string; devices: DeviceView[] }> {
    const userId = await this.reportSubject(reportId);
    return { reportId, subjectHash: subjectHash(this.config.masterKey, userId), devices: await devicesForAccount(this.db, userId) };
  }

  /** Every device of the account a report is about. */
  async banForReport(reportId: string, reasonCode: string, actor: string): Promise<AccountBanResult> {
    const userId = await this.reportSubject(reportId);
    return this.db.withTx((tx) => banDevicesForAccount(tx, this.config.masterKey, userId, { reasonCode, actor, reportId }));
  }

  async banDevice(deviceId: string, reasonCode: string, actor: string, reportId?: string): Promise<{ banId: string; deviceId: string; alreadyBanned: boolean }> {
    if (!INSTALL_HASH_RE.test(deviceId)) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That device does not exist.');
    let subject: string | null = null;
    if (reportId) subject = subjectHash(this.config.masterKey, await this.reportSubject(reportId));
    const out = await this.db.withTx(async (tx) => {
      const known = await tx.query('select 1 from public.device_installs where install_hash = $1 limit 1', [deviceId]);
      const banned = await tx.query('select 1 from public.device_bans where install_hash = $1 limit 1', [deviceId]);
      if (!known.rowCount && !banned.rowCount) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That device does not exist.');
      return banInstall(tx, deviceId, { reasonCode, actor, reportId: reportId ?? null, subjectHash: subject });
    });
    return { ...out, deviceId };
  }

  liftBan(banId: string, reasonCode: string, actor: string): Promise<{ banId: string; liftedAt: string }> {
    if (!isUuid(banId)) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That device ban does not exist.');
    return this.db.withTx((tx) => liftDeviceBan(tx, banId.toLowerCase(), { actor, reasonCode }));
  }

  listBans(status: 'active' | 'lifted' | 'all'): Promise<BanView[]> {
    return listDeviceBans(this.db, status);
  }

  private async reportSubject(reportId: string): Promise<string> {
    if (!isUuid(reportId)) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That report does not exist.');
    const r = await this.db.query<{ target_user_id: string | null }>('select target_user_id from public.reports where id = $1', [reportId]);
    if (!r.rows[0]) throw new ApiError(HttpStatus.NOT_FOUND, 'not_found', 'That report does not exist.');
    const userId = r.rows[0].target_user_id;
    if (!userId) throw ApiError.conflict('no_subject', 'This report has no account to act on (the account may have been deleted).');
    return userId;
  }
}
