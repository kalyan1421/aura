# First playable universe slice

29 September 2026. Local working-tree prototype, built and exercised on iPhone 16 Pro / iOS 18.0 Simulator. This is the first implementation step toward the public release in [NEXT_RELEASE_PLAN.md](./NEXT_RELEASE_PLAN.md), not a completed release or store submission.

## What works

Open **Your universe** below the Home hero, or from the end of Sanctuary. `/universe` uses Aura's existing router and onboarding/age/update gates. There is no new invitation, paid tier or beta flag for this entry.

The scene is an original geometric island in world coordinates, with perspective projection, directional lighting, depth ordering, a companion and four destinations. Horizontal drags orbit; vertical drags scroll the page. Labelled rotate, zoom and reset buttons provide alternatives. Tap a landmark light or a destination button to move the companion and select its care card. Starting an activity requires its explicit button.

| Place | Existing flow opened | Current world behavior |
|---|---|---|
| Habit Grove | The same `HabitsSection` and editor used on Home | Plants grow from aggregate existing Starlight, including optimistic local progress |
| Tide Pool | Existing breathing setup | Opening does not start a timed session |
| Reflection Garden | Existing private check-in | No separate reflection repository or invented mood record |
| Observatory | Existing Future You capsule list | Existing seal/open/crisis rules remain in that feature |

**Use list view** removes the renderer and keeps all four destinations/actions. Reduced motion snaps the companion to its destination. Backgrounding stops its short travel animation. The scene has no idle animation loop, autoplay audio, camera/microphone use or social presence. The existing device profile selects simpler geometry in power-save/low-memory conditions.

Habits retain their existing local transaction, outbox and sync notification. The renderer receives an aggregate growth amount and presentation coordinates, not habit names, check-in notes, capsule content or account identifiers. It awards no currency, submits no network calls and writes no new database rows. Growth is presentation-only: no per-plant identity, placement or independent reward ledger is persisted. A deletion, correction or server reconciliation can alter the underlying total; missed days and feelings do not create a penalty rule.

The reused habit semantics now explicitly report enabled state. Previously native accessibility inspection described these actionable controls as disabled. Automated semantics checks and Simulator accessibility inspection now show enabled, tappable switches. Physical VoiceOver/TalkBack and Sounds checks remain open under R04.

## Renderer decision and limit

The attempted native renderer was `thermion_flutter ^0.5.0`. Its dependency solver rejected this combination:

- `thermion_flutter >=0.4.0+6` requires `hooks ^1.0.0`.
- Aura's `sqlite3 ^3.6.0` requires `hooks ^2.2.0`.

No override, SQLite downgrade, encryption change or Thermion dependency was added to Aura. The package's iOS build hook recognizes the simulator target, but that alone is not a successful native integration or performance result. Sources inspected: [Thermion package](https://pub.dev/packages/thermion_flutter), [iOS guidance](https://thermion.dev/ios/), [source](https://github.com/nmfisher/thermion).

This slice uses Flutter Canvas to draw projected 3D triangles. `UniverseSceneView` is the replaceable renderer boundary; the world geometry and care flows remain separate. Camera basis and island geometry are cached; the test suite bounds scene complexity and confirms the lower-detail mesh reduces triangles. This renderer uses approximate painter depth ordering, not a GPU depth buffer. Hidden overlapping terrain caps were removed, and the pool has an actual ring opening, fixing artifacts found during visual inspection. More complex/intersecting scenes need a native renderer or a separately measured renderer design.

T01 remains open: resolve the dependency integration without weakening encrypted storage, load a rigged sample, and collect physical-device evidence before selecting the production engine. No physical-device frame-time, battery, memory, thermal or store-release claim follows from this simulator run.

## Art brief for the next stage

All present meshes are original code-created study artwork; no external model downloads, textures or asset licensing obligations were introduced. They are a reviewable visual direction, not a finished asset pack or avatar rig.

- Keep a small floating island with four distinct, readable silhouettes: grove, water, star garden and observatory. Keep the central companion and short connecting paths visible at phone scale.
- Develop the companion from Aura's existing identity. Prepare a small rig with neutral idle/walk and optional celebration; feelings must not determine good/bad appearance. Cosmetics, progression and motion choices stay consistent with existing account rules.
- Export a trial `.glb` with explicit scale/origin, named destination anchors, non-overlapping surfaces and a small material set. Supply standard and low-detail versions and still thumbnails. Test final polygon/texture budgets on target physical devices rather than treating this study as an accepted budget.
- Record creator, source, rights/license, derivative permission, attribution and version/hash for each eventual asset before integration. Include rig clips and export settings in the manifest. None of those final assets has been acquired yet.
- Native language review is required for the new five-locale copy. Current Hindi availability still follows Aura's existing locale review gate.

## Verification

[Targeted tests](./verification/universe-tests.log): **113 passed**, one existing conditional beta-locale test skipped because the beta-locale build define is off. This includes 11 new world tests plus Home, Sanctuary, routing, habits/editor, copy and localization regressions. [Flutter analysis](./verification/universe-analyze.log): **no issues**. `git diff --check` passed.

The new tests cover bounded/monotonic growth, projection/picking after orbit and zoom, camera limits/near clipping, geometry bounds, existing habit writes and resulting mesh growth, enabled habit semantics, horizontal drag and landmark tap, power-save detail changes, backgrounding during travel, breathing/capsule/check-in navigation, and all five locale layouts at 320 dp / 200% text with reduced motion.

Simulator checks opened Home → world, changed orbit and zoom with buttons, tapped a landmark light, observed companion movement, switched list/world views, and opened all four existing care flows. No fabricated check-in/capsule or live habit completion was saved. Habit-write/growth verification used an in-memory test database. The native computer-control service rejected later drag attempts with `noWindowsAvailable`; direct horizontal dragging is verified by the widget gesture test, not claimed as a successful manual simulator drag. Accessibility-tree checks do not replace real screen-reader testing.

- [World preview](./verification/universe-simulator.png)
- [List view](./verification/universe-list-simulator.png)
- [Grove integration](./verification/universe-grove-simulator.png)

## Main source

- [Scene geometry and camera](../../apps/mobile/lib/src/features/universe/universe_scene.dart)
- [Renderer boundary and gestures](../../apps/mobile/lib/src/features/universe/universe_scene_view.dart)
- [World UI and care navigation](../../apps/mobile/lib/src/features/universe/universe_screen.dart)
- [Entry card](../../apps/mobile/lib/src/features/universe/universe_entry.dart)
- [Geometry tests](../../apps/mobile/test/universe_scene_test.dart), [interaction tests](../../apps/mobile/test/universe_screen_test.dart)

## Next implementation steps

1. Resolve T01 and validate a native rigged companion on physical Android/iOS targets. Review this visual direction before commissioning the full asset pack.
2. Implement individual Habit Grove plant mappings and durable world state using the existing authoritative progression; define eligibility/reconciliation before adding any grants.
3. Build Orbit Loom's accessible first game, then optional gentle quests. Avatar customization, richer reflections, permanent decoration and additional games remain planned.
4. Complete release reliability, language/screen-reader, performance and availability gates. The user-selected destination remains a public release for all eligible supported users.
