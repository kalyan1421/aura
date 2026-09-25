-- v1.0 launches free: an off switch for everything that can be bought (Aura Plus, cosmetic skies, Stardust, gifts).
--
-- `plus_enabled` is OFF by default, in the table and in the app's bundled defaults (a fresh install that has never
-- reached the server, or is offline, never shows a purchase). While off:
--   * the app shows no paywall route or entry point (Settings › Aura Plus, Home trial / billing / gift cards, "See
--     Aura Plus" on limit screens, sky / Stardust purchases, the gift entry in rooms, Restore) and never initialises
--     or queries the store plugin; Plus-only features stay locked with their calm "Part of Aura Plus" line;
--   * NestJS refuses every purchase route with `503 plus_disabled` (`@KillSwitch(PLUS_KILL_SWITCH)`,
--     src/remote-config/kill-switch.ts): POST /v1/billing/purchases, /restore, /gifts and /stardust/redeem. Unlike
--     the other kill switches, a MISSING row also counts as off (purchases are opt-in).
-- Entitlement reads, the store webhooks and gift delivery keep working (nothing already bought is taken away).
-- Turning it on is the console's Kill switches page (Owner, audited) — only once the store products are live.

insert into public.feature_flags (key, enabled, payload, description)
values ('plus_enabled', false, '{}'::jsonb,
        'Purchases (F12: Aura Plus, skies, Stardust, gifts). Off (v1.0 launches free): the app shows no paywall, Plus '
        'card, gift or restore; POST /v1/billing/purchases, /restore, /gifts, /stardust/redeem → 503 plus_disabled. '
        'Turn on only once store products are live.')
on conflict (key) do nothing;
