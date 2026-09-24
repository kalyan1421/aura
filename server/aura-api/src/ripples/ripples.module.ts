import { Module } from '@nestjs/common';
import { AdminCoreModule } from '../admin/admin-core.module';
import { RippleSafetyService } from './ripple-safety.service';
import { RipplesController } from './ripples.controller';
import { RipplesService } from './ripples.service';

/**
 * F7 Breath Ripples (contracts/api/v1-ripples.md). AdminCoreModule provides the URGENT_PAGER that paging reports go
 * to (REQ-ADM-05). Safety checks are the plain functions of src/safety; pseudonyms come from src/rooms. The worker tick
 * (session end, ticket expiry, due invites, retention) is src/ripples/ripples.worker.ts.
 */
@Module({
  imports: [AdminCoreModule],
  controllers: [RipplesController],
  providers: [RipplesService, RippleSafetyService],
})
export class RipplesModule {}
