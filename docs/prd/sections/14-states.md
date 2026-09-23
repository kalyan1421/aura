## Error, Empty & Loading States

### Rules for every screen
- **Warm, no blame.** No red on personal data, no "Error!" headings, no exclamation marks in failure copy.
- **Never lose input.** Notes, reflections and capsule drafts persist locally until sent or discarded.
- **Local first.** Solo screens render from Drift at once; network screens show skeletons after 300 ms. Insights and all solo screens work offline.
- **"I need help now" stays visible** in every error and offline state where it normally appears. Helplines are cached on device.
- **Art fallback.** If a fragment shader fails to compile or load, draw the simpler CustomPainter version of that stage or scene, retry next launch, log it (no user content).
- **Offline banner:** "You're offline. Your own things still save here."
- **Same states for everyone 13+.** No screen below differs by age.

### Onboarding and age gate
| State | What the user sees | Recovery |
|---|---|---|
| Error: sign-in failed | "That didn't go through. Try again, or sign in another way." | Retry; other methods shown |
| Edge: magic link expired | "This link has timed out. We'll send a fresh one." | One-tap resend |
| Offline at first launch | "Pick your first mood now. We'll finish setting up when you're connected." | DOB and first check-in saved locally; account creation resumes on reconnect `[ASSUMPTION]` |
| Edge: under 13 | "Aura is made for people 13 and older. We'd love to see you then." Helpline link visible | Device-level lock: the block screen returns on every launch for 30 days, reinstall included (see F8, REQ-ACC-03) |

### Home and avatar
| State | What the user sees | Recovery |
|---|---|---|
| Empty (new user) | A tiny Spark: "This is your Aura. Check in to give it light." | Check-in button pulses once |
| Edge: Resting Nebula | Avatar in soft clouds: "Your Aura has been resting. Say hi when you're ready." | Next check-in plays welcome-back animation |
| Error: shader failed | Simpler painted avatar for the same stage, slow glow | Auto-retry next launch |
| Offline | Normal Home; small cloud on the sync indicator | Silent sync on reconnect |

### Check-in
| State | What the user sees | Recovery |
|---|---|---|
| Offline | Saves normally, small "saved on this phone" tick | Outbox syncs later |
| Error: local write failed | "We couldn't save that. Your phone may be low on space." | Selection kept; Retry |
| Edge: mic denied | "Voice is off. Type instead, or turn it on in Settings." | Settings deep link |
| Edge: crisis words in note | Check-in saves; support sheet opens | "Back to my check-in" |
| Edge: saved after a crisis sheet | Starlight, a neutral line ("Thank you for checking in tonight."), the room offer. No "A minute for you" | None needed |
| Edge: save wakes or evolves the avatar | The welcome-back or evolution moment replaces the shimmer; one line only | Skippable |

### Sanctuary (F15)
| State | What the user sees | Recovery |
|---|---|---|
| First visit | The avatar orb, Today's minute and the library. Nothing plays | Tap any activity |
| Paused (call, alarm, app sent to background) | "Paused. Pick up where you left off?" Sounds keep playing | Resume / Done. Time already breathed still counts toward 60 s |
| Reduce Motion or haptics off | Still orb with phase words; haptics if on | None needed |
| Sounds not downloaded, offline | "Sounds download once, then work offline. Brown noise works now." | Brown noise; download when online |
| Storage full | "Sounds need about 8 MB. Free some space, or play brown noise, which needs none." | Brown noise |
| Headphones disconnected | Playback pauses: "Paused because your headphones disconnected." | Play (the speaker only by choice) |
| Timer ends | Sound fades out over 30 s; "Sounds stopped" | Play again |

### Habits
| State | What the user sees | Recovery |
|---|---|---|
| Empty | "Pick one small thing to start." Six presets shown | Tap to add |
| Edge: 3 custom habits | "You have 3 custom habits. Swap one to add another." | Edit list |

### Capsules list and capsule detail
| State | What the user sees | Recovery |
|---|---|---|
| Empty | "Write to future you. Seal it for a date, or for a feeling." | "Seal your first capsule" |
| Edge: tap a sealed capsule | "Sealed until 12 Oct 2027. It'll keep." | Delete allowed, early open not `[ASSUMPTION]` |
| Edge: 4th mood capsule (free) | "Free accounts keep 3 mood capsules waiting. Date capsules are unlimited." | Pick a date, or see Aura Plus |
| Error: media upload failed | "Sealed and safe on this phone. Photos and voice back up when you're online." | Outbox retries |
| Edge: unlock while offline | Full ceremony. If media was sealed on another device: "Your capsule is open. The voice note arrives when you're back online." | Media downloads on reconnect |

### Insights
| State | What the user sees | Recovery |
|---|---|---|
| Empty (< 7 check-ins) | "Your sky fills in as you check in. 4 more days to see patterns." | None |
| Edge: Plus preview | Blurred deeper chart; basic sky stays free | Paywall |

### Room
| State | What the user sees | Recovery |
|---|---|---|
| Loading (≤ 5 s) | "Finding people who feel this way right now…" | Falls back to cold-start room |
| Empty (cold start) | "12 people have been here today. Leave a light for the next one." | Gestures work asynchronously |
| Edge: language pool not open yet (Hindi + Hinglish, until a Hindi-reading moderator or reliable auto-moderation exists) | "Hindi and Hinglish rooms are opening soon. Join an English room for now?" | "Join English room" / "Tell me when they open" (in-app card) / close |
| Offline | "Rooms need a connection. Your check-in is saved." | Retry on reconnect |
| Error: realtime dropped | "Reconnecting…" chip; gestures queue 30 s | Auto-reconnect; stale gestures dropped quietly |
| Edge: room closes while viewing | Room dims: "This room has become a memory. You can look back for 7 days." Composer and gestures disabled | "Find a new room" |
| Edge: Lantern Hour ends before the lantern is full | "Tonight's lantern glowed this bright." No failed or missed copy | None needed |

### Quiet Together (F16)
| State | What the user sees | Recovery |
|---|---|---|
| Offline | "Quiet Together needs a connection. Sanctuary works offline." | Sanctuary; retry on reconnect |
| Only person here | "Just you right now. Others drop in through the hour." (count 1, never faked) | Stay or leave |
| Block ending | "The next session starts at 10:00." The next block follows without a countdown | Stay (joins the next block) or leave |
| Error: realtime dropped | "Reconnecting…" chip; the shared sound keeps playing locally | Auto-reconnect |
| Shared sound not downloaded | "The shared sound needs a one-time download." Session works silently meanwhile | Download / stay silent |

### Reflection composer
| State | What the user sees | Recovery |
|---|---|---|
| Edge: on-device PII block | "Phone numbers, links and handles can't be shared here. It keeps everyone safer." | Offending part highlighted |
| Edge: moderation > 2 s | "Sending gently…" for 2 s, then composer closes; post visible to author only: "Still checking. You can keep reading." | Updates in place |
| Edge: held for review | "Held for a quick human look. Usually within an hour." | Author can withdraw |
| Error: rejected | "This one can't go up here. It may hurt someone or share personal details. Your words are still here to edit." | Edit and resend; rejections don't use up the 3/day limit `[ASSUMPTION]` |
| Edge: crisis-flagged | No rejection wording. Support sheet: "It sounds like a lot right now. You don't have to carry it alone." | Helplines, grounding, "Back to the room" |
| Edge: 3 sent today | "That's 3 reflections for today. Gestures are always open." | None |
| Offline | Draft kept, send disabled | Manual send when online |

### Breath Ripples lobby and session
| State | What the user sees | Recovery |
|---|---|---|
| Loading (≤ 20 s) | Pacer starts at once: "Looking for others to breathe with…" | Leave anytime |
| Edge: echoes fill seats | "2 echoes joined. They're recordings of real people who breathed here before." | None |
| Edge: no echoes available | "Breathing on your own this time. The ocean still listens." | Solo pacer |
| Error: connection lost | Pacer continues locally: "You're breathing on your own for a moment." | Silent rejoin within 10 s (see F7); after that the light becomes an echo and the session ends gently |
| Offline | "Breathing together needs a connection. Breathe solo instead?" | Solo pacer |

### Crisis support sheet and Safety Center
The Safety Center (`/safety`, opened by "I need help now") shows the same content as a full route and has the same states.

| State | What the user sees | Recovery |
|---|---|---|
| Edge: country with no listed helpline | "If you're in danger right now, please call your local emergency number." Grounding exercise and "Aura is not a medical or emergency service" still shown; no empty list | Country from device region, never IP or GPS |

### Language
| State | What the user sees | Recovery |
|---|---|---|
| Edge: switch mid-session (Settings) | UI redraws in the new language at once, no restart; drafts keep their text; others' reflections stay as written (no translation). "New rooms will match you with Telugu + Tenglish speakers." | An open room keeps its pool until you leave `[ASSUMPTION]` |
| Edge: string missing in te / te-Latn / hi / hi-Latn | That string shows in English, never a raw key | Missing key logged (key only) |

### Paywall, trial and store
Purchases are confirmed by Aura's server (NestJS) with Apple or Google before anything unlocks.

| State | What the user sees | Recovery |
|---|---|---|
| Loading prices | Skeleton rows; prices come from the store in local currency, never hard-coded | Retry after 5 s |
| Edge: trial offer | "Try Aura Plus free for a month. Then ₹49/month or ₹399/year. Cancel anytime in the store." Not eligible (trial used before on this store account): plain price, no trial wording `[STORE]` | Buy / "Not now" |
| Error: store unreachable | "The store isn't reachable right now. Nothing was charged." | Retry |
| Edge: confirming with server (pending) | "Confirming with the store…" for up to 10 s, then "The store has your request. Plus unlocks the moment it's confirmed. You can close this." Nothing granted until confirmed, even across restarts | App retries in the background; server also accepts the store notification; in-app note when unlocked |
| Error: validation failed | "We couldn't confirm this yet. If you were charged, it's safe. We'll keep checking." | Auto-retry for 72 h `[ASSUMPTION]`; "Restore purchases"; then support contact. Never asks to pay again |
| Edge: UPI or store approval pending | "Waiting for approval. You won't be charged until it goes through." | Unlock on store notification; push when done |
| Error: declined | "Payment didn't go through. You weren't charged." | Try again |
| Trial active | Plus card in Settings: "Free month: 23 days left. First charge on 30 Oct 2026." | "Manage in store" |
| Edge: trial ends in 2 days | Quiet Home card (and a push if notifications are on) `[ASSUMPTION]`: "Your free month ends on 30 Oct. Plus then continues at ₹49/month unless you cancel in the store." Never shown right after a Storm or Rain check-in | "Keep Plus" (dismiss) / "Manage in store" |
| Trial converted | One small note: "Aura Plus continues. Thank you." | None |
| Trial cancelled | "Your free month stays on until 30 Oct. After that you're on free Aura, and everything you made stays yours." | "Turn Plus back on" |
| Edge: billing retry | In grace period: "The store couldn't renew Aura Plus. Plus stays on while it tries again." After grace: "Aura Plus is paused until the store can renew it. Everything you made stays yours." | "Update payment in store"; resumes on store notification |
| Edge: refunded | "Your refund went through, so Aura Plus has ended. Everything you made stays yours." | Existing capsules keep working; new Plus items locked `[ASSUMPTION]` |

**Storefront not available (EU, UK, Australia until beta ≈ w/e 2 May 2027).** Store-level only: Aura isn't listed in those storefronts, set in App Store Connect and Play Console availability. No in-app state and no IP geo-blocking; an existing user who travels there keeps using the app `[ASSUMPTION]`.

### Settings and data export
| State | What the user sees | Recovery |
|---|---|---|
| Loading export | "Packing up your data. We'll let you know when it's ready." | Push; link valid 7 days `[ASSUMPTION]` |
| Error: export failed or offline | "The export didn't finish. We'll try again when you're connected." | Auto and manual retry |
| Edge: sign out, unsynced items | "3 things haven't synced yet. Stay signed in until they do?" | Wait, or sign out anyway |
