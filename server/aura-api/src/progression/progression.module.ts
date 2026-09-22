import { Global, Module } from '@nestjs/common';
import { ProgressionRepository } from './progression.repository';
import { ProgressionService } from './progression.service';

@Global()
@Module({ providers: [ProgressionRepository, ProgressionService], exports: [ProgressionService] })
export class ProgressionModule {}
