-- F3 "Longest streak lives only in Insights" (PRD 06a F3; contracts/rules/RULES.md §7 `longestGlowStreak`).
--
-- The glow-streak fold now also keeps the longest run so far (never decreases). NestJS derives it from the ledger's
-- active days like every other streak field (DS-5) and writes it with them (src/progression/progression.repository.ts);
-- the app shows it in Insights only. Clients read it through the existing select-own policy; no new privileges.
--
-- Existing rows: at least the current run. The next recompute (any sync push or snapshot) re-folds every active day and
-- stores the true value.

alter table public.streak_state
  add column longest_glow_streak int not null default 0
  constraint streak_state_longest_nonneg check (longest_glow_streak >= 0);

update public.streak_state set longest_glow_streak = glow_streak where longest_glow_streak < glow_streak;
