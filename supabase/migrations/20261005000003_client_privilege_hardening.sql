-- Defence in depth on top of the foundations RLS (no tables/columns renamed or dropped).

-- 1. Server-only tables get no client privileges at all. RLS with no policy already returns zero
--    rows; revoking SELECT turns any client/PostgREST read into an explicit permission error.
revoke all on table
  public.user_data_keys,
  public.sync_mutations,
  public.device_tokens,
  public.crisis_events
from anon, authenticated;

-- 2. bigserial sequences: clients have no business calling nextval/setval.
revoke all on sequence
  public.starlight_ledger_id_seq,
  public.crisis_events_id_seq
from anon, authenticated;

-- 3. The foundations "revoke insert, update, delete, truncate on all tables" only covered tables that
--    existed at that moment. Make it the default for every table later migrations create in public,
--    so a new table can never be client-writable by accident (still SELECT-able; RLS decides rows).
alter default privileges for role postgres in schema public
  revoke insert, update, delete, truncate on tables from anon, authenticated;
