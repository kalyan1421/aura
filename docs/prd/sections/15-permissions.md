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
