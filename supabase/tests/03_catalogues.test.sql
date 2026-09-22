-- Catalogues (moods, preset_habits, feature_flags) are public-read and match contracts/moods.json
-- (loaded by supabase/seed.sql — run `supabase db reset` first).
begin;
create extension if not exists pgtap with schema extensions;

select plan(12);

-- ---------- anon ----------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is((select count(*)::int from public.moods), 16, 'anon reads all 16 moods');
select is((select count(*)::int from public.preset_habits), 6, 'anon reads all 6 preset habits');
select lives_ok('select * from public.feature_flags', 'anon can read feature_flags');

select results_eq(
  'select quadrant, count(*)::int from public.moods group by quadrant order by quadrant',
  $$ values ('moonlight', 4), ('rain', 4), ('storm', 4), ('sunrise', 4) $$,
  'four moods per quadrant'
);
select results_eq(
  'select sort from public.moods order by sort',
  'select generate_series(0, 15)',
  'mood sort is 0..15 without gaps'
);
select is_empty(
  $$ select id from public.moods where not (names ?& array['en','te','te-Latn','hi','hi-Latn']) $$,
  'every mood has names in all five locales'
);
select is(
  (select names->>'te-Latn' from public.moods where id = 'anxious'),
  'Aandolanaga',
  'jsonb names are keyed by locale (anxious.te-Latn)'
);
select is(
  (select names->>'te' from public.moods where id = 'quietly_hopeful'),
  'మెల్లగా ఆశగా',
  'non-Latin names survive the seed round-trip'
);
select set_eq(
  'select key from public.preset_habits',
  array['hydrate','sleep_on_time','move','breathe','journal','go_outside'],
  'preset habit keys match the contract'
);
select is(
  (select names->>'en' from public.preset_habits where key = 'sleep_on_time'),
  'Sleep on time',
  'preset habit names are jsonb keyed by locale'
);

-- ---------- authenticated ----------
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0aaaaaaa-0000-4000-8000-00000000000a","role":"authenticated","aud":"authenticated"}', true);

select is((select count(*)::int from public.moods), 16, 'authenticated reads all 16 moods');
select is((select count(*)::int from public.preset_habits), 6, 'authenticated reads all 6 preset habits');

reset role;
select * from finish();
rollback;
