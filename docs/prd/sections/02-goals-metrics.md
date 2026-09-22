## Goals & Success Metrics

### Goals
**User goals**
1. **Feel less alone, in under a minute a day.** At least 60% of room visitors answer "yes" to *"Did you feel a little less alone?"* (asked on 1 in 5 room exits).
2. **Build a self-care rhythm without guilt.** Users who hit a gap come back: 40% of users who enter Resting Nebula check in again within 7 days.
3. **Get perspective on hard days.** At least 30% of users who seal a mood-trigger capsule see it open within 60 days, and 70% of openings are rated "helpful" or better.

**Business goals**
4. **Prove retention before scale.** Hit D30 ≥ 10% in the open beta (India cohort). This gates public launch spend.
5. **Prove India will pay small amounts.** Paid conversion ≥ 2% of MAU within 60 days of monetization launch, with gross ARPPU ≥ ₹55/month (≈ 72% of that reaches Asan after GST and store fee; see F12).
6. **Stay safe at small-team scale.** Zero unresolved crisis-flagged items older than 1 hour, and reports below 5 per 1,000 room visits.

### North Star metric
**Weekly Supported Users (WSU)**: users who check in on **≥ 3 days** in a week **and** have **≥ 1 social moment** (gesture given or received, reflection published, or Breath Ripples session completed).

It captures both halves of the value: the personal habit and the "not alone" moment. It can't be pushed up by spammy notifications alone, because a social moment needs another person.

### Leading indicators (days to weeks)
| Metric | Definition | Success | Stretch | Measured |
|---|---|---|---|---|
| Onboarding completion | Install → first check-in saved | ≥ 70% | ≥ 80% | Daily, PostHog funnel |
| Check-in speed | Median time, mood-only check-in | < 5 s | < 3 s | Client timing event |
| Room conversion | Check-ins followed by a room visit within 10 min | ≥ 25% | ≥ 40% | Weekly |
| Gestures per visit | Gestures sent per room visit | ≥ 1.5 | ≥ 3 | Weekly |
| Reflection publish rate | Reflections published / submitted | ≥ 80% | ≥ 90% | Weekly. Low means over-blocking; expect lower in Telugu/Tenglish/Hinglish with OpenAI-only auto-moderation |
| Breath Ripples match time | p50 time to start (human or echo seats) | < 20 s | < 10 s | Daily |
| Human seat share | Share of Breath Ripples seats filled by humans (not echoes) | ≥ 30% at beta | ≥ 50% | Weekly |
| "Less alone" micro-survey | Yes / (Yes + No) | ≥ 60% | ≥ 75% | Weekly |

### Lagging indicators (weeks to months)
| Metric | Success | Stretch | Notes |
|---|---|---|---|
| D1 retention | 35% | 45% | Research doc's 45% target is used as the stretch goal |
| D7 retention | 18% | 25% | |
| D30 retention | 10% | 15% | Typical wellness apps sit far lower; Finch-level retention is the outlier |
| DAU/MAU | 25% | 30% | |
| Paid conversion (India) | 2% of MAU | 5% | Research doc claims 6.5–10.5%, which is unproven |
| Monthly ARPPU (India, gross) | ₹55 | ₹90 | ₹49 Plus + occasional cosmetics. Net ≈ 72% after GST and the 15% store fee |
| K-factor | 0.15 | 0.3 | Research doc's K > 1.1 assumes hard invite gates, which don't fit a pseudonymous app |
| App store rating | ≥ 4.5 | ≥ 4.7 | Both stores |

### Guardrail metrics (must not get worse)
| Guardrail | Threshold | Why |
|---|---|---|
| Reports per 1,000 room visits | < 5 | Early warning of a toxic room culture |
| Crisis-flagged items actioned | < 15 min during Lantern Hour, < 1 h otherwise | Duty of care |
| All reports actioned | < 24 h | Indian IT Rules grievance timelines are stricter for some categories `[LEGAL]` |
| Reports involving an under-18 account | Actioned < 4 h; grooming or sexual-content-involving-minor cases: instant ban + evidence + report per SOP, **100%** | Mixed-age rooms (D2) make this the key child-safety guardrail |
| Held reflections waiting > 12 h | < 5% of held items | One moderator (AK) until 5,000 DAU; a growing backlog is the signal to hire early |
| Notification opt-out rate | < 15% of notification-enabled users per month | Too many nudges is a form of pressure |
| Uninstall within 24 h of a streak ending | Lower than the D1 uninstall baseline | Checks that the non-punitive design actually works |

### Measurement notes
- All product targets are measured on **18+ users only**. Under-18 users (by stored DOB) are excluded from behavioural analytics (see Analytics & Tracking Plan); their safety guardrails are tracked server-side as non-identifying aggregates. Retention and conversion are reported separately for the **India cohort** and the **rest of world**.
- Evaluate at **Milestone A + 4 weeks** (alpha: qualitative plus D1/D7), **Milestone B + 30 days** (beta: D30, conversion, safety), and **Milestone C + 90 days** (launch).
- **Single-moderator exception (until 5,000 DAU):** AK is the only moderator, so the < 1 h crisis SLA applies 8 am–11 pm IST. Overnight, safety is automatic: crisis items are never published and the author sees the support sheet at once, and uncertain reflections are held (fail-closed). **Government/court orders (3 h) and nudity/CSAM grievances (2 h) page AK 24×7 from day one.** Hitting 5,000 DAU triggers the first moderator hire.
- **Kill/pivot signals:** if room conversion stays < 10% after 4 weeks of beta, the stranger layer isn't pulling its weight, so revisit the matching and entry points before adding more social features. If D30 < 6% at beta, fix the core loop before any paid acquisition.
