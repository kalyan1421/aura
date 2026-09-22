# Aura design system

Status: implementation reference for the Flutter app. The runtime source of truth is [`aura_tokens.dart`](../apps/mobile/lib/src/core/theme/aura_tokens.dart) plus [`app_theme.dart`](../apps/mobile/lib/src/core/theme/app_theme.dart). This document explains how to use those tokens; it does not create a second token set.

Aura uses a dark-only Material 3 theme. Platform conventions may shape behavior, but they must not replace the semantic roles and component contracts below.

## Experience principles

- **Calm cosmic night.** Depth comes from quiet sky layers, sparse stars, typography and spacing—not alarm colors or heavy elevation.
- **Feelings have equal dignity.** Sunrise, Rain, Moonlight and Storm are parallel emotional contexts. Never rank, score, moralize or arrange them from “good” to “bad.”
- **Private by default.** Mood, notes and history are personal. Stranger surfaces use only explicitly shared, predefined gestures in the MVP.
- **Support without alarm.** Immediate help is always easy to reach, warm and direct. Aura is wellness support, not therapy, diagnosis or an emergency service.
- **Progress without punishment.** Companion growth, streak language and empty states must not shame inactivity or loss.

## Color roles

Use the named constants from `AuraColors`; do not duplicate hex values in feature code.

| Role | Token | Value | Use |
|---|---|---:|---|
| deepest sky | `skyDeep` | `#05060F` | lower background and immersive edges |
| app sky | `sky` | `#0A0C1D` | scaffold and primary canvas |
| raised sky | `skyHigh` | `#10132A` | inputs and low containers |
| surface | `surface` | `#151935` | cards and grouped content |
| raised surface | `surfaceHigh` | `#1D2245` | selected/disabled controls and floating feedback |
| structural outline | `outline` | `#2C3264` | control boundaries and drag handles |
| quiet divider | `hairline` | 12% white | separators on dark surfaces |
| primary text | `text` | `#F2F0FF` | headings and essential content |
| secondary text | `textSoft` | `#BDB9E0` | explanations and supporting content |
| muted text | `textMuted` | `#9591BD` | hints and nonessential metadata |
| gentle light | `starlight` | `#F7E6B5` | companion/progress light, not currency pressure |
| focus/link | `lavender` | `#C9BFFF` | visible focus and text actions |
| primary action | `accent` | `#BBAAFF` | filled actions and selected controls |
| on primary action | `onAccent` | `#15112E` | text/icons on `accent` |
| immediate support | `lantern` | `#F6C1A4` | “I need help now,” helplines and calm recovery cues |
| on immediate support | `onLantern` | `#2A1510` | text/icons on `lantern` |

### Emotional quadrants

| Quadrant | Foreground | Ground | Contrast |
|---|---:|---:|---:|
| Sunrise | `#F3BE67` | `#2E2213` | 9.13:1 |
| Rain | `#5ACBBE` | `#0E2A2B` | 7.74:1 |
| Moonlight | `#AFC3F0` | `#161F3A` | 9.21:1 |
| Storm | `#AE93FA` | `#221A43` | 6.44:1 |

All four pairings pass WCAG AA for normal text. Keep tile area, typography, icon weight, motion, selection treatment and grid position equal. A quadrant color communicates identity only; always pair it with a label, glyph and selected state. Never reuse `lantern` to imply a “bad” feeling.

### Warm support-action rule

`lantern` is a dedicated warm beacon, not a danger red and not an emotional ranking. It may identify the global help entry, verified helplines and recovery-oriented messages. Do not use it to decorate Storm/Rain, penalize missed activity, or turn ordinary validation into crisis language. Destructive actions must use explicit labels, confirmation and icons rather than relying on hue alone. The Material scheme currently maps `error` to `lantern`; feature code must still distinguish ordinary form recovery from immediate support through copy, iconography and placement.

### Verified contrast

WCAG 2 relative-luminance checks for the implementation values are: `text/sky` 17.25:1, `textSoft/sky` 10.32:1, `textMuted/sky` 6.52:1, `onAccent/accent` 8.95:1 and `onLantern/lantern` 10.78:1. The weakest intended quadrant pair is Storm at 6.44:1. Recheck contrast when tint washes, opacity, disabled treatments or dynamic companion hues are introduced; token-level results do not automatically validate composited pixels.

## Typography and localization

- Use the platform system font for Latin-script English, Tenglish and Hinglish.
- Use bundled `NotoSansTelugu` for Telugu and `NotoSansDevanagari` for Hindi, with both in `fontFamilyFallback`.
- Use the Material 2021 dark type scale already tuned in `buildAuraTheme`. Headings are medium weight, titles/labels semibold, and display tracking is slightly tightened.
- Line height is **1.55** for Telugu/Hindi native scripts and **1.4** otherwise. Test Telugu and Devanagari conjuncts at 200% text scale.
- All user-facing text belongs in ARB files. Use ICU plurals/placeholders; never concatenate translated clauses, encode gendered assumptions or truncate critical copy.
- Budget 30–45% expansion for Telugu and 20–35% for Hindi. Buttons may wrap; layouts must grow or scroll.
- Alpha locales are `en`, `te` and `te-Latn`; `hi` and `hi-Latn` remain beta-gated in the current app configuration. Romanized system strings intentionally fall back to English.
- Use directional padding/alignment and direction-aware icons so future RTL support is not blocked.

## Spacing and shape

| Scale | `xs` | `s` | `m` | `l` | `xl` | `xxl` | page gutter |
|---|---:|---:|---:|---:|---:|---:|---:|
| dp | 4 | 8 | 12 | 16 | 24 | 32 | 20 |

| Radius | `s` | `m` | `l` | `pill` |
|---|---:|---:|---:|---:|
| dp | 12 | 18 | 26 | 999 |

Use the 20dp gutter for route-level content, 16–24dp internal card padding, 8–16dp related-item gaps and 24–32dp section separation. Use 12dp for compact containers, 18dp for inputs/cards, 26dp for prominent cards and top sheets, and the pill radius for buttons/chips. Hierarchy should come from surface, type and space rather than shadows.

## Motion and feedback

| Token | Duration | Use |
|---|---:|---|
| `quick` | 180ms | press, selection and small state feedback |
| `calm` | 420ms | content changes, gentle reveals and companion response |
| `slow` | 900ms | ambient, non-blocking emphasis only |

Use `Curves.easeOutCubic`. Motion must explain a relationship or confirm an action; it must not delay saving, help access or navigation. Honor OS and in-app reduced-motion preferences: remove parallax/particle drift and use crossfades of at most 300ms for necessary transitions. Sound and haptics are optional enhancements, default to restrained feedback, and must each be independently disabled. Never make them the only confirmation.

## Component contracts

| Component | Contract and states |
|---|---|
| Filled button | 56dp minimum height, pill shape, `accent/onAccent`. Press feedback is immediate. Disabled uses `surfaceHigh/textMuted`. For work longer than 300ms, keep the label stable and show progress without changing width. |
| Outlined button | 52dp minimum height, pill shape, `outline` boundary. Use for secondary actions and the compact help entry. |
| Text/icon button | At least 48×48dp; lavender foreground; tooltip/semantic label for icon-only use. |
| Chips | Pill shape, 8dp vertical padding, outline when idle, `surfaceHigh` when selected. Selected state needs more than color. Wrap across lines. |
| Inputs | `skyHigh` fill, 18dp radius, 16dp vertical padding, persistent label where ambiguity is possible. Focus uses a visible 1.5dp lavender border. Preserve input on errors. |
| Quadrant/mood tile | Equal geometry and emphasis across all quadrants; glyph + label + semantic selected state; stable ordering; minimum 48dp target. |
| Cards | `surface` or translucent `surface` with `hairline`; 18dp or 26dp radius; no decorative elevation required. |
| Top sheet | 26dp top radius, visible outline drag handle, safe-area aware, scrollable at large text sizes. Do not require drag-to-dismiss. |
| Global help entry | `lantern` foreground/accent, explicit “I need help now” label, reachable within the first three focus stops on primary screens. Must work offline and without sign-in. |
| Navigation | Four peer destinations plus a distinct central Check-in action. Active state uses icon, label and container—not color alone. Settings/profile stay outside the primary five items. |
| Feedback | Prefer inline status for saving/sync and persistent recovery actions for failure. Toasts containing information remain at least 5 seconds or until dismissed. |

Interactive components must define enabled, pressed, focused, selected, disabled, loading, success and recoverable-error behavior as applicable. Focus is never removed. Disabled controls still need nearby text explaining availability when the reason is not obvious.

## Accessibility and safety guardrails

- Target WCAG 2.1 AA, 200% text scaling and 44×44dp minimum targets (48dp preferred by current themes).
- Maintain logical focus order; announce headings, selection, live save status and companion changes without reading decorative stars.
- Do not rely on color, sound, haptics, animation or spatial position alone.
- Every timed regulation activity can pause, exit and resume without penalty. No countdown may pressure a user.
- The check-in saves before any support intervention. Support is dismissible, does not imply diagnosis and never claims that another person was notified.
- “Aura is not a medical device or an emergency service” belongs in onboarding trust content, Settings and the Safety Center.
- Empty, offline and missed-day states use neutral or caring language. Never use red, loss framing, broken-streak punishment or declining companion health.
- Test VoiceOver and TalkBack flows in English and Telugu from alpha, including onboarding, Check-in, Safety Center and every shared gesture surface.

## Implementation ownership

- Global tokens and theme: `apps/mobile/lib/src/core/theme/`
- Reusable sky: `apps/mobile/lib/src/core/widgets/cosmic_background.dart`
- Localized copy: `apps/mobile/lib/l10n/*.arb`
- Feature components: colocate in `apps/mobile/lib/src/features/<feature>/`; promote to `core/widgets/` only after genuine cross-feature reuse.
- Mood names and quadrant mapping: `contracts/moods.json` and `packages/aura_domain/`; UI must not fork those definitions.
