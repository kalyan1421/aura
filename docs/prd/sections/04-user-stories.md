## User Stories

Format: *As a [user], I want [capability] so that [benefit].* IDs are stable (gaps are removed stories); each story fits one sprint. An edge-case story carries the priority of the feature it protects. **Edge** notes give expected behaviour for error, empty or risky states. Everyone 13+ gets the same features; **(13–17)** marks the invisible protections that apply when an under-18 account is involved.

### Riya (student, 20)

| ID | Pri | F-ID | Story |
|---|---|---|---|
| US-01 | P0 | F1 | As Riya between classes, I want to record how I feel in two taps so that checking in never feels like homework. |
| US-02 | P0 | F1 | As Riya, I want to optionally add tags, a short note or a voice note so that I can later see what was behind a feeling without always explaining it. |
| US-03 | P0 | F1 | As Riya on patchy hostel Wi-Fi, I want my check-in, Starlight and avatar change to work offline so that a bad connection never loses how I felt. **Edge:** queued check-ins sync later with original timestamps; the room offer waits until I'm online and says so. |
| US-04 | P0 | F5 | As Riya after a check-in, I want to join people feeling the same thing today so that I know I'm not the only one. |
| US-05 | P0 | F5 | As Riya entering my first-ever room late at night, I want to see that others were here today and still leave gestures that will be seen later so that a quiet room doesn't feel like rejection. **Edge:** adjacent moods merge first; if still near-empty, show "N people have been here today" and when Lantern Hour starts. |
| US-06 | P0 | F5 | As Riya, I want a predictable time each evening (Lantern Hour, 9–11 pm my local time) when rooms are busiest so that I can drop in when people are actually there. |
| US-07 | P0 | F5 | As Riya, I want to give and receive gestures under a fresh pseudonym per room so that nobody can link my feelings to me. |
| US-08 | P0 | F6 | As Riya, I want my short reflection to go live within seconds, or a kind reason why not, so that I'm never silently ignored. |
| US-09 | P0 | F9 | As Riya, when a reflection or pseudonym upsets me, I want to mute, block or report it in one step and stop seeing it at once so that the room still feels safe. **Edge:** the blocked person isn't told and is never matched with me again `[ASSUMPTION]`. |
| US-10 | P0 | F9 | As Riya at 2 am, writing something that signals I might hurt myself, I want calm support with Tele-MANAS 14416 one tap away and a 60-second grounding exercise so that I reach real help. **Edge:** lexicon covers Telugu and Tenglish; works offline from cached helplines; never behind login, paywall or a spinner; nobody is notified automatically. |
| US-11 | P0 | F2 | As Riya, I want my avatar to change visibly when I drink water, sleep on time or breathe so that self-care has something to show for it. |
| US-12 | P0 | F3 | As Riya after missing exam-week days, I want banked rest days applied automatically and my avatar resting, not suffering, so that coming back feels welcome. **Edge:** if the streak ends anyway, show "Your glow carries on" with lifetime glow days; no red, no loss copy, no streak-loss push. |
| US-13 | P0 | F4 | As Riya on a good day, I want to seal a message that opens on a date or the next time I feel a chosen mood so that my future self hears from someone who knows me. |
| US-14 | P0 | F4 | As Riya, when a mood-trigger capsule fires on a day I checked in Overwhelmed, I want to choose "open now" or "keep for later", with support one tap away, so that my own words help rather than hit too hard. **Edge:** a capsule crisis-flagged at sealing shows support options before content; "keep for later" doesn't start the 7-day cooldown `[ASSUMPTION]`. |
| US-15 | P0 | F14 | As Riya, I want at most one check-in reminder a day, at a time I choose, so that notifications feel like a friend, not a nag `[ASSUMPTION: cap of one]`. |
| US-16 | P1 | F13 | As Riya, I want to share my avatar's evolution as an image with no mood data so that I can post it on Instagram without revealing how I feel. |
| US-17 | P2 | — | As Riya, I want a private room with one close friend so that we can support each other the same way (post-v1, "Bring a friend"). |
| US-53 | P0 | F15 | As Riya on a night I don't want strangers, I want to breathe with a gentle pacer and soft haptics in a private space so that I can settle on my own. **Edge:** works offline; with Reduce Motion the orb is still and words + haptics lead; no score; ≥ 60 s ticks off Breathe. |
| US-54 | P0 | F2, F1 | As Riya after saving how I feel, I want my Aura to answer with the same warmth whatever I picked, and to offer one small optional minute for me, so that checking in feels heard, not filed. **Edge:** after a crisis sheet the line is neutral and no minute card appears; the minute never replaces help. |

### Arjun (working professional, 26) and users abroad

| ID | Pri | F-ID | Story |
|---|---|---|---|
| US-18 | P0 | F7 | As Arjun after a draining day, I want to breathe in sync with a few strangers for three minutes, with no score or chat, so that I calm down without performing. |
| US-19 | P0 | F7 | As Arjun at an off-peak hour, I want the session to start within 20 s, with labelled echoes if no one joins, so that I'm never left in an empty lobby. |
| US-20 | P0 | F7 | As Arjun, when a partner disconnects mid-session, I want it to carry on with their light dimming into an echo so that their network doesn't break my calm. **Edge:** if my connection drops, the pacer keeps running locally and I rejoin if back within 10 s `[ASSUMPTION]`; otherwise it ends gently, no error screen. |
| US-21 | P0 | F3 | As Arjun returning after three weeks away, I want my avatar to wake with a welcome-back moment and lifetime glow days intact so that I stay instead of uninstalling. **Edge:** nothing sent during the gap mentions streaks or loss; the first screen is a check-in, not a list of missed days. |
| US-22 | P1 | F10 | As Arjun, I want a mood calendar with simple patterns, such as which tags appear on Drained days, so that I can spot what is burning me out. |
| US-23 | P1 | F11 | As Arjun, I want to check in without opening the app so that it fits between meetings. |
| US-24 | P1 | F12 | As Arjun, I want to keep Aura Plus after the free month (₹49/month or ₹399/year) via my App Store account and cancel there any time so that paying is as simple as any other app `[STORE]`. |
| US-25 | P1 | F12 | As Arjun, I want to send a ₹10 Warm Tea to a pseudonym whose reflection moved me so that I can offer more than a free gesture. |
| US-26 | P1 | F12 | As Arjun, when a gift purchase fails or stays pending, I want to know plainly whether I was charged and whether it was sent so that I never pay twice or leave a stranger half a gift. **Edge:** pending purchases deliver once the store confirms, even after the room closes (into the recipient's room memory) `[ASSUMPTION]`; failures show "no charge, nothing sent" with no auto-retry. |
| US-46 | P0 | F5 | As Arjun's friend in Dubai, I want Lantern Hour at 9–11 pm Dubai time with room-mates who share my evening so that rooms are busy when I'm awake. **Edge:** time zone from the phone, never location; a thin region pool merges with the nearest region `[ASSUMPTION]`. |
| US-47 | P0 | F9 | As Arjun's friend in Dubai, I want the support sheet to tell me to call my local emergency number, not show numbers I can't use, so that help is real where I am. **Edge:** India shows Tele-MANAS 14416 / 1-800-891-4416, the US 988, everywhere else the local-emergency fallback plus grounding; region from device settings `[ASSUMPTION]`; works offline. |
| US-55 | P1 | F10 | As Arjun, I want to look back at how the same week felt a year ago, only when I choose, so that I can see how far I've come. **Edge:** hidden right after a Storm or Rain check-in and for a day after a crisis sheet; crisis-flagged entries left out; notes open only on tap; never pushed. |

### Meera (16, mixed-age rooms)

| ID | Pri | F-ID | Story |
|---|---|---|---|
| US-31 | P0 | F9 | As Meera, I want help one tap away on every screen, knowing no one (family, coaching centre) is alerted automatically, so that I'm not afraid to use it. **Edge:** nothing appears on the lock screen `[LEGAL: any duty to alert for a minor at imminent risk]`. |
| US-32 | P0 | F9 | As Meera, when a stranger's reflection makes me uneasy, I want my report handled quickly so that I trust something happens. **(13–17)** Minors & grooming lane, actioned < 4 h; my age is never shown. |
| US-48 | P0 | F5, F7, F12 | As Meera, I want to join rooms, play Breath Ripples and send a ₹10 Warm Tea like everyone else, with nothing marking me as a teen, so that Aura doesn't feel like a kids' version. **(13–17)** No visible limits. Invisibly: stricter grooming, PII and sexual-content thresholds on reflections I write or can see `[ASSUMPTION]`; no behavioural analytics. Purchases follow any family approval my store account applies `[STORE]`. |
| US-56 | P1 | F15 | As Meera in a PG with no privacy, I want rain sounds through my earphones with a sleep timer, even offline, so that I can wind down without anyone noticing. **Edge:** silent until I tap; pauses if my earphones disconnect instead of playing aloud; the lock screen shows only "Aura · Sounds". |

### Sai (19, Telugu-first)

| ID | Pri | F-ID | Story |
|---|---|---|---|
| US-49 | P0 | F5, F6 | As Sai, I want the app in Telugu and to post Tenglish reflections in the Telugu+Tenglish room pool so that I can say how I feel in the words I actually type. **Edge:** room pool defaults to my UI language, changeable in Settings `[ASSUMPTION]`; a held reflection says "a person is checking this", never just vanishes. |
| US-50 | P0 | F2, F7 | As Sai on a budget Android phone, I want the avatar and Breath Ripples to run smoothly and the app to stay small so that Aura never lags or gets deleted for space. **Edge:** below mid-range, the procedural renderer drops to a lighter quality tier automatically. |
| US-51 | P1 | F12 | As Sai, I want the free first month of Aura Plus to show its end date (with a reminder 48 h before it ends) and the price after (₹49/month or ₹399/year), and to cancel in Google Play before paying, so that a trial never becomes a surprise charge. **Edge:** one trial per store account `[STORE]`; reminder 3 days before renewal `[ASSUMPTION]`; never offered within 24 h of onboarding or right after a Storm or Rain check-in; sealed capsules still open after it ends. |
| US-40 | P0 | F9 | As Sai, when a moderation decision feels unfair, I want a named Grievance Officer (AK) I can write to in English or Telugu so that a real person is accountable. **Edge:** acknowledged in 24 h, resolved in 7 days `[LEGAL]`. |
| US-57 | P1 | F16 | As Sai before placements, I want to study alongside others without talking, with a shared sound and an optional 25/5 rhythm, so that I feel less alone without being watched. **Edge:** I see only a count and gestures, never names; leaving costs nothing; no text anywhere. |

### AK (only moderator until 5,000 DAU; then Kabir)

| ID | Pri | F-ID | Story |
|---|---|---|---|
| US-41 | P0 | F9 | As AK, I want one queue ordered crisis > minors & grooming > harassment > spam, with SLA timers and a phone alert when a crisis or grooming item waits 5 min unassigned `[ASSUMPTION]`, so that nothing urgent is missed while I'm coding. |
| US-42 | P0 | F6, F9 | As AK facing a crisis-flagged reflection, I want the text, quadrant, whether an under-18 account is involved, whether the support sheet was shown and the author's recent flags on one screen, with a short playbook, so that I act within 15 min at Lantern Hour. **Edge:** no real identity shown; actions are keep unpublished, release as false positive, or escalate; authors are never struck for a crisis flag. |
| US-43 | P0 | F9 | As AK, I want to apply a strike, shadow-mute or ban with a reason code, and the reporter told it was handled, so that enforcement is consistent and reporters feel heard. |
| US-52 | P0 | F9 | As AK, when a report or auto-flag shows someone pushing an under-18 account toward contact or sexual content, I want one action that bans them at once, preserves the evidence and starts the mandatory report so that the minor is protected even with one moderator. **Edge:** pages me 24×7; evidence held 180 days, exempt from the room purge; device also banned `[ASSUMPTION]`; report under POCSO and IT Rules `[LEGAL: recipient, timeline, non-India duties]`; reporter sees only "handled". |
| US-45 | P1 | F9 | As AK, I want a weekly view of reports per 1,000 room visits, SLA hit rate and DAU against the 5,000 hiring trigger so that I know when to bring Kabir in. |
