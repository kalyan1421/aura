# Aura: design critique, every screen

**Date:** 25 Sep 2026 · **Build:** `c91b338` (Milestones A–C) · **Stage:** feature-complete, pre-alpha polish
**Method:** 138 screens rendered at iPhone 15 size (393×852 pt, 3x) with real fonts, the app theme and seeded data
(`docs/design/screens/`, index in `INDEX.md`; regenerate with
`cd apps/mobile && flutter test --tags capture --run-skipped test/design_capture`). English at 100%, plus Telugu, Hindi and
200% text for the densest screens. Contrast ratios are computed from `aura_tokens.dart`.

## Overall impression

Aura looks calm, coherent and deliberate: one night-sky palette, one avatar and one voice everywhere, with
"I need help now" on every screen. Most screens make their purpose clear within two seconds. There are two
system-wide problems. **Selected states are almost invisible**: a selected chip differs from an unselected one by
1.12:1, which affects check-in tags, Breathe rhythm and length, capsule unlocks and gifts. **The header doesn't hold
up** when a title is long, the language is Telugu, or text is at 200%: the help pill drops to a second row and the
"Aura" wordmark disappears. Fixing those two components fixes about half of what follows.

## Findings by area

Severity: 🔴 Critical (blocks or misleads the user) · 🟡 Moderate (costs effort or trust) · 🟢 Minor (polish).
Screen numbers refer to `docs/design/screens/`.

### Cross-cutting (design system)

| Finding | Severity | Recommendation |
|---|---|---|
| Selected chips look unselected: `surfaceHigh` vs `surface` is 1.12:1 with no check mark (033 tags, 054 rhythm/length, 072/073 unlock, 074 trigger mood, 092 gift). People can't tell what they picked, and the Save/Start result is a surprise | 🔴 | One selected style for every `ChoiceChip`/`FilterChip` in `buildAuraTheme`: lavender fill (`accent`) with `onAccent` text **and** a leading check. The Home habit chip already does this (021, cream fill + check), so reuse that pattern |
| Unselected chip borders and off switches use `outline` at 1.4–1.6:1 against the background, below WCAG 1.4.11's 3:1 for control boundaries. Off switches read as "missing" (141, 142, 143) | 🟡 | Raise the control outline to about `#5A61A0` (≥3:1 on `surface` and `sky`) and give the off-switch knob `textMuted`. Leave decorative hairlines as they are |
| Header wrap: on screens with a long title, the help pill drops to a second row under the title (history 041–043, capsule composer 072, room 085, month in stars 118, delete account 147, all 200% screens). About 50 pt of every room screen is lost to it, and the pill moves around between screens | 🟡 | One `AuraTopBar`: back or close, title (1 line, ellipsis, shrinks at large text), help pill always on the right. At 200% or in Telugu the pill becomes a heart-only icon button with the label kept for screen readers. **Never** let it wrap |
| Settings is on the **left** on Rooms, Aura Sky and Insights (080, 110) and on the **right** on Home (020). The same icon lives in two places | 🟡 | Put it on the right on every tab, next to the sync icon, as on Home |
| Four gesture layouts: the room's bottom tray tiles (085), member-sheet grid (089), wrap chips in Quiet Together and wind-down (098, 101), and a chip row in Ripples (107). The same eight gestures look like four different things | 🟡 | One `GestureTray` component in two densities (compact row, full grid) with the same icons, order and pressed feedback |
| Full-width primary buttons everywhere except grounding steps, where "Next" is half-width and right-aligned (056, 057) | 🟢 | Full-width Next, with "Back" as a text button above it or on the left in the top bar |
| Icons don't scale with text at 200% (the heart in the help pill, the star, the tab icons). Tiny icons sit beside huge words (230, 234) | 🟢 | Size icons from `MediaQuery.textScaler` (clamped at about 1.5x), or use `IconTheme` sizes tied to the text style |

### Onboarding (010–018)

| Finding | Severity | Recommendation |
|---|---|---|
| The sign-in screen (016) puts the email field at the top and its button ("Email me a code") at the very bottom, with Apple and Google in between. The white Apple button is the loudest thing on screen, so an email user has to find their button past two others | 🟡 | Two clear groups: Apple and Google first, then "or", then the email field **with its button directly under it**. The bottom slot stays empty or holds one "Continue with email" |
| The year picker (014) opens at 2026, so the youngest and not-allowed years come first and a 25-year-old scrolls through 13 years | 🟢 | Open scrolled to about 2008 (a typical first-run age) and keep the type-to-search field. Typing is already supported |
| The DOB screen (013) is mostly empty below the three fields | 🟢 | Fine for calm. Consider one line on why the age is needed (13+), next to the fields |
| ✅ The welcome, trust and blocked screens are clear, warm and honest ("Wellness support, not therapy"). Helplines on the under-13 screen are well done | — | — |

### Home (020–029)

| Finding | Severity | Recommendation |
|---|---|---|
| Top cards stack: a keepsake card, share prompt and capsule-ready card can all appear above the avatar (024, 026, 027). On a busy day the avatar, the heart of Home, is pushed below the fold | 🟡 | One "moment" slot above the avatar, with priority capsule-ready › keepsake › share prompt. The others wait for the next visit |
| The trial-ending card touches the Breathe-together card with no gap (025) | 🟢 | Standard 12 pt card gap (`AuraSpace.m`) |
| In Telugu and at 200% the "Aura" wordmark disappears and the help pill wraps to two lines (200, 230) | 🟡 | The header fix above. On Home, drop the wordmark before the pill wraps |
| ✅ Hierarchy is right: avatar, then today's progress, then rooms, then streak, then habits. The completed habit chip (cream + check) is the best selected state in the app | — | — |

### Check-in (030–043)

| Finding | Severity | Recommendation |
|---|---|---|
| Picked tags look unpicked (033) | 🔴 | The chip fix above |
| After a mood is picked, the details section (tags, note, voice) opens **below the sticky Save**. Only a cut-off "Add a tag or a few words" peeks out (031), so many people will save without seeing it | 🟡 | On pick, scroll so the "What's it about?" heading is visible, or show a small "Add details ↓" chip above Save |
| The recorded voice note's "Record again / Remove" row is covered by the sticky Save (035) | 🟡 | Bottom padding on the scroll view equal to the sticky bar's height plus the safe area |
| The Hindi mood grid switches to 2×2 compact tiles with a dot above each word and leaves a large empty area above Save (211). The layout differs from every other language | 🟡 | Keep the English 1-column list per quadrant. Devanagari fits (the Hindi words are short) |
| The axis hints ("More energy", "Pleasant") are 11 pt `textMuted` | 🟢 | 12 pt, or put them in the grid's screen-reader label only |
| ✅ The saved moment (036/037) is the emotional high point: calm, one line, one optional minute, then Done | — | — |

### Sanctuary (050–063)

| Finding | Severity | Recommendation |
|---|---|---|
| Breathe setup (054): the selected rhythm and length are invisible, so people don't know what Start will do | 🔴 | The chip fix, plus the summary line under Rhythm ("In for 4, out for 6") that already exists |
| The hub is a long, uniform list of cards (050–052), so Sounds and Future you sit about three screens down | 🟢 | Compact 2-column tiles for the five grounding activities, or a section index. Keep Today's minute on top |
| ✅ Sounds is excellent: silent until chosen, a clear "Nothing playing" / "Playing · fades out in 15 min" status, a sticky Pause/Stop, and an honest Plus lock sheet (058–063) | — | — |

### Capsules (070–076)

| Finding | Severity | Recommendation |
|---|---|---|
| In the composer (072–074), "On a date" vs "For a feeling" and the chosen mood don't look selected | 🔴 | The chip fix. The "Any Storm feeling" outline colours already work, so extend them to the selected state |
| The composer title wraps the help pill to a second row (072) | 🟢 | The header fix |
| ✅ Sealed detail (071) and the opening ceremony (075/076) are among the best screens in the app | — | — |

### Rooms, Reflections, Lanterns (080–098)

| Finding | Severity | Recommendation |
|---|---|---|
| The Quiet Together mode buttons break mid-word: "Stu/dy", "Rea/d", "Res/t" (081) | 🔴 | Icon above a 1-line label with `FittedBox`/`maxLines: 1`, or three full-width rows. The current three columns are too narrow for icon plus text |
| "What rooms are" (080) stays fully expanded for people who already have rooms, pushing Quiet Together below the fold | 🟡 | Collapse it to a one-line "How rooms work ›" once someone has joined a room |
| Gesture chips inside reflection cards are cut off at the card edge ("Hug" clipped, 087, 094) | 🟡 | Make that chip row a horizontal scroller with edge fade, or show the three most-used gestures plus "More". Don't clip silently |
| At 200% the sticky gesture tray takes about 25% of the screen (234) | 🟡 | Collapse the tray to a single "Send warmth" button that opens the sheet when text scale is above 1.3 |
| The report sheet's "Send report" stays disabled with no hint until a reason is picked (090) | 🟢 | Helper text "Pick what's happening" near the button, or enable it and validate on tap |
| The gift sheet doesn't show which gift is chosen, only the price on the button (092) | 🟡 | The chip fix |
| ✅ The lantern and Tonight's intention cards are calm and clear, and "Nobody sees who holds it" is the right reassurance. The member sheet puts Report/Block/Mute at the top: good safety hierarchy | — | — |

### Breath Ripples and Quiet Together (100–108)

| Finding | Severity | Recommendation |
|---|---|---|
| The light labels "you / echo / guide" are about 9 pt inside the glowing orbs, with low contrast (106, 107) | 🟡 | Put labels **under** each light in 12 pt `textSoft`. Screen readers already get them |
| The moon's reflection reads as a dotted vertical line at phone size (105) | 🟢 | Wider, softer glints that fade faster with depth, or drop the reflection when the lobby is empty |
| The Ripples end screen crowds the echo toggle card against the buttons (108) | 🟢 | Move the echo setting under "How do you feel now?" as a secondary row, or into Settings with a link |
| ✅ Quiet Together's count-only presence ("7 here"), "Reconnecting…" chip and "Leave whenever you like. Nothing is lost." are exactly on-brief | — | — |

### Insights: Aura Sky, Look back, Month in stars (110–122)

| Finding | Severity | Recommendation |
|---|---|---|
| The year view (112) is a dense glyph field that's hard to read at a glance. Twelve months of four-shape symbols blur together | 🟡 | One dot per day, coloured by quadrant, in a 7-column grid per month, with glyphs only on tap. Or show the month's majority quadrant as a larger glyph beside each month name |
| The pattern sentences read awkwardly ("On check-ins with Love, Sunrise showed up more often.") | 🟢 | "When you tagged Love, Sunrise showed up more often." This is copy only. The translated templates must follow |
| The Keepsakes entry is a bare row while Look back is a card (114) | 🟢 | Same card style for both entry points |
| "Week of Monday, September 7" (122) is clunky | 🟢 | "Week of 7 September" |
| ✅ The care card (116) is excellent. The Plus-locked blur (113) is honest and never blocks the free sky | — | — |

### Keepsakes and share cards (125–129)

| Finding | Severity | Recommendation |
|---|---|---|
| The store line on the card image ("Aura · App Store and Google Play") is about 6 pt in the preview | 🟢 | Fine at 1080 px export. Check the exported PNG on a phone story |
| ✅ The keepsake box is the most polished screen: medallions, soft colour and "Kept on …" dates. Share cards clearly state "Never your moods, notes or name" | — | — |

### Plus (130–134)

| Finding | Severity | Recommendation |
|---|---|---|
| "Start free month" sits below about a screen of plan and legal text and isn't sticky (130/131). On small phones people have to scroll to find it | 🟡 | Sticky bottom bar with the CTA plus "Not now". Keep the legal text in the scroll |
| The paywall opens on dense text with no visual anchor (130) | 🟢 | A small sky or avatar illustration above "More of what you already have" |
| The sky theme swatches are small, dark and nearly identical (132–134). You can't tell First light from Lantern festival | 🟡 | A larger preview (a 3:2 strip of the actual sky gradient) and a tap to preview live on Home |
| "Use 10 Stardust" with 0 Stardust is greyed out with no reason given (132) | 🟢 | "Needs 10 Stardust (you have 0)", or hide the button and show the cost as a label |

### Settings, Delete account, Safety, System (140–155)

| Finding | Severity | Recommendation |
|---|---|---|
| **Delete my account** is styled as the primary lavender button (147), and the dialog's "Delete my account" uses the same weight as Cancel (148). A destructive action looks like a positive one | 🟡 | Outlined button in a warm danger tone (for example `#FF8A80` text and border), and a destructive-styled confirm in the dialog |
| The Grievance Officer and support contacts show placeholders ("Grievance Officer (placeholder)", `example.com`) (143, 145, 155) | 🔴 before release | Fill in real details (AK/lawyer). The build should fail in release if a placeholder is left |
| "Avatar lab" is visible in Settings › About (145) | 🟡 | Confirm it's hidden in release (`Env.debugTools` is off in release). Add a release-build test |
| Settings is one long list with eight sections (140–145) | 🟢 | A small section index at the top, or group into Personal · Notifications · Privacy & safety · About |
| ✅ The Safety Center (150–153) is exemplary: large tappable numbers, "Call emergency services" guidance, a 60-second breathing anchor, and no clutter | — | — |
| ✅ Update required and Device banned (154, 155) are calm, and help stays reachable | — | — |

## Visual hierarchy

- **What draws the eye first:** the peach "I need help now" pill, then the avatar or orb. That's correct for a safety-first
  wellbeing app, as long as the pill never wraps or moves.
- **Reading flow:** top-down and single-column everywhere. The flow breaks where stacked cards push the main content
  down (Home top cards, room explainer) and where sticky bars cover content (check-in details, recorded voice).
- **Emphasis:** primary actions are consistently lavender and full-width. The exceptions to fix are Delete account
  (too strong) and the grounding Next (too weak).

## Accessibility

- **Text contrast:** passes. `text` on `surface` is 15.3:1, `textSoft` 9.2:1, `textMuted` 5.2–6.5:1, and the button
  label on `accent` 9.0:1.
- **Non-text contrast:** **fails** for selected vs unselected chips (1.12:1), chip borders and off switches (1.4–1.6:1).
  WCAG 1.4.11 needs 3:1.
- **Touch targets:** chips, cards, switches and buttons are at least 44 pt. The dots under Look back and the legend items
  aren't interactive, so that's fine.
- **Large text (200%):** everything stays reachable with no overflow errors, but the tab labels shrink unevenly
  ("Sanctuary" tiny, "Check in" wraps), the header wraps, and the room tray takes a quarter of the screen.
- **Telugu:** tab labels wrap to two lines ("ప్రశాంత నిలయం"), and Telugu glyphs look about 10% smaller than Latin at
  the same size. Consider a Telugu `height`/`fontSize` multiplier of 1.05–1.1 in the theme.

## What works well

- One coherent world: the night sky, the avatar and quadrant colours carry meaning (Storm lavender, Rain teal, Moonlight
  blue, Sunrise amber) and are used consistently in the grid, calendar, share cards and history.
- Safety is designed in, not bolted on: help on every screen, calm crisis copy, honest privacy lines ("Only you can read
  this"), and a paywall that never blocks help or the free sky.
- Microcopy is warm and specific, and never pushy ("Leave whenever you like. Nothing is lost.").
- The best screens are the capsule opening, the keepsake box, the Sounds mixer, the Safety Center and the saved
  moment.

## Priority recommendations

1. **One selected-state style for all chips** (theme-level): lavender fill, `onAccent` text and a check. This fixes five
   critical findings at once: check-in tags, Breathe, capsule unlock, capsule mood trigger and gifts.
2. **One `AuraTopBar`** where the help pill never wraps: an icon-only pill at large text or in Telugu, settings on the
   right on every tab. This fixes the header on about 30 screens plus the Telugu and 200% issues.
3. **Quiet Together mode buttons** so words never break (081).
4. **Sticky bars never cover content:** bottom padding for check-in details and voice, a sticky paywall CTA, and the room
   tray collapsed at large text.
5. **Control contrast to 3:1:** the outline token for chip borders and off switches.
6. **Destructive styling** for Delete account and its dialog.
7. **One `GestureTray`** component across the room, member sheet, Quiet Together, wind-down and Ripples.
8. **Before release:** real Grievance Officer and support details, "Avatar lab" hidden, and the Hindi mood grid
   matching the other languages.
