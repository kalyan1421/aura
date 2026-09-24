-- F12 Monetization (migration 20261005000020): server-owned billing tables.
--   * every table has RLS; the app reads only its own entitlement, cosmetics, sky choice and Stardust ledger, and
--     writes nothing (all writes are NestJS, service role); subscriptions, purchases, gifts, store notifications and
--     the store token are server-only; the console role and anon hold nothing;
--   * Stardust never goes below zero and ledger rows never change;
--   * idempotency keys: one row per store purchase, one log row per store notification;
--   * account deletion: personal rows cascade; purchase records stay without the account link ([LEGAL]);
--   * the gifts kill switch and the gift_pattern report signal exist.
begin;
create extension if not exists pgtap with schema extensions;
grant usage on schema extensions to aura_admin;

select plan(42);

select has_table('public', t, format('%s exists', t))
from unnest(array['billing_accounts','subscriptions','purchases','entitlements','user_cosmetics','sky_preferences',
                  'stardust_ledger','gifts','store_notifications']) t;

select is_empty(
  $$ select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace
       and c.relname in ('billing_accounts','subscriptions','purchases','entitlements','user_cosmetics','sky_preferences',
                         'stardust_ledger','gifts','store_notifications') and not c.relrowsecurity $$,
  'RLS is on for every billing table'
);

insert into auth.users (id, email, aud, role) values
  ('20aaaaaa-0000-4000-8000-00000000000a', 'pgtap-billing-a@aura.test', 'authenticated', 'authenticated'),
  ('20bbbbbb-0000-4000-8000-00000000000b', 'pgtap-billing-b@aura.test', 'authenticated', 'authenticated');

-- ---------------------------------------------------------------- server writes
insert into public.billing_accounts (user_id, account_token) values
  ('20aaaaaa-0000-4000-8000-00000000000a', '20a0c1a4-51b2-4c3d-9e4f-5a6b7c8d9e0f'),
  ('20bbbbbb-0000-4000-8000-00000000000b', '20b0c1a4-51b2-4c3d-9e4f-5a6b7c8d9e0f');
insert into public.subscriptions (id, owner_user_id, store, store_ref, product_id, environment, state, trial_ends_at, expires_at)
values ('20cccccc-0000-4000-8000-00000000000c', '20aaaaaa-0000-4000-8000-00000000000a', 'apple', 'pgtap-orig-1',
        'aura_plus_monthly', 'sandbox', 'trial', now() + interval '20 days', now() + interval '20 days');
insert into public.entitlements (user_id, plus_active, plus_state, plus_until) values
  ('20aaaaaa-0000-4000-8000-00000000000a', true, 'trial', now() + interval '20 days'),
  ('20bbbbbb-0000-4000-8000-00000000000b', false, null, null);
insert into public.purchases (id, owner_user_id, store, store_ref, product_id, kind, environment, state)
values ('20dddddd-0000-4000-8000-00000000000d', '20aaaaaa-0000-4000-8000-00000000000a', 'google', 'pgtap-token-1',
        'sky_deep_ocean', 'cosmetic', 'sandbox', 'completed');
insert into public.user_cosmetics (user_id, cosmetic_id, source, purchase_id) values
  ('20aaaaaa-0000-4000-8000-00000000000a', 'deep_ocean', 'purchase', '20dddddd-0000-4000-8000-00000000000d');
insert into public.sky_preferences (user_id, sky_theme, soundscape) values ('20aaaaaa-0000-4000-8000-00000000000a', 'deep_ocean', 'shore');
insert into public.stardust_ledger (user_id, amount, reason, ref_id) values
  ('20aaaaaa-0000-4000-8000-00000000000a', 30, 'gift_received', '20eeeeee-0000-4000-8000-00000000000e'),
  ('20bbbbbb-0000-4000-8000-00000000000b', 10, 'gift_received', '20eeeeee-0000-4000-8000-00000000000f');

-- ---------------------------------------------------------------- constraints
select throws_ok(
  $$ insert into public.subscriptions (store, store_ref, product_id, environment, state)
     values ('apple', 'pgtap-orig-1', 'aura_plus_annual', 'sandbox', 'active') $$,
  '23505', null, 'one row per store purchase (original transaction id / purchase token)'
);
select throws_ok(
  $$ insert into public.subscriptions (store, store_ref, product_id, environment, state)
     values ('apple', 'pgtap-orig-2', 'aura_plus_monthly', 'sandbox', 'cancelled') $$,
  '23514', null, '"cancelled" is not a state (it is trial/active with auto_renew off)'
);
select throws_ok(
  $$ insert into public.subscriptions (store, store_ref, product_id, environment, state)
     values ('apple', 'pgtap-orig-3', 'aura_plus_monthly', 'sandbox', 'grace') $$,
  '23514', null, 'grace needs its end'
);
select throws_ok(
  $$ insert into public.entitlements (user_id, plus_active, plus_state) values ('20bbbbbb-0000-4000-8000-00000000000b', true, 'billing_retry')
     on conflict (user_id) do update set plus_active = excluded.plus_active, plus_state = excluded.plus_state $$,
  '23514', null, 'Plus can only be active in trial, active or grace'
);
select throws_ok(
  $$ insert into public.stardust_ledger (user_id, amount, reason, ref_id)
     values ('20aaaaaa-0000-4000-8000-00000000000a', -50, 'cosmetic_redeemed', gen_random_uuid()) $$,
  'AR030', null, 'Stardust never goes below zero'
);
select lives_ok(
  $$ insert into public.stardust_ledger (user_id, amount, reason, ref_id)
     values ('20aaaaaa-0000-4000-8000-00000000000a', -30, 'cosmetic_redeemed', gen_random_uuid()) $$,
  'spending exactly the balance works'
);
select throws_ok(
  $$ insert into public.stardust_ledger (user_id, amount, reason, ref_id)
     values ('20bbbbbb-0000-4000-8000-00000000000b', -5, 'gift_received', gen_random_uuid()) $$,
  '23514', null, 'gifts only ever add Stardust, redemptions only spend it'
);
select throws_ok(
  $$ insert into public.stardust_ledger (user_id, amount, reason, ref_id)
     values ('20bbbbbb-0000-4000-8000-00000000000b', 10, 'gift_received', '20eeeeee-0000-4000-8000-00000000000f') $$,
  '23505', null, 'a gift credits its recipient once'
);
select throws_ok(
  $$ update public.stardust_ledger set amount = 1000 where user_id = '20bbbbbb-0000-4000-8000-00000000000b' $$,
  'AR031', null, 'ledger rows never change'
);
select throws_ok(
  $$ insert into public.gifts (id, sender_user_id, recipient_user_id, gift_kind, product_id, stardust_amount, status, sender_day, expires_at)
     values (gen_random_uuid(), '20aaaaaa-0000-4000-8000-00000000000a', '20bbbbbb-0000-4000-8000-00000000000b', 'warm_tea',
             'gift_warm_tea', 20, 'checked', current_date, now() + interval '7 days') $$,
  '23514', null, 'gift Stardust is 10 / 30 / 50'
);
select throws_ok(
  $$ insert into public.gifts (id, sender_user_id, recipient_user_id, gift_kind, product_id, stardust_amount, status, sender_day, expires_at)
     values (gen_random_uuid(), '20aaaaaa-0000-4000-8000-00000000000a', '20aaaaaa-0000-4000-8000-00000000000a', 'warm_tea',
             'gift_warm_tea', 10, 'checked', current_date, now() + interval '7 days') $$,
  '23514', null, 'nobody gifts themselves'
);
select throws_ok(
  $$ insert into public.gifts (id, sender_user_id, recipient_user_id, gift_kind, product_id, stardust_amount, status, sender_day, expires_at)
     values (gen_random_uuid(), '20aaaaaa-0000-4000-8000-00000000000a', '20bbbbbb-0000-4000-8000-00000000000b', 'warm_tea',
             'gift_warm_tea', 10, 'delivered', current_date, now() + interval '7 days') $$,
  '23514', null, 'delivered needs its delivery time'
);
select lives_ok(
  $$ insert into public.store_notifications (store, notification_id, notification_type, payload)
     values ('apple', 'pgtap-uuid-1', 'TEST', 'x') $$,
  'a store notification is logged'
);
select throws_ok(
  $$ insert into public.store_notifications (store, notification_id, notification_type, payload)
     values ('apple', 'pgtap-uuid-1', 'TEST', 'x') $$,
  '23505', null, 'the same notification is logged once (idempotency key)'
);

-- ---------------------------------------------------------------- app access
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"20aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.entitlements), 1, 'the app reads its own entitlement only');
select is((select plus_active from public.entitlements), true, '… and sees Plus on');
select is((select count(*)::int from public.user_cosmetics), 1, 'the app reads its own cosmetics');
select is((select count(*)::int from public.stardust_ledger), 2, 'the app reads its own Stardust ledger only');
select is((select sky_theme from public.sky_preferences), 'deep_ocean', 'the app reads its own sky');
select throws_ok($$ select * from public.subscriptions $$, '42501', null, 'subscriptions are server-only');
select throws_ok($$ select * from public.purchases $$, '42501', null, 'purchases are server-only');
select throws_ok($$ select * from public.gifts $$, '42501', null, 'gifts are server-only (the recipient never sees the sender)');
select throws_ok($$ select * from public.billing_accounts $$, '42501', null, 'the store token table is server-only');
select throws_ok($$ select * from public.store_notifications $$, '42501', null, 'the notification log is server-only');
select throws_ok(
  $$ update public.entitlements set plus_active = true $$, '42501', null, 'the app can never grant itself Plus'
);
select throws_ok(
  $$ insert into public.user_cosmetics (user_id, cosmetic_id, source, redemption_id)
     values ('20aaaaaa-0000-4000-8000-00000000000a', 'meteor_shower', 'stardust', gen_random_uuid()) $$,
  '42501', null, 'the app can never grant itself a cosmetic'
);
select throws_ok(
  $$ insert into public.stardust_ledger (user_id, amount, reason, ref_id)
     values ('20aaaaaa-0000-4000-8000-00000000000a', 100, 'gift_received', gen_random_uuid()) $$,
  '42501', null, 'the app can never add Stardust'
);
reset role;

select ok(
  not has_table_privilege('aura_admin', 'public.subscriptions', 'SELECT, INSERT, UPDATE, DELETE')
  and not has_table_privilege('anon', 'public.entitlements', 'SELECT, INSERT, UPDATE, DELETE')
  and not has_table_privilege('aura_admin', 'public.gifts', 'SELECT, INSERT, UPDATE, DELETE'),
  'neither the console role nor anon holds billing privileges'
);

select is((select enabled from public.feature_flags where key = 'gifts_enabled'), true, 'the gifts kill switch exists (on)');
-- Later migrations that redefine reports_auto_signal_check (e.g. 20261005000021) must keep 'gift_pattern'.
select lives_ok(
  $$ insert into public.reports (source, auto_signal, reason, lane, involves_minor, target_kind, target_ref, sla_due_at, target_user_id)
     values ('auto', 'gift_pattern', 9, 'minors_grooming', true, 'member', gen_random_uuid(), now() + interval '4 hours',
             '20aaaaaa-0000-4000-8000-00000000000a') $$,
  'the gift_pattern signal can open a Minors & grooming item'
);
delete from public.reports where auto_signal = 'gift_pattern' and target_user_id = '20aaaaaa-0000-4000-8000-00000000000a';

-- ---------------------------------------------------------------- account deletion
delete from auth.users where id = '20aaaaaa-0000-4000-8000-00000000000a';
select is(
  (select count(*)::int from public.billing_accounts where user_id = '20aaaaaa-0000-4000-8000-00000000000a')
  + (select count(*)::int from public.entitlements where user_id = '20aaaaaa-0000-4000-8000-00000000000a')
  + (select count(*)::int from public.user_cosmetics where user_id = '20aaaaaa-0000-4000-8000-00000000000a')
  + (select count(*)::int from public.stardust_ledger where user_id = '20aaaaaa-0000-4000-8000-00000000000a')
  + (select count(*)::int from public.sky_preferences where user_id = '20aaaaaa-0000-4000-8000-00000000000a'),
  0, 'personal billing rows go with the account'
);
select ok(
  (select owner_user_id is null from public.subscriptions where id = '20cccccc-0000-4000-8000-00000000000c')
  and (select owner_user_id is null from public.purchases where id = '20dddddd-0000-4000-8000-00000000000d'),
  '[LEGAL] purchase records stay, without the account link'
);

select * from finish();
rollback;
