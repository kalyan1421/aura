# Aura — pending work across Milestones A, B and C

Audit of branch `fix/design-audit` at `9e44942` (25 Sep 2026) against every PRD section in `docs/prd/sections/`
(06a–06d REQ tables, 12–22) and the milestone "Ships" rows and exit criteria in 20-timeline, followed by the fixes made
in the same working tree (uncommitted; the lead commits). Evidence is a `file:line` or file in the repo (source, then a
test where one exists).

**Status legend:** **done** = built, with a test or a clear code path · **partial** = built in part (the notes say
what's missing) · **missing** = not built · **blocked on AK** = needs something only AK can supply (credentials, store
consoles, lawyer, native review, recordings, domain, hiring, a real-device spike) · **out of scope** = parked or
excluded by an AK decision (PRD 21/22, or the parked `wip/analytics-ci` branch: PostHog, Sentry, CI).

Each row shows the status found by the audit (**Before**) and after the fixes (**After**). Rows that the fixes changed
are marked ✱ and explained in "What was fixed".

## Counts

Over the 104 rows of the four status tables below (Milestones A, B, C and cross-cutting; one row per REQ group or item):

| Status | Before | After |
|---|---|---|
| done | 71 | 89 |
| partial | 12 | 1 |
| missing | 9 | 0 |
| blocked on AK | 7 | 9 |
| out of scope | 5 | 5 |
| **total** | **104** | **104** |

- The two "partial → blocked on AK" rows (REQ-SAFE-03, REQ-SAN-11) have no code left to write: they wait on native /
  safe-messaging review and on licensed recordings.
- The one partial left is the security-residuals row: parts of it are fixed, the rest is in "Remaining work" (key
  rotation is too large to do well here) or is AK's production configuration.
- The sweep table adds five items not repeated above: dead code (removed), stale comments (corrected), and three
  blocked on AK (Universal Links domain, attestation keys, real legal / grievance values).

---

## Milestone A — closed alpha

| REQ / item | Before | After | Evidence | Notes |
|---|---|---|---|---|
| REQ-CHK-01 2-tap check-in | done | done | `apps/mobile/lib/src/features/checkin/mood_grid.dart:55`; `test/checkin_screen_test.dart:23` | median timing is a field metric (analytics parked) |
| REQ-CHK-02 fully offline | done | done | `features/checkin/checkin_repository.dart:71`; `test/checkin_repository_test.dart` | |
| REQ-CHK-03 notes crisis-checked on device | done | done | `features/checkin/checkin_screen.dart:219` | hi/hi-Latn terms: REQ-SAFE-03 |
| REQ-CHK-04 room prompt after save | done | done | `features/rooms/room_offer.dart:20`; `test/checkin_post_save_order_test.dart` | |
| REQ-CHK-05 guided prompt in the note | done | done | `features/checkin/checkin_details.dart:202`; `test/companion_prompts_test.dart:14` | |
| REQ-CHK-06 backfill earns nothing | done | done | `server/aura-api/src/sync/sync.service.ts:276`; `apps/mobile/test/backfill_test.dart:27` | |
| F1 tags, note ≤ 500, voice ≤ 60 s, storage-full notice | done | done | `features/checkin/checkin_repository.dart:19`; `features/voice/voice_store.dart:49` | |
| REQ-AVA-01 never regresses | done | done | `packages/aura_domain/lib/src/avatar/aura_stage.dart:24`; `packages/aura_domain/test/avatar_and_projection_test.dart:29` | |
| REQ-AVA-02 Starlight per table | done | done | `contracts/rules/vectors/starlight.json`; `avatar_and_projection_test.dart:80` | |
| REQ-AVA-03 never sold | done | done | `server/aura-api/src/billing/catalogue.ts:8`; `test/unit/billing.catalogue.spec.ts:19` | |
| REQ-AVA-04 Nebula after 2 idle days | done | done | `contracts/rules/vectors/nebula.json` | |
| REQ-AVA-05 evolution plays once | done | done | `features/avatar/moments_controller.dart:15` | |
| REQ-AVA-06 renderer contract (goldens) | done | done | `test/avatar_painter_test.dart:93`; `test/goldens/avatar_*.png` | |
| ✱ REQ-AVA-07 Low tier on weak phones | partial | done | `lib/src/core/perf/device_profile.dart`; `features/avatar/aura_avatar.dart` (`_resolveTier`); `MainActivity.kt` / `AppDelegate.swift` `deviceProfile`; `test/device_profile_test.dart` | was: Low only after 2 s of slow frames |
| F3 glow streak, rest days, welcome rest day | done | done | `packages/aura_domain/lib/src/rules/streak.dart`; `contracts/rules/vectors/streak.json` | |
| REQ-STK-01..05 | done | done | `contracts/rules/vectors/streak.json`, `aura_day.json:16` | |
| F3 "Hide streak number" | done | done | `apps/mobile/lib/src/core/prefs/comfort_prefs.dart:18` | |
| ✱ F3 "Longest streak lives only in Insights" | missing | done | `contracts/rules/RULES.md` §7; `streak.json` (3 new vectors); `aura_domain/.../streak.dart`; `server/aura-api/src/rules/streak.ts`; migration `…030_longest_streak.sql` + `supabase/tests/30_longest_streak.test.sql`; `features/insights/insights_screen.dart` `_Lifetime`; `test/insights_screen_test.dart` | hidden with "Hide streak number" (interpretation) |
| REQ-CAP-01..05, 07 | done | done | `features/capsules/capsule_composer_screen.dart:199,775`; `server/aura-api/src/capsules/capsule-rules.ts:14`; `test/capsules_repository_test.dart` | |
| REQ-CAP-06 crisis hold | done | done | `test/checkin_post_save_order_test.dart:161` | |
| REQ-CAP-08 guided prompt in composer | done | done | `features/capsules/capsule_composer_screen.dart:20` | |
| F4 hard-moment gate, "Keep for next time", EXIF strip, deletion count | done | done | `capsule_opening.dart`; `photo_processing.dart:83`; `account/delete_account_screen.dart:206` | |
| F4 date-capsule push "at reminder time or 10 am local" | done | done | `server/aura-api/src/capsules/capsule-unlock.service.ts` | interpretation: 10:00 local (the PRD says "or") |
| REQ-CMP-01..05 | done | done | `features/companion/*`; `test/companion_response_test.dart`; `test/checkin_post_save_order_test.dart` | line pools need native review (A11) |
| REQ-CMP-06 saved-moment order | done | done | `test/checkin_post_save_order_test.dart` | |
| REQ-CMP-07 offline, once per check-in | done | done | `test/companion_response_test.dart:254` | |
| REQ-SAN-01..08 | done | done | `features/sanctuary/*`; `test/sanctuary_*_test.dart` | |
| REQ-ROOM-01, 03–12 | done | done | `server/aura-api/src/rooms/*`; `test/e2e/rooms.e2e-spec.ts`; `test/unit/rooms.matching.spec.ts` | |
| F5 exit survey, join and gesture limits, limit-hit shadow-mute | done | done | `features/rooms/room_controller.dart:1048`; `server/aura-api/src/rooms/gesture-limits.ts:39` | |
| ✱ PRD 19 config: pseudonym word lists per language + offensive-combination blocklist | partial | done | migration `…034_pseudonym_blocklist.sql` + test 34; `src/rooms/pseudonym-blocklist.ts`; `src/admin/pseudonyms.{service,controller}.ts`; `apps/admin/src/app/(console)/pseudonyms/`; `test/unit/admin.pseudonyms.spec.ts` | word lists stay curated in code (interpretation: names are never translated) |
| REQ-SAFE-01 help everywhere | done | done | `core/widgets/help_app_bar.dart:23`; `HelpNowButton`; `test/help_app_bar_test.dart:27` | |
| REQ-SAFE-02 region-aware sheet | done | done | `src/remote-config/helplines.service.ts:36`; `test/unit/helplines.spec.ts:43` | |
| REQ-SAFE-03 lexicon, ≥ 90% recall on 200 phrases per language | partial | blocked on AK | `contracts/safety/crisis_lexicon.v1.json` (en 8, te 5, te-Latn 5 crisis entries); ✱ draft `contracts/safety/candidates/crisis_lexicon.hi.draft.json` (20 hi / hi-Latn entries + 17 cases, not active) + `test/unit/lexicon.candidates.spec.ts` | recall sets and every term need native + safe-messaging review (A9) |
| REQ-SAFE-04 guidelines before first room | done | done | `features/rooms/room_offer.dart:29`; `test/rooms_offer_test.dart:23` | |
| REQ-SAFE-05 report with reasons | done | done | `features/rooms/report_sheet.dart:32` | |
| REQ-SAFE-06 mute and block | done | done | `test/e2e/rooms.e2e-spec.ts:590` | |
| REQ-SAFE-08 strikes, bans, appeals | done | done | `src/reflections/admin-reflections.service.ts:450`; `test/unit/admin.actions.spec.ts` | the in-app appeal: REQ-SAFE-11 |
| REQ-SAFE-10 SLA timers, paging, hold-all | done | done | `src/admin/legal-orders.controller.ts:53`; `src/reflections/reflections.service.ts:251` | paging channels are AK's config |
| ✱ REQ-SAFE-11 Grievance Officer; ticket id within 1 min | partial | done | `features/support/grievance_{api,screen}.dart`; Settings row, closed-account and banned-device rows; `tool/l10n/grievance.py`; `test/grievance_form_test.dart`; contract `contracts/api/v1.md` "Grievances" | was: `mailto:` only; appeals had no in-app path |
| REQ-SAFE-12 health-data handling, disclaimers | done | done | `features/settings/settings_screen.dart`; `test/onboarding_flow_test.dart:140` | |
| REQ-SAFE-15 safe-messaging self-review | blocked on AK | blocked on AK | `contracts/safety/README.md:3` | A9 |
| REQ-ACC-01, 02, 04, 10, 11 | done | done | `features/auth/*`; `test/sign_in_screen_test.dart`; `test/onboarding_dob_test.dart`; `test/account_delete_screen_test.dart` | |
| ✱ REQ-ACC-03 under-13 30-day device lock | partial | done | `features/onboarding/age_gate.dart` (`BlockStoreDeviceLockMirror`); `MainActivity.kt` `com.akvega.aura/device_lock`; `build.gradle.kts` (play-services-auth-blockstore 16.4.0); `test/age_gate_test.dart` | iOS already survived reinstall; Android now mirrors into Block Store. Whether Block Store survives a reinstall on real devices is spike A8 (AK) |
| ✱ REQ-ACC-12 data export (JSON + readable HTML) | missing | done | `features/account/data_export{,_screen}.dart`; `src/account/account-export.ts` (`GET /v1/account/export`); `test/data_export_test.dart`; `test/e2e/account-export.e2e-spec.ts`; contract `v1.md` "Data export" | includes the Insights CSV ("free `[LEGAL]`"); made on the phone (interpretation) |
| REQ-ACC-13 AKVega publisher; regions closed until beta | blocked on AK | blocked on AK | store consoles | |
| REQ-ACC-15 lawyer review before alpha | blocked on AK | blocked on AK | `features/onboarding/trust_screen.dart:52` TODO(legal) | |
| F8 wrong-DOB route, 7-day restore, under-13 confirmed deletion | done | done | `onboarding/blocked_screen.dart:22`; `account/deletion_pending.dart`; `src/admin/admin.schemas.ts:130` | |
| REQ-ADM-01..15 | done | done | `server/aura-api/src/admin/*`; `apps/admin/src/app/(console)/*`; `test/unit/admin.*.spec.ts`; `supabase/tests/13_admin.test.sql`, `16_admin_completion.test.sql` | SSO + paging channels are AK's config |
| F14 daily reminder, date-capsule push | done | done | `src/notifications/reminder.service.ts`; `src/capsules/capsule-unlock.service.ts` | |
| REQ-NTF-01, 02 | done | done | `test/unit/notifications.policy.spec.ts`, `notifications.copy-lint.spec.ts` | |
| Ships: app shell + `/safety` | done | done | `features/shell/app_shell.dart`; `features/safety/safety_center_screen.dart` | |
| Ships: native Apple / Google sign-in, age signals | done | done | `features/auth/social_sign_in.dart`; `features/auth/age_signals.dart` | |
| Ships: English, Telugu, Tenglish | done | done | `lib/l10n/app_te.arb`, `app_te_Latn.arb` | native review (AK) |
| Ships: foundations — PostHog + Sentry | out of scope | out of scope | `wip/analytics-ci` | |
| Exit: "RLS + API tests in CI" | out of scope | out of scope | CI parked; tests run locally | |
| ✱ Exit: "60 fps mid-range, tier drop on low-end" | partial | done | see REQ-AVA-07 | |
| Exit: "a test takedown order pages AK" | done | done | `src/admin/legal-orders.service.ts` | channels are AK's config |
| Exit: TestFlight + Play closed testing | blocked on AK | blocked on AK | | |

## Milestone B — open beta

| REQ / item | Before | After | Evidence | Notes |
|---|---|---|---|---|
| REQ-REF-01..08 | done | done | `src/reflections/*`; `test/unit/reflections.decide.spec.ts`; `test/e2e/reflections.e2e-spec.ts` | |
| REQ-SAFE-07 four-stage pipeline | done | done | `contracts/safety/reflection_filter.vectors.json`; `test/reflections_filter_test.dart` | |
| REQ-SAFE-13 stricter under-18 thresholds | done | done | `src/reflections/decide.ts:17,56` | |
| REQ-SAFE-14 zero tolerance, evidence | done | done | `src/safety/evidence.ts`; `src/reflections/reflection-queue.ts:57` | |
| ✱ REQ-SAFE-16 de-identified corpus, notice, opt-out | missing | done | migration `…031_moderation_corpus.sql` + test 31; `src/reflections/corpus.ts`; hooks in `reflections.service.ts` / `admin-reflections.service.ts`; `GET/PUT /v1/safety/corpus-consent`; `features/settings/corpus_consent.dart`; `test/unit/reflections.corpus.spec.ts`; e2e in `reflections.e2e-spec.ts`; `test/corpus_consent_test.dart`; contract `v1-reflections.md` §7 | privacy notice text is the lawyer's (A2) |
| REQ-GAME-01, 03–09 | done | done | `src/ripples/*`; `test/e2e/ripples.e2e-spec.ts`; `test/ripples_*_test.dart` | |
| ✱ REQ-PAY-01 no RevenueCat / Razorpay / UPI (static scan), PBL 8 | partial | done | `apps/mobile/test/billing_static_scan_test.dart` | `in_app_purchase_android` 0.5.3 = Play Billing 8.0.0 (the PRD's `[STORE: confirm]`) |
| REQ-PAY-02..08, 10, 11 | done | done | `src/billing/*`; `test/plus_*_test.dart`; `test/unit/billing.*.spec.ts` | sandbox matrix: AK |
| REQ-INS-01..07 | done | done | `features/insights/*`; `test/insights_screen_test.dart`; `test/insights_copy_lint_test.dart` | |
| REQ-NTF-03 trial-ending reminder | done | done | `src/user-mail/trial-ending-email.ts`; `test/unit/billing.trial-push.spec.ts` | |
| REQ-NTF-04 wind-down reminder | done | done | `test/unit/notifications.milestone-b.spec.ts:79` | |
| F14 habit nudge, gestures, Lantern Hour, welcome back, crisis follow-up, billing banner | done | done | `features/push/*`; `home/home_screen.dart:31`; `core/entitlements/entitlement.dart:54` | |
| ✱ F14 rule 7 smart timing | missing | done | migration `…033_reminder_smart_timing.sql` + test 33; `src/notifications/policy.ts` (`smartTimingSkip`, `ignoredSoFar`); `delivery.service.ts`; `test/unit/notifications.smart-timing.spec.ts`; contract `v1-notifications.md` | |
| REQ-SAN-09, 10, 12, 13 | done | done | `features/sanctuary/sounds/*`; `test/sounds_*_test.dart` | |
| REQ-SAN-11 offline after one download | partial | blocked on AK | `docs/sounds/licence-log.md:27-36` | recorded stems pending sourcing (A12); procedural stand-ins and brown noise play offline |
| REQ-ROOM-13, 14 lanterns, intention | done | done | `src/rooms/lantern-rules.ts`; `test/unit/rooms.lanterns.spec.ts` | |
| Hindi + Hinglish UI (hidden behind `AURA_BETA_LOCALES`) | done | done | `lib/l10n/app_hi.arb`, `app_hi_Latn.arb`; `test/l10n_hindi_test.dart` | native review + reviewed crisis terms (AK) |
| REQ-ACC-14 EU/UK/AU checklist | blocked on AK | blocked on AK | lawyer (A4) | |
| Exit: realtime load test | done | done | `docs/perf/realtime-load-test.md` | |
| Exit: security review of the NestJS / RPC boundary | done | done | `docs/security/milestone-b-review.md` | residuals below |
| Exit: sandbox trial → paid, refund, grace, cancel | blocked on AK | blocked on AK | | |

## Milestone C — public launch

| REQ / item | Before | After | Evidence | Notes |
|---|---|---|---|---|
| REQ-WID-01..04 | done | done | `ios/AuraWidget/AuraWidget.swift:496,513,120`; `android/.../widget/AuraGlanceWidget.kt:70,299`; `test/widget_*_test.dart` | |
| REQ-SHR-01..06 | done | done | `features/share/*`; `test/share_card_test.dart`; `test/unit/keepsakes.spec.ts` | |
| REQ-QUIET-01..07 | done | done | `src/quiet/*`; `test/quiet_test.dart`; `test/unit/quiet.spec.ts`; `test/rooms_wind_down_test.dart` | |
| REQ-INS-08 Look back | done | done | `features/insights/look_back_screen.dart`; `test/look_back_test.dart` | |
| Hindi/Hinglish rooms (if moderation is ready) | blocked on AK | blocked on AK | flag `rooms_pool_hi` | needs a Hindi-reading moderator or the ≥ 95% recall bar |
| ASO in 5 languages | done | done | `apps/mobile/store/*`; `test/store_listing_lint_test.dart` | drafts; screenshots and review are AK's |
| MASVS L1 | done | done | `docs/security/masvs-l1.md` | F-5 (Universal Links) needs the domain: sweep row |
| Final age rating, Data Safety, privacy labels | done | done | `docs/store/*.md` | submission is AK's |

## Cross-cutting sections (no REQ id)

| Section / item | Before | After | Evidence | Notes |
|---|---|---|---|---|
| 12 quiet hours (+ night-shift confirmation), 2/day cap, discreet mode, provisional iOS auth, 30-day re-ask | done | done | `features/push/notification_prefs.dart`; `push_service.dart:122,138`; `src/notifications/policy.ts` | |
| 13 PostHog events, consent toggle, `acq_source_answered` | out of scope | out of scope | `wip/analytics-ci` | |
| 13 aggregate crisis counters, North Star, under-18 aggregates | out of scope | out of scope | `crisis_events` table exists (`…001_foundations.sql:179`), no writer | Postgres-only, so it could be unparked separately from PostHog |
| 13 `notification_sent` server event | out of scope | out of scope | `src/notifications/delivery.service.ts` TODO(analytics) | |
| ✱ 14 "switch mid-session: New rooms will match you with …" | missing | done | `features/settings/settings_screen.dart` `LanguagePoolNotice`; `tool/l10n/rooms.py`; `test/settings_screen_test.dart` | |
| 14 every other listed state | done | done | `lib/l10n/app_en.arb` keys | |
| 15 permissions (no location / ATT / exact alarms, AD_ID removed, soft asks) | done | done | `AndroidManifest.xml:4-28`; `ios/Runner/Info.plist` | |
| 16 local-first writes, outbox, dead letters, conflict rules | done | done | `core/sync/sync_service.dart`, `outbox_repository.dart` | |
| ✱ 16 delta pulls since a server cursor; two phones' pulls merge | partial | done | `core/sync/pull_service.dart` `pullDelta`; `sync_service.dart` step 5; migration `…032_sync_tombstones.sql` + test 32; `test/sync_delta_pull_test.dart`; `test/sync_service_test.dart`; contract `v1.md` "Pull" | was: one full pull per install; deletes never propagated |
| 17 REQ-A11Y-01..12, 15..17 | done | done | `test/mood_grid_layout_test.dart`, `checkin_contrast_test.dart`, `help_app_bar_test.dart`, … | manual VoiceOver / TalkBack passes and PEAT are AK's |
| ✱ REQ-A11Y-13 correct language for speech | missing | done | `core/l10n/locale_controller.dart` `speechLocaleFor`; `app.dart` builder `Semantics(localeForSubtree:)`; `test/speech_locale_test.dart` | |
| ✱ REQ-A11Y-14 script line height; goldens at 100 / 150 / 200% in te and hi | partial | done | `core/theme/app_theme.dart:16`; `test/a11y_script_rendering_test.dart` + `test/goldens/script_{te,hi}_{100,150,200}.png` (real Noto fonts) | was: layout tests only, no script goldens |
| ✱ 18 "No hard-coded user-facing strings (lint)" | missing | done | `test/no_hardcoded_strings_test.dart`; wordmark now `l.appTitle` (`home_screen.dart`) | |
| ✱ 18 RTL-ready layout, lint-enforced | missing | done | `test/rtl_ready_test.dart`; `features/rooms/room_lantern.dart` | |
| ✱ 18 pseudo-localized build before each milestone | missing | done | `tool/gen_pseudo_l10n.py` (in `tool/gen.sh`); `test/pseudo/`; `test/pseudo_localization_test.dart` | a test run, not a separate app build (interpretation) |
| Security residuals (`docs/security/milestone-b-review.md` §5) | partial | partial | ✱ §5.14: sealed console cookies bound to purpose (`apps/admin/src/lib/seal.ts`, v2 + AAD), `Origin: null` → 403 (`apps/admin/src/lib/origin.ts`); tests `test/seal.test.mts`, `test/origin.test.mts` | still open: §5.6 master-key rotation, §5.9 sandbox entitlements, `__Host-` cookie prefix, prefetch/CSP, §5.1 `NODE_ENV` required; production config items are AK's (see Remaining) |
| ✱ Orphan private-media uploads ("no sweeper yet") | partial | done | `src/media/orphan-sweep.ts` (daily maintenance, 30 days); `test/e2e/media-sweep.e2e-spec.ts`; contracts `v1.md`, `v1-capsules.md` §5 | |

## Sweep: TODO / stub / dead code / stale copy

| Where | Finding | Before | After |
|---|---|---|---|
| `apps/mobile/lib/src/core/sync/pull_service.dart:18` | TODO(sync) delta pulls | partial | done (row "16 delta pulls") |
| `apps/mobile/lib/src/features/avatar/aura_avatar.dart:260` | TODO(perf) Low tier at launch | partial | done (REQ-AVA-07) |
| `apps/mobile/lib/src/core/security/secure_store.dart:31` | TODO(android) Block Store | partial | done in code; A8 spike (REQ-ACC-03) |
| `apps/mobile/lib/src/features/onboarding/trust_screen.dart:52` | TODO(legal) SPDI consent text | blocked on AK | blocked on AK |
| `server/aura-api/src/notifications/delivery.service.ts` | TODO(analytics) `notification_sent` | out of scope | out of scope |
| ✱ `server/aura-api/src/queues/processors.ts`, `queue-names.ts` | `moderation` queue still ran the log-only skeleton | dead code | removed (`processors.ts` deleted; README updated) |
| ✱ `src/capsules/capsules.schema.ts:11`, `contracts/api/v1-capsules.md:72` | "Plus … not built yet, so everyone is Free" (stale) | stale | corrected |
| ✱ `contracts/api/v1.md:235`, `v1-capsules.md:229` | "no sweeper yet" | partial | done (orphan media row) |
| ✱ `src/rooms/pseudonyms.ts:7` | "admin console will own per-language lists later" | partial | done (pseudonym row) |
| ✱ `src/notifications/reminder.service.ts:20`, `contracts/api/v1-notifications.md:96` | "Smart timing … not built" | missing | done |
| ✱ `docs/security/masvs-l1.md` PRIVACY-4 | "Export … not built yet" | missing | done |
| `docs/security/masvs-l1.md:93` | F-5 Universal / App Links | blocked on AK | blocked on AK (domain) |
| `docs/setup/lexicon-and-flags.md:154` | device-ban attestation (DeviceCheck / Play Integrity) | blocked on AK | blocked on AK (keys) |
| `docs/sounds/licence-log.md:27-36` | 8 file stems pending sourcing | blocked on AK | blocked on AK (A12) |
| `docs/design/design-critique.md:185` | real legal / grievance values; native review of new copy | blocked on AK | blocked on AK |

---

## What was fixed (grouped)

**Safety, privacy and compliance**
- **In-app grievance and appeal form (REQ-SAFE-11).** Settings › Help & Safety › "Write to the Grievance Officer", and
  "Ask for a review in the app" on the closed-account and banned-device screens (category `moderation_appeal`). Uses the
  existing public `POST /v1/grievances` (`channel: in_app`); shows the ticket id, the resolve-by date and the GAC appeal
  route; failures keep every word. 33 new strings × 5 locales.
- **De-identified moderation corpus with opt-out (REQ-SAFE-16).** Final decisions (pipeline publish/reject, moderator
  approve/remove) become `text + language + label + ISO week` rows with no link to anyone, text sealed under the DS-1
  envelope; `GET/PUT /v1/safety/corpus-consent` and a Settings switch (on by default per the privacy notice). Never:
  under-18 authors, opted-out authors, crisis text, Minors & grooming items, contact details / links / personal
  questions, held items. Store privacy docs updated.
- **Data export (REQ-ACC-12).** Settings › Account › "Download a copy of my data": HTML + JSON + check-in CSV made on the
  phone and handed to the share sheet; `GET /v1/account/export` adds the server-held records (profile incl. DOB,
  purchases, subscriptions, Plus, Stardust, cosmetics, gifts without counterparts, keepsakes, Sanctuary records,
  consents, guidelines, notification settings, own reflections). No other person's data, no moderation detail; sealed
  capsules stay sealed; works during the deletion grace period and on a closed account. The screen warns the files are
  not encrypted.
- **Under-13 lock on Android (REQ-ACC-03).** Mirrored into Block Store (device-only, date only); either copy keeps the
  lock; expiry clears both.
- **Hindi / Hinglish crisis-lexicon candidates** for review only (`contracts/safety/candidates/…hi.draft.json`), with a
  test that proves they are adoptable and that nothing leaked into the signed baseline. Hindi stays hidden.
- **Console hardening (§5.14):** sealed cookies bound to their purpose (a PKCE cookie can't be a session), `Origin: null`
  on the evidence export → 403 instead of 500.
- **Orphan media sweep:** uploads with no record after 30 days are removed (data minimisation).
- **Pseudonym blocklist in the console (PRD 19 Configuration)**, Owner-only changes, audited without the name.
- **Billing static scan (REQ-PAY-01)**, which also confirms Play Billing Library 8.

**Product behaviour**
- **Longest glow streak** in Insights (rules contract → Dart → TS → DB → snapshot → app).
- **Multi-device delta pull** with server tombstones (PRD 16 sync model).
- **Reminder smart timing** (rule 7).
- **Avatar Low tier at launch** on ≤ 3 GB Android or battery saver, re-checked on resume.
- **Language switch notice** about which rooms new rooms use.

**Accessibility and localization**
- Semantics tagged with the app language for screen readers (REQ-A11Y-13).
- Telugu / Devanagari line-height check and reviewable goldens at 100 / 150 / 200% with the bundled fonts (REQ-A11Y-14).
- Lints as tests (CI is parked): no hard-coded user-facing strings; RTL-ready directional layout.
- Pseudo-localization run: generated accented, ~40% longer catalogue; key screens on a small phone must not overflow.

**Cleanup:** the dead `moderation` queue and its skeleton processors; stale "Plus not built" and "no sweeper" notes.

## Interpretations (where the PRD was open)

1. **Longest streak** follows "Hide streak number" (hidden in Insights too when that is on): the setting exists to take
   streak pressure away.
2. **Corpus exclusions** go beyond the PRD's two (under-18 authors, Minors & grooming): crisis-diverted text (DS-7) and
   rejections for contact details, links or personal questions (the text itself is personal data or a grooming ask)
   never enter it; held items enter only once a human decides. Only the ISO week is kept, never a timestamp; the row
   id is random. The opt-out also works on a closed account (a privacy choice is never locked).
3. **Data export is made on the phone**, not emailed or linked: private text is only decrypted on the device (DS-1), and
   nothing is uploaded or linked. So "within 72 h", "push" and "link valid 7 days" become "right away, in the share
   sheet". Voice notes and photos are listed, not attached (they stay playable in the app). Sealed capsules stay sealed
   (title and unlock only). A signed-in account whose server part can't be fetched gets "The export didn't finish" and a
   retry, never a copy that looks complete but isn't. Reflection states are reduced to published / waiting /
   not_published ("no moderation notes").
4. **Grievance form** pre-fills the account email (editable); nothing typed is stored on the phone.
5. **Delta pull**: a phone's own unsent change wins until sent; a server tombstone always wins (and drops that item's
   unsent mutations); cursors use "≥" so boundary rows are re-read, never missed; tombstones kept 400 days, and a phone
   idle longer re-reads everything and prunes synced rows the server no longer has.
6. **Smart timing** counts a reminder as ignored when no check-in of any kind (live, backfill, widget) reached the server
   after it; the skip happens before the day's push slot is taken.
7. **Low tier**: "≤ 3 GB" is `totalMem ≤ 3.3 × 10⁹` bytes (a "3 GB" phone reports ~2.8–2.9 × 10⁹, a "4 GB" one
   ~3.6–3.8 × 10⁹); battery saver (Android) / Low Power Mode (iOS) also picks Low.
8. **Speech locale**: `te` → Telugu voice, `hi` → Hindi voice, Tenglish / Hinglish → English voice (PRD 17's accepted
   limitation).
9. **Pseudonyms**: the same Latin-letter names serve every language pool (like brand terms, never translated; the DB
   CHECK allows Latin letters only). "Per-language word lists" is met by curated lists reviewed in code plus the
   Owner's live blocklist; a blocked name is never handed out again, but nobody is renamed mid-room.
10. **Block Store** is device-only (`setShouldBackupToCloud(false)`): the lock should not travel to other devices.
11. **Pseudo-localization** is a test run over key screens (check-in, Sanctuary, Settings, Safety Center, grievance
    form, export) rather than a separate app build.
12. **Date-capsule push** stays at 10:00 local; the "at reminder time" option isn't offered (the PRD says "or").

## Blocked on AK

- **Lawyer:** SPDI consent notice and privacy notice incl. the moderation corpus and export (A2, REQ-ACC-15,
  `trust_screen.dart:52`), risk register R1–R7 (A1), POCSO / IT Rules SOP (A3), EU/UK/AU go/no-go (REQ-ACC-14, A4),
  GAC appeal wording.
- **CA:** GST/TDS on store sales (A5).
- **Stores / consoles:** app records under AKVega and storefront availability (REQ-ACC-13), age-rating questionnaire
  (A6), INR price points and the free-month offer (A7), TestFlight / Play testing, the sandbox matrix,
  background-audio review notes and the Play foreground-service video, final Data Safety / privacy labels.
- **Native + safe-messaging review:** crisis lexicon incl. the hi / hi-Latn candidates and 200-phrase recall sets per
  language (A9, REQ-SAFE-03 / 15); companion lines, prompts and grounding copy (A11); all Telugu / Tenglish / Hindi /
  Hinglish copy incl. the new grievance, export, corpus and pool-notice strings; the script goldens.
- **Recordings / assets:** CC0 / royalty-free base stems (A12, REQ-SAN-11), store screenshots, the App Review
  "report actioned" recording, VoiceOver / TalkBack passes, PEAT flash check.
- **Credentials / infra:** production env (`NODE_ENV`, `TRUST_PROXY`, Supabase settings, Firebase key restrictions —
  milestone-b-review §5.1–5.5), secrets custody (§5.7), paging webhooks, SMTP, Apple DeviceCheck key and Play Integrity
  project (device-ban attestation), Android upload key + Play App Signing, the domain for Universal / App Links
  (MASVS F-5), external pen test (§5.16), edge rate limits (§5.12), `aps-environment` check on the archive.
- **Real-device spike:** Block Store persistence across reinstall (A8) — the code is in place.
- **Decisions:** whether sandbox-sourced Plus should expire at public launch (§5.9; App Review needs sandbox to work).
- **People:** first moderator hire plan (A10); screen-reader beta testers.

## Out of scope by decision

- PostHog, Sentry, all behavioural events, the "Help improve Aura" toggle, `acq_source_answered`, aggregate crisis
  counters, North Star and under-18 aggregate counters (parked with analytics on `wip/analytics-ci`).
- CI workflows (parked on `wip/analytics-ci`; the new lints run under `flutter test`).
- Everything in PRD 22 (DMs, replies, voice, stranger letters, RevenueCat, Razorpay, Rive, wearables, web app, extra
  languages, Pathways, narrated wind-down…).
- Texas SB 2420 / PermissionKit for 13–17 (D2, `docs/store/age-rating.md:69`).

## Remaining work that is code but not done here (with a plan)

1. **Master-key rotation (§5.6), large.** `AURA_MASTER_KEY` both wraps keys (user data keys, reflection and corpus row
   keys, evidence text, Apple tokens) and derives HMAC keys (billing `appAccountToken`, install-id hashes, audit subject
   hashes, rate limits, near-duplicate hashes). Rotating it today would break store account linkage. Plan: (a) add
   `AURA_HMAC_KEY` seeded once from the current master's HKDF outputs so HMACs never change; (b) key ids on every
   wrapped blob (`user_data_keys.key_id` exists; add to the others); (c) a re-wrap CLI that walks each table in batches
   under both keys; (d) a runbook (docs/security). About 2–3 days.
2. **Sandbox entitlements (§5.9).** Code is small once AK decides: tag entitlements granted from `environment =
   'Sandbox'` and expire them at a configured date, keeping App Review accounts.
3. **Console `__Host-` cookie prefix and prefetch CSP (§5.14 leftovers).** Needs production-only cookie names (the prefix
   requires `Secure`, which local http development doesn't set) and a Next.js prefetch policy; small, next time the
   console is touched.
4. **`NODE_ENV` required at boot (§5.1).** A one-line schema change, left to AK because it changes how every environment
   must be configured.
5. **Aggregate crisis counters** (analytics plan principle 9) if AK wants them before the rest of analytics: an
   unauthenticated, rate-limited `POST /v1/crisis-events` into the existing `crisis_events` table, no user id, token or
   IP, and a console aggregate. About half a day; parked with analytics for now.

## Verification (this working tree)

- `packages/aura_domain`: `dart test` — 353 passed.
- `apps/mobile`: `flutter analyze` — no issues; `flutter test` — 2,352 passed (5 skipped, as before);
  `flutter build ios --simulator --debug` and `flutter build apk --debug` — built.
- `server/aura-api`: `pnpm test` — 1,500 passed; `pnpm lint` — clean; `pnpm test:e2e` — 322 passed (19 suites).
- `supabase test db` — every file passes, incl. the new 30–34.
- `apps/admin`: `pnpm typecheck`, `pnpm lint` — clean; `pnpm test` — 41 passed; `pnpm build` — built.
- Migrations 20261005000030–34 applied to the local database with `supabase migration up --include-all` (no reset).
