import { Global, Module } from '@nestjs/common';
import { CatalogueService } from './catalogue.service';

@Global()
@Module({ providers: [CatalogueService], exports: [CatalogueService] })
export class CatalogueModule {}
