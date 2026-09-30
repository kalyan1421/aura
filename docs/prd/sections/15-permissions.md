## Permission Flows

### Rules
- **Nothing at launch.** Each OS prompt follows a moment where the benefit is obvious.
- **Soft ask first.** An in-app explainer with "Allow" and "Not now". "Not now" never fires the OS prompt, so the one-time iOS prompt is saved for a real yes.
- **No permission gates a core flow.** Check-in, habits, avatar, text capsules and crisis support work with every permission denied.
- **Re-ask at most once**, no sooner than 30 days after a decline and at a meaningful moment; after that, only a Settings row deep-linking to OS settings.
- **Same for everyone 13+.** No prompt, timing or default differs by age. The full date of birth (DS-6) is typed in at onboarding and needs no OS permission.

### Permission matrix
| Permission | When asked | Explainer copy | If denied |
|---|---|---|---|
| **Notifications** (iOS authorization; Android 13+ `POST_NOTIFICATIONS`, on by default below 13) | After the first check-in in onboarding, on the "evening nudge" screen with a time picker | "Want a gentle nudge each evening? One a day at most, and never about streaks." | Home shows a reminder card instead; capsule unlocks appear as a badge on next open. One re-ask after 30+ days, when a capsule is sealed: "Want to know when it opens?" |
| **Microphone** (iOS `NSMicrophoneUsageDescription`; Android `RECORD_AUDIO`) | First tap on the mic in check-in or the capsule composer | "To record a voice note, Aura needs your microphone. Recordings stay private to you and are never shared in rooms." | Mic button shows "Voice is off" with a Settings link; typing still works |
| **Photos** (iOS PHPicker; Android Photo Picker) | Never as a permission. The system picker opens when adding a photo to an F4 capsule | None needed: the picker shares only what the user selects | Not applicable |
| **Haptics** (Android `VIBRATE`, install-time normal permission; iOS none) | Never | None | Follows the system haptics setting and Settings › Comfort › Haptics. Breath Ripples falls back to a visual pulse; Sanctuary Breathe and the focus rhythm fall back to phase words |
| **Background audio** (iOS `UIBackgroundModes: audio`; Android media-playback foreground service: `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, install-time) | Never: a capability, not a prompt. Used only while F15 Sounds or an F16 shared sound is playing (from Milestone B) | None | Not applicable. On Android 13+ the media playback notification is exempt from `POST_NOTIFICATIONS` `[STORE: verify]`, so Sounds work even if notifications are declined |
| **Exact alarms** (Android `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`) | **Not requested** | None | Reminders use inexact scheduling; ±15 min is fine for a nudge |
| **Location** | **Not requested** | None | Lantern Hour (9–11 pm local) and the room timezone-region key use the device time zone setting, not location |
| **Health: steps** (iOS HealthKit `NSHealthShareUsageDescription` + capability; Android Health Connect `READ_STEPS`) | **Not enabled in v1.0.** When an adapter ships (W06): only from the opt-in card in the personal universe, after its soft-ask copy | "If you allow it, today's steps make the path stones glow a little. Aura only reads a step count, keeps it on this phone, never uploads or shows it, and a quiet day just leaves a plain path." | Nothing changes and nothing is lost; the card says so. The universe, check-in and every care tool work unchanged |
| **App Tracking Transparency** (iOS) | **Not requested**: Aura does no tracking | None | Not applicable |

### Notes

#### Notifications
- **Android channels:** Reminders (incl. the wind-down reminder), Capsules, Rooms & Lantern Hour, Account, and from Milestone B Sounds playback (media controls). Each can be muted separately.
- **iOS provisional authorization** is registered only if the user taps "Not now" `[ASSUMPTION]`. Capsule notices then arrive quietly in Notification Center without an interruptive prompt; the full prompt is shown at the single re-ask moment.
- **Lock-screen copy never names a mood or quotes user text** ("A capsule is ready for you"), for every user. This matters for anyone who shares a phone or has little privacy at home.
- On Android 11+, two denials stop the system dialog; the app then offers only the Settings deep link.

#### Microphone
- Foreground recording only. The background-audio capability is used for **playback** (Sounds) only, never for recording.
- **No microphone for Breath Ripples, Sanctuary or Quiet Together.** Breathing is hold and release, or following the orb, on screen. Shared sound plays from each phone's own cache, and no user audio exists.

#### Background audio (from Milestone B)
- Starts only after the user taps play and stops with the timer, Stop or a disconnected headset. There is no silent keep-alive audio and no background work beyond playback.
- Store review `[STORE]`: Apple 2.5.4 allows background audio for audible content the user started. Google Play needs the foreground-service type declared in Play Console with a short video. Both go in the review notes.

#### Photos
- No `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE` or `NSPhotoLibraryUsageDescription`. Play restricts broad photo access to apps with a core need `[STORE]`; the Photo Picker is backported to older Android via Google Play services.
- EXIF and location metadata are stripped before storage.
- No in-app camera in v1 `[ASSUMPTION]`. Share cards (F13) use the system share sheet ("Save image" included), so no library write permission.

#### Exact alarms
- `USE_EXACT_ALARM` is limited by Play policy to alarm and calendar apps, and `SCHEDULE_EXACT_ALARM` is denied by default for new installs on Android 14+ `[STORE]`. Evening reminders use WorkManager or inexact local scheduling. Date-capsule unlocks are pushed by the server via FCM, with an inexact local notification as backup.

#### Tracking
- No IDFA or GAID; the `AD_ID` permission some Google libraries merge in is removed with `tools:node="remove"` `[STORE]`. `PrivacyInfo.xcprivacy` declares no tracking domains, the App Store label reads "Data Not Used to Track You", and the Play Data safety form matches the Analytics & Tracking Plan. Excluding under-18 users from behavioural analytics is an internal rule with no prompt or permission.

#### Health steps (W06, not enabled in v1.0)
- **What it reads:** one number, today's step count, read-only. No sleep, heart rate, workouts, location or history. Sleep is deliberately not used: any threshold would be a health judgement.
- **What it does:** lights up to 16 path stones in the personal universe, one per thousand steps (RULES.md section 13 `stones`). Warmth only: no steps is a plain path, never a dim or "missed" one; there is no goal, streak or reward; it never touches Starlight, streaks or keepsakes.
- **What it never does:** show the number, store it (only the opt-in flag is kept), log it, send it to analytics, upload it, or share it. Off by default; nothing is read from the health store until the person turns it on.
- **Same for everyone 13+**, like every permission (no age difference), and it never gates a core flow.
- **In the app (built, W06):** `health` plugin, read-only steps adapter (iOS asks once and can never know whether a read was allowed, so a denied read just returns no steps; Android asks Health Connect), iOS `NSHealthShareUsageDescription` and the `com.apple.developer.healthkit` entitlement, Android `READ_STEPS` only (the merged APK adds no other permission), the permission-rationale intent and `VIEW_PERMISSION_USAGE` alias, `MainActivity` on `AudioServiceFragmentActivity`, and **minSdk 26** (drops Android 7.0 and 7.1). The privacy policy text (`apps/site/pages/privacy.html`) has a "Steps (optional)" paragraph. Apple's privacy manifest declares nothing new: a number read on the phone and never sent off it is not "collected".
- **Ship checklist (owner, not done):** confirm the HealthKit capability is enabled on the App ID (automatic signing with `-allowProvisioningUpdates` should add it; a signed device build is the proof); publish the updated privacy policy (`python3 apps/site/build.py`, then `firebase deploy --only hosting`) and refresh its effective date; answer the App Store privacy label (no health data collected) and, on Play, the Data safety form and the Health Connect permissions declaration form (read steps; on-device only); write the App Review note (optional read-only step count that lights path stones; nothing uploaded); add a Health Connect rationale page if Play review asks for one (today the rationale intent opens the app). Apple can reject a HealthKit entitlement it judges unnecessary: if v1.0 is going through review now, ship this in the next version.

