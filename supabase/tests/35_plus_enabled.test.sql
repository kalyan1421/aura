-- Purchases off switch (migration 20261005000035): `plus_enabled` exists, is OFF, described, and public like every flag.
begin;
create extension if not exists pgtap with schema extensions;

select plan(5);

select is((select count(*)::int from public.feature_flags where key = 'plus_enabled'), 1, 'flag plus_enabled exists');
select is((select enabled from public.feature_flags where key = 'plus_enabled'), false,
          'plus_enabled is OFF by default (v1.0 launches free)');
select ok((select description ~ 'plus_disabled' and char_length(description) <= 300
             from public.feature_flags where key = 'plus_enabled'),
          'described for the console (names the 503 code, <= 300 chars)');
select is((select payload from public.feature_flags where key = 'plus_enabled'), '{}'::jsonb, 'no payload');
select ok(has_table_privilege('anon', 'public.feature_flags', 'SELECT'),
          'flags stay public (GET /v1/config serves every row)');

select * from finish();
rollback;
