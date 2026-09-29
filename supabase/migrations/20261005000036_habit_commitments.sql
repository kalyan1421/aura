-- W02 — habit commitments (RULES.md §13, opt-in reversible decay in the personal world).
--
-- Two nullable dates on `habits`, written only through POST /v1/sync/push like every personal column:
--   committed_from  : the Aura day the person chose "treat this as a commitment". NULL = not a commitment (never decays).
--   paused_through  : a person-chosen pause (holiday, illness); needs a commitment.
-- Presentation-only: nothing here touches starlight_ledger, active_days, avatar_state or streaks.
-- Decay is never available to a minor: NestJS refuses it (`commitment_not_available`), and this trigger is the backstop,
-- using the same `user_is_minor` (stored DOB or an unexpired platform age signal) as every other invisible protection.

alter table public.habits
  add column committed_from date,
  add column paused_through date,
  add constraint habits_commitment_shape
    check (paused_through is null or committed_from is not null),
  -- A pause is bounded by NestJS (60 days ahead); this only keeps the pair sane.
  add constraint habits_pause_after_commitment
    check (paused_through is null or paused_through >= committed_from - 1);

comment on column public.habits.committed_from is
  'W02: Aura day the person opted this habit in as a commitment (RULES.md §13). NULL = never decays. Never available to minors.';
comment on column public.habits.paused_through is
  'W02: person-chosen pause; while today <= this day the habit''s world object does not decay. Needs committed_from.';

create function public.habits_commitment_not_minor() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.committed_from is not null
     and (tg_op = 'INSERT' or new.committed_from is distinct from old.committed_from)
     and public.user_is_minor(new.user_id) then
    raise exception 'commitment_not_available' using errcode = '23514';
  end if;
  return new;
end
$$;
revoke all on function public.habits_commitment_not_minor() from public, anon, authenticated;

create trigger habits_commitment_not_minor
  before insert or update on public.habits
  for each row execute function public.habits_commitment_not_minor();
