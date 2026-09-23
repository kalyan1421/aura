import { Module } from '@nestjs/common';
import { AccountController } from './account.controller';
import { AccountRepository } from './account.repository';
import { AccountService } from './account.service';

/**
 * HTTP side of account deletion. The pending-deletion guard lives in src/auth (global); the purge and the
 * private-media client run in the worker (src/account/account-purge.ts via src/queues).
 */
@Module({ controllers: [AccountController], providers: [AccountRepository, AccountService] })
export class AccountModule {}
