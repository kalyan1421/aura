# Aura application and UI audit

Observed 27 September 2026; report completed 28 September. Baseline `faca132`.

## Assessment

Aura has substantial working foundations: a coherent night-sky visual language, local care activities, protected private writing, capsules, a mature-looking moderation console, and extensive automated checks. Its strongest emotional material is distributed across separate screens. The current Home reads mainly as a companion plus progress dashboard; Sanctuary reads as a catalogue. Neither yet delivers the explorable personal world the owner wants.

The immediate priority is clearer availability and recovery, then a stronger daily experience, then 3D. Adding a world before correcting misleading connection states would make the same confusion more expensive to maintain.

Evidence labels used below:

- **Observed:** directly seen in the running app or local admin.
- **Code:** confirmed by source inspection.
- **Documented:** asserted by the handbook or prior audit, not independently demonstrated here.
- **Proposal:** a design/product judgment to validate.

## Test environments and coverage

The iOS simulator was already installed, onboarded and signed in. It was an iPhone 16 Pro running iOS 18.0. The generated build configuration named `https://aura-api-3ht9.onrender.com` as its API. This was an existing installed build; there was no clean rebuild/reinstall proving its binary exactly matched HEAD. The source review and automated tests used `faca132`.

The local admin was Next.js at `http://localhost:3320`, using the local NestJS API at port 3310 and local Supabase at port 55521. The existing owner test account was used with the normal OTP and MFA flow; no new staff account or access grant was created. Local report counts, ages, flags, and paging history are test-environment observations, not production incident metrics.

| Surface or flow | Result and scope |
|---|---|
| Home | Inspected companion, progress, room chip, streak and habit layout. Did not change the signed-in user's habits |
| Check-in | Opened from Rooms, selected Calm, expanded details, inspected tags/note/voice controls, verified discard confirmation and returned to Rooms without saving |
| Saved moment | Covered by existing automated tests; not saved against the live account in this audit |
| Sanctuary | Inspected hub and activity entries; observed deep placement of Sounds and Future you |
| Breathe | Started the one-minute Calm rhythm, paused successfully, exited |
| Sounds | Rain changed from off to playing with volume control; Stop returned it to Nothing playing. Acoustic quality/background playback not evaluated |
| Rooms | Observed connection error, retried, opened cached room and reached recovery screen. Live gestures, matching and reflections not verified |
| Insights | Inspected calendar, insufficient-data state, all-time counters and visible Plus explanation |
| Safety | Opened from failed Rooms; help content and breathing entry available. Did not place calls or independently validate phone numbers |
| Settings | Inspected language, comfort and account entries; did not change persistent preferences |
| Keepsakes | Inspected empty/offline state |
| Capsules | Inspected empty state and composer, date/feeling choices, note/photo/voice affordances. Did not seal, open, upload or delete a capsule |
| Admin | Inspected all 18 main sections: Now, Queue, Reflections, Sanctions, Mandatory reports, Grievances, Deletion cases, Legal orders, Paging, Audit log, Kill switches, Lexicon, Helplines, Intentions, Pseudonyms, Device bans, Staff, Stats |
| Admin responsiveness | Observed default narrow width, 1280px desktop and 390px phone viewport; restored viewport override afterwards |

Native simulator scroll/drag automation intermittently returned `noWindowsAvailable`; that is a tooling limit, not an app defect. Accessibility-based taps still allowed additional screens to be inspected. No full VoiceOver/TalkBack session, fresh onboarding, small Android device, physical-device GPU/battery measurement, store purchase, push delivery, account deletion, or full end-to-end moderation action was completed.

## Phase 1 — critical usability and release readiness

### A01. Cached room presence still says “here now” after refresh fails

**Observed + Code · P1 · high confidence.** Rooms showed “We couldn't reach the rooms just now” alongside an existing room showing “1 here now.” Home also displayed that presence count. Retry did not recover the room, and opening it led to an error-only route.

`apps/mobile/lib/src/features/rooms/rooms_home_screen.dart` retains `rooms.value` and renders it while an error is present. `_RoomCard` uses `rooms_hereNow(summary.counts.hereNow)` with no freshness input.

**Change:** preserve the room link but replace live counts with “Last seen room” / “Reconnect to see who's here” while stale. Model freshness separately from cached membership, and use the same rule on Home. Show a specific sign-in recovery action for authentication failures and Retry for service failures.

**Acceptance:** after a successful load followed by a failed refresh, neither visual text nor accessibility labels claim live presence. Recovery updates the count and freshness together. Help and solo Sanctuary remain reachable.

**Investigation boundary:** `/health` on the configured API returned HTTP 200 with DB and Redis healthy during this audit. That does not establish authenticated room health. Determine whether this session's failure was authentication, routing, API contract, connectivity, or a transient service error before assigning a backend root cause.

### A02. Keepsakes classifies every refresh exception as offline

**Observed + Code · P1 · high confidence.** The screen said “New keepsakes arrive when you're back online.” `KeepsakesRepository.refresh()` catches `Object` and returns `KeepsakesRefresh.offline`, explicitly covering signed-out/deletion-pending cases too.

**Change:** distinguish no connection, expired sign-in, temporary service failure and account state. Keep cached keepsakes visible and provide the relevant recovery action. If the cause is unknown, say “Couldn't refresh keepsakes” rather than blaming the connection.

**Acceptance:** simulated 401, 5xx and offline failures yield different useful actions; cached objects survive all three. This requires a functional error-model change, not only styling.

### A03. Deployment references disagree

**Observed + Code · P1 before deployment · high confidence.** The handbook/Render blueprint referenced a remote admin displaying a Spanish email/password application, whereas the repository produces “Aura console” with development OTP or Google Workspace plus MFA. The owner redirected the audit to local admin. The blueprint's `PUBLIC_API_URL` also differs from the generated mobile build's API hostname.

**Change:** verify deployment ownership, intended project and callback URLs; maintain a small environment matrix with app build version, API host, admin host, auth project and release commit. Treat the observed remote mismatch as unresolved deployment identity, not proof of compromise. Do not copy credentials between environments.

**Acceptance:** one documented release configuration produces the expected app and console; sign-in callbacks and support links reach those verified deployments. No remote deployment was changed here.

### A04. Custom interactive semantics appear disabled

**Observed + Code · P1 investigation · medium confidence.** Home habit chips and sound toggles were exposed by the simulator accessibility bridge as disabled switches. Rain nevertheless responded to an accessibility click and changed to playing. Habit chips wrap `FilterChip` in custom `Semantics(toggled, onTap, excludeSemantics)` without an explicit enabled state.

**Change:** reproduce with actual VoiceOver on a device; verify role, enabled state, toggle action and announcement. Compare with ordinary Settings switches, which did not show this disabled marker. Fix semantics only after determining whether the issue is Flutter's exported node or the automation bridge.

**Acceptance:** VoiceOver can discover, activate and correctly announce both habit and sound controls. Do not call this a proven touch-functionality failure.

### A05. Operational readiness needs a visible health summary

**Observed locally + Documented · P1 before public social launch.** Paging reports no delivery channels, no escalation channel, no grievance-officer email and no prior test. Audit export also says it is unconfigured. The Now page's “Pages 24×7” label describes policy, not verified delivery capability.

**Change:** put environment name and a concise operational-health banner on Now; separate “requires paging” from “delivery configured/last successful delivery.” Display worker freshness, channel health and last drill result. Verify real deployment configuration separately.

**Acceptance:** a configured-looking urgent queue cannot imply a working pager when all channels are absent. A controlled staging drill proves acknowledgement and escalation before social launch. The local missing channels are not evidence that production channels are absent.

## Phase 2 — refinement of the daily experience

### A06. Home's companion lacks scale and a clear next action

**Observed + Proposal · P2.** A small, intricate avatar sits in a relatively empty hero, followed by stage, Starlight, a room chip, streak, rest-day indicators and habits. The first useful habit rows sit low on the screen. Several progress concepts compete before a user takes an action.

**Change:** keep global help reachable; let the companion/world dominate the central area. Add one contextual invitation (“One small thing?”). Move detailed Starlight and streak information into a compact expandable progress row. Keep Check-in immediately available outside 3D navigation. Measure recognizability of the current silhouette at actual phone size before investing in a full rig.

**Acceptance:** in a five-second test, new users identify the companion, the primary action, and help. The first recommended action is visible without scrolling at standard phone size. Large text uses a list fallback.

### A07. Sanctuary's repeated cards flatten importance

**Observed + Proposal · P2.** Today's minute can duplicate a grounding activity listed again below. Similar cards push Sounds and Future you down a long page. Breathing and capsules have stronger distinctiveness than their placement suggests.

**Change:** show a compact set of labelled destinations: Breathe, Ground, Sounds, Future you. Put the suggested minute in one slot. For the universe prototype, represent these as accessible locations with an equivalent list, rather than adding another parallel feature catalogue.

**Acceptance:** testers find a soundscape and a capsule without instruction. One-tap direct access remains available alongside exploration.

### A08. Free launch contains unavailable Plus explanations

**Observed + Code + Documented · P2.** Insights shows a Plus explanation and Sounds contains Plus-labelled content while the handbook says purchases are disabled for v1. This is currently documented behavior, not a regression.

**Change:** decide a coherent free-launch presentation. Recommended: remove purchase-oriented teasers while checkout is disabled; either omit unavailable extras or clearly label future content. Do not silently grant entitlements or change the never-paywalled list.

**Acceptance:** a new user never searches for an upgrade that cannot be purchased. Enabling billing later restores relevant information through one shared availability policy.

### A09. Admin navigation consumes too much vertical space

**Observed + Code · P2.** All 18 owner destinations are peers in a wrapping top navigation. At 390px, main content started approximately 335px from the top. Tables use horizontal scrolling; important fields can sit offscreen.

**Change:** group destinations into Work, Safety operations, People and System. Use a compact mobile menu with Now and Queue immediately visible. For urgent items, show priority, age/deadline, delivery state and open action in a stacked narrow layout. Keep the desktop table and keyboard shortcuts.

**Acceptance:** urgent queue content starts within roughly the first 200px on a 390px viewport; priority and deadline are simultaneously visible without horizontal scrolling. Measure before accepting the design.

### A10. “Stats” does not answer growth questions

**Observed + Documented · P1 for acquisition experiments, P2 for UI.** Stats shows reports, grievances, legal orders and pages. It is an operations view. Product analytics are recorded as parked in the handbook.

**Change:** preserve operational Stats and add a separate adult-only, consent-respecting product measurement view for activation, return cohorts, care-activity completion, world usage and acquisition source. Use aggregated events with no note, mood label, capsule text, habit name, DOB or precise world representation.

**Acceptance:** the founder can answer which recruitment source produced people who returned and completed a meaningful action after seven days. Session duration alone is insufficient.

### A11. Existing docs can send implementation work backwards

**Code + Documented · P2.** `docs/screen-plan.md` calls several now-built screens placeholders. The earlier design critique lists selected chips, header wrap and Quiet Together labels as open issues, while current UI/tokens show fixes.

**Change:** date and mark superseded audit findings; update the screen inventory from current routes. Keep the handbook as context but verify claims against code and a versioned build. A new universe plan should explicitly revise relevant product decisions instead of inheriting all “locked” statements from an attached document.

## Phase 3 — polish and stronger first-use states

- **Keepsakes:** the empty state is calm but vague. Show one example of a small moment that can create a keepsake, with a direct care action and no daily pressure. Keep offline/unknown status separate from an actually empty collection.
- **Insights:** new users see an empty calendar, a seven-check-in threshold, counters, and a Plus explanation. Lead with one useful reflection or a sample explanation explicitly labelled as an example. Never fabricate personal patterns.
- **Motion:** preserve existing reduce-motion support; every future orbit, camera move and scene transition needs a still alternative. A simulator cannot verify battery or GPU performance.
- **Audio:** in this audit, the UI start/stop flow worked. The handbook reports procedural placeholder stems. Source and review real audio before marketing an audio-rich universe; retain a licence ledger.
- **Identity:** evaluate an orb/creature and an androgynous avatar option with global testers. The current stylized character may be loved by one audience and less relatable to another; this is a research question, not an assumed defect.
- **Admin wording:** replace raw configuration error codes with a short plain-language summary plus expandable technical detail; retain the underlying identifiers for operators.

## What to preserve

The current check-in presents all four mood groups with equal visual treatment, has explicit selected states, and reveals optional detail through a clear button. The detail view scrolls to useful fields. Breathing has obvious pause and exit actions. Safety remains reachable from failure states. Quiet Together labels fit in the current layout. The local admin exposes MFA status, audited changes, a verified audit hash chain, and role-aware navigation. These are foundations for the new direction.

## Automated verification performed

| Check | Result |
|---|---|
| Focused Flutter tests: design audit, shell navigation, check-in screen/order, habit editor, Rooms home, Breathe session, Safety Center | **135 passed** |
| `flutter analyze` | **No issues found** |
| Admin `pnpm test` | **42 passed** |
| Admin `pnpm typecheck` | **Passed** |
| Configured mobile API `/health` | HTTP 200; DB and Redis reported healthy at observation time |
| Local API `/health` | DB and Redis reported healthy after local startup |

Full server/unit/e2e/database suites were not rerun. Existing tests support component behavior, not store readiness, moderation staffing, billing correctness in production or demand for 3D.

## Implementation order

1. Correct stale presence and error recovery, investigate semantics, and reconcile deployment references.
2. Make Now operational health explicit and simplify narrow admin navigation.
3. Improve Home/Sanctuary hierarchy and the free-launch presentation.
4. Establish minimal product measurement and validate the proposed world loop.
5. Run the constrained 3D prototype described in `UNIVERSE_PLAN.md`.

The visual audit remains a proposal. Functional changes above are separately identified so implementation can update contracts and tests rather than disguise behavior changes as visual polish.
