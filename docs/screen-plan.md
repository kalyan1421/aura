# Aura phased screen plan

Status: product/design plan aligned with the current Flutter repository. It describes screens and states; it does not authorize new data fields, APIs or production behavior. **Updated 23 Sep 2026:** AK resolved the open decisions (see "Decisions" below and the PRD v1.2 Decision Record, CI-12), and the statuses reflect the build on that date.

## Current implementation snapshot

The app is feature-first under `apps/mobile/lib/src/features/`, uses Riverpod and GoRouter, keeps shared visual foundations in `core/theme/`, and localizes copy through `apps/mobile/lib/l10n/`.

Built as of 23 Sep 2026:

- **Routed screens:**
  - onboarding: Welcome, Privacy & boundaries (`/onboarding/trust`), DOB gate, Blocked, Language, Sign in (email);
  - Home and Check-in;
  - History (`/history`) and Check-in detail (`/history/:id`);
  - Settings, and Delete account (`/settings/delete-account`).
- **Check-in detail:** tags incl. custom tags, a private note, and a voice note up to 60 s.
- **History:** 24 h edit and delete anytime, with voice playback.
- **Settings:** Language · Comfort (Reduce motion, Haptics, Hide streak number) · Account (sign in/out, delete) · Help & Safety · About.
- **Overlays and states:**
  - DOB pickers;
  - the offline-capable support sheet, whose 60 s grounding auto-completes Breathe;
  - notification and microphone rationale;
  - sign-out and delete confirmations (7-day grace; "Keep my account?" on sign-in during the grace period);
  - Check-in saved/offline/failure states and a disabled "room coming soon" prompt.

Home combines the companion, progression, habits, sync status, global help and the Check-in entry. Placeholder widgets for Sanctuary, Rooms and the capsules entry exist (Milestone A scaffolding). There is no production app shell, Insights route or `/safety` route yet.

## Decisions (resolved by AK, 23 Sep 2026)

1. **Age policy:** Aura stays **13+** with the under-13 block (PRD D2). The newer brief's 18+ proposal is not adopted.
2. **Public content:** PRD F6 **short pre-moderated reflections stay in v1, at Milestone B** (answered with gestures only). This supersedes this plan's earlier "no public UGC in MVP" note. Alpha rooms run on predefined gestures alone.
3. **Intensity and body signal:** post-v1. They are not collected.
4. **Safety Center:** a full route, `/safety`, opened by "I need help now". The existing support sheet is reserved for contextual and crisis interception: a lexicon hit, a crisis-diverted reflection, or a report for danger.
5. **Navigation:** five positions: `Home · Sanctuary · [Check-in] · Rooms · Insights`.
   - "Rooms" is the F5 mood-room space; this plan earlier called it "Universe".
   - The Insights tab shows History until F10 ships (Milestone B).

Still open (implementation detail): whether a completed Check-in returns to the originating tab. Recommended: yes.

## Navigation (decided)

Five-position shell after onboarding:

`Home · Sanctuary · [Check-in] · Rooms · Insights`

- Home is the companion-led today view.
- Sanctuary (PRD F15) owns the private calm space:
  - Breathe, grounding and Today's minute from Milestone A;
  - Sounds from B;
  - the entry to capsules ("Future you").
- Check-in is a visually distinct central action, not a persistent destination state; it opens the existing full-screen flow.
- Rooms holds F5 mood rooms:
  - gestures and Lantern Hour (A);
  - F6 reflections, room lanterns and Tonight's intention (B);
  - F16 Quiet Together and the Lantern Hour wind-down (C).
- Insights contains private history (built) and non-diagnostic patterns (F10 at B), then Look back and keepsakes (C).
- Profile/Settings opens from Home/Insights and is not a sixth tab.
- "I need help now" remains global and early in focus order and opens the routable Safety Center (`/safety`), so deep links and assistive navigation do not depend on a modal context. Contextual triggers still open the existing support sheet.

In the current architecture, the shell belongs near `core/router/` (for example a `StatefulShellRoute.indexedStack` plus one scaffold), while each destination stays feature-owned. Preserve state and scroll position per branch. Check-in and Safety Center sit above the shell so they can open from anywhere.

## Delivery phases

| Phase | Outcome | Repository impact |
|---|---|---|
| 0 — Foundation and shell | Shared app scaffold, five-position navigation, `/safety` route, deep links, accessibility baseline (Milestone A) | Extend `core/router/`; add only genuinely shared navigation widgets under `core/` |
| 1 — Onboarding and trust | Private start, eligibility, privacy promise, wellness/safety boundary, locale and account setup. **Built**; native Apple/Google sign-in added at A | `features/onboarding/` and `features/auth/` |
| 2 — Core check-in loop | Fast local-first feeling capture, optional detail, save response and safe exit. **Built** incl. voice; guided prompts, 7-day backfill and the new saved-moment order at A | Evolve `features/checkin/`; contracts first for any new fields |
| 3 — Regulation and companion | Companion response + "A minute for you" and F15 Sanctuary v1 (A); Sounds (B) | Extend `features/avatar/`; build `features/sanctuary/` |
| 4 — Rooms | F5 rooms with predefined gestures (A); F6 reflections, room lanterns, Tonight's intention (B); F16 Quiet Together + Lantern Hour wind-down (C). No open chat; F6 reflections are the only stranger text | Build `features/rooms/` |
| 5 — Insights and settings | History **built**; F10 Insights (B); Look back and keepsakes (C); settings for notifications, sound and data export | `features/history/` (built), add `features/insights/`; expand `features/settings/` |

## Route-level screens

Status uses **built**, **partial** or **planned** relative to this repository; the milestone is the PRD milestone.

| Route / screen | Purpose and key components | Entry → exit | Important states | Status |
|---|---|---|---|---|
| `/welcome` · Welcome | Establish calm private value; short promise, cosmic hero, Begin, global help | first launch → Trust | fresh/returning, large text, offline | built |
| `/onboarding/trust` · Privacy & boundaries | Explain private-by-default handling, no diagnosis, no emergency service, no DMs or open chat; concise links to policy | Welcome → Eligibility | policy unavailable, offline cached copy | built |
| `/onboarding/dob` · Eligibility | Neutral DOB entry; no preselected year; 13+ (decided) | Trust → Language or Blocked | incomplete date, boundary birthday, local 30-day block | built |
| `/blocked` · Not eligible | Clear eligibility result, locally relevant youth/emergency resources, no account capture | Eligibility → app exit/help | offline, region fallback | built |
| `/onboarding/language` · Language | Endonym list, script preview, beta labels | Eligibility → Sign in | locale unavailable/beta, immediate preview | built |
| `/onboarding/sign-in` · Private account | Pseudonymous account setup; explain why it is needed | Language → first Check-in | provider unavailable, code/link sent, retry, offline continuation | built (email one-time code + magic link); native Apple (iOS) + Google planned (A) |
| `/home` · Home | Companion-led today view, non-punitive status, light progress, active practices, settings and global help | shell/default → Check-in, Sanctuary, Settings, Safety | first day, resting, welcome back, evolving, offline/syncing | built without shell |
| `/checkin` · Check-in | Equal-weight 4×4 mood grid; optional detail; Save; always-visible help | central action/onboarding → saved moment → origin/Home | no selection, selected, saving locally, saved offline, recoverable failure, support collision | built; prompts, companion response and "A minute for you" planned (A) |
| `/sanctuary` · Sanctuary | Private calm space: avatar orb, Today's minute, Breathe, grounding, capsules entry; Sounds (B) | shell → activity/Home | first visit, sound off, reduced motion, offline | placeholder; planned (A) |
| `/sanctuary/activity/:id` · Activity | Breathe (3 patterns), grounding, stillness, savour; pause/exit; no score | Sanctuary / "A minute for you" → Sanctuary/origin | ready, active, paused, completed, interrupted | planned (A) |
| `/rooms` · Rooms (was "Universe") | Your active rooms, how rooms work, next Lantern Hour; Quiet Together modes (C); no browseable people list | shell/post-check-in offer → room/session | offline, empty, connecting, safety notice | placeholder; planned (A) |
| `/rooms/:id` · Mood room | Time-limited room, predefined gesture tray; reflections (B); lantern + intention in Lantern Hour (B); visible leave/report/help | Rooms/check-in offer → Rooms | joining, live, reconnecting, memory, reported/blocked | planned (A) |
| `/rooms/quiet/:id` · Quiet Together | Count only, session-wide gestures, shared sound played locally, optional 25/5 rhythm | Rooms → Rooms | offline, alone, block ending, reconnecting | planned (C) |
| `/insights` · Insights | History until F10; then calendar, supported patterns, weekly card, month in stars; Look back and keepsakes (C) | shell → History/detail/Settings | fewer than 7 check-ins, enough data, care card, offline | planned (B); tab shows History until then |
| `/history` · History | Chronological private check-ins with discreet previews; add a past day (7-day backfill, A) | Insights → entry/back | empty, filtered-empty, local-only | built at `/history`; backfill planned (A) |
| `/history/:id` · Check-in detail | View/edit within 24 h, delete, voice playback, sync status | History → History | editable/read-only, unsynced, delete pending, missing | built |
| `/settings` · Settings | Language, Comfort (reduce motion, haptics, hide streak), Account, Help & Safety, About; notifications and sound rows later | Home/Insights → subpage/back | signed out/in, pending sync, capability unavailable | built (notifications, prompts and sound rows planned) |
| `/settings/delete-account` · Delete account | What is deleted, 7-day grace, store subscriptions, online only | Settings → confirmation/sign-out | offline, scheduled, grace ended | built; data export planned |
| `/safety` · Safety Center | Globally reachable help route: immediate help, verified regional numbers, offline grounding, boundary copy | any screen/deep link → origin/call/activity | crisis-context entry, no listed helpline, offline, signed out, under-13 screen | planned route (A); sheet content built |

`/debug/avatar` remains a debug-only lab and is not part of product navigation.

## Sheets, dialogs and transient surfaces

| Surface | Purpose and key components | Opens from → closes to | Important states | Status |
|---|---|---|---|---|
| DOB picker sheet | Accessible day/month/year selection | Eligibility → same screen | invalid day, leap year, large text | built |
| Check-in details sheet/section | Context tags (incl. custom), private note with optional guided prompt, voice note ≤ 60 s; clear Skip/Done. Intensity/body signal are post-v1 | selected mood → Check-in | pristine, partial, max tags/note, preserved error, mic denied | built; guided prompts planned (A) |
| Saved moment | Local save, Starlight, companion response (shimmer + one line), "A minute for you", room offer, offline status | Check-in save → origin/Home | award pending, local-only, support shown first (then neutral line, no minute card), wake/evolve | built as in-route state (Starlight, offline); companion response + minute planned (A); room offer when F5 lands |
| Support sheet | Contextual/crisis interception without losing the underlying task; helplines, grounding, disclaimer | lexicon trigger, crisis-diverted reflection, danger report → origin | crisis/non-crisis wording, offline, region fallback | built |
| Notification rationale sheet | Explain value, time and privacy before OS permission | first saved check-in/Settings → origin | denied, provisional, scheduled | built |
| Companion evolution moment | Celebrate change without implying regression or blocking access | Home after eligible update → Home | reduced motion, interrupted/resume | existing moment system, presentation partial |
| Ambient controls sheet | Stem mixer, volume, timer, night wind-down, download status | Sanctuary → Sanctuary | not downloaded, storage full, headphones disconnected, background interruption | planned (B) |
| Quiet gesture tray | Predefined localized gestures only; no keyboard or free text | room / Quiet Together → same | cooldown, queued briefly, offline/expired | planned (A rooms, C Quiet Together) |
| Room info/report/block sheet | Explain pseudonyms; report category, block and leave | room/member → room/Rooms | submitted, offline draft, already blocked | planned (A) |
| Sign-out confirmation | Warn about unsynced items while preserving choice | Settings → Settings/sign-in | zero/pending sync | built |
| Delete/export confirmations | Plain-language scope, delay and recovery; no dark patterns | Settings → same screen/status | offline, scheduled, keep my account, grace ended | delete built; export planned |

Do not use a dialog for routine education when a full route or inline explanation can remain available. Any sheet must be scrollable, keyboard-safe, dismissible without gesture-only interaction and restore focus to its invoker.

## Cross-screen state contract

| Area | Required states and language rule |
|---|---|
| App shell | startup/skeleton, offline, reconnecting, sync pending, authenticated/signed out; never block private local use on network |
| Onboarding | resume exact step, offline continuation where supported, policy-link failure, age boundary; never collect an under-policy account identifier before eligibility |
| Check-in | preserve selection and text on failure; idempotent double-save; save before support; help never disables Save; post-save order: crisis sheet → capsule → Starlight + companion response → "A minute for you" + room offer |
| Companion | new, active, resting, welcome-back and evolved; one equal-warmth line after each live check-in; never sick, dying, disappointed or reset |
| Sanctuary | silent by default until chosen, audio interrupted, headphones disconnected (pause), reduced motion, paused activity; completion is acknowledged, not scored |
| Rooms | offline, empty, joining, live, reconnecting and closed; prerecorded/automated presence must be labeled; the only stranger text is F6 reflections (B) through the moderation pipeline; Quiet Together shows counts only and has no text input |
| Insights | threshold-gated patterns, insufficient data, care card and filtered empty; observations are descriptive, never causal or diagnostic; Look back is pull-only and hidden after Storm/Rain check-ins and crisis sheets |
| Settings/data | permission unavailable/denied, export queued/failed/ready, pending sync, sign-out and delete confirmation; explain consequences before action |
| Safety | offline and region fallback are first-class; helpline data never depends on IP/GPS; visible exit and return to prior task |

## Repository placement and implementation rules

- Keep route constants and redirects in `apps/mobile/lib/src/core/router/`; add shell mechanics there, not inside a feature screen.
- Keep screens and local components in `features/onboarding`, `checkin`, `avatar`, `sanctuary`, `rooms`, `history`, `insights`, `settings`, `account` and `support` as appropriate.
- Reuse `CosmicBackground`, `AuraColors`, `AuraSpace`, `AuraRadius` and `AuraMotion`. Do not add per-screen token copies.
- Continue Riverpod providers/repositories per feature and local-first writes. UI planning must not bypass the existing sync boundary.
- Any new stored check-in field, shared gesture payload, insight calculation or privacy control starts with the relevant PRD/contract/data review before UI implementation. This plan intentionally defines no API shape.
- Keep public-facing copy in ARB files and validate English, Telugu and Tenglish in each MVP phase; Hindi/Hinglish follow the existing beta gate.
