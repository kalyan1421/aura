import { Logger, Module } from '@nestjs/common';
import { AdminCoreModule } from '../admin/admin-core.module';
import { AdminGuard } from '../admin/admin.guard';
import { QueueSessionService } from '../admin/queue-session';
import { AppConfig } from '../config/app-config';
import { RemoteConfigModule } from '../remote-config/remote-config.module';
import { RoomsModule } from '../rooms/rooms.module';
import { SafetyModule } from '../safety/safety.module';
import { AdminReflectionsController } from './admin-reflections.controller';
import { AdminReflectionsService } from './admin-reflections.service';
import { MODERATION_PROVIDER, parseReflectionsSettings, providerFrom, type ModerationProvider } from './moderation-provider';
import { ReflectionsController } from './reflections.controller';
import { ReflectionsService } from './reflections.service';

/**
 * F6 Reflections (contracts/api/v1-reflections.md): the app routes `/v1/rooms/:roomId/reflections*`, the moderation
 * pipeline (crisis lexicon → grooming → contact rules → OpenAI omni-moderation → human queue, fail closed), and the
 * console routes `/admin/reflections*`. Gestures on reflections live in src/rooms (GesturesService, target
 * `reflection`); reports on them in src/safety (ReportsService, target kind `reflection`). The worker side (stuck
 * pending → held, memory → expired, pool auto-pause) is ReflectionsWorkerModule (src/reflections/reflections.worker.ts).
 *
 * `OPENAI_API_KEY` unset → the classifier is the fail-closed `UnavailableModerationProvider`: every reflection the text
 * rules don't decide is held for a human (logged at boot and on every hold, never with text).
 */
@Module({
  imports: [AdminCoreModule, RoomsModule, SafetyModule, RemoteConfigModule],
  controllers: [ReflectionsController, AdminReflectionsController],
  providers: [
    {
      provide: MODERATION_PROVIDER,
      // AppConfig first: its factory merges `.env` into process.env before these variables are read.
      useFactory: (_app: AppConfig): ModerationProvider => {
        const p = providerFrom(parseReflectionsSettings(process.env));
        const log = new Logger('Reflections');
        if (p.available) log.log(`reflection classifier: OpenAI omni-moderation`);
        else log.warn('OPENAI_API_KEY is not set: reflections fail closed — every reflection the text rules do not decide is held for human review');
        return p;
      },
      inject: [AppConfig],
    },
    ReflectionsService,
    AdminReflectionsService,
    QueueSessionService,
    AdminGuard,
  ],
  exports: [ReflectionsService],
})
export class ReflectionsModule {}
