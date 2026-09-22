# Aura: Product Requirements Document

**Asan Innovators** | Prepared by: Kalyan Kumar Bedugam (AK) | *Building Beyond Boundaries*

| | |
|---|---|
| **Product** | Aura: social and gamified mood check-in app (iOS + Android) |
| **Owner / publisher** | **AKVega** (company App Store + Play accounts; data fiduciary / controller) |
| **Document** | PRD v1.1 (all open questions answered by AK) |
| **Date** | 23 Sep 2026 |
| **Status** | Decisions locked; ready for build planning |
| **Sources** | Market research, competitor analysis and 1M-download blueprint (Google Docs); store and regulatory fact-check of 23 Sep 2026 (`docs/research/`) |

### TL;DR
- **What:** a calm, pseudonymous app. You check in with how you feel in 2 taps, grow a celestial avatar that never dies or regresses, and feel less alone in 24-hour mood rooms where strangers who feel the same share silent gestures and short moderated reflections. You can also breathe together in a no-fail co-op game and write capsules to your future self.
- **Who:** everyone **13+**, with full access and one shared pool. Core audience: Indian students and young professionals, **Telugu/Tenglish-first**, then Hindi/Hinglish. Available **worldwide** (EU, UK and Australia open at beta).
- **Why now:** incumbents are either solo trackers (Daylio) or friends-only (Finch). No one offers low-pressure *stranger* support without chat.
- **v1 scope:** research Phase 1–2 in full (F1–F9 at P0, F10–F14 at P1), built solo by AK on Flutter + Supabase + NestJS/BullMQ. The avatar is AK's AI-generated celestial character, animated in code.
- **Dates:** start **5 Oct 2026**, closed alpha **w/e 10 Jan 2027**, open beta **w/e 2 May 2027**, public launch **30 Sep 2027**.
- **Biggest risks:**
  1. **Legal: no parental consent for under-18s, and mixed-age rooms.** This is AK's accepted risk; see F8 and Technical Constraints.
  2. **App Store:** Apple's rule against "random/anonymous chat" apps.
  3. **Moderation:** one moderator (AK) until 5,000 DAU, with OpenAI moderation only.
  4. **Empty rooms** at small scale.

### Decision log
| # | Decision | Made by | Status |
|---|---|---|---|
| D1 | v1 = research Phase 1–2 in full (incl. reflections + one co-op game) | AK | Locked |
| D2 | **13+ with full access, no parental consent, one mixed-age pool**; under-13 blocked. Invisible protections only (see F8/F9) | AK (revised; risk explained and accepted) | Locked |
| D3 | AK builds solo; **avatar = AK's AI-generated character art + code-animated layers** (no animator); lawyer engaged week 0 | AK | Locked |
| D4 | **Worldwide from alpha, except EU/UK/Australia until beta**; AKVega owns and publishes | AK | Locked |
| D5 | Flutter + Supabase + **NestJS modular monolith + Redis/BullMQ from day one**; **own receipt validation in NestJS** (no RevenueCat); PostHog Cloud; min iOS 16 / Android 7 | AK | Locked |
| DS-1…10 | Data-shape decisions (see Data Model) | AK | Locked |
| Q-series | All open questions answered (see Decision Record) | AK | Closed; items waiting on a lawyer or CA listed there |

**Tags used in this document:** `[ASSUMPTION]` = default to tune in alpha · `[LEGAL]` = needs the lawyer's opinion · `[STORE]` = depends on App Store / Play policy or console settings.
