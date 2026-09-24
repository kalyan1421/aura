-- Milestone B security review of the NestJS / RPC boundary (PRD 20-timeline weeks 28–29).
-- Findings, method and residual risks: docs/security/milestone-b-review.md. Regression: supabase/tests/24_security_review.test.sql.
-- Idempotent (safe to re-run on the shared local stack). No table or column is renamed or dropped.

-- 1. [SR-3] private-media object size cap.
--    Clients upload through signed upload URLs that NestJS issues after checking the declared `bytes` per kind
--    (voice 1 MiB, capsule photo 4 MiB, capsule voice 2 MiB / Plus 6 MiB — server/aura-api/src/media/media.schema.ts,
--    billing/entitlement-check.ts). Storage cannot bind a size to a signed upload token, so until now the only real cap
--    was the project-wide [storage].file_size_limit (50 MiB): a client could declare 10 bytes and PUT 50 MiB. The bucket
--    limit is the one Storage enforces on every upload, so pin it to the largest object the API ever signs for.
update storage.buckets
   set file_size_limit = 6291456            -- = PLUS_CAPSULE_VOICE_BYTES (6 MiB); keep in sync if a kind grows
 where id = 'private-media';

-- 2. [SR-4] Functions are not client-callable by default.
--    Postgres grants EXECUTE on every new function to PUBLIC, and Supabase's default privileges add anon and
--    authenticated in schema public — so every SECURITY DEFINER function a migration creates is a PostgREST RPC
--    (`/rest/v1/rpc/<name>`) until that migration remembers to revoke it. All 48 current functions were checked and
--    are revoked correctly; this makes "not callable" the default for the next ones (the same idea migration
--    20261005000003 applied to table writes). A function clients must call (the Realtime topic checks) needs an
--    explicit `grant execute … to authenticated`, as migrations 20261005000010/21 already do.
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from anon, authenticated;

--    The one remaining client EXECUTE grant: a trigger function (not callable directly; EXECUTE is only checked when a
--    trigger is created). Revoked so the catalogue invariant "clients execute only the Realtime topic checks" holds.
revoke all on function public.stardust_ledger_immutable() from public, anon, authenticated;
