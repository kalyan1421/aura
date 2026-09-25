-- Milestone B gaps (migration 20261005000025):
--   * Tonight's intention words: all five languages per key, seeded from the app's bundled strings, one short clean
--     line each; every preset has words (FK); the key can't change; a key a room still shows can't lose its words;
--     retiring a preset never touches a room that pinned it tonight;
--   * the console role (aura_admin) reads and edits the list but can never delete, and reads only the two room columns
--     it needs; clients can't read any of it (the app gets the words through NestJS GET /v1/intentions);
--   * the trial-ending email ledger: one row per trial, state + reason code only, server-only, purged with the account.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

-- pgTAP lives in `extensions`; let aura_admin call it for the role-switched assertions (rolled back at the end).
grant usage on schema extensions to aura_admin;

insert into auth.users (id, email, aud, role) values
  ('25aaaaaa-0000-4000-8000-00000000000a', 'pgtap-gapsb-a@aura.test', 'authenticated', 'authenticated');
insert into public.rooms (id, language_pool, quadrant, tz_region, seed_mood_id, theme, opened_at, joins_close_at, memory_at, purge_at)
values ('25cccccc-0000-4000-8000-00000000000c', 'en', 'storm', 'south_asia', 'anxious', 'lighthouse', now(),
        now() + interval '19 hours', now() + interval '23 hours', now() + interval '8 days');

-- ---------------------------------------------------------------- shape and seed
select has_table('public', 'room_intention_texts', 'room_intention_texts exists');
select has_table('public', 'trial_ending_emails', 'trial_ending_emails exists');
select results_eq(
  $$ select text_en, text_te, text_te_latn, text_hi, text_hi_latn from public.room_intention_texts where key = 'sleep_before_midnight' $$,
  $$ values ('Sleep before midnight'::text, 'అర్ధరాత్రి లోపు నిద్రపోవాలి'::text, 'Ardharaatri lopu nidrapovaali'::text,
             'आधी रात से पहले सोना'::text, 'Aadhi raat se pehle sona'::text) $$,
  'the bundled words are seeded word for word'
);
select is((select count(*)::int from public.room_intention_texts
            where key in ('sleep_before_midnight','gentle_with_myself','phone_down_10','water_before_bed','one_kind_thought','slow_breaths')),
  6, 'all six bundled keys have words');
select is((select count(*)::int from public.room_intention_presets p
            where not exists (select 1 from public.room_intention_texts t where t.key = p.key)),
  0, 'every preset has its words');
select is((select count(*)::int from public.room_intention_presets where enabled and language_pool = 'en'
            and key in ('sleep_before_midnight','gentle_with_myself','phone_down_10','water_before_bed','one_kind_thought','slow_breaths')),
  6, 'the seeded presets stay in rotation');

select throws_ok(
  $$ insert into public.room_intention_presets (language_pool, key) values ('en', 'no_words_yet') $$,
  '23503', null, 'a preset without words is refused (FK)'
);
select throws_ok(
  $$ insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
     values ('too_long_one', repeat('a', 81), 'ఒక', 'oka', 'एक', 'ek') $$,
  '23514', null, 'a line over 80 characters is refused'
);
select throws_ok(
  $$ insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
     values ('two_lines', E'one\ntwo', 'ఒక', 'oka', 'एक', 'ek') $$,
  '23514', null, 'a line break is refused'
);
select throws_ok(
  $$ insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
     values ('padded_one', ' padded', 'ఒక', 'oka', 'एक', 'ek') $$,
  '23514', null, 'untrimmed words are refused'
);
select throws_ok(
  $$ insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
     values ('Bad Key', 'x', 'ఒక', 'oka', 'एक', 'ek') $$,
  '23514', null, 'a malformed key is refused'
);

-- ---------------------------------------------------------------- the console role
insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
values ('pgtap_gapsb_one', 'One quiet page of a book', 'ఒక పుస్తకం పేజీ', 'Oka pustakam page', 'किताब का एक पन्ना', 'Kitaab ka ek panna');

set local role aura_admin;
select lives_ok(
  $$ insert into public.room_intention_presets (language_pool, key, position, enabled) values ('hi', 'pgtap_gapsb_one', 900, false) $$,
  'aura_admin adds a preset'
);
select lives_ok(
  $$ update public.room_intention_texts set text_en = 'One quiet page before sleep' where key = 'pgtap_gapsb_one' $$,
  'aura_admin rewords a key'
);
select lives_ok(
  $$ update public.room_intention_presets set enabled = false, position = 901 where language_pool = 'hi' and key = 'pgtap_gapsb_one' $$,
  'aura_admin retires and moves a preset'
);
select throws_ok(
  $$ delete from public.room_intention_presets where key = 'pgtap_gapsb_one' $$,
  '42501', null, 'aura_admin can never delete a preset (retire instead)'
);
select throws_ok(
  $$ delete from public.room_intention_texts where key = 'pgtap_gapsb_one' $$,
  '42501', null, 'aura_admin can never delete words'
);
select throws_ok(
  $$ update public.room_intention_presets set key = 'slow_breaths' where key = 'pgtap_gapsb_one' $$,
  '42501', null, 'aura_admin can''t rename a preset'
);
select lives_ok(
  $$ select intention_key, lantern_hour_at from public.rooms limit 1 $$,
  'aura_admin reads which preset rooms show tonight'
);
select throws_ok(
  $$ select intention_holds from public.rooms limit 1 $$,
  '42501', null, 'but no other lantern column it doesn''t need'
);
select throws_ok(
  $$ select * from public.trial_ending_emails $$,
  '42501', null, 'aura_admin can''t read the trial email ledger'
);
reset role;

select ok((select updated_at from public.room_intention_texts where key = 'pgtap_gapsb_one') >= (select created_at from public.room_intention_texts where key = 'pgtap_gapsb_one'),
  'updated_at follows the change');

-- ---------------------------------------------------------------- a retired preset stays with the room using it
update public.rooms set lantern_hour_at = now() - interval '5 minutes', intention_key = 'pgtap_gapsb_one'
 where id = '25cccccc-0000-4000-8000-00000000000c';
update public.room_intention_presets set enabled = false where key = 'pgtap_gapsb_one';
select is((select intention_key from public.rooms where id = '25cccccc-0000-4000-8000-00000000000c'), 'pgtap_gapsb_one',
  'retiring the preset leaves the room''s intention for tonight');
delete from public.room_intention_presets where key = 'pgtap_gapsb_one';
select throws_ok(
  $$ delete from public.room_intention_texts where key = 'pgtap_gapsb_one' $$,
  'AR050', 'intention_in_use', 'the words of a key a room still shows can''t be deleted, by any role'
);
select throws_ok(
  $$ update public.room_intention_texts set key = 'pgtap_gapsb_two' where key = 'pgtap_gapsb_one' $$,
  'AR050', 'intention_key_fixed', 'a key never changes'
);
insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
values ('pgtap_gapsb_three', 'Warm socks tonight', 'వెచ్చని సాక్స్', 'Vechani socks', 'गरम मोज़े', 'Garam moze');
insert into public.room_intention_presets (language_pool, key, enabled) values ('te', 'pgtap_gapsb_three', false);
select throws_ok(
  $$ delete from public.room_intention_texts where key = 'pgtap_gapsb_three' $$,
  '23503', null, 'the words of a key a preset uses can''t be deleted'
);
delete from public.rooms where id = '25cccccc-0000-4000-8000-00000000000c';
select lives_ok(
  $$ delete from public.room_intention_texts where key = 'pgtap_gapsb_one' $$,
  'once no preset or room uses a key, the service role may remove it'
);

-- ---------------------------------------------------------------- trial-ending email ledger
insert into public.subscriptions (id, owner_user_id, store, store_ref, product_id, environment, state, trial_ends_at, expires_at)
values ('25dddddd-0000-4000-8000-00000000000d', '25aaaaaa-0000-4000-8000-00000000000a', 'apple', 'pgtap-gapsb-1',
        'aura_plus_monthly', 'sandbox', 'trial', now() + interval '47 hours', now() + interval '47 hours');
select lives_ok(
  $$ insert into public.trial_ending_emails (subscription_id, user_id, state, attempts, locale)
     values ('25dddddd-0000-4000-8000-00000000000d', '25aaaaaa-0000-4000-8000-00000000000a', 'sending', 1, 'te-Latn') $$,
  'one ledger row per trial'
);
select throws_ok(
  $$ insert into public.trial_ending_emails (subscription_id, user_id, state)
     values ('25dddddd-0000-4000-8000-00000000000d', '25aaaaaa-0000-4000-8000-00000000000a', 'sending') $$,
  '23505', null, 'never a second row for the same trial'
);
select throws_ok(
  $$ update public.trial_ending_emails set reason = 'Contains an address@x' where subscription_id = '25dddddd-0000-4000-8000-00000000000d' $$,
  '23514', null, 'the reason is a code, never free text'
);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"25aaaaaa-0000-4000-8000-00000000000a","role":"authenticated"}', true);
select throws_ok($$ select state from public.trial_ending_emails $$, '42501', null, 'clients can''t read the ledger, not even their own row');
select throws_ok($$ select text_en from public.room_intention_texts $$, '42501', null, 'clients read intention words only through NestJS');
reset role;

delete from auth.users where id = '25aaaaaa-0000-4000-8000-00000000000a';
select is((select count(*)::int from public.trial_ending_emails where subscription_id = '25dddddd-0000-4000-8000-00000000000d'), 0,
  'the ledger row goes with the account');

select * from finish();
rollback;
