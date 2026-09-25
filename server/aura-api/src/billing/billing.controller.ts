import { Body, Controller, Delete, Get, Header, HttpCode, Inject, Param, Post, Put, Req, Res } from '@nestjs/common';
import type { Request, Response } from 'express';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthUser } from '../auth/jwt-verifier';
import { Public } from '../auth/public.decorator';
import { ApiError } from '../common/api-error';
import { KillSwitch, PLUS_KILL_SWITCH, type KillSwitchSpec } from '../remote-config/kill-switch';
import { BillingService, type EntitlementView, type VerifyResponse } from './billing.service';
import { PUBSUB_VERIFIER } from './billing.tokens';
import type { GiftChecked, ReceivedGift } from './gifts';
import { PushAuthError, type PubSubPushVerifier } from './google/pubsub-auth';
import { StoreSync } from './store-sync.service';

/** Gifts kill switch (PRD 19): off → no new gift checks; gifts already paid for still deliver. */
export const GIFTS_KILL_SWITCH: KillSwitchSpec = {
  flag: 'gifts_enabled',
  code: 'gifts_paused',
  message: 'Gifts are resting for a bit. Nothing was charged.',
};

/**
 * F12 Monetization — contracts/api/v1-billing.md. Every `/v1/billing/*` route except the two webhooks: Supabase JWT,
 * `403 account_deletion_pending` during a deletion grace period (global guards), `Cache-Control: no-store`.
 * Every route that buys or spends (purchases, restore, gifts, Stardust) answers `503 plus_disabled` while
 * `plus_enabled` is off (v1.0 launches free; PLUS_KILL_SWITCH). Reads, the sky choice and gift cleanup stay open.
 */
@Controller('v1/billing')
export class BillingController {
  constructor(private readonly billing: BillingService) {}

  @Get('entitlement')
  @Header('Cache-Control', 'no-store')
  entitlement(@CurrentUser() user: AuthUser): Promise<EntitlementView> {
    return this.billing.entitlement(user.id);
  }

  /** 200 with `status`; `confirming` answers 202 (the store couldn't be asked yet — nothing granted). */
  @Post('purchases')
  @Header('Cache-Control', 'no-store')
  @KillSwitch(PLUS_KILL_SWITCH)
  async verify(@CurrentUser() user: AuthUser, @Body() body: unknown, @Res({ passthrough: true }) res: Response): Promise<VerifyResponse> {
    const out = await this.billing.verify(user.id, body);
    res.status(out.status === 'confirming' ? 202 : 200);
    return out;
  }

  @Post('restore')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @KillSwitch(PLUS_KILL_SWITCH)
  restore(@CurrentUser() user: AuthUser, @Body() body: unknown): ReturnType<BillingService['restore']> {
    return this.billing.restore(user.id, body);
  }

  @Post('gifts')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @KillSwitch(PLUS_KILL_SWITCH, GIFTS_KILL_SWITCH)
  checkGift(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<GiftChecked & { accountToken: string }> {
    return this.billing.checkGift(user.id, body);
  }

  @Delete('gifts/:giftId')
  @HttpCode(204)
  @Header('Cache-Control', 'no-store')
  async cancelGift(@CurrentUser() user: AuthUser, @Param('giftId') giftId: string): Promise<void> {
    await this.billing.cancelGift(user.id, giftId);
  }

  @Get('gifts/received')
  @Header('Cache-Control', 'no-store')
  received(@CurrentUser() user: AuthUser): Promise<{ gifts: ReceivedGift[] }> {
    return this.billing.receivedGifts(user.id);
  }

  @Post('gifts/received/seen')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  seen(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<{ marked: number }> {
    return this.billing.giftsSeen(user.id, body);
  }

  @Post('stardust/redeem')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  @KillSwitch(PLUS_KILL_SWITCH)
  redeem(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<EntitlementView> {
    return this.billing.redeem(user.id, body);
  }

  @Put('sky')
  @HttpCode(200)
  @Header('Cache-Control', 'no-store')
  sky(@CurrentUser() user: AuthUser, @Body() body: unknown): Promise<EntitlementView> {
    return this.billing.setSky(user.id, body);
  }
}

/**
 * Store webhooks (public: no Supabase JWT). Apple's payload is self-authenticating (JWS to Apple's root); Google's
 * Pub/Sub push carries a Google-signed OIDC token for our push service account. Both are logged once and handled
 * idempotently; once logged they answer 2xx even when handling failed (the billing worker retries from the log).
 */
@Controller('v1/billing/webhooks')
export class BillingWebhooksController {
  constructor(
    private readonly sync: StoreSync,
    @Inject(PUBSUB_VERIFIER) private readonly pubsub: PubSubPushVerifier,
  ) {}

  @Public()
  @Post('apple')
  @HttpCode(200)
  async apple(@Body() body: unknown): Promise<{ status: string }> {
    const signed = (body as { signedPayload?: unknown } | null)?.signedPayload;
    return { status: await this.sync.receiveApple(signed, new Date()) };
  }

  @Public()
  @Post('google')
  @HttpCode(204)
  async google(@Req() req: Request, @Body() body: unknown): Promise<void> {
    try {
      await this.pubsub.verify(req.headers.authorization);
    } catch (err) {
      if (err instanceof PushAuthError) {
        throw err.reason === 'not_configured'
          ? new ApiError(503, 'rtdn_not_configured', 'Play notifications are not configured on this server.')
          : ApiError.unauthorized('The push was not signed by the configured Pub/Sub service account.', 'invalid_push_token');
      }
      throw err;
    }
    await this.sync.receiveGoogle(body, new Date());
  }
}
