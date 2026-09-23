import { Module } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { AdminCoreModule } from '../admin/admin-core.module';
import { AdminGuard } from '../admin/admin.guard';
import { DeviceBanGuard, InstallSeenInterceptor } from './device-ban.guard';
import { DeviceBansService } from './device-bans.service';
import { DevicesAdminController } from './devices-admin.controller';
import { DevicesController } from './devices.controller';
import { DevicesRepository } from './devices.repository';
import { DevicesService } from './devices.service';

/**
 * Devices: FCM registration (`PUT/DELETE /v1/devices`) and device bans (PRD 19 REQ-ADM-14): the install id the app
 * sends (src/devices/install-id.ts) is remembered per account after successful calls (InstallSeenInterceptor) and
 * refused everywhere but the account/safety-read routes once banned (DeviceBanGuard, global, after the auth guards —
 * DevicesModule is imported after AuthModule). `DeviceBansService` is exported for the instant ban; the console
 * routes are `/admin/devices*` (Owner only).
 */
@Module({
  imports: [AdminCoreModule],
  controllers: [DevicesController, DevicesAdminController],
  providers: [
    DevicesRepository,
    DevicesService,
    DeviceBansService,
    AdminGuard,
    { provide: APP_GUARD, useClass: DeviceBanGuard },
    { provide: APP_INTERCEPTOR, useClass: InstallSeenInterceptor },
  ],
  exports: [DeviceBansService],
})
export class DevicesModule {}
