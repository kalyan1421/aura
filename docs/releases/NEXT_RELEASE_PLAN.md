# Aura next release — public personal universe

Updated 29 September 2026. This is the implementation plan for the next release, building on the [application audit](../audits/2026-09-27-universe/APPLICATION_AUDIT.md), [universe proposal](../audits/2026-09-27-universe/UNIVERSE_PLAN.md) and [market research](../audits/2026-09-27-universe/MARKET_AND_LAUNCH.md).

**Owner decision: public 3D release for everyone**, confirmed 29 September. The universe will be available to all eligible users in supported launch markets. It is not a permanent invitation-only feature or a Plus benefit. Existing account, age and geographic rollout policies continue to determine eligibility. Physical-device limitations need an equivalent accessible activity view, not account-based exclusion from core care tools.

This decision supersedes the earlier proposal's default of a feature-flag beta rollout. Internal testing and release candidates still precede public distribution. No public deployment or store submission has occurred.

## Release promise

**A private pocket world that grows through habits, reflection and mindful play, and welcomes people back after missed days.** A new user should understand the action-to-world connection in their first visit. A returning user should find their world intact. Existing check-in remains immediately available and fast.

The public scope is one explorable island, one customizable avatar, four recognizable destinations, two gentle games, optional quests and a forgiving return experience. The full future universe is a roadmap; this release must feel complete on its own.

## Status at the start of implementation

| Item | Actual status |
|---|---|
| Application/simulator/admin audit | Complete with explicit coverage limits |
| Skill discovery and installation | Three official Flutter/Dart skills installed; details below |
| Stale Rooms presence | Implemented in this working tree; cached cards/links remain but counts and live Lantern labels are suppressed during refresh, failure, offline state or pause |
| Keepsakes recovery | Implemented in this working tree; distinguishes known offline state, network/service failure, sign-in, account state, unavailable build and unexpected failure; keeps cache |
| Account recovery links | Implemented for expired Rooms sign-in and Keepsakes sign-in/account notices where router is available |
| New 3D renderer, island, avatar rig and games | Planned; not yet implemented |
| Public release readiness | Not established; use the exit gates below |

“Implemented” means source changes in this checkout, not a deployed feature. Verification results are recorded in `NEXT_RELEASE_PROGRESS.md`. Earlier user edits to store descriptions are separate from these changes.

## The public feature set

| ID | Feature | What ships | Acceptance criteria | Dependencies |
|---|---|---|---|---|
| U01 | Personal island | Real 3D diorama, orbit camera, tap-to-travel paths, four labelled landmarks | Discover destinations without instruction; exit freely; no joystick required; same activities available in list view | R01–R04, T01–T03 |
| U02 | Avatar | Existing Aura identity translated into a simple rig, idle/walk/celebration states, small cosmetic selection | Recognizable on phone; no animation tied to “good” versus “bad” feelings; existing progression remains authoritative | T02–T04, D01 |
| U03 | Habit Grove | Existing habits map to selected plants; a qualifying completion produces one understandable growth step | Offline action reconciles exactly once; retries cannot farm growth; missed days never destroy plants | D01–D03, existing F2 |
| U04 | Reflection Constellation | Choose a star shape after reflection; optionally attach a private moment reference | Writing optional; no bonus for intimate disclosure; all feelings equal; private text absent from scene telemetry | D02–D04, existing F1/F6 boundaries |
| U05 | Breathing Tide Pool | Spatial entry to existing breathing and grounding; clear pause/exit | Help always reachable; no completion required to leave; reduced-motion equivalent | U01, existing F15 |
| U06 | Future You Observatory | Capsule landmark opens existing capsule list/composer/opening flows | No unlock-rule changes; sealed content never reaches renderer; existing crisis/capsule order preserved | U01, existing F4 |
| U07 | Orbit Loom game | Forgiving star arrangement, tap and drag modes, optional neutral meaning prompt | No timer pressure/score; finish without drag precision or writing; can exit at any stage | T03, D02–D04 |
| U08 | Tide Garden game | Petals follow a gentle visual rhythm; tap freely or choose automatic motion | No microphone; no claims to measure calm or breathing; still-mode outcome equal; clear audio controls | T03, existing F15 |
| U09 | Gentle quests | One optional handcrafted invitation at a time, composed of existing care activities | No deadline/FOMO, obligation, loss or daily completion gate; no repeated reward exploit | D01, U03–U08 |
| U10 | Effort choice | “Something tiny / a little more / just explore” | Choice is voluntary, editable and not inferred from mood or health; explore requires no checklist | U01, existing Home |
| U11 | Welcoming return | Friendly return after absence, intact world, resume/tiny/explore options | No guilt copy, dead plants or lost cosmetics; compatible with rest and hide-streak preferences | D01, existing F3 |
| U12 | Decoration and layout | Place a limited set of owned objects at validated positions | Save/restore after account recovery; no cross-account data leak; supported asset IDs only | D02–D03, T02 |
| U13 | Accessible universe | Flat destination view, labels outside GL, large text, screen reader, reduced motion, independent sound | Core care tasks and outcomes equivalent; no tiny-object/colour-only interaction; graceful unsupported-renderer path | All U features, T05 |
| U14 | Optional postcard | Preview a sanitized composition selected by the user, then invoke existing sharing | No default mood, habit name, note, date, identifier or private world geometry; no auto-upload or forced referral | D04, existing F13 |
| U15 | Product measurement | Consent-aware aggregated activation/return/meaningful-care cohorts | Existing youth exclusion honored; no private content; founder can compare channel cohorts | O03, policy decision |

The destination list provides Breathe, Habits, Reflect and Future You even when a scene cannot load. Check-in and global help sit in ordinary Flutter controls. The 3D world enhances the experience without becoming a prerequisite for saving personal data.

## Complete implementation backlog

Estimates below are engineering effort ranges, not delivery dates. They exclude waiting for art, device access or specialist review. Tickets are ordered by dependency, not excitement.

### Reliability and daily UI

| Ticket | Work and completion condition | Estimate | Status |
|---|---|---|---|
| R01 | Rooms freshness: remove visual and semantic live counts from stale cards; preserve links; successful refresh restores counts | 0.5–1 day | Implemented; regression tests added |
| R02 | Keepsakes typed recovery: cache retained across offline, 401, 5xx, account and unexpected failures; useful retry/sign-in action | 0.5–1 day | Implemented; regression tests added |
| R03 | Reconcile app/API/admin environment references; verify expected deployment identity and callback URLs; update environment matrix | 0.5–1 day plus deployment access | Planned |
| R04 | Verify habit/sound enabled semantics on VoiceOver/TalkBack and correct confirmed defects | 0.5–1 day plus device validation | Partial: habit enabled semantics fixed; device/sound checks open |
| R05 | Home invitation and compact progress hierarchy; keep first care action/check-in/help immediately visible | 1–2 days | Planned |
| R06 | Compact Sanctuary destinations; remove duplicate activity placement; direct Sound/Future You access | 1–2 days | Planned |
| R07 | Coherent free-launch presentation while Plus billing disabled; no unavailable purchase CTA | 0.5–1 day | Planned |

### Renderer, assets and games

| Ticket | Work and completion condition | Estimate | Status |
|---|---|---|---|
| T01 | Evaluate Thermion/Filament against exact Flutter/OS targets using one rigged sample; capture physical-device performance/lifecycle evidence | 3–5 days | Compatibility spike found hooks conflict; native integration/device evidence open |
| T02 | Asset brief: island, rigged companion, landmarks, limited props; source/license ledger, export settings and version manifest | 1–2 engineering days; art estimate separate | Initial study/brief in UNIVERSE_PROTOTYPE.md; final assets/manifest open |
| T03 | Scene adapter, hit targets, camera rails and Flutter overlay; scene emits intents to repositories; no direct database access | 3–5 days | Canvas prototype implemented; production native adapter pending T01 |
| T04 | Avatar states and world-change animations driven from reconciled view state; replay is cosmetic | 2–3 days | Planned |
| T05 | Render failure/static fallback, lifecycle release, asset-load retry and reduced-detail settings | 2–3 days | Partial: list view, reduced detail/motion and travel lifecycle; native load/retry open |
| T06 | Orbit Loom interactions, accessible tap/auto-arrange paths and exit behaviour | 2–3 days | Planned |
| T07 | Tide Garden interactions, still/automatic modes and pause/audio handling | 2–3 days | Planned |

### Data, progression and privacy

| Ticket | Work and completion condition | Estimate | Status |
|---|---|---|---|
| D01 | Define exact grant eligibility and reward caps; reuse existing grants where possible; change contract/vectors before any new progression rule | 1–2 days | Planned |
| D02 | Contract for private world layout, cosmetic placement, constellation tokens and encrypted entry references; define migration/conflicts/tombstones | 1–2 days | Planned |
| D03 | Server/DB/RLS and Flutter sync support; offline replay, duplicate operations, account switch, recovery, export and wipe tests | 3–5 days | Planned after D02 |
| D04 | Minimize renderer state; prevent note/capsule content in logs; sanitized explicit sharing preview | 1–2 days | Planned |
| D05 | Hook eligible care actions to Grove/Constellation; never double-award for one action appearing in several destinations | 2–3 days | Planned after D01–D03 |
| D06 | Quest/return/effort state with defined private persistence; preferences respected; no new public profile | 2–3 days | Planned |

### Operations, research and release

| Ticket | Work and completion condition | Estimate | Status |
|---|---|---|---|
| O01 | Admin grouped narrow navigation and urgent item layout; retain role/MFA checks and desktop keyboard flow | 1–2 days | Planned |
| O02 | Now health summary: environment, pager delivery readiness, worker freshness, last drill and export status; verify staging paging drill | 1–2 days plus configuration | Planned |
| O03 | Explicit analytics scope and event contract; consent handling/youth exclusion; separate product dashboard from moderation Stats | 2–3 days after policy decision | Planned |
| O04 | Ten concept interviews and five observed prototype sessions; adjust usability before asset lock | 7–10 elapsed days | Planned; owner/research activity |
| O05 | Release candidate: physical iOS/Android journeys, crash/lifecycle/offline checks, accessibility, asset licence review and regression suites | 3–5 days plus tester availability | Planned |
| O06 | Real screenshots/demo, accurate store descriptions, supported-market list, support route and versioned release notes | 1–2 days plus store review | Planned |
| O07 | Public distribution and rollback drill; verify core care tools remain reachable if scene is disabled | 0.5–1 day plus store review | Planned |

All open tickets remain visible. A code-only completion is insufficient for a ticket whose acceptance requires physical devices, commissioned assets or operational configuration.

## Architecture and engine decision

Keep Riverpod and the existing repository structure. A new skill's generic ChangeNotifier/MVVM recommendation is not a reason to migrate this working app. Core progression belongs in `packages/aura_domain`, cross-stack rules in `contracts/rules`, server verification in `server/aura-api`, personal storage/sync in the existing Flutter/Drift boundary.

Thermion is the first engine candidate because it integrates native 3D with Flutter. It is not selected for production until T01 passes. Unity integration is a contingency if measured requirements exceed the simpler adapter; it needs its own memory/lifecycle evaluation. A WebView rendering stack is not the default for the native release. [Thermion](https://thermion.dev/), [Unity mobile integration constraints](https://docs.unity.com/en-us/engine/6000.3/manual/platform-specific/cross-platform-features/unityasa-library).

World view state includes public-to-the-renderer cosmetics and geometry only. User intents call existing services/repositories. Private writing remains encrypted and never becomes engine telemetry. Do not put new personal layout state in a device-only preference cache as a shortcut: it requires explicit recovery, export, deletion and account boundaries.

During offline use, ordinary care actions use existing local-first flows. If new grants are introduced, their provisional and reconciled states must be defined. Cosmetic animation may occur provisionally; persistent unlocks must follow the authoritative ledger. Backfills and repeated game play do not silently become new reward sources.

## Preserve all existing feature families

The handbook lists F1–F16 as broadly built. That inventory is context, not fresh release certification. Each family needs a regression check when the new world redirects entry points.

| Existing feature | Next-release treatment and required check |
|---|---|
| F1 Check-in | Keep two-tap path outside world; private details, edits, backfill and save-before-effects order still work |
| F2 Avatar/habits | Reuse habits and authoritative progression; 3D is an alternate presentation, not a second ledger |
| F3 Streak/rest | Respect hide-streak and rest behaviour; no plant loss or guilt on return |
| F4 Capsules | Existing sealing/unlock/media/crisis gates unchanged; Observatory navigates to these flows |
| F5 Rooms | Reliability fix now; public social access remains controlled by existing room readiness and safety rules |
| F6 Reflections | Distinguish private constellation meaning from moderated room reflections; never copy room messages into a private entry automatically |
| F7 Breath Ripples | Keep existing shared breathing; Tide Garden does not claim verified breath activity |
| F8 Account/age | Preserve age gate, sign-in, encrypted recovery, export and deletion; add new world entities to export/wipe |
| F9 Safety/admin | Help outside engine; no scene text replaces established support routing; paging readiness verified |
| F10 Insights | Existing calendar/history stays available; new world does not invent mood insights |
| F11 Native widget | Existing habit/check-in quick actions still work with app closed; no widget launches requiring a heavy world to save |
| F12 Billing | No paid gate for public universe; purchases remain off unless a separate billing decision and readiness work is completed |
| F13 Share/keepsakes | Correct error recovery; keep explicit preview/sharing and private earned seals |
| F14 Notifications | Existing reminder/privacy rules; no “your world is dying” push or quest FOMO |
| F15 Sanctuary | Direct care access plus world landmarks; replace placeholder audio only with licensed reviewed recordings |
| F16 Quiet Together | Preserve existing sessions; public shared-world expansion is a later product, not implied by the personal island |

## Ideas planned after this release

All ideas are accounted for below rather than left as vague “more features.” They are not promises for the immediate public build.

| Idea | Trigger for scheduling | Reason to sequence later |
|---|---|---|
| Additional islands/planets and biomes | The first island has useful repeat care and users ask for exploration | More environments multiply art/device/download cost |
| Shared 3D clearing with guests | Private world stable; moderation, public identity and anti-fingerprinting contracts reviewed | Actual private layouts can reveal habit/mood patterns |
| Co-op quests | Existing social safety/ops proven; no coercive dependency on friends | Avoid punishing solo users or missed partner sessions |
| Sound Garden | Two launch games reused; licensed audio available | Creative audio value requires quality assets and lifecycle work |
| Pebble arrangements | Users want calm tactile variety | Reuse engine interaction foundations rather than a broad launch catalogue |
| Memory Trail | Users intentionally create and revisit private tokens | Avoid automatically resurfacing sensitive memories |
| Comet focus journeys | Demand from study/focus cohort | Timer/background behaviour must work with renderer stopped |
| More avatar types | Research identifies preferences and asset capacity exists | Rig/accessibility/art maintenance per avatar |
| Long-project support | Research confirms short habits don't meet this need | Needs an explicit task/project model, not unlimited habit checkboxes |
| Real-world “scan and play” | Owner defines what is scanned and the intended user benefit | No inferred permission to read other computer apps, camera feeds or private content; design the exact data flow first |
| Trading, open chat, user-created worlds | New business/safety decision | Adds economy, abuse, moderation and privacy scope beyond a personal-care release |

## Build order and schedule

1. Finish R01/R02 verification and R03/R04 investigation; complete concept brief and engine spike.
2. Lock minimal asset specifications and world data/progression contracts.
3. Build island/avatar plus direct existing care destinations and accessible fallback.
4. Implement both games and connect eligible activities to deduplicated world growth.
5. Add optional quests, effort choice, return and sanitized sharing; complete admin readiness/product measurement.
6. Test a release candidate on physical platforms, repair failures, then distribute the same public feature set to eligible users.

Allow roughly **8–14 elapsed weeks** for a solo engineer with suitable art assistance and timely device/research access. This is a planning range derived from the ticket scope; it is not a deadline or a promise. Engine/asset failure changes the estimate. Ongoing operations and review time sit outside pure implementation effort. Internal volunteer tests can happen throughout; the chosen product distribution remains public.

## Public release exit gates

- Complete first visit and return journeys, including after missed days and while offline. Quick check-in/help remain reachable.
- Define and verify performance targets from the universe proposal: 30fps low tier, 60fps where suitable, measured memory/load budgets and no background rendering. Treat those numbers as targets until measured; tune art before raising device requirements.
- Confirm stable renderer enter/exit, background/resume, audio interruptions, failed asset load and unsupported-device fallback on physical iOS and Android.
- Pass domain/server rule vectors where rules change; sync/RLS/export/wipe checks for new entities; relevant Flutter, native and admin regressions.
- Verify VoiceOver/TalkBack, 200% text and reduced-motion flows. Human review new translated copy before store submission.
- Verify intended production URLs, auth callbacks, environment secrets/configuration and operational paging in a controlled environment.
- Keep product metrics consent-aware and under-18 exclusion intact. Record real crash/activation denominators; do not infer mental-health outcomes.
- Use real screenshots and a supported-market list. All shipped claims must match the build; no promised multiplayer or games still on the backlog.
- Have a rollback path that disables a failing scene while retaining ordinary care tools and personal data. An emergency reliability switch is compatible with public availability; it is not an invitation-only product strategy.

The earlier 25% D7/60% activation suggestions are research targets, not automatic guarantees or universal public-release rules. Use them to identify poor value/usability; do not declare market validation from a tiny sample.

## Skills installed for this work

Installed at user level in `/Users/kalyan/.codex/skills/`, using the Codex installer after checking the leaderboard, searching the Skills CLI, verifying the source repository and reading the candidate instructions. They will be available through the normal skill catalog on the next turn. Their instructions were also reviewed for this work.

| Skill | Purpose | Search snapshot, 29 Sep | Source |
|---|---|---|---|
| flutter-build-responsive-layout | Responsive world overlays and equivalent activity view | Approximately 37K installs | [Skill](https://skills.sh/flutter/agent-plugins/flutter-build-responsive-layout) |
| flutter-add-widget-test | UI interactions, stale/recovery states, accessibility regressions | Approximately 34.3K installs | [Skill](https://skills.sh/flutter/agent-plugins/flutter-add-widget-test) |
| dart-add-unit-test | Repository failures, offline deduplication and future domain rules | Approximately 10.4K installs | [Skill](https://skills.sh/flutter/agent-plugins/dart-add-unit-test) |

Official source: [flutter/agent-plugins](https://github.com/flutter/agent-plugins), approximately 3,004 GitHub stars at inspection. Popularity is one signal; the relevant instructions and fit were inspected. Counts are snapshots, not permanent facts.

Reproduce installation for missing skills with:

```sh
python3 /Users/kalyan/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --repo flutter/agent-plugins \
  --path skills/flutter-build-responsive-layout skills/flutter-add-widget-test skills/dart-add-unit-test
```

Existing skills already cover UI audit, NestJS/Next.js review, database guidance, launch planning and image direction. The inspected Unity/Unreal game skill was not installed because its mandatory engine-specific workflow does not match the Flutter scene adapter. No broad skill update, unknown executable, new connector or new permission grant was needed.

## Implementation update — 29 September

The first local 3D slice is now built. [UNIVERSE_PROTOTYPE.md](./UNIVERSE_PROTOTYPE.md) records its scope, the Thermion/SQLite dependency conflict, original study-art brief, tests and simulator evidence. This does not mark U01–U15 complete: U01 is a working prototype, U02 is a geometric stand-in, U03 uses aggregate Starlight rather than individual durable plant mappings, and the other destinations reuse existing care flows. Games and the public-release gates remain planned.

## Revision 29 September (audit) — decisions and corrections

Result of the plan/codebase audit and the owner's answers the same day. This section supersedes earlier rows where they disagree.

### Owner decisions recorded

| Question | Decision |
|---|---|
| What does "failing" mean? | **Reversible, opt-in decay.** Missed *commitment* habits dim, wilt and go dormant in the world. One log restores them. Starlight, glow days, streak, rest bank and keepsakes never drop. The PRD line "never dies or regresses" is unchanged for the ledger and the avatar. |
| What is the "real world"? | Free-roam 3D **and** tap-to-travel island; real-life data (HealthKit steps/sleep, local time/daylight) as a later bridge. **AR is out.** GPS/physical location is **deferred**: not in scope until separately decided (permission, privacy and DPDP cost). |
| Avatar | **Celestial first, 3D-ified**; customizable humanoid body forms later (PRD P2, high priority). |
| Renderer | Re-open T01 with `flutter_scene` (below). |

Pending owner defaults, recorded so they are not silent: decay is **not available under 18** (`decayEligible`); decay is **never** applied to mood check-ins, only to habits the person marks as commitments; rest days do **not** bridge vitality (the stakes are the person's own choice).

### Audit findings that change the plan

1. **Aggregate growth is not a habit tracker.** The prototype grows the island from `log(1+Starlight)/log(1001)`: half grown after roughly three maximum days, then nearly flat. It cannot show *this habit* or a missed one. Replace with per-habit world objects (RULES.md §13: `growthStage`, `habitVitality`), a pure device-side view of habit logs. **Implemented as a contract + Dart + TypeScript, with 34 shared vectors; no UI, schema or sync change yet.**
2. **The data model has no "missed".** Habits are binary with six presets and three custom slots. Decay needs a per-habit *commitment* (`committedFrom`, `pausedThrough`); that per-habit choice *is* the opt-in, so no separate global setting is stored (only the age gate). That is new personal data and needs D02/D03 (contract, server, RLS, sync, export, wipe) before any UI. Not started.
3. **The art estimate is missing.** The 8–14 week range excludes 3D art, the largest cost. A rigged celestial avatar, island and props need a source/licence ledger and a separate budget (T02).
4. **Locked decision to amend deliberately.** "Art is procedural code, no Rive" was written for 2D. `.glb` assets are a new pipeline; record the amendment in the PRD before commissioning art.
5. **3D is not a Plus lever.** Public availability for everyone removes the obvious way for 3D to earn. Revenue paths are cosmetics (₹10–99) and Plus's existing benefits. The PRD's own model gives roughly ₹0.70–1.75 per monthly active user per month at 2–5% conversion.
6. **Rooms are the largest operational risk**, not 3D: strangers, a mixed 13+ pool, a single moderator, and the DPDP minors rule from 13 May 2027. Consider a limited Rooms launch.

### T01 update: `flutter_scene` replaces Thermion as the candidate

Run in a scratch copy of the repo; the repository's `pubspec` files were not changed.

| Check | Result |
|---|---|
| Resolve `flutter_scene ^0.23.0` against Aura's `sqlite3 3.6.0` / `hooks 2.2.0` | Resolves; `sqlite3` and `hooks` unchanged |
| Side effects of resolving | `code_assets` 2.1.0→1.2.1, `native_toolchain_c` 0.19.5→0.19.3, `objective_c` 9.6.0→9.5.0 |
| iOS simulator debug build (full app, SQLite3MultipleCiphers) | Builds; `sqlite3mc.framework` bundled with cipher symbols |
| Android debug build (full app) | Builds; `libsqlite3mc.so` in arm64-v8a, armeabi-v7a and x86_64 |
| Size signal | `flutter_scene` shader bundles add about 10.6 MB uncompressed to the debug APK. Release size and per-ABI splits are unmeasured |
| Rendered scene (iOS Simulator, iPhone 16 Pro, debug) | A built-in sphere and a loaded `.glb` (animation clip parsed) draw with PBR lighting on Impeller/Metal with Flutter GPU enabled: [screenshot](./verification/flutter-scene-spike-ios.png). Simulator only; the model is cropped by the test camera, and no skinned rig was tested |
| Flutter GPU | Needs `FLTEnableFlutterGPU` (iOS `Info.plist`) and `EnableFlutterGPU` (Android manifest); Impeller required |

Still open: rendered-scene evidence on Android and on physical iOS and Android devices; a skinned, animated rig (the sample has a morph animation, no skin); frame time, memory, battery and heat; behaviour on a 3 GB Android device (the PRD low tier); release-mode builds; the full test suite with the three downgraded build tools; and the package's own stability (pre-1.0, "early preview", breaking minor releases). Adopt only after those pass; keep the Canvas renderer behind `UniverseSceneView` until then.

### New and re-ordered tickets

| Ticket | Work | Status |
|---|---|---|
| W01 | World rules: per-habit `growthStage`, opt-in `habitVitality`, `decayEligible`; spec in RULES.md §13, shared vectors, Dart and TS | **Done** (rules only) |
| W02 | Commitment data: per-habit `committedFrom`/`pausedThrough`; contract, migration, RLS, sync push, pull, export, wipe, tombstones; never under 18 | **Done (data layer, no UI).** Migration `…36`, server validation (`commitment_not_available`, `invalid_commitment`), DB backstop trigger, app schema v6 + `HabitRepository.setCommitment/pauseCommitment`, pull, JSON export. The editor toggle and pause control are W03 |
| W03 | Per-habit plants in the existing Canvas island using W01; decay visuals; editor toggle and pause; warm copy in five locales | **Done (first pass).** One plant per shown habit (stage by distinct logged days; vitality only changes colour and how high the crown sits; nothing disappears). Accessible plant list in the Grove card. Adults-only **Commitments** section in the habits editor (switch + pause menu). A server refusal is undone locally. Copy in en/te/te-Latn/hi/hi-Latn is a first draft and **needs native review**. Screenshot: [world-grove-plants.png](./verification/world-grove-plants.png) |
| W04 | Recovery: one log restores; "welcome back" moment; no guilt copy | Partly done: one log restores a plant at once (tested end to end). The explicit "welcome back" moment is still open |
| W05 | Free-roam camera/joystick as an optional mode; tap-to-travel stays the default; flat list equivalent | Planned (needs T01) |
| W06 | Real-life data bridge: HealthKit steps/sleep and local daylight; permission copy and privacy review | Planned, after W03 evidence |
| W07 | Product measurement for decay: retention of commitment users vs non-commitment users; guardrail "uninstall within 24 h of a decay state" | Planned |

### Recommended order (business)

1. **Ship v1.0 as built** (Plus off, free) and measure D1/D7/D30 with the PRD's existing kill signal: D30 under 6% means fix the core loop before paid acquisition or heavy 3D spend.
2. **Test the world hypothesis cheaply** with W02–W04 on the existing Canvas island. If commitment users return more, invest in the native renderer, the rigged avatar and free-roam (T01–T04, W05).
3. **Decide the market before the art**: India-regional first, or global English. It sets pricing, marketing and whether Finch is the direct competitor.
4. Split the universe work onto its own branch before further code lands; it is currently uncommitted alongside the l10n and Rooms fixes.

### Tooling fix found during W03

29 UI strings from the earlier recovery and personal-universe work (23 `universe_*`, 5 `keepsakes_*`, 1 `rooms_*`) had been written straight into the ARB files and never reached the generator (`tool/l10n`). The next `bash tool/gen.sh` would have silently deleted them. They now live in `tool/l10n/recovery.py`; regenerating reproduces the previous ARB files exactly in all five locales, and W03 copy lives in `tool/l10n/world.py`. Add future strings to a `tool/l10n` fragment, never to the ARB files.
