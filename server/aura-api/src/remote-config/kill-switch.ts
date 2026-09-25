import { CanActivate, ExecutionContext, HttpStatus, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ApiError } from '../common/api-error';
import { RemoteConfigService } from './remote-config.service';

/**
 * Server-side kill switches (PRD 19 "Configuration … kill switches"; REQ-ADM-12). A flag hides or greys UI in the app,
 * but a flag on the phone alone never decides anything: the route itself refuses while the switch is off.
 *
 *   @KillSwitch(ROOMS_KILL_SWITCH)   // on the route
 *
 * The global KillSwitchGuard (RemoteConfigModule) reads the flag from the cached config document (≤ 10 s old) and
 * answers `503 { code }` while it is off. A flag missing from `public.feature_flags` counts as on (kill switches only
 * ever take things away) — unless the spec says `whenMissing: false` (an opt-in switch such as `plus_enabled`).
 * Several switches can guard one route (`@KillSwitch(A, B)`, or one on the class and one on the route): every one of
 * them must be on, and the first one that is off answers.
 */
export interface KillSwitchSpec {
  /** `public.feature_flags.key`. */
  flag: string;
  /** The error code while the switch is off (the app maps it to calm copy). */
  code: string;
  message: string;
  /** What a missing row means (default `true`: a kill switch only takes things away). */
  whenMissing?: boolean;
}

export const KILL_SWITCH = 'aura:killSwitch';
export const KillSwitch = (...specs: KillSwitchSpec[]): MethodDecorator & ClassDecorator => SetMetadata(KILL_SWITCH, specs);

/** Mood rooms: off → no new joins (`POST /v1/rooms/match`); people already in a room keep it until it closes. */
export const ROOMS_KILL_SWITCH: KillSwitchSpec = {
  flag: 'rooms_enabled',
  code: 'rooms_paused',
  message: 'Rooms are resting for a bit. Please try again later.',
};

/**
 * Purchases (F12: Aura Plus, cosmetic skies, Stardust, gifts). v1.0 launches free: the row ships OFF (migration
 * 20261005000035) and a missing row is off too, so no purchase can be verified, restored, redeemed or gifted until the
 * Owner turns it on. Entitlement reads, the store webhooks and delivery of gifts already paid for are not guarded.
 */
export const PLUS_KILL_SWITCH: KillSwitchSpec = {
  flag: 'plus_enabled',
  code: 'plus_disabled',
  message: "Purchases aren't available in Aura right now. Nothing was charged.",
  whenMissing: false,
};

@Injectable()
export class KillSwitchGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly config: RemoteConfigService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const found = this.reflector.getAll<Array<KillSwitchSpec | KillSwitchSpec[] | undefined>>(KILL_SWITCH, [ctx.getHandler(), ctx.getClass()]);
    const specs = found.flat().filter((s): s is KillSwitchSpec => s !== undefined);
    for (const spec of specs) {
      if (!(await this.config.flagEnabled(spec.flag, spec.whenMissing ?? true))) {
        throw new ApiError(HttpStatus.SERVICE_UNAVAILABLE, spec.code, spec.message);
      }
    }
    return true;
  }
}
