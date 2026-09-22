-- Code-review fixes (23 Sep 2026).

-- 1. Habits (PRD F2): each preset exists at most once per user. The API checks first and
--    rejects with `duplicate_preset_habit`; this index is the backstop against races.
create unique index habits_one_per_preset
  on public.habits (user_id, preset_key)
  where kind = 'preset';

-- 2. A custom habit must not carry a preset_key (the old check allowed it).
alter table public.habits drop constraint habits_kind_shape;
alter table public.habits add constraint habits_kind_shape check (
  (kind = 'preset' and preset_key is not null)
  or (kind = 'custom' and name is not null and preset_key is null)
);

-- 3. Hardening follow-up: migration 000003 made future *tables* read-only for clients, but
--    sequences created later (bigserial) would still be usable via nextval/setval.
alter default privileges for role postgres in schema public
  revoke usage, select, update on sequences from anon, authenticated;

-- 4. sync_mutations is an idempotency window, not an archive: the worker purges rows older
--    than 90 days (maintenance queue). This index keeps that purge cheap.
create index sync_mutations_applied_at_idx on public.sync_mutations (applied_at);
