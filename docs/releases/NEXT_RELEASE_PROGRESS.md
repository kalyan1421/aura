# Next-release implementation progress

29 September 2026. Working-tree changes; no commit, deployment or store submission.

## Completed now

- **R01 — accurate Rooms presence.** The Rooms tab and Home strip retain cached room links while refresh fails or runs, but stop showing live counts. Connectivity/readiness/pause state also suppresses those counts. Stale semantic labels and Lantern Hour claims are removed. Successful refresh restores the counts. Failed loads no longer establish an empty-room state.
- **R02 — Keepsakes recovery.** Known offline state skips the request. Network/service failures, expired sign-in, account restrictions, unavailable configuration and unexpected exceptions have separate results. All preserve the existing cache. Retry is offered for retryable failures; sign-in/account notices navigate to the corresponding screens. A failed first fetch no longer labels the collection empty.
- **Rooms sign-in recovery.** A 401 notice offers sign-in when the app router is present.
- Added recovery copy across all five locale catalogues and regenerated Flutter localization and pseudo-localization output. Human language review remains a release requirement.
- Installed three official Flutter/Dart skills and documented the complete public-release scope in [NEXT_RELEASE_PLAN.md](./NEXT_RELEASE_PLAN.md).

## Main source changes

- [Rooms tab](../../apps/mobile/lib/src/features/rooms/rooms_home_screen.dart), [Home rooms strip](../../apps/mobile/lib/src/features/rooms/your_rooms_strip.dart), [Rooms recovery](../../apps/mobile/lib/src/features/rooms/room_status.dart).
- [Keepsakes repository](../../apps/mobile/lib/src/features/keepsakes/keepsakes_repository.dart), [provider](../../apps/mobile/lib/src/features/keepsakes/keepsakes_providers.dart), [screen](../../apps/mobile/lib/src/features/keepsakes/keepsakes_screen.dart).
- [Rooms regressions](../../apps/mobile/test/rooms_home_test.dart), [Keepsakes regressions](../../apps/mobile/test/keepsakes_test.dart), [navigation checks](../../apps/mobile/test/recovery_navigation_test.dart).

The network result means a connection/timeout/service/rate-limit failure; it does not assert that the device is offline. Only a known disconnected state uses the offline result. Account-restriction text does not bypass the existing account rules.

## Verification

The targeted suite spans Rooms home/screen/offers/remote flags, Keepsakes/recovery navigation, copy lint, Hindi localization, pseudo-localization and hard-coded-string checks. Its clean run passed **102 tests**, with **one pre-existing beta-locale conditional test skipped** because `Env.betaLocales` is off. This is not an ignored failure.

After the final empty-state refinement, **17 Keepsakes/navigation tests passed** and Flutter analysis again reported **no issues**. These 17 checks overlap the main suite and should not be added to its total as distinct tests. `git diff --check` also passed.

Verification logs: [main suite](./verification/mobile-tests.log), [final cache/navigation checks](./verification/recovery-tests.log), [Flutter analysis](./verification/mobile-analyze.log).

Checks explicitly cover cached success → failed refresh → successful recovery, retained cached keepsakes across failure kinds, no request when known offline, and actual navigation to sign-in/account screens. No backend schema/progression rule changed, so server and database suites were not rerun for this UI/repository change.

## First 3D slice built

A local universe now opens from Home and Sanctuary. It contains a perspective island, geometric companion, horizontal orbit, zoom/reset controls, landmark picking and four destinations that reuse the existing habits, breathing, private check-in and capsule flows. There is an equivalent list view, reduced-motion travel, lower-detail device profile and background handling. Aggregate existing Starlight grows the Grove's plants; individual habit-to-plant mappings and durable world state are not built yet. No new progression rules, personal tables or grants were introduced.

**R04 partial:** actionable habit semantics now explicitly report enabled state. A regression verifies enabled/tap/toggle semantics; Simulator accessibility inspection confirms the controls are no longer described as disabled. Sound controls and physical screen readers remain unverified.

**T01 compatibility finding:** Thermion 0.5.0 requires hooks 1.x while Aura's SQLite requires hooks 2.x. The native candidate did not resolve. No database/security downgrade or dependency override was made. This first slice projects 3D meshes through Flutter Canvas behind a replaceable renderer boundary. T01 still requires successful native integration and measured physical-device evidence.

The final new/affected suite passed **113 tests**, with one existing beta-locale conditional skip. Flutter analysis and `git diff --check` passed. Simulator interaction opened all four care flows and exercised camera buttons, landmark picking and list fallback. Live personal records were not fabricated; growth writes were tested against an in-memory database.

[Implementation, art brief and verification limits](./UNIVERSE_PROTOTYPE.md), [tests](./verification/universe-tests.log), [analysis](./verification/universe-analyze.log), [preview](./verification/universe-simulator.png).

## What remains

The public release is not ready. Native renderer integration, final rigged avatar/art, persistent per-plant growth, games, quests, customization and the remaining release gates are still work ahead. Start with the T01 compatibility/device spike and the Habit Grove data contract; do not treat the current study art or simulator performance as a production decision.

Existing user edits in the Android store descriptions and existing untracked `.claude/`, handbook and admin guidance files were preserved. Skill installation is user-level and does not add app dependencies. No authentication setting or permission was weakened.
