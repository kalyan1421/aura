# Aura screen captures

Rendered by `apps/mobile/test/design_capture/capture_test.dart` (`cd apps/mobile && flutter test --tags capture --run-skipped test/design_capture`) at 393×852 pt, DPR 3 (1179×2556 px), iPhone 15 safe areas, real fonts (SF Pro (SFNS.ttf), Noto Sans Telugu / Devanagari, Material Icons), the app theme (`buildAuraTheme`) and in-memory fakes. Test clock: Thu 8 Oct 2026, 15:30 IST unless a state says otherwise.

| File | Screen | State | Locale | Text scale | Source |
|---|---|---|---|---|---|
| [010_onboarding_welcome_default.png](010_onboarding_welcome_default.png) | Onboarding · Welcome | first launch | en | 100% | `WelcomeScreen (/welcome)` |
| [011_onboarding_trust_default.png](011_onboarding_trust_default.png) | Onboarding · Privacy & boundaries | default | en | 100% | `TrustScreen (/onboarding/trust)` |
| [013_onboarding_dob_empty.png](013_onboarding_dob_empty.png) | Onboarding · Date of birth | nothing picked | en | 100% | `DobScreen (/onboarding/dob)` |
| [014_onboarding_dob_year-picker.png](014_onboarding_dob_year-picker.png) | Onboarding · Date of birth | year picker sheet open | en | 100% | `DobPickerSheet` |
| [015_onboarding_language_default.png](015_onboarding_language_default.png) | Onboarding · Language | English selected | en | 100% | `LanguageScreen (/onboarding/language)` |
| [016_onboarding_signin_default.png](016_onboarding_signin_default.png) | Onboarding · Sign in | Apple + Google + email (iOS config) | en | 100% | `SignInScreen (/onboarding/sign-in)` |
| [017_onboarding_blocked_under-13.png](017_onboarding_blocked_under-13.png) | Onboarding · Under 13 | 30-day device lock (India helplines) | en | 100% | `BlockedScreen (/blocked)` |
| [018_onboarding_first-checkin_mood-grid.png](018_onboarding_first-checkin_mood-grid.png) | Onboarding · First check-in | mood grid, no close button | en | 100% | `CheckInScreen(first: true) (/checkin)` |
| [020_home_today_fresh-day.png](020_home_today_fresh-day.png) | Home | fresh day, not checked in yet (11-day glow streak) | en | 100% | `HomeScreen (/home)` |
| [021_home_today_checked-in.png](021_home_today_checked-in.png) | Home | after today's check-in (glow active, 2 habits done) | en | 100% | `HomeScreen (/home)` |
| [022_home_today_scrolled-end.png](022_home_today_scrolled-end.png) | Home | scrolled to the end (habits, Breath Ripples card) | en | 100% | `HomeScreen (/home)` |
| [023_home_new-user_empty.png](023_home_new-user_empty.png) | Home | brand-new person (Check in pulses) | en | 100% | `HomeScreen (/home)` |
| [024_home_keepsake-card_new.png](024_home_keepsake-card_new.png) | Home | new-keepsake card | en | 100% | `KeepsakeHomeCards on HomeScreen` |
| [025_home_plus-card_trial-ending.png](025_home_plus-card_trial-ending.png) | Home | Plus trial-ending card (scrolled to the end) | en | 100% | `PlusHomeCards on HomeScreen` |
| [026_home_share-prompt_milestone.png](026_home_share-prompt_milestone.png) | Home | milestone share prompt ("Your Aura reached Glow") | en | 100% | `SharePromptCard on HomeScreen` |
| [027_home_capsule-card_ready.png](027_home_capsule-card_ready.png) | Home | a date capsule is ready to open | en | 100% | `CapsuleReadyCard on HomeScreen` |
| [028_home_habits-editor_sheet.png](028_home_habits-editor_sheet.png) | Home · Habits editor | presets + 2 custom habits | en | 100% | `HabitsEditorSheet (showHabitsEditor)` |
| [029_home_rest-days_sheet.png](029_home_rest-days_sheet.png) | Home · Rest days | sheet open | en | 100% | `RestDaysSheet (showRestDaysSheet)` |
| [030_checkin_mood-grid_empty.png](030_checkin_mood-grid_empty.png) | Check-in · Mood grid | nothing picked | en | 100% | `CheckInScreen (/checkin)` |
| [031_checkin_mood-grid_selected.png](031_checkin_mood-grid_selected.png) | Check-in · Mood grid | "Drained" picked | en | 100% | `CheckInScreen (/checkin)` |
| [032_checkin_details_prompt.png](032_checkin_details_prompt.png) | Check-in · Details | tags + note field with the guided prompt | en | 100% | `CheckInDetails in CheckInScreen` |
| [033_checkin_details_typed.png](033_checkin_details_typed.png) | Check-in · Details | 2 tags picked, note typed | en | 100% | `CheckInDetails in CheckInScreen` |
| [034_checkin_voice_recording.png](034_checkin_voice_recording.png) | Check-in · Voice note | recording (~5 s) | en | 100% | `VoiceNoteField in CheckInScreen` |
| [035_checkin_voice_recorded.png](035_checkin_voice_recorded.png) | Check-in · Voice note | recorded, ready to save | en | 100% | `VoiceNoteField in CheckInScreen` |
| [036_checkin_saved_companion.png](036_checkin_saved_companion.png) | Check-in · Saved moment | Sunrise mood: Starlight + companion line | en | 100% | `CheckInScreen saved view` |
| [037_checkin_saved_minute-for-you.png](037_checkin_saved_minute-for-you.png) | Check-in · Saved moment | Rain mood: companion + "A minute for you" + room offer | en | 100% | `CheckInScreen saved view (MinuteForYouCard, RoomOfferButton)` |
| [039_checkin_backfill_mood-grid.png](039_checkin_backfill_mood-grid.png) | Check-in · Add a past day | backfill for Tue 6 Oct | en | 100% | `CheckInScreen(backfillDay:) from History` |
| [040_checkin_backfill_saved.png](040_checkin_backfill_saved.png) | Check-in · Add a past day | saved ("Added to your sky") | en | 100% | `CheckInScreen(backfillDay:) saved view` |
| [041_history_list_default.png](041_history_list_default.png) | History | a year of check-ins, newest first | en | 100% | `HistoryScreen (/insights/history)` |
| [042_history_entry_today.png](042_history_entry_today.png) | History · Check-in detail | today's check-in (editable for 24 h) | en | 100% | `CheckInDetailScreen (/history/:id)` |
| [043_history_entry_editing.png](043_history_entry_editing.png) | History · Check-in detail | editing | en | 100% | `CheckInDetailScreen edit mode` |
| [050_sanctuary_hub_top.png](050_sanctuary_hub_top.png) | Sanctuary | top (orb, Today's minute, Breathe) | en | 100% | `SanctuaryScreen (/sanctuary)` |
| [051_sanctuary_hub_grounding.png](051_sanctuary_hub_grounding.png) | Sanctuary | scrolled: grounding library | en | 100% | `SanctuaryScreen (/sanctuary)` |
| [052_sanctuary_hub_end.png](052_sanctuary_hub_end.png) | Sanctuary | scrolled to the end: Sounds + Future you | en | 100% | `SanctuaryScreen (/sanctuary)` |
| [053_sanctuary_todays-minute_intro.png](053_sanctuary_todays-minute_intro.png) | Sanctuary · Today's minute | activity opened from the Today card | en | 100% | `StepsActivityScreen / BreatheSessionScreen (calmRoute)` |
| [054_breathe_setup_default.png](054_breathe_setup_default.png) | Sanctuary · Breathe | pattern choice before starting | en | 100% | `BreatheSessionScreen` |
| [055_breathe_running_mid-inhale.png](055_breathe_running_mid-inhale.png) | Sanctuary · Breathe | running, mid-inhale | en | 100% | `BreatheSessionScreen (BreathOrb)` |
| [056_grounding_senses_intro.png](056_grounding_senses_intro.png) | Sanctuary · Grounding (5-4-3-2-1) | intro | en | 100% | `StepsActivityScreen` |
| [057_grounding_senses_step-3.png](057_grounding_senses_step-3.png) | Sanctuary · Grounding (5-4-3-2-1) | step 3 (hear) | en | 100% | `StepsActivityScreen` |
| [058_sounds_idle_wind-down-card.png](058_sounds_idle_wind-down-card.png) | Sanctuary · Sounds | nothing playing (night wind-down card on top) | en | 100% | `SoundsScreen` |
| [059_sounds_timer_sheet.png](059_sounds_timer_sheet.png) | Sanctuary · Sounds | timer sheet (2 layers playing) | en | 100% | `_TimerSheet in SoundsScreen` |
| [060_sounds_playing_two-layers-timer.png](060_sounds_playing_two-layers-timer.png) | Sanctuary · Sounds | rain + brown noise playing, 15-minute timer | en | 100% | `SoundsScreen` |
| [061_sounds_playing_mixer.png](061_sounds_playing_mixer.png) | Sanctuary · Sounds | mixer scrolled (volumes, locked Plus stems) | en | 100% | `SoundsScreen` |
| [062_sounds_plus-stem_locked-note.png](062_sounds_plus-stem_locked-note.png) | Sanctuary · Sounds | a locked Plus stem tapped: "Part of Aura Plus" note | en | 100% | `showPlusNoteSheet` |
| [063_sounds_wind-down_active.png](063_sounds_wind-down_active.png) | Sanctuary · Sounds | night wind-down running | en | 100% | `SoundsScreen (_WindDownCard)` |
| [070_capsules_list_sealed.png](070_capsules_list_sealed.png) | Capsules | a date capsule and a feeling capsule, sealed | en | 100% | `CapsulesListScreen` |
| [071_capsule_detail_sealed.png](071_capsule_detail_sealed.png) | Capsule | sealed until 12 Mar 2027 | en | 100% | `CapsuleDetailScreen` |
| [072_capsule_composer_top.png](072_capsule_composer_top.png) | Capsule composer | title + note written | en | 100% | `CapsuleComposerScreen` |
| [073_capsule_composer_date.png](073_capsule_composer_date.png) | Capsule composer | opens on a date (15 Jun 2027) | en | 100% | `CapsuleComposerScreen` |
| [074_capsule_composer_mood-trigger.png](074_capsule_composer_mood-trigger.png) | Capsule composer | opens on a feeling (Overwhelmed) | en | 100% | `CapsuleComposerScreen` |
| [075_capsule_opening_ceremony.png](075_capsule_opening_ceremony.png) | Capsule opening | ceremony (~1.5 s in) | en | 100% | `CapsuleOpeningScreen` |
| [076_capsule_opening_opened.png](076_capsule_opening_opened.png) | Capsule opening | opened: the note | en | 100% | `CapsuleOpeningScreen` |
| [080_rooms_home_top.png](080_rooms_home_top.png) | Rooms | your rooms + a memory | en | 100% | `RoomsHomeScreen (/rooms)` |
| [081_rooms_home_quiet-together-card.png](081_rooms_home_quiet-together-card.png) | Rooms | scrolled: Quiet Together entry card | en | 100% | `QuietTogetherCard on RoomsHomeScreen` |
| [083_rooms_join_guidelines.png](083_rooms_join_guidelines.png) | Rooms · Join | first join: room guidelines sheet | en | 100% | `RoomGuidelinesSheet (RoomJoinScreen, /rooms/join)` |
| [084_rooms_join_matching.png](084_rooms_join_matching.png) | Rooms · Join | "Finding people…" | en | 100% | `RoomJoinScreen (/rooms/join)` |
| [085_room_lantern-hour_top.png](085_room_lantern-hour_top.png) | Room | Lantern Hour: lantern 3/5, intention card, gesture received | en | 100% | `RoomScreen (/rooms/:id)` |
| [086_room_lantern-hour_members.png](086_room_lantern-hour_members.png) | Room | scrolled: members + gesture tray | en | 100% | `RoomScreen (/rooms/:id)` |
| [087_room_reflections_list.png](087_room_reflections_list.png) | Room · Reflections | yours pending + held, others published | en | 100% | `ReflectionsSection in RoomScreen` |
| [088_room_reflections_end.png](088_room_reflections_end.png) | Room · Reflections | scrolled to the end | en | 100% | `ReflectionsSection in RoomScreen` |
| [089_room_member-sheet_default.png](089_room_member-sheet_default.png) | Room · Member sheet | Quiet Comet: gestures, gift, mute, report, block | en | 100% | `MemberSheet (showMemberSheet)` |
| [090_room_report-sheet_default.png](090_room_report-sheet_default.png) | Room · Report | report a member | en | 100% | `ReportSheet (showReportSheet)` |
| [091_room_reflection-composer_typed.png](091_room_reflection-composer_typed.png) | Room · Share a reflection | text typed | en | 100% | `ReflectionComposeSheet (showReflectionComposer)` |
| [092_room_gift-sheet_default.png](092_room_gift-sheet_default.png) | Room · Send a gift | three gifts with store prices | en | 100% | `GiftSheet (showGiftSheet)` |
| [093_room_memory_default.png](093_room_memory_default.png) | Room | a memory (read-only, after 24 h) | en | 100% | `RoomScreen (state: memory)` |
| [094_room_memory_end.png](094_room_memory_end.png) | Room | memory, scrolled to the end | en | 100% | `RoomScreen (state: memory)` |
| [095_rooms_join_hindi-pool-choice.png](095_rooms_join_hindi-pool-choice.png) | Rooms · Join | Hindi pool not open yet: English-room choice | hi | 100% | `RoomJoinScreen (rooms_pool_hi off)` |
| [096_rooms_home_paused.png](096_rooms_home_paused.png) | Rooms | rooms kill switch off | en | 100% | `RoomsHomeScreen (rooms_enabled off)` |
| [097_room_wind-down_card.png](097_room_wind-down_card.png) | Room · Lantern Hour wind-down | entry card ("4 winding down") | en | 100% | `WindDownEntry in RoomScreen` |
| [098_wind-down_session_running.png](098_wind-down_session_running.png) | Lantern Hour wind-down | joined: pacer + cue | en | 100% | `WindDownScreen` |
| [100_quiet_session_study-rhythm.png](100_quiet_session_study-rhythm.png) | Quiet Together | study mode, 7 here, 25/5 rhythm on | en | 100% | `QuietScreen(mode: study)` |
| [101_quiet_session_scrolled.png](101_quiet_session_scrolled.png) | Quiet Together | scrolled: shared sound, gestures, leave | en | 100% | `QuietScreen(mode: study)` |
| [102_quiet_session_reconnecting.png](102_quiet_session_reconnecting.png) | Quiet Together | connection dropped: "Reconnecting…" | en | 100% | `QuietScreen(mode: study)` |
| [105_ripples_lobby_looking.png](105_ripples_lobby_looking.png) | Breath Ripples | lobby: "Looking for others…" with the pacer | en | 100% | `RippleScreen(entry: quick)` |
| [106_ripples_session_settle.png](106_ripples_session_settle.png) | Breath Ripples | matched: "Settle in" (2 people, 1 echo, 1 guide) | en | 100% | `RippleScreen` |
| [107_ripples_session_three-lights.png](107_ripples_session_three-lights.png) | Breath Ripples | in session with 3 other lights | en | 100% | `RippleScreen (OceanPainter)` |
| [108_ripples_end_default.png](108_ripples_end_default.png) | Breath Ripples | end screen | en | 100% | `RippleScreen (end)` |
| [110_insights_top_weekly-month-cards.png](110_insights_top_weekly-month-cards.png) | Insights (Aura Sky) | top: month-in-stars card | en | 100% | `InsightsScreen (/insights)` |
| [111_insights_sky_month.png](111_insights_sky_month.png) | Insights (Aura Sky) | sky calendar, month view (October) | en | 100% | `SkyCalendar in InsightsScreen` |
| [112_insights_sky_year.png](112_insights_sky_year.png) | Insights (Aura Sky) | sky calendar, year view (2026) | en | 100% | `SkyCalendar in InsightsScreen` |
| [113_insights_patterns_free.png](113_insights_patterns_free.png) | Insights (Aura Sky) | patterns (free: Plus depth locked) | en | 100% | `InsightsScreen _PatternsSection` |
| [114_insights_end_look-back-keepsakes.png](114_insights_end_look-back-keepsakes.png) | Insights (Aura Sky) | end: lifetime, Look back entry, keepsakes, all check-ins | en | 100% | `InsightsScreen` |
| [115_insights_day-sheet_yesterday.png](115_insights_day-sheet_yesterday.png) | Insights · Day | a day tapped in the sky (yesterday) | en | 100% | `showDaySheet` |
| [116_insights_care-card_heavy-week.png](116_insights_care-card_heavy-week.png) | Insights (Aura Sky) | a heavy week: care card | en | 100% | `CareCard in InsightsScreen` |
| [117_insights_patterns_plus.png](117_insights_patterns_plus.png) | Insights (Aura Sky) | patterns with Plus | en | 100% | `InsightsScreen _PatternsSection` |
| [118_month-in-stars_plus_top.png](118_month-in-stars_plus_top.png) | Your month in stars | September, with Plus | en | 100% | `MonthInStarsScreen (/insights/month)` |
| [119_month-in-stars_plus_end.png](119_month-in-stars_plus_end.png) | Your month in stars | September, with Plus, scrolled | en | 100% | `MonthInStarsScreen (/insights/month)` |
| [120_month-in-stars_free_top.png](120_month-in-stars_free_top.png) | Your month in stars | September, free | en | 100% | `MonthInStarsScreen (/insights/month)` |
| [121_month-in-stars_free_plus-locked.png](121_month-in-stars_free_plus-locked.png) | Your month in stars | free: the Plus-locked "deeper" part | en | 100% | `MonthInStarsScreen (/insights/month)` |
| [122_look-back_weeks_top.png](122_look-back_weeks_top.png) | Look back | 1 month / 6 months / 1 year ago | en | 100% | `LookBackScreen (from Insights)` |
| [125_keepsakes_box_six.png](125_keepsakes_box_six.png) | Keepsakes | six keepsakes earned | en | 100% | `KeepsakesScreen (/keepsakes)` |
| [126_share_evolution_preview.png](126_share_evolution_preview.png) | Share card preview | Evolution | en | 100% | `ShareCardSheet (showShareCardSheet)` |
| [127_share_glow_preview.png](127_share_glow_preview.png) | Share card preview | Glow days (30) | en | 100% | `ShareCardSheet (showShareCardSheet)` |
| [128_share_capsule-anniversary_preview.png](128_share_capsule-anniversary_preview.png) | Share card preview | Capsule anniversary (1 year) | en | 100% | `ShareCardSheet (showShareCardSheet)` |
| [129_share_keepsake_preview.png](129_share_keepsake_preview.png) | Share card preview | Keepsake (Lantern Hour) | en | 100% | `ShareCardSheet (showShareCardSheet)` |
| [130_plus_paywall_top.png](130_plus_paywall_top.png) | Aura Plus paywall | free account, trial offered (App Store prices) | en | 100% | `PaywallScreen (/plus)` |
| [131_plus_paywall_end.png](131_plus_paywall_end.png) | Aura Plus paywall | scrolled: cancel steps, restore, terms | en | 100% | `PaywallScreen (/plus)` |
| [132_plus_sky-themes_top.png](132_plus_sky-themes_top.png) | Sky themes | with Plus | en | 100% | `SkyThemesScreen (/plus/skies)` |
| [133_plus_sky-themes_end.png](133_plus_sky-themes_end.png) | Sky themes | with Plus, scrolled | en | 100% | `SkyThemesScreen (/plus/skies)` |
| [134_plus_sky-themes_free.png](134_plus_sky-themes_free.png) | Sky themes | free account | en | 100% | `SkyThemesScreen (/plus/skies)` |
| [140_settings_top_default.png](140_settings_top_default.png) | Settings | top (language) | en | 100% | `SettingsScreen (/settings)` |
| [141_settings_comfort_section.png](141_settings_comfort_section.png) | Settings | Comfort section | en | 100% | `SettingsScreen (/settings)` |
| [142_settings_notifications_section.png](142_settings_notifications_section.png) | Settings | Notifications section | en | 100% | `SettingsScreen (/settings)` |
| [143_settings_widget_section.png](143_settings_widget_section.png) | Settings | Home-screen widget section | en | 100% | `SettingsScreen (/settings)` |
| [144_settings_account_section.png](144_settings_account_section.png) | Settings | Account section | en | 100% | `SettingsScreen (/settings)` |
| [145_settings_plus_section.png](145_settings_plus_section.png) | Settings | Help & safety, Aura Plus (trial), About (end) section | en | 100% | `SettingsScreen (/settings)` |
| [147_settings_delete-account_default.png](147_settings_delete-account_default.png) | Delete account | before confirming | en | 100% | `DeleteAccountScreen (/settings/delete-account)` |
| [148_settings_delete-account_confirm.png](148_settings_delete-account_confirm.png) | Delete account | confirm dialog | en | 100% | `DeleteAccountScreen` |
| [150_safety-center_top.png](150_safety-center_top.png) | Safety Center | top (India) | en | 100% | `SafetyCenterScreen (/safety)` |
| [151_safety-center_end.png](151_safety-center_end.png) | Safety Center | scrolled to the end | en | 100% | `SafetyCenterScreen (/safety)` |
| [152_support-sheet_help-now.png](152_support-sheet_help-now.png) | Support sheet | "I need help now" | en | 100% | `SupportSheet (showSupportSheet)` |
| [153_support-sheet_crisis.png](153_support-sheet_crisis.png) | Support sheet | crisis (after a note that needs support) | en | 100% | `SupportSheet(crisis: true)` |
| [154_update-required_default.png](154_update-required_default.png) | Update required | forced update (iOS) | en | 100% | `UpdateRequiredScreen (/update-required)` |
| [155_device-banned_default.png](155_device-banned_default.png) | Device banned | "This device can't use Aura" | en | 100% | `DeviceBannedScreen` |
| [200_home_today_checked-in_te.png](200_home_today_checked-in_te.png) | Home | after today's check-in | te | 100% | `HomeScreen (/home)` |
| [201_checkin_mood-grid_empty_te.png](201_checkin_mood-grid_empty_te.png) | Check-in · Mood grid | nothing picked | te | 100% | `CheckInScreen (/checkin)` |
| [202_checkin_saved_minute-for-you_te.png](202_checkin_saved_minute-for-you_te.png) | Check-in · Saved moment | Rain mood: companion + "A minute for you" | te | 100% | `CheckInScreen saved view` |
| [203_sanctuary_hub_top_te.png](203_sanctuary_hub_top_te.png) | Sanctuary | top | te | 100% | `SanctuaryScreen (/sanctuary)` |
| [204_sanctuary_hub_grounding_te.png](204_sanctuary_hub_grounding_te.png) | Sanctuary | scrolled: grounding library | te | 100% | `SanctuaryScreen (/sanctuary)` |
| [205_insights_top_te.png](205_insights_top_te.png) | Insights (Aura Sky) | top: month-in-stars card | te | 100% | `InsightsScreen (/insights)` |
| [206_insights_sky_month_te.png](206_insights_sky_month_te.png) | Insights (Aura Sky) | sky calendar, month view | te | 100% | `SkyCalendar in InsightsScreen` |
| [210_home_today_checked-in_hi.png](210_home_today_checked-in_hi.png) | Home | after today's check-in | hi | 100% | `HomeScreen (/home)` |
| [211_checkin_mood-grid_empty_hi.png](211_checkin_mood-grid_empty_hi.png) | Check-in · Mood grid | nothing picked | hi | 100% | `CheckInScreen (/checkin)` |
| [212_checkin_saved_minute-for-you_hi.png](212_checkin_saved_minute-for-you_hi.png) | Check-in · Saved moment | Rain mood: companion + "A minute for you" | hi | 100% | `CheckInScreen saved view` |
| [213_sanctuary_hub_top_hi.png](213_sanctuary_hub_top_hi.png) | Sanctuary | top | hi | 100% | `SanctuaryScreen (/sanctuary)` |
| [214_sanctuary_hub_grounding_hi.png](214_sanctuary_hub_grounding_hi.png) | Sanctuary | scrolled: grounding library | hi | 100% | `SanctuaryScreen (/sanctuary)` |
| [215_insights_top_hi.png](215_insights_top_hi.png) | Insights (Aura Sky) | top: month-in-stars card | hi | 100% | `InsightsScreen (/insights)` |
| [216_insights_sky_month_hi.png](216_insights_sky_month_hi.png) | Insights (Aura Sky) | sky calendar, month view | hi | 100% | `SkyCalendar in InsightsScreen` |
| [230_home_today_checked-in_200pct.png](230_home_today_checked-in_200pct.png) | Home | after today's check-in | en | 200% | `HomeScreen (/home)` |
| [231_home_today_scrolled_200pct.png](231_home_today_scrolled_200pct.png) | Home | scrolled | en | 200% | `HomeScreen (/home)` |
| [232_checkin_mood-grid_empty_200pct.png](232_checkin_mood-grid_empty_200pct.png) | Check-in · Mood grid | nothing picked | en | 200% | `CheckInScreen (/checkin)` |
| [233_checkin_saved_minute-for-you_200pct.png](233_checkin_saved_minute-for-you_200pct.png) | Check-in · Saved moment | Rain mood | en | 200% | `CheckInScreen saved view` |
| [234_room_lantern-hour_top_200pct.png](234_room_lantern-hour_top_200pct.png) | Room | Lantern Hour | en | 200% | `RoomScreen (/rooms/:id)` |
| [235_room_lantern-hour_members_200pct.png](235_room_lantern-hour_members_200pct.png) | Room | scrolled: members | en | 200% | `RoomScreen (/rooms/:id)` |
| [236_plus_paywall_top_200pct.png](236_plus_paywall_top_200pct.png) | Aura Plus paywall | free account | en | 200% | `PaywallScreen (/plus)` |
| [237_plus_paywall_scrolled_200pct.png](237_plus_paywall_scrolled_200pct.png) | Aura Plus paywall | scrolled | en | 200% | `PaywallScreen (/plus)` |
| [238_settings_top_200pct.png](238_settings_top_200pct.png) | Settings | top | en | 200% | `SettingsScreen (/settings)` |
| [239_settings_scrolled_200pct.png](239_settings_scrolled_200pct.png) | Settings | scrolled (Comfort) | en | 200% | `SettingsScreen (/settings)` |
