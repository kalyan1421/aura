## Analytics & Tracking Plan

### Tooling
- **Product analytics: PostHog Cloud** (confirmed), EU region `[ASSUMPTION]`, via `posthog_flutter` behind a typed `Analytics` service. Funnels, cohorts and feature flags in one tool, with no ad-ID dependency.
- **Source of truth for counts is Supabase Postgres.** Revenue comes from the server ledger, fed by NestJS purchase validation (App Store Server API + Server Notifications V2; Google Play Developer API + Real-time Developer Notifications). North Star, safety and under-18 aggregates live in an internal admin view over Postgres (Metabase or the admin console) `[ASSUMPTION]`, never in PostHog.

### Principles
1. **Explicit events only.** Autocapture, session replay, heatmaps and free-text surveys are off. Events are declared in one Dart schema; properties are enums, booleans, counts or buckets, and a test fails the build on any free-text string property.
2. **Never sent:** note text, voice audio, reflection text, capsule content, custom tag or custom habit names, room pseudonyms, other users' IDs, DOB, email, phone number, IP address (PostHog "discard client IP" is on).
3. **Mood granularity = quadrant only.** Events carry `quadrant` (storm / rain / moonlight / sunrise), never the specific mood label. Per-mood distributions are computed server-side as aggregate counts with a minimum cell size of 20 `[ASSUMPTION]`. Context tags are sent as `tag_count` only.
4. **Pseudonymous IDs.** The PostHog `distinct_id` is a random analytics UUID, not the Supabase user ID; the mapping lives only in Postgres. Account deletion triggers PostHog person deletion within 30 days `[LEGAL]`.
5. **Consent (18+).** A "Help improve Aura" toggle at onboarding and in Settings. Default-on vs opt-in under the DPDP Act (and GDPR when the EU/UK open at beta) is `[LEGAL]`; partial coverage is expected, so headline numbers come from Postgres.
6. **Under-18 users are excluded from behavioural product analytics.** The server computes age from the stored full DOB. The PostHog SDK is never initialised for an account under 18, whatever the toggle says; their activity exists only as server-side aggregate counters (daily totals, no user ID, no device ID) for capacity and safety. **This is invisible: no feature, screen or limit differs for under-18 users.** On the 18th birthday the SDK starts on next launch with a fresh analytics UUID and no backfill `[ASSUMPTION]`.
7. **Pre-age-gate buffering.** Events before DOB entry are held in memory. 18+ → flushed. Under 18 or under 13 → discarded and nothing is sent. Under-18 signups are counted server-side as an aggregate at account creation.
8. **No ad IDs, no ATT prompt, no ad SDKs.** No IDFA/GAID; the Android `AD_ID` permission is removed from the manifest `[STORE]`. Attribution is online-first and link-based (see Acquisition), not ad networks.
9. **Crisis events are aggregate-only** `[LEGAL]`. Crisis sheet views and helpline taps go to an unauthenticated NestJS counter endpoint with no user ID, token or IP logging.
10. **Retention:** raw events kept 12 months `[ASSUMPTION]`.

**Global properties on every event:** `app_version`, `platform`, `os_major`, `app_language` (en / te / te-Latn / hi / hi-Latn), `country` (device region, never IP), `plan` (free / trial / plus), `signup_age_bucket` (0, 1, 2–7, 8–30, 31+ days), `acq_channel` (reddit / instagram / youtube / discord / store_search / share_card / other / unknown). Age is always 18+ by construction.

### Event taxonomy
Source: **C** client, **S** server (NestJS API or worker, including store notifications), **A** aggregate counter with no user linkage.

| Event | Src | Trigger | Key properties | F | Pri |
|---|---|---|---|---|---|
| `onboarding_started` | C | First screen (buffered) | `entry` (organic / deeplink), `utm_source`, `utm_campaign` (mapped to an allow-list; unknown → `other`) | F8 | P0 |
| `language_selected` | C | Language picked at onboarding or changed in Settings | `language` (en / te / te-Latn / hi / hi-Latn), `from_language`, `surface` (onboarding / settings), `changed_from_default` | F8 | P0 |
| `age_gate_completed` | C | DOB submitted (18+ only) | none | F8 | P0 |
| `onboarding_step_completed` | C | Each step | `step`, `step_index`, `duration_ms` | F8 | P0 |
| `account_created` | C | Auth success | `auth_method` (apple / google / email / phone) | F8 | P0 |
| `onboarding_completed` | C | Lands on Home | `first_checkin_done`, `total_duration_ms` | F8 | P0 |
| `acq_source_answered` | C | One-time "Where did you hear about Aura?" card, after the 2nd check-in `[ASSUMPTION]` | `answer` (reddit / instagram / youtube / discord / friend / store_search / other / skip) | F8 | P1 |
| `checkin_started` | C | Check-in sheet opened | `source` (home / widget / notification / onboarding) | F1 | P0 |
| `checkin_completed` | C | Save tapped | `quadrant`, `tag_count`, `has_note`, `has_voice`, `duration_ms`, `source`, `is_offline`, `is_backfill`, `prompt_shown` | F1 | P0 |
| `companion_response_shown` | C | Saved-moment reaction plays | `quadrant`, `motion` (full / still), `moment` (none / wake / evolve). No line or pool id: the neutral after-support pool would reveal a crisis sheet (DS-7) | F2 | P1 |
| `checkin_abandoned` | C | Closed without saving | `reached_step` (none / mood) | F1 | P1 |
| `habit_logged` | C | Habit marked done | `habit_key` (preset key or `custom`), `is_backfill` | F2 | P0 |
| `avatar_stage_reached` | S | Server derives new stage | `stage`, `days_since_signup` | F2 | P0 |
| `avatar_rest_changed` | C | Enters / leaves Resting Nebula | `state` (resting / woke), `days_away` | F2 | P1 |
| `rest_day_changed` | S | Rest day earned or applied | `change`, `bank_after`, `streak_bucket` | F3 | P0 |
| `streak_ended` | S | Streak breaks, bank empty | `streak_bucket`, `lifetime_days_bucket` | F3 | P0 |
| `capsule_sealed` | C | Seal confirmed | `unlock_type` (date / mood), `trigger_scope` (mood / quadrant), `horizon_bucket`, `has_voice`, `photo_count`, `prompt_shown` | F4 | P0 |
| `capsule_unlocked` | C | Unlock fires | `unlock_type`, `days_sealed_bucket`, `is_offline` | F4 | P0 |
| `capsule_opened` | C | Ceremony viewed | `ceremony_completed` | F4 | P1 |
| `room_offer_shown` | C | Post-check-in prompt | `quadrant`, `is_lantern_hour` (user's local time), `language_pool` | F5 | P0 |
| `room_joined` | C | Enters room | `quadrant`, `entry`, `members_bucket`, `cold_start_merged`, `language_pool` (en / te_tenglish / hi_hinglish), `tz_region` (the room's matching key) | F5 | P0 |
| `room_pool_unavailable` | C | User's language pool isn't open yet (Hindi + Hinglish before it launches) | `language_pool`, `choice` (english_room / notify_me / dismissed) | F5 | P1 |
| `room_left` | C | Leaves or backgrounds | `dwell_s`, `gestures_sent` | F5 | P0 |
| `gesture_sent` | C | Gesture tapped | `gesture` (8 keys), `target` (member / reflection / room / session), `surface` (room / game / quiet) | F5 | P0 |
| `room_survey_answered` | C | "Did you feel less alone?" | `answer` (yes / no / skip) | F5 | P0 |
| `safety_action_taken` | C | Report / block / mute | `action`, `surface`, `reason` | F9 | P0 |
| `reflection_submitted` | C | Send tapped | `on_device_block` (none / pii / link), `language_pool` | F6 | P0 |
| `reflection_moderated` | S | Pipeline decision | `stage` (omni_moderation / human), `outcome` (published / held / rejected), `omni_top_category` (OpenAI category enum or none), `language_pool`, `latency_ms` | F6 | P0 |
| `game_match_started` | C | Enters lobby | `entry` (room_invite / quick_match) | F7 | P0 |
| `game_session_started` | C | Session begins | `match_wait_ms`, `human_seats`, `echo_seats` | F7 | P0 |
| `game_session_ended` | C | Session ends | `elapsed_s`, `completed`, `sync_bucket` (internal), `pulses_sent`, `gestures_sent`, `rejoined` | F7 | P0 |
| `crisis_sheet_shown` | A | Support sheet opens | `trigger` (help_button / lexicon / omni_moderation / report), `surface`, `country` | F9 | P0 |
| `crisis_helpline_tapped` | A | Call / text tapped | `helpline` (tele_manas / 988 / local_emergency), `country` | F9 | P0 |
| `grounding_completed` | A | 60 s exercise finished | `surface` | F9 | P1 |
| `insights_viewed` | C | Aura Sky opened | `view` (history / sky / patterns / weekly_card / month / look_back / keepsakes), `is_plus_preview` | F10 | P1 |
| `paywall_viewed` | C | Paywall shown | `trigger` (capsule_limit / voice_limit / theme / sounds / insights / settings), `trial_eligible` | F12 | P0 |
| `purchase_started` | C | Buy tapped | `product_type` (plus_monthly / plus_annual / cosmetic / gift), `product_id`, `currency`, `price_local` | F12 | P0 |
| `purchase_completed` | S | NestJS validates the receipt with the store | same + `store` | F12 | P0 |
| `purchase_failed` | C | Store returns non-success | `reason` (cancelled / pending / declined / store_error) | F12 | P0 |
| `purchase_validation_failed` | S | Store said yes, NestJS can't confirm | `reason` (store_timeout / invalid / product_mismatch / duplicate), `will_retry` | F12 | P0 |
| `trial_started` | S | Validated start of the free Plus month | `product_id`, `store`, `paywall_trigger` | F12 | P0 |
| `trial_converted` | S | First paid renewal after the free month | `product_id`, `store` | F12 | P0 |
| `trial_cancelled` | S | Auto-renew turned off during the trial | `days_into_trial`, `store` | F12 | P0 |
| `subscription_changed` | S | Store notification after trial | `change` (renewed / cancelled / billing_retry / grace / recovered / expired / refunded), `months_active` | F12 | P0 |
| `gift_sent` | C | Gift delivered | `gift_key` | F12 | P1 |
| `share_card_created` | C | Card generated | `card_type` (evolution / glow / capsule_anniversary / keepsake) | F13 | P1 |
| `keepsake_earned` | S | NestJS awards a keepsake | `keepsake_key` | F13 | P1 |
| `notification_permission_result` | C | OS prompt answered | `result` (granted / denied / provisional) | F14 | P0 |
| `notification_sent` | S | Push dispatched | `type` (reminder / capsule / room / lantern_hour / wind_down / trial_ending) | F14 | P0 |
| `notification_opened` | C | Push tapped | `type` | F14 | P0 |
| `sanctuary_activity_started` | C | Breathe, grounding, stillness, savour, Sounds or the night wind-down starts | `activity` (breathe / grounding / stillness / savour / sounds / night_wind_down), `variant` (calm / box / 4_7_8 / 5_4_3_2_1 / hand_on_heart / gratitude / mix / none), `entry` (sanctuary / todays_minute / minute_for_you / wind_down_reminder) | F15 | P0 |
| `sanctuary_activity_ended` | C | Activity finishes or is left | `activity`, `variant`, `duration_bucket` (< 30 s / 30–59 s / 1–3 / 3–10 / 10–30 / 30+ min), `completed`, `habit_logged`; Sounds only: `stem_count`, `plus_stems`, `timer` (off / 15 / 30 / 60), `played_in_background` | F15 | P0 |
| `quiet_session_joined` | C | Enters a Quiet Together session | `mode` (study / read / rest), `count_bucket`, `joined_mid_block` | F16 | P1 |
| `quiet_session_left` | C | Leaves, or the block ends | `mode`, `dwell_bucket`, `sound_on`, `focus_rhythm`, `gestures_sent` | F16 | P1 |
| `lantern_wind_down_joined` | C | Opts into the Lantern Hour wind-down | `sound_on`, `members_bucket` | F16 | P1 |

**Calm and co-presence events (F2, F15, F16)** follow the same rules: 18+ only, enums and buckets, no content. Three extra rules apply:
- No client event carries crisis context. `entry` never takes a support-sheet or Safety Center value.
- "A minute for you" logs only starts (via `sanctuary_activity_started`), never impressions. The card is skipped after a crisis sheet, so a missing impression would reveal the sheet (DS-7).
- Room lantern levels and Tonight's intention holds are counted per room in Postgres, never as per-user events (no individual counts, F5). Quiet Together events carry no mood.

Gestures received are counted in Postgres, not as a client event. Crisis-flagged reflections never appear as a `reflection_moderated` outcome; they increment the aggregate counter only. Decisions made with the stricter under-18 thresholds, and anything in the "Minors & grooming" lane, are counted in Postgres only.

### Funnels and dashboards

#### Activation (PostHog)
`onboarding_started` → `language_selected` → `age_gate_completed` → `account_created` → `checkin_completed` (source = onboarding) → `onboarding_completed`.
- **Targets:** onboarding completion ≥ 70%; first check-in during onboarding ≥ 90% of completers.
- **Activated user** `[ASSUMPTION]`: check-ins on ≥ 2 distinct days and ≥ 1 room visit within 7 days of signup. Used as the leading indicator for D30.

#### Acquisition (PostHog + store consoles)
- **Online-first channels only** (Reddit, Instagram and YouTube creators, Discord, ASO; no campus codes), each with a tagged link. Android passes UTM through the Play Install Referrer (per user); iOS App Store campaign links (`pt`/`ct`) report only as aggregates in App Store Connect, so per-user iOS channel comes from `acq_source_answered`.
- **Report:** installs → activated → D7 by channel and `app_language`; share-card links count as their own channel.

#### Retention cohorts (PostHog, verified in Postgres)
- Retained on day N = an **active day** (≥ 1 check-in or habit), the same rule as the glow streak, using the 4 am local day boundary. App opens alone don't count.
- **Targets:** D1 35% / 45%, D7 18% / 25%, D30 10% / 15%, DAU/MAU 25% / 30%.
- Splits: room visit on day 0, capsule sealed on day 0, Sanctuary used in week 1, notifications granted, channel, `app_language`, country.

#### North Star: Weekly Supported Users (Postgres, weekly pg_cron)
- Users with check-ins on ≥ 3 days in their local week **and** ≥ 1 social moment (gesture given or received, published reflection, or Breath Ripples session).
- Reported as a count and as % of weekly actives, split 18+ and under-18 (the under-18 figure is an aggregate count only).
- The definition doesn't change with F15 and F16. A gesture sent in Quiet Together counts as a gesture given; solo Sanctuary use is not a social moment `[ASSUMPTION]`.

#### Room funnel (PostHog)
`checkin_completed` → `room_offer_shown` → `room_joined` → `gesture_sent` → `room_survey_answered` (yes).
- **Targets:** ≥ 25% of check-ins lead to a room visit; ≥ 1.5 gestures per visit; ≥ 60% "yes".
- Splits: quadrant, Lantern Hour, cold-start merged, language pool, `tz_region`.
- **Hindi + Hinglish demand:** `room_pool_unavailable` counts feed the decision to open that pool.

#### Breath Ripples (PostHog)
- Match wait p50 < 20 s (human or echo); share of sessions with ≥ 1 other human; completion rate; lobby abandons; rejoins within the 10 s window.

#### Sanctuary and the saved moment (PostHog)
- Weekly reach: share of weekly actives who start ≥ 1 Sanctuary activity.
- Completion rate by activity; Breathe habit logs that came from Sanctuary.
- Sounds: background-play share, timer use, base vs Plus stems.
- "A minute for you": start rate by quadrant. The card is the same for all four, so a large gap points to the copy, not the user.
- **Guardrail:** room conversion (target ≥ 25%) must not fall once "A minute for you" ships beside the room offer. Compare the 4 weeks before and after.

#### Quiet Together (PostHog, from Milestone C)
- Joins per block by mode and region, median dwell, share with sound on, gestures per join. Counts shown to users come from the server counter, not PostHog.

#### Monetization (PostHog funnel, Postgres ledger revenue)
`paywall_viewed` → `purchase_started` → `trial_started` → `trial_converted`, and `paywall_viewed` → `purchase_completed` for cosmetics and gifts.
- **Paid conversion** = paying users ÷ MAU, 60 days after monetization launch. Target 2% / 5% (research doc claims 6.5–10.5%; treat as unproven). Trial users count as paying only after `trial_converted`.
- Also: trial-to-paid rate, cancel timing within the trial, billing-retry recovery rate, validation-failure rate, UPI pending-to-completed rate, refund rate, Plus churn by month, ARPPU in INR excl. GST (store-local prices converted server-side). Under-18 purchases appear only in Postgres ledger aggregates.
- **Guardrails:** D7 retention of users who saw a paywall must not fall below those who didn't; any `paywall_viewed` within 24 h of onboarding or straight after a Storm/Rain check-in is a bug and alerts.

#### Safety dashboard (Postgres admin view, owner AK as sole moderator until 5,000 DAU)
- Reports per 1,000 room visits, target < 5, by language pool and quadrant.
- Crisis-flagged items time-to-action p50 / p95: < 15 min in Lantern Hour, < 1 h otherwise. All reports actioned < 24 h.
- **Auto-moderation (OpenAI omni-moderation only):** latency p95 (target ≤ 2 s), outcome mix, held rate by language pool (expect higher for Telugu, Tenglish and Hinglish), human overturn rate of auto decisions, API errors that fell back to "hold for human".
- Queue depth per lane (crisis > minors & grooming > harassment > spam), strikes and shadow-mutes issued, crisis sheet views and helpline tap-through (aggregate).
- **Alert:** any crisis item past its SLA pages AK.
