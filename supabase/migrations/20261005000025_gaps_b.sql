-- Milestone B gaps (PRD v1.3):
--  1. Tonight's intention list editor (PRD 19 "Configuration": "the Tonight's intention list per language"; 06b "It
--     rotates from a localized list"; contracts/api/v1-rooms.md §1.9 and §1.10).
--  2. The trial-ending email (PRD 12 catalogue "Aura Plus trial ending": Push + in-app card + email; "Email
--     (trial-ending reminder only, and only if the account has a verified email)"; contracts/api/v1-billing.md §6.1).
--
-- 1. Intentions
--   * `room_intention_texts` — the words of each preset key in all five app languages (en, te, te-Latn, hi, hi-Latn),
--     the same rule as the app's own strings (PRD 18: "Line pools are the same size in every language"). A key's
--     words are the same in every pool (a room can mix languages: pools fall back to English). Seeded with the six
--     keys the app bundles, word for word from app_*.arb. `GET /v1/intentions` serves them to the app, which prefers
--     them over its bundled strings (so the console's edits reach phones without a release) and hides the card for a
--     key it has no words for.
--   * `room_intention_presets.key` now references a text row: a preset can't exist without its words.
--   * Nothing is ever deleted by the console (aura_admin has no DELETE): a preset is RETIRED (`enabled = false`) —
--     out of the rotation from the next room that starts its Lantern Hour. A room keeps the key it pinned for the
--     night (`rooms.intention_key` is write-once, migration 000022), and the words for a key stay readable while any
--     room still shows it: deleting a text row a room uses is refused for every role (AR050).
--   * aura_admin (the console's role) may read and write both tables (Owner-only writes are enforced in NestJS, reads
--     are Owner + Moderator) and read the two room columns the console's "tonight" view needs (the preset each room
--     shows — a room total, never who holds it).
--
-- 2. Trial-ending email
--   * `trial_ending_emails` — one row per trial subscription the email was attempted for: the idempotency ledger
--     (the primary key is the subscription, so a trial is never emailed twice, whatever retries or restarts do). It
--     never stores the address (read from auth.users.email at send time) or any copy; only the state and a reason
--     code. Server-only (no client grant), purged with the account (FK cascade).

-- =============================================================================================== 1. intention texts
create table if not exists public.room_intention_texts (
  key          text primary key check (key ~ '^[a-z][a-z0-9_]{1,47}$'),
  text_en      text not null,
  text_te      text not null,
  text_te_latn text not null,
  text_hi      text not null,
  text_hi_latn text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- One short line, trimmed, no line breaks or control characters (the console lints the words themselves).
  constraint room_intention_texts_shape check (
    char_length(text_en) between 1 and 80 and text_en = btrim(text_en) and text_en !~ '[[:cntrl:]]' and
    char_length(text_te) between 1 and 80 and text_te = btrim(text_te) and text_te !~ '[[:cntrl:]]' and
    char_length(text_te_latn) between 1 and 80 and text_te_latn = btrim(text_te_latn) and text_te_latn !~ '[[:cntrl:]]' and
    char_length(text_hi) between 1 and 80 and text_hi = btrim(text_hi) and text_hi !~ '[[:cntrl:]]' and
    char_length(text_hi_latn) between 1 and 80 and text_hi_latn = btrim(text_hi_latn) and text_hi_latn !~ '[[:cntrl:]]'
  )
);
comment on table public.room_intention_texts is
  'Tonight''s intention words per preset key in all five app languages (PRD 19 "the Tonight''s intention list per language"). Served by GET /v1/intentions; edited in the admin console (Owner). Never deleted while a room shows the key.';
alter table public.room_intention_texts enable row level security;
revoke all on table public.room_intention_texts from anon, authenticated;

-- The six keys every app build bundles (apps/mobile/lib/l10n/app_*.arb `rooms_intention_*`), word for word.
insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn) values
  ('sleep_before_midnight', 'Sleep before midnight', 'అర్ధరాత్రి లోపు నిద్రపోవాలి', 'Ardharaatri lopu nidrapovaali',
   'आधी रात से पहले सोना', 'Aadhi raat se pehle sona'),
  ('gentle_with_myself', 'Be gentle with myself tonight', 'ఈ రాత్రి నా పట్ల మృదువుగా ఉంటాను', 'Ee raatri naa patla gentle ga untaanu',
   'आज रात खुद से नरमी', 'Aaj raat khud se narmi'),
  ('phone_down_10', 'Phone down for 10 minutes', '10 నిమిషాలు ఫోన్ పక్కన పెడతాను', '10 nimishaalu phone pakkana pedataanu',
   '10 मिनट फ़ोन से दूरी', '10 minute phone se doori'),
  ('water_before_bed', 'A glass of water before bed', 'పడుకునే ముందు ఒక గ్లాసు నీళ్ళు', 'Padukune mundu oka glass neellu',
   'सोने से पहले एक गिलास पानी', 'Sone se pehle ek glass paani'),
  ('one_kind_thought', 'One kind thought about today', 'ఈ రోజు గురించి ఒక మంచి ఆలోచన', 'Ee roju gurinchi oka manchi aalochana',
   'आज के बारे में एक अच्छा ख्याल', 'Aaj ke baare mein ek achha khayal'),
  ('slow_breaths', 'Three slow breaths before sleep', 'నిద్రకు ముందు మూడు నెమ్మదైన శ్వాసలు', 'Nidraku mundu moodu nemmadaina swaasalu',
   'सोने से पहले तीन धीमी साँसें', 'Sone se pehle teen dheemi saansein')
on conflict (key) do nothing;

-- A preset key the texts don't have yet (added by hand before this migration) gets its key as placeholder words in
-- every language, retired, so the foreign key can be added; the console shows it for the Owner to word and re-enable.
insert into public.room_intention_texts (key, text_en, text_te, text_te_latn, text_hi, text_hi_latn)
select distinct p.key, p.key, p.key, p.key, p.key, p.key
  from public.room_intention_presets p
 where not exists (select 1 from public.room_intention_texts t where t.key = p.key)
on conflict (key) do nothing;
update public.room_intention_presets p set enabled = false
 where p.enabled and exists (select 1 from public.room_intention_texts t where t.key = p.key and t.text_en = p.key);

-- =============================================================================================== 2. presets
alter table public.room_intention_presets
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'room_intention_presets_key_text') then
    alter table public.room_intention_presets
      add constraint room_intention_presets_key_text foreign key (key)
      references public.room_intention_texts (key) on update restrict on delete restrict;
  end if;
end $$;
create index if not exists room_intention_presets_key_idx on public.room_intention_presets (key);

-- updated_at follows every change (the console lists "last changed").
create or replace function public.gaps_b_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists room_intention_presets_touch on public.room_intention_presets;
create trigger room_intention_presets_touch before update on public.room_intention_presets
  for each row execute function public.gaps_b_touch_updated_at();
drop trigger if exists room_intention_texts_touch on public.room_intention_texts;
create trigger room_intention_texts_touch before update on public.room_intention_texts
  for each row execute function public.gaps_b_touch_updated_at();

-- The words of a key a room still shows can never go (a retired preset never disappears from a room using it). The
-- key itself is immutable (it is what rooms pinned).
create or replace function public.room_intention_texts_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.key is distinct from old.key then
      raise exception 'intention_key_fixed' using errcode = 'AR050';
    end if;
    return new;
  end if;
  if exists (select 1 from public.rooms r where r.intention_key = old.key) then
    raise exception 'intention_in_use' using errcode = 'AR050';
  end if;
  return old;
end;
$$;
drop trigger if exists room_intention_texts_guard on public.room_intention_texts;
create trigger room_intention_texts_guard before update of key or delete on public.room_intention_texts
  for each row execute function public.room_intention_texts_guard();

-- =============================================================================================== 3. console grants
grant select, insert, update (position, enabled) on public.room_intention_presets to aura_admin;
grant select, insert, update (text_en, text_te, text_te_latn, text_hi, text_hi_latn) on public.room_intention_texts to aura_admin;
-- "In use tonight": which preset each room pinned for its night (room totals, no member data).
grant select (intention_key, lantern_hour_at) on public.rooms to aura_admin;

-- =============================================================================================== 4. trial-ending email
create table if not exists public.trial_ending_emails (
  subscription_id uuid primary key references public.subscriptions (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  -- sending: claimed (an attempt is under way or was cut short — never retried, so nobody gets it twice);
  -- sent: the mail server accepted it; failed: the mail server refused or was unreachable (retried a few times);
  -- skipped: not sent for a reason (no verified email, auto-renew off, account deleted / closed, trial changed).
  state           text not null check (state in ('sending', 'sent', 'failed', 'skipped')),
  reason          text check (reason is null or reason ~ '^[a-z0-9_]{1,40}$'),
  attempts        int  not null default 0 check (attempts between 0 and 20),
  locale          text check (locale is null or locale in ('en', 'te', 'te-Latn', 'hi', 'hi-Latn')),
  sent_at         timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
comment on table public.trial_ending_emails is
  'PRD 12 trial-ending email: one row per trial (idempotency). No address, no copy: state + reason code only. Server-only; purged with the account.';
create index if not exists trial_ending_emails_user_idx on public.trial_ending_emails (user_id);
alter table public.trial_ending_emails enable row level security;
revoke all on table public.trial_ending_emails from anon, authenticated;
drop trigger if exists trial_ending_emails_touch on public.trial_ending_emails;
create trigger trial_ending_emails_touch before update on public.trial_ending_emails
  for each row execute function public.gaps_b_touch_updated_at();
