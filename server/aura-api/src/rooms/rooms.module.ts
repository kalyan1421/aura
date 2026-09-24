import { Module } from '@nestjs/common';
import { GesturesService } from './gestures.service';
import { LanternsService } from './lanterns.service';
import { RoomsController } from './rooms.controller';
import { RoomsRepository } from './rooms.repository';
import { RoomsService } from './rooms.service';

/**
 * F5 Mood Rooms (contracts/api/v1-rooms.md). Safety checks (sanctions, blocks, reports, evidence) are plain functions
 * from src/safety, so this module has no DI dependency on SafetyModule. The lifecycle tick (state transitions,
 * Lantern Hour, presence sweep, purge) runs in the worker: src/rooms/room-lifecycle.ts. Room lanterns and Tonight's
 * intention (Milestone B): lantern-rules.ts, lanterns.ts (incl. the Breath Ripples hook), lanterns.service.ts.
 */
@Module({
  controllers: [RoomsController],
  providers: [RoomsRepository, RoomsService, GesturesService, LanternsService],
  exports: [RoomsRepository],
})
export class RoomsModule {}
