-- Code-review fix: the API judges age-13 on the user's LOCAL date (the app does the same). The old
-- constraint compared against the UTC current_date, so a user already 13 in a zone ahead of UTC (IST
-- until 05:30, up to UTC+14) was rejected on their birthday — and the app then applied a 30-day lock.
-- Backstop now allows one day of slack; exact enforcement lives in the API (src/profile/age.ts).
alter table public.profiles drop constraint profiles_min_age;
alter table public.profiles add constraint profiles_min_age
  check (birth_date <= ((current_date + 1) - interval '13 years'));
