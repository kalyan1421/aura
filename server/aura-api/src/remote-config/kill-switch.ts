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
 * ever take things away).
 */
export interface KillSwitchSpec {
  /** `public.feature_flags.key`. */
  flag: string;
  /** The error code while the switch is off (the app maps it to calm copy). */
  code: string;
  message: string;
}

export const KILL_SWITCH = 'aura:killSwitch';
export const KillSwitch = (spec: KillSwitchSpec): MethodDecorator & ClassDecorator => SetMetadata(KILL_SWITCH, spec);

/** Mood rooms: off → no new joins (`POST /v1/rooms/match`); people already in a room keep it until it closes. */
export const ROOMS_KILL_SWITCH: KillSwitchSpec = {
  flag: 'rooms_enabled',
  code: 'rooms_paused',
  message: 'Rooms are resting for a bit. Please try again later.',
};

@Injectable()
export class KillSwitchGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly config: RemoteConfigService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const spec = this.reflector.getAllAndOverride<KillSwitchSpec | undefined>(KILL_SWITCH, [ctx.getHandler(), ctx.getClass()]);
    if (!spec) return true;
    if (await this.config.flagEnabled(spec.flag, true)) return true;
    throw new ApiError(HttpStatus.SERVICE_UNAVAILABLE, spec.code, spec.message);
  }
}
