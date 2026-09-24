import { Module } from '@nestjs/common';
import { ProfileController } from './profile.controller';
import { ProfileRepository } from './profile.repository';
import { ProfileService } from './profile.service';
import { SignupThrottle } from './signup-throttle';

@Module({
  controllers: [ProfileController],
  providers: [ProfileRepository, ProfileService, SignupThrottle], // SignupThrottle: reduced mode (PRD 19)
  exports: [ProfileService],
})
export class ProfileModule {}
