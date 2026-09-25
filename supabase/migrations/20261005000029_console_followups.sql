-- Milestone C console follow-ups (PRD 19 "Configuration"; docs/setup/admin-console.md).
--
-- The console's Kill switches page now shows each flag's `feature_flags.description` instead of hard-coded text (which
-- had gone stale: it still listed room lanterns, Tonight's intention, Breath Ripples, echoes, gifts, Quiet Together and
-- the wind-down as "not built", and said the sign-up throttle wasn't wired). This refreshes the descriptions that had
-- fallen behind what exists:
--   * quiet_enabled / lantern_wind_down_enabled: single regions are now paused from the console
--     (`POST /admin/config/regions/:key/:region/pause|resume`, Owner, audited; src/admin/region-pause.service.ts);
--   * rooms_pool_hi: turning it on sends the "Tell me when they open" push (pool-open sweep, every minute);
--   * hold_all, rooms_enabled, room_lanterns_enabled, room_intention_enabled: where to act, no milestone wording.
-- The others (reduced_mode, reflections_composer, ripples_enabled, ripples_echoes, gifts_enabled) are already current.
-- Descriptions only: no flag state, payload or privilege changes (`aura_admin` still updates `enabled` only; region
-- payloads are written by the service role behind the Owner-only route).

update public.feature_flags
   set description = 'Quiet Together (F16). Off: no new joins (POST /v1/quiet/join → 503 quiet_paused) and the app hides its entry; sessions running finish their block. payload.pausedRegions pauses single timezone regions: Kill switches page → Per region.'
 where key = 'quiet_enabled';

update public.feature_flags
   set description = 'Lantern Hour wind-down (F16). Off: rooms offer no "Wind down together" (POST /v1/rooms/:id/wind-down → 503 wind_down_paused). payload.pausedRegions pauses single timezone regions: Kill switches page → Per region.'
 where key = 'lantern_wind_down_enabled';

update public.feature_flags
   set description = 'Hindi + Hinglish rooms (F5). Off until their moderation is ready: those accounts are offered English rooms (POST /v1/rooms/match → 409 language_pool_unavailable). On: everyone who tapped "Tell me when they open" gets one push within a minute.'
 where key = 'rooms_pool_hi';

update public.feature_flags
   set description = 'Hold-all (06c F9, before planned absences): every new reflection waits for a human (review them on the Reflections page); gestures unaffected.'
 where key = 'hold_all';

update public.feature_flags
   set description = 'Mood rooms (F5). Off: no new room joins (POST /v1/rooms/match → 503 rooms_paused) and the app hides its join offers; rooms already joined keep working until they close.'
 where key = 'rooms_enabled';

update public.feature_flags
   set description = 'Room lanterns (F5). Off: lanterns take no light and are hidden in every room (the stored level is kept).'
 where key = 'room_lanterns_enabled';

update public.feature_flags
   set description = 'Tonight''s intention (F5). Off: no intention card shows in rooms and holding one answers 503 intention_paused.'
 where key = 'room_intention_enabled';
