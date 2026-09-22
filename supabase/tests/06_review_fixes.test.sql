-- Code-review fixes: habit shape/uniqueness, future-sequence privileges, sync_mutations index.
begin;
select plan(7);

insert into auth.users (id, email) values ('0192f0c2-0000-7000-8000-00000000a001', 'review-fixes@aura.test');

insert into public.habits (id, user_id, kind, preset_key)
values ('0192f0c2-0000-7000-8000-0000000b0001', '0192f0c2-0000-7000-8000-00000000a001', 'preset', 'breathe');

select throws_ok(
  $$ insert into public.habits (id, user_id, kind, preset_key)
     values ('0192f0c2-0000-7000-8000-0000000b0002', '0192f0c2-0000-7000-8000-00000000a001', 'preset', 'breathe') $$,
  '23505', null, 'a user cannot have the same preset habit twice'
);

select lives_ok(
  $$ insert into public.habits (id, user_id, kind, preset_key)
     values ('0192f0c2-0000-7000-8000-0000000b0003', '0192f0c2-0000-7000-8000-00000000a001', 'preset', 'move') $$,
  'a different preset is fine'
);

select throws_ok(
  $$ insert into public.habits (id, user_id, kind, preset_key, name)
     values ('0192f0c2-0000-7000-8000-0000000b0004', '0192f0c2-0000-7000-8000-00000000a001', 'custom', 'hydrate', 'Tea') $$,
  '23514', null, 'a custom habit cannot carry a preset_key'
);

select lives_ok(
  $$ insert into public.habits (id, user_id, kind, name)
     values ('0192f0c2-0000-7000-8000-0000000b0005', '0192f0c2-0000-7000-8000-00000000a001', 'custom', 'Stretch') $$,
  'a plain custom habit is fine'
);

-- A table created by a later migration (as postgres) gets a sequence clients cannot use.
create table public.tmp_future_table (id bigserial primary key);
select ok(
  not has_sequence_privilege('anon', 'public.tmp_future_table_id_seq', 'USAGE'),
  'anon has no USAGE on a future sequence'
);
select ok(
  not has_sequence_privilege('authenticated', 'public.tmp_future_table_id_seq', 'UPDATE'),
  'authenticated cannot setval a future sequence'
);

select has_index('public', 'sync_mutations', 'sync_mutations_applied_at_idx', 'purge index on sync_mutations.applied_at');

select * from finish();
rollback;
