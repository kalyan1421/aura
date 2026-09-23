## Overview

### Problem
Young Indians are under heavy, constant emotional load (competitive exams, first jobs in new cities, hostel and PG life, loneliness) and have almost nowhere safe to put it. Therapy is scarce and expensive (research doc: fewer than 0.75 psychiatrists per 100,000 people, ₹1,500–₹4,000 per session) and heavily stigmatised (*"log kya kahenge"*). Identity-linked social apps punish vulnerability, and the wellness apps that exist fail in one of two ways:

- **Solo trackers (Daylio, Bearable)** leave you alone with your feelings. When a bad week hits, logging stops, streaks break, and the empty calendar makes you feel worse, so you uninstall.
- **Gamified apps with group mechanics (Habitica, Forest)** add friends but punish the whole group when one person slips, which creates guilt spirals for exactly the people who most need support.
- **The closest incumbent (Finch)** is warm and non-punitive but only connects you with friends you already have. There's no way to feel understood by someone who feels the same way right now.

**Cost of not solving it:** people carry stress alone until it becomes a crisis. For the business, the whitespace is being approached from both sides: Finch could add stranger features, and chat-first entrants (e.g. YourSecret, Mar 2026) and Indian players such as Amaha are active in the space.

### Solution
**Aura** is a calm, pseudonymous iOS + Android app built around one loop:

> **Check in (2 taps) → your avatar glows → you're not alone → come back tomorrow.**

1. **Check in** with how you feel in under 5 seconds (F1).
2. **Grow your Aura**, a procedurally rendered celestial avatar that *is you*. It evolves as you look after yourself and **never dies or regresses**; on hard days it rests in a protective nebula (F2, F3).
3. **Sit with strangers who feel the same**: a 24-hour mood room, matched by mood, language and local evening, where people send silent gestures (a warm chai, a candle, "me too") and short, moderated reflections. There are no profiles, no DMs and no follower counts (F5, F6).
4. **Breathe together**: a 3-minute co-op breathing game with strangers. It has no score and no fail state (F7).
5. **Write to your future self**: time capsules that open on a date, or the next time you feel a certain way (F4).
6. **Settle on your own**: a private Sanctuary with a haptic breathing pacer, grounding exercises and offline soundscapes, for nights you don't want company. After each check-in, your avatar answers with one warm line and offers an optional minute of calm (F15, F2).

Safety is designed in without limiting anyone: crisis routing (Tele-MANAS / 988 / local emergency), a fresh pseudonym per room, no private messaging, moderation of every piece of stranger-visible text, stricter automatic checks on anything involving under-18 accounts, and instant ban plus mandatory reporting for grooming or sexual content involving minors (F8, F9).

### Target users
| Segment | Who | Why they come | Priority |
|---|---|---|---|
| **College students (18–24)** | Engineering, medical and diploma students in Telangana/AP and other Indian cities; Telugu/Tenglish or English speakers | Exam stress, homesickness, no private space to talk | **Primary** (personas: Riya, Sai) |
| **Early-career professionals (22–30)** | First job, moved cities, living alone | Burnout, loneliness; will pay small amounts | Secondary (Arjun) |
| **Teens (13–17)** | JEE/NEET/board-exam students | Extreme pressure, little privacy. **Full access, no parental consent** (D2) | Secondary (Meera) |
| **Global English speakers** | Anyone 13+ outside India (EU/UK/AU from beta) | Same need for low-pressure support | Opportunistic; no dedicated GTM in v1 |

### What makes Aura different (one line each)
- **Stranger connection without chat**: empathy through gestures, not conversation.
- **Non-punitive by construction**: nothing you care about is ever taken away.
- **Co-op calm play**: shared activity with no failure and no competition.
- **Telugu-first, India-native**: Telugu, Tenglish, Hindi and Hinglish; UPI-backed store billing; ₹10–₹99 price points; a first month of Plus free; Tele-MANAS in the crisis flow.

### What Aura is not
Aura is **not therapy, not a diagnostic tool and not an emergency service**. It's a daily emotional check-in and peer-presence space. That line shapes copy, store listings and what the moderator does (see F9 and the Technical Constraints section).

### Source material
This PRD is built from three research documents supplied by AK: (1) *Global and Indian Market Research Analysis: Social and Gamified Mood-Tracking Ecosystems* (main source; saved at `docs/research/market-research.md`), (2) *Aura App: Top 10 Competitors & Unique Features Analysis* (a subset of doc 1's competitor section), and (3) *Blueprint for 1M+ Downloads* (four other app concepts; used here for the Flutter architecture and growth-loop thinking only). Market-size and competitor revenue figures in those docs are secondary estimates and have **not** been independently verified. Store-policy and regulatory facts were checked separately (see Technical Constraints). All open questions were answered by AK on 23 Sep 2026 (see Decision Record). The same day AK approved the competitor-integration plan (`docs/competitor-integration-plan.md`), built from two further competitor documents he supplied; it added F15 Sanctuary, F16 Quiet Together and the companion response (PRD v1.2).
