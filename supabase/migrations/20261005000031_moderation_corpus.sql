-- REQ-SAFE-16 "De-identified corpus, notice, opt-out" (PRD 06c F9 "Training corpus"; PRD 19 "Decisions are kept as
-- de-identified labels for a future in-house model"; Q24; contracts/api/v1-reflections.md §7).
--
-- Moderation decisions on reflections feed a de-identified corpus for a future in-house classifier (MuRIL / XLM-R):
-- the text, its language and the label, nothing else. Written only by NestJS (src/reflections/corpus.ts), after a
-- final decision (the pipeline's publish / reject, a moderator's approve / remove):
--   * no user, room, member, pseudonym, reflection or report id, and no FK to anything; the id is random (no order);
--   * the only time is the ISO week (a Monday), so a row can't be matched to a reflection by timestamp;
--   * the text is sealed like reflection text (DS-1 envelope under AURA_MASTER_KEY, bound to the row id); nothing in
--     the console reads this table (`aura_admin` has no grant);
--   * kept past the room purge and the account purge (it links to no one) [LEGAL: whether it is still personal data].
-- Never enters it: under-18 authors, authors who opted out (Settings; `user_consents` purpose `moderation_corpus`,
-- on by default per the privacy notice), crisis-diverted text (DS-7), Minors & grooming items (they stay in the
-- evidence store only), contact details, links and personal questions (the text carries personal data), held items
-- until a human decides.

create table public.moderation_corpus (
  id        uuid primary key default gen_random_uuid(),
  language  text not null check (language in ('en','te','te-Latn','hi','hi-Latn')),
  label     text not null check (label in ('allow','reject_hurtful','reject_sexual','reject_other',
                                           'removed_hurtful','removed_sexual','removed_other')),
  source    text not null check (source in ('auto','human')),
  week      date not null check (extract(isodow from week) = 1),
  text_ct   text not null check (char_length(text_ct) between 16 and 20000),
  text_key  text not null check (char_length(text_key) between 16 and 200)
);
comment on table public.moderation_corpus is
  'REQ-SAFE-16 de-identified moderation corpus: sealed text + language + label + ISO week. No link to any person, room '
  'or reflection. Server-only (NestJS service role); never readable by clients or the console.';

alter table public.moderation_corpus enable row level security;
revoke all on public.moderation_corpus from anon, authenticated;
