## Notification & Communication Strategy

Notifications offer a quiet minute; they never pull people back through guilt or pressure. Many users share or lend their phones (Riya in a hostel, anyone living with family), so **nothing on a lock screen may reveal how someone feels**. The same rules apply to every account, whatever the age.

**Ship order `[ASSUMPTION]`:** daily reminder and date-capsule push at Milestone A; trial-ending reminder with the F12 free month; the rest with F14 at Milestone B. Smart timing is P1. BullMQ delayed jobs in the NestJS worker schedule by the device time zone (refreshed on each open).

### Catalogue

Channels: **Push** (FCM/APNs) · **In-app** (card or banner while Aura is open) · **Widget** (F11) · **Email** (trial-ending reminder only, and only if the account has a verified email `[ASSUMPTION]`).

| Notification | Trigger | Channel | English | Tenglish (`te-Latn`) | Cap | Pri |
|---|---|---|---|---|---|---|
| Daily check-in reminder | User-chosen time (suggested 8 pm `[ASSUMPTION]`); skipped if already checked in | Push + widget glow | "A quiet minute for you. How's today feeling?" | "Mee kosam oka quiet minute. Ee roju ela anipistondi?" | 1/day | P0 |
| Habit nudge (opt-in) | Time set per habit | Push | "Small one: a glass of water?" | "Chinna pani: oka glass neellu?" | 1/day, due habits bundled | P1 |
| Date capsule unlocked | Unlock date; sent at reminder time or 10 am local | Push + widget badge | "Something you sealed is ready to open." | "Meeru daachukunnadi ippudu open cheyyochu." | 1/day | P0 |
| Mood-trigger capsule | Next matching check-in | **In-app only** | "You left a note for a moment like this. Open now or later?" | "Ilanti moment kosam meeru oka note raasukunnaru. Ippude open cheyyala, tarvatha na?" | 7-day cooldown (F4) | P0 |
| Gestures received | Gesture sent to you in a room | Push (batched) + in-app | "3 people in your room sent you warmth." | "Mee room lo 3 mandi meeku warmth pampaaru." | **1 push per room per day** | P1 |
| Lantern Hour (opt-in) | When **the user's timezone region's** Lantern Hour starts (21:00 on the region clock, F5; e.g. 9 pm IST for `south_asia`). Up to ±2 h from the device's own 9 pm | Push | "Lantern Hour is on. Others are here tonight." | "Lantern Hour modalaindi. Ee raatri inka kondaru ikkade unnaru." | 1/day; skipped if already in a room today | P1 |
| Breath Ripples invite | "Breathe together" tapped in your room | **In-room banner only** | "2 people are about to breathe together. Join?" | "2 mandi kalisi breathe cheyyabotunnaru. Join avutaara?" | 1 per session | P0 |
| Welcome back | 7 days inactive; again at day 21 | Push | "No catch-up needed. Aura is here whenever you want a quiet minute." | "Catch-up emi avasaram ledu. Meeku eppudu kaavalante appudu Aura ikkade untundi." | **2 per absence, then silence** | P1 |
| **Aura Plus trial ending** | **48 h before the free month ends** (validated store state in NestJS), outside quiet hours | Push + in-app card + email | "Your free month of Aura Plus ends on {date}. After that it's {price}/month. Keep it or cancel anytime." | "Mee Aura Plus free month {date} tho aipotundi. Tarvatha nelaki {price}. Continue cheyyochu, leda eppudaina cancel cheyyochu." | **Once per account**; exempt from daily cap | P0 once the trial ships |
| Billing issue | Store server notification validated in NestJS | **In-app banner only**; receipts are store-handled | "Your Aura Plus payment didn't go through. Everything you've made is safe." | "Aura Plus payment jaragaledu. Meeru chesinavanni safe ga unnayi." | No push | P1 |
| Moderation outcome | Reflection held/rejected, strike | **In-app inbox only** | "Your reflection wasn't posted because it had a phone number. Edit and try again?" | "Mee reflection post kaaledu, andulo phone number undi. Edit chesi malli try chestara?" | Per event | P0 |
| Crisis follow-up | Support sheet shown 12–72 h ago | **In-app card on next open only** | "Just checking in. However today feels, help is one tap away." | "Oorike adugutunnam, ee roju ela undi? Help oka tap dooram lo undi." | Once per event | P0 |

**Telugu script and Hinglish drafts** for the highest-volume lines:

| Line | Telugu (`te`) | Hinglish (`hi-Latn`, from beta) |
|---|---|---|
| Daily reminder | మీ కోసం ఒక నిమిషం. ఈ రోజు ఎలా అనిపిస్తోంది? | Ek minute apne liye? Aaj kaisa feel ho raha hai? |
| Lantern Hour | Lantern Hour మొదలైంది. ఈ రాత్రి ఇంకా కొందరు ఇక్కడే ఉన్నారు. | Lantern Hour shuru. Aaj raat aur log bhi yahin hain. |
| Trial ending | మీ Aura Plus ఉచిత నెల {date}తో ముగుస్తుంది. తర్వాత నెలకు {price}. కొనసాగించవచ్చు, లేదా ఎప్పుడైనా రద్దు చేయవచ్చు. | Aura Plus ka free month {date} ko khatam hoga. Uske baad {price}/month. Continue karo ya kabhi bhi cancel karo. |

All non-English lines are drafts for native review. Telugu uses the respectful *meeru* form; Hinglish avoids gendered verb forms (see Localization).

### Trial-ending reminder rules `[STORE]` `[LEGAL]`

Follows the **CCPA Guidelines for Prevention and Regulation of Dark Patterns, 2023** (no subscription trap, false urgency, confirm shaming or nagging) and store rules:
- **Facts only:** end date, the store's localized price string (never a hard-coded ₹49) and billing period. Transactional, never marketing: no offers, no "lose your perks" (App Review 4.5.4).
- **One tap to cancel:** push, card and email open the store's own subscription page (`showManageSubscriptions` on iOS; Play subscriptions deep link), with no retention screen or survey in between.
- Discreet mode applies to the push; the card and email still carry date and price. The card shows at most once a day in the final 2 days.
- **Not sent** if auto-renew is already off; instead a one-time in-app note: "Plus stays on until {date}. You won't be charged." RBI e-mandate pre-debit notices come from the store as merchant of record `[STORE]`.

### Why some items are never pushed

- **Mood-trigger capsule:** the user is already in the app, and a push would put the mood on the lock screen. The card always offers "Later"; after a widget check-in it waits for the next app open; a crisis sheet from the same check-in comes first.
- **Breath Ripples invite:** echoes fill seats after 20 s, so a push arrives too late and only creates a missed-it feeling.
- **Crisis follow-up:** no push ever mentions distress. (1) In shared households a lock-screen line like "Checking on you after last night" invites the family questions users came to Aura to avoid. (2) An unexpected reminder can re-trigger distress. (3) A push implies Aura is monitoring and will act; **Aura is not an emergency service** `[LEGAL]`. (4) Push is not reliable enough to be a safety channel. The in-app card is private, dismissible and carries "I need help now" plus locale helplines; the daily reminder keeps its usual time and wording.
- **Moderation outcome:** "Your post was removed" on a lock screen is shaming.

### Global rules

1. **Quiet hours 11 pm–8 am local** by default for everyone, editable. Nothing system-initiated is sent inside them. A reminder the user deliberately schedules inside quiet hours (night-shift workers) is honoured after a one-time confirmation.
2. **Max 2 pushes per day**, all types combined. Precedence when capped: capsule unlocked > daily reminder > gestures > Lantern Hour > habit nudge > welcome back. Dropped items stay as in-app cards. The trial-ending reminder is exempt (it fires once per account).
3. **Payloads carry no mood or content**: only a type, an opaque ID and generic copy. Never a mood, quadrant, room theme name ("Rain Sanctuary" reveals the quadrant), capsule or reflection text, pseudonym or habit history. The app fetches details after unlock. Android uses `VISIBILITY_PRIVATE` with a generic public version; iOS uses a generic hidden-preview placeholder.
4. **Discreet mode** ("Aura · You have a gentle update" for every push): available to everyone, off by default, offered as a one-tap choice on the permission screen `[ASSUMPTION]`.
5. **Widget** shows the avatar and a "Check in" button; the last mood only if the user opts in.
6. **Permission is asked in context**, after the first check-in when the user picks a reminder time, never at install. After a decline, no re-ask for 30 days.
7. **Smart timing (P1):** reminder ignored 5 days in a row → every other day; 14 ignored days → stop and leave it to welcome-back. Any check-in restores the schedule.
8. Per-type toggles plus a master switch in Settings > Notifications. Copy follows the app language and is rendered server-side from the shared key catalogue.
9. Events `notification_sent`, `notification_opened`, `notification_setting_changed` are sent for 18+ accounts only; under-18 accounts are counted in aggregate only.

### Banned copy patterns

| Pattern | Banned | Instead |
|---|---|---|
| Guilt | "You haven't checked in for 3 days" | "A quiet minute is here if you want it" |
| Loss or decay | "Your Aura is fading" | Never mention loss; the avatar only rests |
| Streak threats | "Don't lose your 12-day streak!" | No streak pushes at all (F3) |
| "We miss you" pressure | "We miss you! Come back" | "No catch-up needed" |
| Mood on lock screen | "Still feeling anxious?" | Generic copy only |
| Social pressure or urgency | "Quiet Comet is waiting" / "Only 2 hours left!" | Counts without names; no countdowns |
| Billing pressure | "Last chance! Don't lose your Plus perks" / "Sure you want to give up on yourself?" | Plain date, price and a one-tap manage link |

### Requirements

| ID | Behaviour | Acceptance criteria | Pri |
|---|---|---|---|
| REQ-NTF-01 | Copy lint on push templates | CI rejects any template (all five languages) containing a mood, quadrant or room theme name, or miss, lose, streak, broken, fading, last chance, hurry | P0 |
| REQ-NTF-02 | Cap, quiet hours, private payloads | A third push in one local day is never sent (trial reminder excepted); payloads hold only type, opaque ID and generic copy. Negative: no system push fires 11 pm–8 am local unless the user scheduled it there | P0 |
| REQ-NTF-03 | Trial-ending reminder | Given a free month ending 3 Nov, push and card arrive on 1 Nov with date, store price and a one-tap store manage link. Negative: not sent when auto-renew is already off | P0 (with F12 trial) |
