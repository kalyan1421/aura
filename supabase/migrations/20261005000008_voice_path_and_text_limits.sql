-- (1) F1 voice notes (contracts/api/v1.md "Media: voice notes"). A check-in's voice note is the client-encrypted
-- private-media object `<user_id>/voice/<check-in id>`: one deterministic name per record (a retried upload
-- overwrites it). NestJS enforces the rule on every write (sync push → `rejected: invalid_voice_path`); this
-- CHECK is the DB backstop, so a stored reference can never point into another user's prefix or at another
-- record: the sync cleanup deletes objects by these names, and the download route only signs the caller's
-- own prefix. uuid::text is canonical lower-case, so the stored path is too.
-- No backfill needed: nothing wrote voice_path before this migration (the column was reserved in 000001).
alter table public.check_ins drop constraint if exists check_ins_voice_path_shape;
alter table public.check_ins
  add constraint check_ins_voice_path_shape
  check (voice_path is null or voice_path = user_id::text || '/voice/' || id::text);

-- (2) Habit names (PRD F2): ≤ 30 characters counted as grapheme clusters — enforced by NestJS
-- (`rejected: habit_name_too_long`, src/sync/text-limits.ts), matching the app's Dart `characters` count.
-- The old backstop `char_length(name) <= 40` counts code points, so it refused valid names: 30 Telugu
-- characters are often 60–180 code points. Postgres cannot count grapheme clusters, so the backstop only
-- bounds the size: NestJS allows at most 16 UTF-16 units per character (30 × 16 = 480 ≥ code points).
alter table public.habits drop constraint if exists habits_name_check;
alter table public.habits drop constraint if exists habits_name_length;
alter table public.habits
  add constraint habits_name_length
  check (name is null or char_length(name) <= 480);
