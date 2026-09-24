-- F12 Monetization (Milestone B) — store billing validated in NestJS (DS-9; no RevenueCat, no Razorpay).
-- Contract: contracts/api/v1-billing.md · server: server/aura-api/src/billing · app: apps/mobile features/plus.
--
-- Every table here is written by NestJS only (service role). The app never writes any of them; it reads its own
-- entitlement, cosmetics and Stardust ledger (RLS select-own) or, preferably, GET /v1/billing/entitlement.
--
--  1. billing_accounts     — the user-derived purchase token (`appAccountToken` / `obfuscatedAccountId`) per account,
--                            plus the once-per-account trial-reminder stamp. Personal (purged with the account).
--  2. subscriptions        — Aura Plus per store subscription (Apple original transaction id / Google purchase token):
--                            state trial / active / grace / billing_retry / paused / expired / refunded / revoked /
--                            pending, auto-renew, trial end, expiry, grace end. [LEGAL] kept de-identified after an
--                            account purge (owner_user_id → null): purchase / tax records "kept only as law requires"
--                            (PRD 06c F8 "Deletion and export"; CGST Act s.36 / Income-tax books: 6–8 years).
--  3. purchases            — one-time store purchases (cosmetics = non-consumable, gifts = consumable). Same retention.
--  4. entitlements         — derived per account (NestJS recomputes after every change). Client: select own.
--  5. user_cosmetics       — owned cosmetics (store purchase or Stardust) and the equipped sky + soundscape pairing.
--  6. stardust_ledger      — signed amounts; balance = sum, never below zero (trigger). No cash-out, no transfers.
--  7. gifts                — pre-checked gifts (≤5 per sender per Aura day), delivery, refunds (recipient keeps Stardust).
--  8. store_notifications  — App Store Server Notifications V2 + Play RTDN, logged raw, idempotent, replayable.
--  9. feature flag `gifts_enabled` (kill switch, PRD 19) and the `gift_pattern` auto report signal (minors lane).

-- =============================================================================================== 1. billing_accounts
create table public.billing_accounts (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  -- HMAC(AURA_MASTER_KEY-derived key, user_id) shaped as a UUID: never the user id itself, so store payloads and the
  -- notification log carry nothing that names the account once this row is gone.
  account_token         uuid not null unique,
  -- PRD 12: the trial-ending reminder goes once per account.
  trial_reminder_at     timestamptz,
  created_at            timestamptz not null default now()
);
comment on table public.billing_accounts is
  'F12: the store account token (appAccountToken / obfuscatedAccountId) per account. Server-only; purged with the account.';

-- =============================================================================================== 2. subscriptions
create table public.subscriptions (
  id                    uuid primary key default gen_random_uuid(),
  owner_user_id         uuid references auth.users(id) on delete set null,
  store                 text not null check (store in ('apple','google')),
  -- Apple: originalTransactionId · Google: purchaseToken.
  store_ref             text not null check (char_length(store_ref) between 1 and 512),
  product_id            text not null check (product_id ~ '^[a-z0-9_.]{1,64}$'),
  environment           text not null check (environment in ('production','sandbox')),
  state                 text not null check (state in ('pending','trial','active','grace','billing_retry','paused',
                                                        'expired','refunded','revoked')),
  auto_renew            boolean not null default true,
  started_at            timestamptz,
  trial_ends_at         timestamptz,
  expires_at            timestamptz,
  grace_ends_at         timestamptz,
  cancelled_at          timestamptz,
  revoked_at            timestamptz,
  latest_transaction_id text check (latest_transaction_id is null or char_length(latest_transaction_id) <= 128),
  -- Google upgrade / downgrade chain: the purchase token this one replaced.
  linked_store_ref      text check (linked_store_ref is null or char_length(linked_store_ref) <= 512),
  -- The store's localized price string the app showed (never a hard-coded ₹49): used by the trial reminder.
  price_display         text check (price_display is null or char_length(price_display) <= 32),
  acknowledged_at       timestamptz,
  -- Ordering guard: the store's own event time of the snapshot applied last (older snapshots are ignored).
  last_event_at         timestamptz,
  -- Last confirmation with the store's server API (the daily reconcile repairs dropped notifications).
  verified_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint subscriptions_store_ref unique (store, store_ref),
  constraint subscriptions_grace check (state <> 'grace' or grace_ends_at is not null)
);
create index subscriptions_owner_idx on public.subscriptions (owner_user_id) where owner_user_id is not null;
create index subscriptions_trial_idx on public.subscriptions (trial_ends_at) where state = 'trial';
create index subscriptions_reconcile_idx on public.subscriptions (verified_at)
  where state in ('pending','trial','active','grace','billing_retry','paused');
comment on table public.subscriptions is
  'F12 Aura Plus subscriptions, owned by NestJS (DS-9) from App Store Server Notifications V2 / Play RTDN and the store '
  'APIs. [LEGAL] De-identified (owner_user_id → null) by the account purge, kept as a purchase record.';

-- =============================================================================================== 3. purchases
create table public.purchases (
  id                    uuid primary key default gen_random_uuid(),
  owner_user_id         uuid references auth.users(id) on delete set null,
  store                 text not null check (store in ('apple','google')),
  -- Apple: transactionId · Google: purchaseToken.
  store_ref             text not null check (char_length(store_ref) between 1 and 512),
  order_id              text check (order_id is null or char_length(order_id) <= 128),
  product_id            text not null check (product_id ~ '^[a-z0-9_.]{1,64}$'),
  kind                  text not null check (kind in ('cosmetic','gift')),
  environment           text not null check (environment in ('production','sandbox')),
  state                 text not null check (state in ('pending','completed','refunded','revoked')),
  purchased_at          timestamptz,
  refunded_at           timestamptz,
  acknowledged_at       timestamptz,
  consumed_at           timestamptz,
  last_event_at         timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint purchases_store_ref unique (store, store_ref)
);
create index purchases_owner_idx on public.purchases (owner_user_id) where owner_user_id is not null;
comment on table public.purchases is
  'F12 one-time purchases (cosmetics, gifts). Owned by NestJS. [LEGAL] De-identified by the account purge, kept as a '
  'purchase record.';

-- =============================================================================================== 4. entitlements
create table public.entitlements (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  plus_active           boolean not null default false,
  plus_state            text check (plus_state is null or plus_state in ('pending','trial','active','grace',
                                    'billing_retry','paused','expired','refunded','revoked')),
  -- Until when the current Plus period (or grace) runs: the app honours a cached entitlement until then (16-offline).
  plus_until            timestamptz,
  plus_store            text check (plus_store is null or plus_store in ('apple','google')),
  plus_product_id       text,
  plus_auto_renew       boolean,
  plus_trial_ends_at    timestamptz,
  plus_subscription_id  uuid references public.subscriptions(id) on delete set null,
  updated_at            timestamptz not null default now(),
  constraint entitlements_active_state check (not plus_active or plus_state in ('trial','active','grace'))
);
comment on table public.entitlements is
  'F12: what the account has right now, derived by NestJS from subscriptions (never from a client receipt alone).';

-- =============================================================================================== 5. user_cosmetics
create table public.user_cosmetics (
  user_id               uuid not null references auth.users(id) on delete cascade,
  cosmetic_id           text not null check (cosmetic_id ~ '^[a-z0-9_]{1,40}$'),
  source                text not null check (source in ('purchase','stardust')),
  purchase_id           uuid references public.purchases(id) on delete set null,
  redemption_id         uuid unique,
  acquired_at           timestamptz not null default now(),
  primary key (user_id, cosmetic_id),
  constraint user_cosmetics_source check ((source = 'stardust') = (redemption_id is not null))
);
comment on table public.user_cosmetics is
  'F12 owned cosmetics (personal sky themes). A refunded store purchase removes its row; Stardust redemptions stay.';

-- The equipped personal sky and its soundscape pairing (one per account; free, Plus or owned themes only — checked by
-- NestJS). Never shown to strangers.
create table public.sky_preferences (
  user_id               uuid primary key references auth.users(id) on delete cascade,
  sky_theme             text not null check (sky_theme ~ '^[a-z0-9_]{1,40}$'),
  soundscape            text check (soundscape is null or soundscape ~ '^[a-z0-9_]{1,40}$'),
  updated_at            timestamptz not null default now()
);

-- =============================================================================================== 6. stardust_ledger
create table public.stardust_ledger (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references auth.users(id) on delete cascade,
  amount                integer not null check (amount <> 0 and amount between -1000 and 1000),
  reason                text not null check (reason in ('gift_received','cosmetic_redeemed')),
  ref_id                uuid not null,
  created_at            timestamptz not null default now(),
  constraint stardust_ledger_once unique (user_id, reason, ref_id),
  constraint stardust_ledger_sign check ((reason = 'gift_received') = (amount > 0))
);
create index stardust_ledger_user_idx on public.stardust_ledger (user_id, created_at desc);
comment on table public.stardust_ledger is
  'F12 Stardust: only earned from gifts received, only spent on cosmetics. Never sold, cashed, transferred or expired.';

-- Balance never below zero (a spend needs the per-user lock and enough earned Stardust).
create function public.stardust_balance_guard() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.amount < 0 and (select coalesce(sum(amount), 0) from public.stardust_ledger where user_id = new.user_id)
                        + new.amount < 0 then
    raise exception 'stardust balance would go below zero' using errcode = 'AR030';
  end if;
  return new;
end $$;
revoke all on function public.stardust_balance_guard() from public, anon, authenticated;
create trigger stardust_balance_guard before insert on public.stardust_ledger
  for each row execute function public.stardust_balance_guard();
create function public.stardust_ledger_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'stardust ledger rows never change' using errcode = 'AR031';
end $$;
create trigger stardust_ledger_immutable before update on public.stardust_ledger
  for each row execute function public.stardust_ledger_immutable();

-- =============================================================================================== 7. gifts
create table public.gifts (
  -- Client-generated UUIDv7 at the pre-check (idempotent retries).
  id                    uuid primary key,
  sender_user_id        uuid references auth.users(id) on delete set null,
  recipient_user_id     uuid references auth.users(id) on delete set null,
  recipient_member_id   uuid references public.room_members(member_id) on delete set null,
  room_id               uuid references public.rooms(id) on delete set null,
  gift_kind             text not null check (gift_kind in ('warm_tea','comfort_lantern','encouragement_bouquet')),
  product_id            text not null check (product_id ~ '^[a-z0-9_.]{1,64}$'),
  stardust_amount       smallint not null check (stardust_amount in (10, 30, 50)),
  status                text not null check (status in ('checked','delivered','cancelled','expired')),
  purchase_id           uuid unique references public.purchases(id) on delete set null,
  -- The sender's Aura day at the pre-check (the "≤ 5 per day" cap).
  sender_day            date not null,
  checked_at            timestamptz not null default now(),
  expires_at            timestamptz not null,
  delivered_at          timestamptz,
  seen_at               timestamptz,
  refunded_at           timestamptz,
  constraint gifts_delivered check ((status = 'delivered') = (delivered_at is not null)),
  constraint gifts_not_self check (sender_user_id is null or recipient_user_id is null
                                   or sender_user_id <> recipient_user_id)
);
create index gifts_sender_day_idx on public.gifts (sender_user_id, sender_day) where sender_user_id is not null;
create index gifts_sender_refunds_idx on public.gifts (sender_user_id, refunded_at) where refunded_at is not null;
create index gifts_recipient_idx on public.gifts (recipient_user_id, delivered_at desc) where recipient_user_id is not null;
create index gifts_open_idx on public.gifts (expires_at) where status = 'checked';
comment on table public.gifts is
  'F12 gifts: checked before the store sheet, delivered after the store confirms. No message; the recipient never '
  'learns who sent it. Refund: the recipient keeps the Stardust, the sender''s refund count grows.';

-- =============================================================================================== 8. store_notifications
create table public.store_notifications (
  id                    uuid primary key default gen_random_uuid(),
  store                 text not null check (store in ('apple','google')),
  -- Apple notificationUUID · Pub/Sub messageId (the idempotency key).
  notification_id       text not null check (char_length(notification_id) between 1 and 128),
  notification_type     text not null check (char_length(notification_type) <= 64),
  subtype               text check (subtype is null or char_length(subtype) <= 64),
  environment           text check (environment is null or environment in ('production','sandbox')),
  signed_at             timestamptz,
  -- Apple: the verified signedPayload (JWS) · Google: the decoded DeveloperNotification JSON. Replayable. Holds no
  -- account id (only the derived account token and store identifiers).
  payload               text not null check (char_length(payload) <= 200000),
  store_ref             text check (store_ref is null or char_length(store_ref) <= 512),
  status                text not null default 'received' check (status in ('received','processed','ignored','failed')),
  attempts              smallint not null default 0,
  last_error            text check (last_error is null or last_error ~ '^[a-z0-9_]{1,64}$'),
  received_at           timestamptz not null default now(),
  processed_at          timestamptz,
  constraint store_notifications_once unique (store, notification_id)
);
create index store_notifications_retry_idx on public.store_notifications (received_at) where status in ('received','failed');
create index store_notifications_received_idx on public.store_notifications (received_at);
comment on table public.store_notifications is
  'F12 App Store Server Notifications V2 and Play RTDN, verified then logged; handled idempotently; retried by the '
  'billing worker; pruned after 400 days.';

-- =============================================================================================== RLS + privileges
alter table public.billing_accounts    enable row level security;
alter table public.subscriptions       enable row level security;
alter table public.purchases           enable row level security;
alter table public.entitlements        enable row level security;
alter table public.user_cosmetics      enable row level security;
alter table public.sky_preferences     enable row level security;
alter table public.stardust_ledger     enable row level security;
alter table public.gifts               enable row level security;
alter table public.store_notifications enable row level security;

revoke all on table public.billing_accounts, public.subscriptions, public.purchases, public.entitlements,
                    public.user_cosmetics, public.sky_preferences, public.stardust_ledger, public.gifts,
                    public.store_notifications
  from anon, authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'aura_admin') then
    execute 'revoke all on table public.billing_accounts, public.subscriptions, public.purchases, public.entitlements, '
            'public.user_cosmetics, public.sky_preferences, public.stardust_ledger, public.gifts, '
            'public.store_notifications from aura_admin';
  end if;
end $$;

-- The app may read its own entitlement, cosmetics, sky choice and Stardust ledger (never write).
grant select on table public.entitlements, public.user_cosmetics, public.sky_preferences, public.stardust_ledger
  to authenticated;
create policy own_read on public.entitlements    for select to authenticated using (user_id = auth.uid());
create policy own_read on public.user_cosmetics  for select to authenticated using (user_id = auth.uid());
create policy own_read on public.sky_preferences for select to authenticated using (user_id = auth.uid());
create policy own_read on public.stardust_ledger for select to authenticated using (user_id = auth.uid());

-- =============================================================================================== 9. flag + report signal
insert into public.feature_flags (key, enabled, payload, description)
values ('gifts_enabled', true, '{}'::jsonb,
        'Gifts (F12). Off: no new gifts (POST /v1/billing/gifts → 503 gifts_paused); the app hides the gift entry. '
        'Gifts already paid for still deliver.')
on conflict (key) do nothing;

-- F12 / 06b: 3+ gifts in 7 days from one adult to the same under-18 account → Minors & grooming lane review.
-- NOTE for later migrations: keep 'gift_pattern' when redefining this check.
alter table public.reports drop constraint reports_auto_signal_check;
alter table public.reports add constraint reports_auto_signal_check check (auto_signal in (
  'gesture_flood','reflection_hold','reflection_crisis','reflection_minor_safety','reflection_violation','gift_pattern'));
