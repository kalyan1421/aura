# Aura — repo guide

Pseudonymous social + gamified mood check-in app (iOS + Android). Owner/publisher: **AKVega**. Built solo by AK.
Product spec: `docs/PRD.md` (assembled from `docs/prd/sections/*.md` via `python3 docs/prd/assemble.py` — edit sections, never PRD.md).

## Layout
| Path | What |
|---|---|
| `apps/mobile` | Flutter app (`com.akvega.aura`), Riverpod 2 + GoRouter + Freezed + Drift, feature-first |
| `packages/aura_domain` | Pure Dart domain: mood catalogue, progression rules (Starlight, streaks, nebula, stage, hue), `AuraAvatarState` |
| `server/aura-api` | NestJS modular monolith (API + BullMQ worker), raw `pg`, pnpm, jest |
| `supabase/` | Supabase CLI project: migrations (source of truth for schema), RLS, pgTAP tests, seed |
| `infra/docker-compose.yml` | Local Redis |
| `contracts/` | Cross-stack contracts: `rules/RULES.md` + `rules/vectors/*.json` (both Dart and TS must pass), `moods.json`, `api/v1.md` |

## Local ports (chosen to avoid OPTEX 5432x, 3D studio 563xx, RMS 5433/6380)
Supabase API **55521** · DB **55522** · Studio **55523** · Inbucket **55524** · Analytics **55527** · Pooler **55529** · Shadow **55520** · Redis **6391** · NestJS API **3310** · Worker health **3311** · Admin (later) **3320**.

## Locked decisions (PRD v1.1 — do not relitigate)
- 13+ full access, **no parental consent**, one mixed-age pool; under-13 blocked with a 30-day device lock. Under-18s get only invisible protections (analytics exclusion, stricter moderation).
- **The app never writes personal tables directly.** All personal writes go through `POST /v1/sync/push` (NestJS); clients read own rows from Supabase (RLS select-own). Server ledger is authoritative (DS-5).
- Envelope encryption for notes/capsules/media (DS-1); full DOB stored (DS-6); stranger-facing reads only via NestJS/RPC returning pseudonyms (DS-10).
- Store billing validated in NestJS (no RevenueCat). No Razorpay for digital goods.
- Art is procedural code (CustomPainter + fragment shaders + flutter_animate) — no Rive in v1.
- Locales: `en`, `te`, `te-Latn` (Tenglish), `hi`, `hi-Latn` (Hinglish). Alpha ships en/te/te-Latn.
- IDs: client-generated **UUIDv7**. Dates: `local_day` is the **Aura day** (04:00 rollover in the user's IANA tz).

## Commands
- Supabase: `supabase start` / `supabase db reset` / `supabase test db` (from repo root)
- Redis: `docker compose -f infra/docker-compose.yml up -d`
- API: `cd server/aura-api && pnpm install && pnpm test && pnpm start:dev`
- Dart: `dart pub get` at root (pub workspace) · `cd packages/aura_domain && dart test`
- Mobile: `cd apps/mobile && flutter run` · codegen `dart run build_runner build -d`

## Conventions
- Match AK's Asan conventions: repository pattern, immutable Freezed models, feature-first folders, no cross-app imports, shared logic in `packages/`.
- Every rule change starts in `contracts/rules` (spec + vectors), then Dart + TS.
- Never log or send mood notes, reflection text, capsule content or DOB to analytics or logs.
