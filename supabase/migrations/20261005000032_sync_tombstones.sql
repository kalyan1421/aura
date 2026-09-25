-- PRD 16 "Sync model · Pull: per-entity delta since a server sequence cursor, after each push and on foreground" and
-- "Two phones, one account … pulls merge". Deletes are hard deletes on the server (a tombstone mutation removes the
-- row), so a phone pulling only what changed could never learn that another phone deleted a check-in, a habit or a
-- habit log. This keeps a small per-account tombstone for each, read through the existing select-own pattern.
--
--   * `public.sync_tombstones (user_id, entity, entity_id, deleted_at)`: written only by triggers on the three tables
--     (every delete path: the sync push, a habit's cascade to its logs, the account purge), never by a client;
--   * clients read their own (RLS select-own) as `deleted_at > cursor`; ids only, no content;
--   * a delete that cascades from the auth user itself (the account is gone) writes nothing; the account purge lists
--     the table last, and the FK cascade is the backstop;
--   * rows older than 400 days are dropped by the maintenance job; a phone whose cursor is older than that re-reads
--     everything (apps/mobile pull_service.dart).

create table public.sync_tombstones (
  user_id    uuid not null references auth.users(id) on delete cascade,
  entity     text not null check (entity in ('check_in','habit','habit_log')),
  entity_id  uuid not null,
  deleted_at timestamptz not null default now(),
  primary key (user_id, entity, entity_id)
);
create index sync_tombstones_user_deleted_idx on public.sync_tombstones (user_id, deleted_at);
comment on table public.sync_tombstones is
  'PRD 16 delta pull: ids of check-ins, habits and habit logs deleted on the server, so other phones drop them. '
  'Trigger-written; select-own for clients; no content.';

alter table public.sync_tombstones enable row level security;
revoke all on public.sync_tombstones from anon, authenticated;
grant select on public.sync_tombstones to authenticated;
create policy own_read on public.sync_tombstones for select to authenticated using (user_id = auth.uid());

create or replace function public.sync_tombstone_record() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- The account itself is being deleted (FK cascade from auth.users): nothing to tell other phones.
  if not exists (select 1 from auth.users where id = old.user_id) then
    return old;
  end if;
  insert into public.sync_tombstones (user_id, entity, entity_id, deleted_at)
  values (old.user_id, tg_argv[0], old.id, clock_timestamp())
  on conflict (user_id, entity, entity_id) do update set deleted_at = excluded.deleted_at;
  return old;
end $$;
revoke all on function public.sync_tombstone_record() from public, anon, authenticated;

create trigger check_ins_tombstone after delete on public.check_ins
  for each row execute function public.sync_tombstone_record('check_in');
create trigger habits_tombstone after delete on public.habits
  for each row execute function public.sync_tombstone_record('habit');
create trigger habit_logs_tombstone after delete on public.habit_logs
  for each row execute function public.sync_tombstone_record('habit_log');

-- A record that comes back (the same client id pushed again after a delete: never in practice, but ids are the
-- client's) is live again: its tombstone goes.
create or replace function public.sync_tombstone_clear() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.sync_tombstones where user_id = new.user_id and entity = tg_argv[0] and entity_id = new.id;
  return new;
end $$;
revoke all on function public.sync_tombstone_clear() from public, anon, authenticated;

create trigger check_ins_tombstone_clear after insert on public.check_ins
  for each row execute function public.sync_tombstone_clear('check_in');
create trigger habits_tombstone_clear after insert on public.habits
  for each row execute function public.sync_tombstone_clear('habit');
create trigger habit_logs_tombstone_clear after insert on public.habit_logs
  for each row execute function public.sync_tombstone_clear('habit_log');

-- Delta cursors read `updated_at` / `server_ts` ranges per account.
create index if not exists check_ins_user_updated_idx on public.check_ins (user_id, updated_at);
create index if not exists habits_user_updated_idx on public.habits (user_id, updated_at);
create index if not exists habit_logs_user_server_ts_idx on public.habit_logs (user_id, server_ts);
