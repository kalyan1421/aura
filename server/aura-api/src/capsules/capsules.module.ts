import { Module } from '@nestjs/common';
import { CapsuleMediaGate } from './capsule-media.gate';
import { CapsuleSyncHandler } from './capsule-sync';
import { CapsuleUnlockModule } from './capsule-unlock.module';
import { CapsulesRepository } from './capsules.repository';

/**
 * F4 Personal Time Capsules (contracts/api/v1-capsules.md), API side: the `capsule` sync entity (SyncModule) and the
 * capsule-media rules (MediaModule). No routes of its own — writes go through `POST /v1/sync/push`, reads through
 * Supabase select-own on `public.capsules`. CatalogueService, DbService and PrivateMediaStore are global.
 */
@Module({
  imports: [CapsuleUnlockModule],
  providers: [CapsulesRepository, CapsuleSyncHandler, CapsuleMediaGate],
  exports: [CapsuleSyncHandler, CapsuleMediaGate],
})
export class CapsulesModule {}
