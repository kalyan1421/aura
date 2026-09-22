# Aura phased screen plan

Status: product/design plan aligned with the current Flutter repository. It describes screens and states; it does not authorize new data fields, APIs or production behavior.

## Current implementation snapshot

The app is feature-first under `apps/mobile/lib/src/features/`, uses Riverpod and GoRouter, keeps shared visual foundations in `core/theme/`, and localizes copy through `apps/mobile/lib/l10n/`.

Already routed: Welcome, DOB gate, Language, Sign in, Blocked, Home, Check-in and Settings. Already implemented as overlays/states: DOB pickers, the offline-capable support sheet with grounding, sign-out confirmation, Check-in saved/offline/failure states and a disabled “room coming soon” prompt. Home currently combines the companion, progression, habits, sync status, global help and the Check-in entry. There is no production app shell, Sanctuary, Universe or Insights route yet.

Two product conflicts must remain explicit:

1. **Age policy:** the repository and PRD lock Aura to 13+ with an under-13 block; the newer brief says India-first 18+. This plan preserves the current 13+ runtime until the owner accepts a policy change and updates legal, PRD, contracts, copy and tests together.
2. **Public content:** PRD F6 includes short moderated reflections, while the newer MVP brief excludes public UGC. This plan follows the safer MVP brief: Universe uses predefined quiet gestures only; reflections remain deferred.

Optional intensity is also marked post-v1 in the current PRD, while the newer brief includes intensity and body signal in the check-in. Their collection, storage and insight use need a product/data decision before implementation.

## Navigation recommendation

Adopt the proposed five-position shell after onboarding:

`Home · Sanctuary · [Check-in] · Universe · Insights`

- Home is the companion-led today view.
- Sanctuary owns private ambient space and regulation tools.
- Check-in is a visually distinct central action, not a persistent destination state; it opens the existing full-screen flow.
- Universe contains only anonymous presence and predefined gestures in MVP.
- Insights contains private history and non-diagnostic patterns.
- Profile/Settings opens from Home/Insights and is not a sixth tab.
- “I need help now” remains global and early in focus order. Add a routable Safety Center so deep links and assistive navigation do not depend on a modal context; contextual triggers may still open the existing support sheet.

In the current architecture, the shell belongs near `core/router/` (for example a `StatefulShellRoute.indexedStack` plus one scaffold), while each destination stays feature-owned. Preserve state and scroll position per branch. Check-in and Safety Center sit above the shell so they can open from anywhere.

## Delivery phases

| Phase | Outcome | Repository impact |
|---|---|---|
| 0 — Foundation and shell | Shared app scaffold, five-position navigation, global help route, deep links, accessibility baseline | Extend `core/router/`; add only genuinely shared navigation widgets under `core/` |
| 1 — Onboarding and trust | Private start, eligibility, privacy promise, wellness/safety boundary, locale and account setup | Improve existing `features/onboarding/` and `features/auth/`; age rule waits on decision |
| 2 — Core check-in loop | Fast local-first feeling capture, optional detail, save response and safe exit | Evolve existing `features/checkin/`; contracts first for any new fields |
| 3 — Regulation and companion | Non-punitive companion response plus private calming space and activities | Extend `features/avatar/`; add `features/sanctuary/` |
| 4 — Shared Universe | Anonymous co-presence with predefined quiet gestures only | Add `features/universe/`; no open chat or public UGC in MVP |
| 5 — Insights and settings | Private non-diagnostic history, controls, language and accessibility | Add `features/insights/`; expand `features/settings/` |

## Route-level screens

Status uses **built**, **partial** or **planned** relative to this repository.

| Route / screen | Purpose and key components | Entry → exit | Important states | MVP phase / status |
|---|---|---|---|---|
| `/welcome` · Welcome | Establish calm private value; short promise, cosmic hero, Begin, global help | first launch → Trust | fresh/returning, large text, offline | 1 · built, copy enhancement |
| `/onboarding/trust` · Privacy & boundaries | Explain private-by-default handling, no diagnosis, no emergency service, no open chat/UGC; concise links to policy | Welcome → Eligibility | policy unavailable, offline cached copy | 1 · planned |
| `/onboarding/dob` · Eligibility | Neutral DOB entry and age-policy explanation; no preselected year. If policy changes, this becomes explicit 18+ confirmation and blocks under-18s only after the source-of-truth update | Trust → Language or Blocked | incomplete date, boundary birthday, local 30-day block | 1 · built for 13+; 18+ decision pending |
| `/blocked` · Not eligible | Clear eligibility result, locally relevant youth/emergency resources, no account capture | Eligibility → app exit/help | offline, region fallback | 1 · built for under-13 rule |
| `/onboarding/language` · Language | Endonym list, script preview, beta labels | Eligibility → Sign in | locale unavailable/beta, immediate preview | 1 · built |
| `/onboarding/sign-in` · Private account | Pseudonymous account setup; explain why it is needed; email/social options from existing auth capability | Language → first Check-in | provider unavailable, code sent, retry, offline continuation | 1 · built |
| `/home` · Home | Companion-led today view, non-punitive status, light progress, active practices, settings and global help | shell/default → Check-in, Sanctuary, Settings, Safety | first day, resting, welcome back, evolving, offline/syncing | 0/3 · built without shell |
| `/checkin` · Check-in | Equal-weight 4×4 mood grid; optional detail; Save; always-visible help | central action/onboarding → saved moment → origin/Home | no selection, selected, saving locally, saved offline, recoverable failure, support collision | 2 · built; detail expansion pending |
| `/sanctuary` · Sanctuary | Private ambient refuge; companion presence, soundscape controls, recent/favorite calming activities | shell → activity/Home | first visit, sound off, reduced motion, offline | 3 · planned |
| `/sanctuary/activity/:id` · Activity | Focused breathing, grounding or sensory exercise with pause/exit and no performance score | Sanctuary/contextual prompt → Sanctuary/origin | ready, active, paused, completed, interrupted | 3 · planned; grounding exists in support sheet |
| `/universe` · Universe | Anonymous shared sky, current quiet gatherings and clear privacy/safety framing; no browseable people list | shell/post-check-in offer → gathering/leave | offline, empty, connecting, presence available, safety notice | 4 · planned |
| `/universe/gathering/:id` · Quiet gathering | Time-limited co-presence, predefined gesture tray, visible leave/report/help | Universe/check-in offer → Universe | joining, live, reconnecting, closed, reported/blocked | 4 · planned |
| `/insights` · Insights | Private calendar and sufficiently supported patterns; plain non-diagnostic language | shell → History/detail/Settings | fewer than 7 check-ins, enough data, care card, offline | 5 · planned |
| `/insights/history` · History | Chronological private check-ins with filters and discreet previews | Insights → entry/back | empty, filtered-empty, pagination/local-only | 5 · planned |
| `/insights/history/:id` · Check-in detail | View/edit within allowed window, delete, note privacy, sync status | History → History | editable/read-only, unsynced, delete pending, missing | 5 · planned |
| `/settings` · Settings | Account, language, notifications, sound, haptics, reduced motion, accessibility, about and help | Home/Insights → subpage/back | signed out/in, pending sync, capability unavailable | 5 · partial (language/account/about built) |
| `/settings/privacy` · Privacy & data | Data use summary, export, delete, local privacy controls and policy links | Settings → confirmation/back | export queued/ready/failed, deletion cooling-off | 5 · planned |
| `/safety` · Safety Center | Globally reachable help route: immediate help, verified regional numbers, offline grounding, boundary copy | any screen/deep link → origin/call/activity | crisis-context entry, no listed helpline, offline | 0 · planned route; sheet content built |

`/debug/avatar` remains a debug-only lab and is not part of product navigation.

## Sheets, dialogs and transient surfaces

| Surface | Purpose and key components | Opens from → closes to | Important states | Phase / status |
|---|---|---|---|---|
| DOB picker sheet | Accessible day/month/year selection | Eligibility → same screen | invalid day, leap year, large text | 1 · built |
| Check-in details sheet/section | Optional intensity, body signal, context tags and private note; clear Skip/Done | selected mood → Check-in | pristine, partial, max tags/note, preserved error | 2 · context/note built inline; intensity/body decision pending |
| Saved moment | Confirm local save, companion reaction, Starlight, offline status, optional Universe invitation | Check-in save → origin/Home | award pending, local-only, support shown first | 2 · built as in-route state |
| Support sheet | Fast contextual help without losing the underlying task; helplines, grounding, disclaimer | help button or lexicon trigger → origin | crisis/non-crisis wording, offline, region fallback | 0 · built |
| Notification rationale sheet | Explain value, time and privacy before OS permission | post-value moment/Settings → origin | denied, provisional, scheduled | 3/5 · planned |
| Companion evolution moment | Celebrate change without implying regression or blocking access | Home after eligible update → Home | reduced motion, interrupted/resume | 3 · existing moment system, presentation partial |
| Ambient controls sheet | Soundscape, volume, timer, sound/haptic toggles | Sanctuary → Sanctuary | audio unavailable, background interruption | 3 · planned |
| Quiet gesture tray | Predefined localized gestures only; no keyboard or free text | gathering → gathering | cooldown, queued briefly, offline/expired | 4 · planned |
| Gathering info/report/block sheet | Explain anonymity; report category, block and leave | gathering/member presence → gathering/Universe | submitted, offline draft, already blocked | 4 · planned |
| Sign-out confirmation | Warn about unsynced items while preserving choice | Settings → Settings/sign-in | zero/pending sync | 5 · built |
| Delete/export confirmations | Plain-language scope, delay and recovery; no dark patterns | Privacy & data → same screen/status | offline, re-auth required, queued | 5 · planned |

Do not use a dialog for routine education when a full route or inline explanation can remain available. Any sheet must be scrollable, keyboard-safe, dismissible without gesture-only interaction and restore focus to its invoker.

## Cross-screen state contract

| Area | Required states and language rule |
|---|---|
| App shell | startup/skeleton, offline, reconnecting, sync pending, authenticated/signed out; never block private local use on network |
| Onboarding | resume exact step, offline continuation where supported, policy-link failure, age boundary; never collect an under-policy account identifier before eligibility |
| Check-in | preserve selection and text on failure; idempotent double-save; save before support; help never disables Save |
| Companion | new, active, resting, welcome-back and evolved; never sick, dying, disappointed or reset |
| Sanctuary | silent by default until chosen, audio interrupted, reduced motion, paused activity; completion is acknowledged, not scored |
| Universe | offline, empty, joining, live, reconnecting and closed; prerecorded/automated presence must be labeled; no input surface that accepts public free text in MVP |
| Insights | threshold-gated patterns, insufficient data, care card and filtered empty; observations are descriptive, never causal or diagnostic |
| Settings/data | permission unavailable/denied, export queued/failed/ready, pending sync, sign-out and delete confirmation; explain consequences before action |
| Safety | offline and region fallback are first-class; helpline data never depends on IP/GPS; visible exit and return to prior task |

## Repository placement and implementation rules

- Keep route constants and redirects in `apps/mobile/lib/src/core/router/`; add shell mechanics there, not inside a feature screen.
- Keep screens and local components in `features/onboarding`, `checkin`, `avatar`, `sanctuary`, `universe`, `insights`, `settings` and `support`/`safety` as appropriate.
- Reuse `CosmicBackground`, `AuraColors`, `AuraSpace`, `AuraRadius` and `AuraMotion`. Do not add per-screen token copies.
- Continue Riverpod providers/repositories per feature and local-first writes. UI planning must not bypass the existing sync boundary.
- Any new stored check-in field, shared gesture payload, insight calculation or privacy control starts with the relevant PRD/contract/data review before UI implementation. This plan intentionally defines no API shape.
- Keep public-facing copy in ARB files and validate English, Telugu and Tenglish in each MVP phase; Hindi/Hinglish follow the existing beta gate.

## Decisions needed before implementation

1. Is Aura remaining 13+, or should the legal/product source of truth move to 18+? This changes more than the label on the DOB screen.
2. Confirm that public reflections are removed from MVP and predefined quiet gestures are the only user-to-user expression.
3. Are intensity and body signal MVP fields or post-v1? If MVP, define their private storage, edit/delete behavior and whether Insights may use them.
4. Should the Safety Center always open as a full route, with the existing sheet reserved for contextual/crisis interception, as recommended here?
5. Confirm the five-position navigation labels and whether the central Check-in action preserves the originating tab on completion.
