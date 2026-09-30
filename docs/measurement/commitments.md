# Do habit commitments help? (W07)

Commitments (RULES.md §13) let an adult opt a habit into reversible decay in their world. This note says how we find out
whether that is good for people, what the numbers can and cannot show, and what we decide from them before we see them.

Where to look: **Admin console → Stats → "Habit commitments: do they help?"** (Owner and Read-only analyst). It calls
`public.commitment_outcomes()`. Nothing is sent to PostHog or any analytics tool: this is computed from Postgres, which
the analytics plan (PRD 13) already names as the source of truth for counts.

## Why not just compare people who commit with people who don't

They are different people. Someone who opts into a commitment was already more motivated, so "committers come back more"
proves nothing. The measurement therefore compares **each person with themselves**:

- a habit under a commitment against the **same person's other habits**, over the **same days**;
- only people who have committed at least once, so the comparison is between their own habits;
- adults only (commitments do not exist under 18), and no cell is shown for fewer than **20 people**.

## The four measures

| Measure | Reads as | Good direction |
|---|---|---|
| `recovery_7d` | After a habit goes unlogged for two full days, the share logged again within 7 days | higher for committed |
| `lapse_14d` | After the same episode, the share followed by **14 days with no habit log and no active day at all** | **not higher** for committed |
| `logs_14d_change` | Logs in the 14 days after committing minus the 14 days before, committed habit vs the person's other habits; `difference` is the within-person gap | positive |
| `ended_30d` | Commitments ended within 30 days of starting | low |

`lapse_14d` is the guardrail. A commitment that nudges someone into leaving Aura altogether is a failure even if the
habit itself improves. There is no way to see uninstalls from the server, so "did they disappear" is the closest honest
proxy.

## What the numbers cannot show

- **Not proof of cause.** It is a within-person comparison, which removes "motivated people opt in", but people often
  commit after a burst of enthusiasm or a lapse, so before/after can move for reasons unrelated to the commitment
  (regression to the mean). The control habits over the same days absorb part of that, not all.
- **Pauses are not recorded**, so an episode that happened during a person-chosen pause counts as decay-eligible.
  This slightly understates recovery for committed habits.
- **Dates:** a commitment's end is stamped with the server's UTC date, not the person's Aura day (off by at most one day).
- **Presets** get their habit row the first time they are used, so a preset created after the 14-day window is not used
  as a control (conservative).
- **Small cells.** Under about 100 people a difference is noise. The console hides cells under 20; do not act on
  anything under 100.

## Decisions, fixed before we look

These are starting points chosen by the developer, not industry benchmarks. Change them deliberately, before reading the
results, and write the change down.

Wait until **at least 100 people** have contributed to a measure and commitments have been live for **8 weeks**, then:

- **Promote it** (show Commitments more prominently, mention it in onboarding) only if **all** hold:
  `logs_14d_change` difference **≥ +0.5** logs per 14 days, `lapse_14d` committed is **no more than 3 points above**
  control, and `ended_30d` is **under 40%**.
- **Pause it** (hide the Commitments section with a remote flag; nothing is lost, plants keep their stage and just stop
  resting) if `lapse_14d` committed is **more than 5 points above** control with 100 or more people, or if
  `logs_14d_change` difference is **zero or negative** with 200 or more people.
- **Anything in between:** leave it opt-in exactly as it is and keep watching. No promotion, no removal.

If the within-person picture stays ambiguous, the clean next step is a randomized offer: show the Commitments section to a
random half of adults (a remote-config flag plus a stable per-install bucket) and compare the halves. That is a product
and privacy decision (a person would not see a feature others do), so it is not built.

## What is stored

`habit_commitment_events` holds only `start` or `end`, a day, and a habit id, written by a trigger on `habits`. It has no
habit name, no notes, no mood. It is deleted with the account and is included in the server half of the data export
(`commitmentHistory`, dates only). Clients cannot read it.
