## Feature Specification — Calm & Companion

Covers **F15 Sanctuary** and two additions to F1's saved moment: the **F2 companion response** and **"A minute for you"**. All of it is solo and offline-first, and nothing here is visible to anyone else. **F16 Quiet Together** (co-presence with strangers and a shared sound) sits in the Social Layer section, where the stranger-surface rules live. Source: `docs/competitor-integration-plan.md`, approved by AK on 23 Sep 2026.

### Shared rules for calm features

- **Calm, not treatment.** Copy says what to do ("breathe with the orb"), never what it achieves ("reduces anxiety", "better sleep"). No binaural beats, frequencies or health claims (Apple 1.4.1, Play health policy). A copy lint like REQ-INS-03 fails the build on banned words.
- **Equal dignity.** Every quadrant gets the same size, motion, warmth and number of options. No feeling is treated as a problem to fix.
- **No score, no streak, no pressure.** Nothing counts "good" breaths, nothing is missed, nothing expires. Finishing is acknowledged, not rated. Sanctuary earns Starlight only through the Breathe habit (5, once a day).
- **Silent until chosen.** No sound plays until the user taps. Haptics follow Settings › Comfort › Haptics and the system setting. Reduce Motion (OS or Comfort) always has a still version.
- **Help comes first.** "I need help now" is in every calm screen's header. The crisis sheet always comes before any calm suggestion, and no calm suggestion ever replaces it.

### F15 Sanctuary

**P0 · Milestone A** for Sanctuary v1 (Breathe, grounding library, Today's minute) · **P1 · Milestone B** for Sounds. Some nights Riya wants a quieter minute, not strangers. Meera, in a PG with no privacy, needs something that works through earphones. Arjun wants a two-minute reset after work. Sanctuary is the private calm space, the second position in the app shell (Home · Sanctuary · [Check-in] · Rooms · Insights).

**Behaviour**
- **Layout** `[ASSUMPTION]`: the user's avatar as a calm orb, then "Today's minute", Breathe, Grounding and, from B, Sounds. The entry to F4 capsules ("Future you") also lives here. "I need help now" sits in the header.
- **Offline and content-free.** Everything at Milestone A works in airplane mode. A finished activity writes one content-free session record (activity, pattern, duration, Aura day) through `POST /v1/sync/push`. It feeds the Breathe auto-complete and the "Sanctuary minutes" keepsake (F13) `[ASSUMPTION]`. Nothing typed, said or picked inside an activity is stored.

**Breathe (Milestone A)**
- **Avatar-orb pacer.** An orb drawn from the user's own avatar (its hue, Still-tier art) grows on the inhale, holds, and softens on the exhale. Phase words sit underneath ("Breathe in", "Hold", "Breathe out").
- **Patterns:**
  - **Calm 4/6** (default): in 4 s, out 6 s, the same rhythm as F7.
  - **Box 4-4-4-4:** in, hold, out, hold.
  - **4-7-8:** in 4 s, hold 7 s, out 8 s. Defaults to 4 cycles (≈ 76 s), and its info line says "Stop any time if you feel light-headed" `[ASSUMPTION]`.
- **Length:** 1, 3 or 5 min; default 1 min `[ASSUMPTION]`.
- **Haptics:** one soft pattern per phase (rising on the inhale, nothing on a hold, falling on the exhale). They obey Settings › Comfort › Haptics and the system setting.
- **Reduce Motion:** the orb holds still, and phase words plus haptics carry the rhythm.
- **No score.** No breath counts, "accuracy", ratings or session history on screen. Pause or leave at any time; leaving early is never mentioned. The end screen shows "That was a few minutes for you" with "Again" and "Done".
- **Breathe habit.** ≥ 60 s of breathing in one session (paused time excluded) completes today's Breathe habit (F2), once per Aura day. It doesn't apply if Breathe is hidden, the same rule as the support sheet's 60 s exercise. It writes an ordinary habit log, so the existing rules credit it (RULES.md §3, §5). It counts toward Starlight rings and can wake a resting avatar.
- **One pacer engine** (a pattern and a start time give the phase at any moment) drives all of these: Breathe, "A minute for you", the Lantern Hour wind-down cues (F16) and Breath Ripples' local pacer (F7). The rhythm is identical everywhere, and F7 builds on an engine that has already been tested.

**Grounding library (Milestone A)**
- **5-4-3-2-1:** notice 5 things you can see, 4 you can touch, 3 you can hear, 2 you can smell and 1 you can taste.
- **Hand-on-heart:** a hand on your chest, slow breaths with the orb and a few gentle lines.
- **Gratitude:** bring three small things from today to mind, one at a time.
- Two short activities used by "A minute for you" are also listed here: **stillness** (one quiet minute with the orb, no instructions) and **savour** (replay one good moment from today).
- **Ephemeral.** Prompts only, with no text fields. Nothing is stored or synced except the content-free session record. Self-paced with "Next", usually 1–3 min, with no timer on screen.
- The F9 support sheet keeps its own bundled 60-second grounding. It never depends on Sanctuary state, sign-in or the network.

**Today's minute (Milestone A)**
- One suggested activity per Aura day at the top of Sanctuary, rotating through the library; Sounds join at B `[ASSUMPTION]`. It isn't based on mood ("A minute for you" handles that).
- One tap starts it. Skipping it changes nothing: there is no "missed" state, no streak and no push.

**Sounds (P1 · Milestone B)**
- **Base stems (free):** rain, ocean, wind, night insects, singing bowl, chimes and brown noise. Up to 4 play at once `[ASSUMPTION]`, each with its own volume. Favourite mixes are saved on the device.
- **Audio source (AK, 23 Sep 2026):**
  - Licensed CC0 or royalty-free field recordings for the base stems.
  - Procedural layering on top: random loop points, crossfades, and chimes and bowl strikes timed in code.
  - Brown noise is synthesized on the device.
  - A licence log (source, licence, date) is kept for each stem; no per-play licences.
- **Aura Plus adds extra stems and themes** ("more of", F12). Base stems and the night wind-down are never paywalled.
- **Timer:** 15, 30 or 60 min, or off `[ASSUMPTION]`. The sound fades out over 30 s.
- **Night wind-down:** a ~20-min `[ASSUMPTION]` procedural sequence of base stems that thins out to silence. Its order is reshuffled each Aura day so it doesn't turn into background noise. No narration in v1.
- **Silent until chosen:** opening Sanctuary or Sounds plays nothing. Sound starts on a tap and fades in over ≥ 2 s.
- **Background playback** continues with the screen locked (iOS `UIBackgroundModes: audio`; Android media-playback foreground service).
  - Lock-screen and notification controls read only "Aura · Sounds". Stem names are hidden because "Rain" is also a quadrant.
  - Disconnecting headphones pauses playback; it never switches to the speaker. A phone call pauses it too.
- **Offline.** The recorded base stems download once, on first use (≈ 8 MB in total `[ASSUMPTION]`; the size is shown first). Brown noise needs no download. Plus stems download when first picked. Everything is cached, and Settings has "Remove downloaded sounds".
- **No microphone** anywhere in Sanctuary; nothing is recorded.
- **F12 paywall rules apply.** On Free, tapping a Plus stem shows the Plus explainer. Straight after a Storm or Rain check-in, or in a crisis flow, it shows only "Part of Aura Plus".

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-SAN-01 | P0 | Breathe pacer with three patterns | Calm 4/6 is the default; box and 4-7-8 are one tap away. Over 5 min, each phase change happens within ±50 ms of the engine's time `[ASSUMPTION]`. Negative: no score, breath count, rating or leaderboard exists. |
| REQ-SAN-02 | P0 | Haptics obey Comfort | Haptics on: one pattern per phase. Comfort › Haptics off, or system haptics off: none fire, and the visual and text rhythm is unchanged. |
| REQ-SAN-03 | P0 | Reduce Motion | With OS or Comfort Reduce Motion on, the orb is still and phase words plus haptics carry the rhythm. Negative: nothing scales, drifts or flashes. |
| REQ-SAN-04 | P0 | ≥ 60 s completes Breathe | A 60 s session logs Breathe once for the Aura day; a 59 s session (pauses excluded) logs nothing. Negative: a second session the same day adds no Starlight, and a hidden Breathe habit is never logged. |
| REQ-SAN-05 | P0 | Grounding is ephemeral | 5-4-3-2-1, hand-on-heart, gratitude, stillness and savour have no text input. Negative: after each one, the local DB, the outbox and a network capture hold no content, only the session record. |
| REQ-SAN-06 | P0 | Today's minute | One suggestion per Aura day, the same all day, started with one tap. Negative: no "missed" state, streak or push is tied to it. |
| REQ-SAN-07 | P0 | Offline and private | Breathe, grounding and Today's minute work in airplane mode. Negative: no Sanctuary screen shows other people, counts or presence. |
| REQ-SAN-08 | P0 | Help always reachable | "I need help now" is within the first 3 focus stops on Sanctuary and every activity; opening it pauses the pacer. |
| REQ-SAN-09 | P1 | Sounds are silent until chosen | Opening Sanctuary or Sounds plays nothing; audio starts only after a tap and fades in over ≥ 2 s. Negative: nothing autoplays anywhere in the app. |
| REQ-SAN-10 | P1 | Background playback, timer, interruptions | Sound plays with the screen locked, and the timer fades it out and stops it. Headphones disconnecting or a phone call pauses it. Lock-screen and notification controls show only "Aura · Sounds". Negative: playback never moves from headphones to the speaker by itself. |
| REQ-SAN-11 | P1 | Offline after one download | After the one-time download, every base stem and the night wind-down play in airplane mode. Brown noise plays offline on a fresh install. |
| REQ-SAN-12 | P1 | Free base set; no claims; no microphone | On Free, every base stem, mix and the night wind-down play with no paywall. The copy lint rejects "binaural", "heal", "cure", "treat", "therapy", "clinically" and sleep or health outcome claims. Negative: Sanctuary never requests the microphone. |
| REQ-SAN-13 | P1 | Night wind-down changes nightly | Two consecutive Aura days give two different stem orders; the same day always gives the same order. Negative: no narration or voice track. |

**Edge cases & states**
- **Call, alarm or app sent to the background mid-Breathe:** the pacer pauses while Sounds keep playing. The user can resume or finish. If 60 s were already done, the habit is already logged.
- **Breathe while resting in the Nebula:** finishing it logs Breathe, which fires `wakeUp` (F2).
- **Low-end phones:** the orb uses the Low or Still tier (F2).
- **Storage full:** "Sounds need about 8 MB. Free some space, or play brown noise, which needs none."
- **Two devices:** Breathe credit is still once per Aura day per account (server rules).

**Under-18 users:** identical. Invisible only: excluded from behavioural analytics.

**Post-v1 (P2):**
- Narrated wind-down (needs voice talent in several languages).
- Pathways, 5–7-day series (see Out of Scope).
- Custom breathing patterns.
- Watch haptics.
- Sounds in the widget or a Live Activity.

### Companion response and "A minute for you" (F2 + F1)

**P0 · Milestone A.** Finch's strength is a companion that responds. Aura's avatar drifts with the 14-day mood mix, but it doesn't react to the check-in just made, and nothing is offered in that moment. These two additions make every save feel answered, equally for every feeling.

**Saved-moment order** (updates F1):
1. The crisis sheet, if the note matched the lexicon (F9).
2. A mood-trigger capsule, if one fires (F4). It is held if the check-in was crisis-flagged.
3. Starlight and the companion response.
4. "A minute for you" (skipped after a crisis sheet) and the room offer (F5).

**Companion response**
- After each saved **live** check-in (not backfills or widget saves), the avatar plays a **≤ 2 s shimmer tinted with the check-in's quadrant**, then shows **one warm line** from a localized pool.
- **Equal warmth:**
  - The same duration, brightness and line length for all four quadrants.
  - Pools of equal size: ≥ 8 lines per quadrant per language at A `[ASSUMPTION]`.
  - No line repeats within the last 5 `[ASSUMPTION]`.
- **Voice:** second person, plain words, low reading level. The avatar *is* the user (F2), so lines never speak as a separate friend ("I missed you").
- **Never:**
  - Advice ("you should", "try to").
  - Diagnosis or clinical words.
  - Cheerleading ("cheer up").
  - Questions that dig ("why?").
  - Promises ("it will be fine").
- **Draft lines** (native review pending):

| Quadrant | Line |
|---|---|
| Storm | "That's a lot at once. Your light is still here." |
| Rain | "Heavy evenings happen. You showed up for yourself anyway." |
| Moonlight | "A quiet glow tonight. Stay as long as you like." |
| Sunrise | "Bright one. Keep a little of this for later." |

- **After a crisis sheet**, the line comes from a small neutral pool that is the same for every quadrant (e.g. "Thank you for checking in tonight.") `[ASSUMPTION]`.
- **Reduce Motion:** the avatar stays still. The line crossfades in (≤ 300 ms), and the screen reader announces it.
- **One moment at a time.** If the check-in also wakes the avatar (`wakeUp`) or crosses a stage (`evolve`), that moment replaces the shimmer, and its line is the only one shown. The response is a one-shot moment keyed by the check-in id: it plays once, and edits and syncs don't replay it.

**"A minute for you"**
- One optional card after Save, next to the room offer. Every quadrant gets one, with the same size, position and visual weight.

| Quadrant | Offer | Activity |
|---|---|---|
| Storm | 30-second grounding | Three slow breaths with the orb (Calm 4/6); "Keep going" opens Breathe |
| Rain | Gentle comfort | Hand-on-heart at A; a soft base sound as an option from B |
| Moonlight | Stillness | One quiet minute with the orb |
| Sunrise | Savour | Replay one good moment from today |

- **Never replaces the crisis sheet or appears before it,** and never shows after a check-in that showed the sheet.
- **Low-key:**
  - It never starts on its own, and one tap dismisses it.
  - It earns no Starlight of its own. The Breathe habit rule applies only if the user breathes for ≥ 60 s.
  - It uses base content only, so it never leads to a paywall.
  - It works offline.

| ID | Pri | Requirement | Acceptance criteria |
|---|---|---|---|
| REQ-CMP-01 | P0 | Avatar responds to every live check-in | A ≤ 2 s shimmer in the check-in's quadrant tint, then one line. Duration and brightness are identical for all four quadrants. Negative: no quadrant gets a longer, brighter or "happier" reaction. |
| REQ-CMP-02 | P0 | Reduce Motion | With Reduce Motion on, there is no shimmer; the line crossfades in ≤ 300 ms and the screen reader announces it. |
| REQ-CMP-03 | P0 | Line rules | Pools are localized (en, te, te-Latn at A; hi, hi-Latn at B) and equal in size per quadrant. A copy lint rejects advice and diagnosis words ("should", "try", "calm down", "cheer up", "anxiety", "depressed", "disorder", "because"). Negative: no line suggests a feeling is wrong or needs fixing. |
| REQ-CMP-04 | P0 | After a crisis sheet | The line comes from the neutral pool and "A minute for you" is not shown. The room offer still follows (REQ-CHK-04). |
| REQ-CMP-05 | P0 | A minute for every quadrant | Storm, Rain, Moonlight and Sunrise each get their card (table above) at the same size and position. Negative: the card never starts on its own and never opens a paywall. |
| REQ-CMP-06 | P0 | Saved-moment order | UI tests cover every combination of crisis sheet, firing capsule and wake/evolve, and the order above always holds. Negative: nothing appears before the crisis sheet. |
| REQ-CMP-07 | P0 | Offline, once per check-in | The response and the minute card work in airplane mode (lines are bundled). Negative: syncing, editing or a second device never replays the response. |

**Edge cases & states**
- **Widget check-in:** no response in the widget, and nothing replays at the next app open.
- **Backfill:** no response, minute card or room offer; just "Added to your sky" `[ASSUMPTION]`.
- **Several check-ins in a day:** the card shows each time and one tap dismisses it.

**Under-18 users:** identical. Invisible only: excluded from behavioural analytics.

**Post-v1 (P2):** seasonal and festival line sets per locale.
