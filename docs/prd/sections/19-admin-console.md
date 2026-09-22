## Admin & Moderation Console

**AK is the only moderator until 5,000 DAU** (Kabir's role); then the first hire joins. The console must let one person clear the queue quickly, page him for what cannot wait, and never show private data. **AKVega** is the data fiduciary; AK is Grievance Officer.

### Build recommendation

**A small internal Next.js app, server-rendered, that talks only to NestJS admin endpoints** (the `/admin` module of the monolith), behind Google Workspace SSO + enforced TOTP 2FA, on its own subdomain with no public sign-up, hosted beside NestJS in DigitalOcean Mumbai. About 2 weeks `[ASSUMPTION]`.

- **Not Supabase Studio** (no roles, queues, SLA timers or audit; every table visible; kept as Owner break-glass), **Flutter Web** (slow for dense tables) or **Retool** (content leaves Mumbai).
- **Access model:** the Next.js app holds no database credentials. Each action is a role-guarded NestJS endpoint running one transaction under a dedicated `aura_admin` Postgres role (no grants on private tables) that also writes the audit row. BullMQ runs SLA timers, paging and evidence snapshots. Staff accounts are separate from app accounts.

### Moderation pipeline

**Lexicon (on device, then server) → OpenAI omni-moderation (the only model) → human queue**, in the NestJS worker, **failing closed** (a provider error holds the item). Under-18-involved content gets stricter sexual, grooming and PII thresholds. Expect a higher held rate for Telugu, Tenglish and Hinglish; the dashboard shows it per pool. Decisions are kept as de-identified labels for a future in-house model (privacy notice, opt-out) `[LEGAL]`.

### Roles

| Role | Can | Cannot |
|---|---|---|
| **Owner** (AK) | Everything a Moderator can, plus device bans, config, flags, lexicons, staff roles, deletion, grievances, legal orders, mandatory reports | Read check-ins, notes, voice notes or capsules (no screen exists) |
| **Moderator** (first hire; defined now) | Work queues; approve, reject, shadow-mute, strike, suspend ≤ 7 days; escalate | Ban devices, change config, see email, phone or DOB, export data |
| **Read-only analyst** | Aggregate dashboards | See any content or user-level record |

### Queues and priority lanes

| Lane | Contents | SLA |
|---|---|---|
| **L0 Crisis** | Self-harm-flagged reflections (auto-held, never published); "someone may be in danger" reports | < 15 min in India's Lantern Hour; < 1 h otherwise (staffed hours) |
| **L1 Minors & grooming** | Any report or auto-flag involving an under-18 account (author, target or reporter, by stored DOB); suspected under-13; grooming signals from anyone (asks for age, photos, contact, meeting up) | **Sexual content or grooming involving a minor: < 2 h, pages 24×7.** Other L1: < 4 h `[ASSUMPTION]` |
| **L2 Harassment** | Hate, adult sexual content, threats, bullying, doxxing | < 24 h |
| **L3 Spam / other** | Promotion, gesture flooding, appeals | < 24 h |

Sorted by lane, then oldest first, with a live SLA timer. A high-confidence auto-flag for sexual content involving a minor also suspends the sender's social features until reviewed `[ASSUMPTION]`.

### Minors & grooming SOP `[LEGAL]`

On confirming sexual content involving or aimed at a minor, or grooming:
1. **Instant ban** of account and device in one action; no strikes.
2. **Evidence preserved 180 days** in `evidence_holds` (item, room context, pseudonym mapping, account and device IDs, timestamps), overriding the room purge.
3. **Mandatory report** under POCSO (police / Special Juvenile Police Unit) and the IT Rules (National Cybercrime Reporting Portal); NCMEC for US users `[LEGAL: confirm]`. Target 24 h. The ticket cannot close without `report_ref` or an Owner-recorded legal reason. Identifiers leave only via an audited Owner break-glass step in that ticket.
4. **No tipping off:** the banned user sees only "This account was closed for breaking Aura's rules". Nobody contacts the minor's family.
5. **Suspected under-13:** account closed, data deleted (evidence excepted), device locked 30 days `[ASSUMPTION]`.

Drafted with the lawyer in week 0; rehearsed before alpha.

### Single operator and on-call

- **Staffed hours 8 am–11 pm IST `[ASSUMPTION]`** carry the normal SLAs. **Overnight, safety is automatic:** crisis items are never published and the author sees the support sheet instantly; anything auto-moderation doesn't rate clean with high confidence waits until morning.
- **Non-negotiable 24×7 pages, no overnight exception, even at alpha:** court or government orders (3 h), nudity/CSAM and intimate-imagery grievances (2 h), and L1 sexual content or grooming involving a minor (2 h). **With one operator, these pages are the on-call.** Console PWA Web Push (iOS 16.4+) within 60 s → voice call at 5 min from a number on AK's Do Not Disturb allow-list `[ASSUMPTION]` → repeat every 5 min until acknowledged; weekly test page. Payload: lane, "minor involved" flag, wait time; never text. L0 alerts use the same channel in India's Lantern Hour or near SLA.
- **When AK will be unreachable** (flight, illness) he first turns on **reduced mode**: reflections paused, sign-ups throttled; check-ins, gestures and crisis support keep working `[ASSUMPTION]`. The 3 h legal-order window stays a known risk.
- **If p90 time-to-action misses SLA two weeks running**, tighten auto-hold thresholds or pause reflections in that pool; never relax SLAs `[ASSUMPTION]`. Queue sessions capped at 2 h.

### Item view and the privacy boundary

**Shows:** the item; omni-moderation scores and matched lexicon terms; room context (quadrant, language pool, timezone region, room age, other reflections in the room); reporter count and reasons; the author's room pseudonym, hashed internal ID, account age, strike history and an **"Under 18" flag** (never the DOB).

**Never shows:** check-ins, notes, voice notes, habits, Insights, capsules (encrypted), date of birth, email or phone. Enforced in the database (`aura_admin` has no grant on them), not just hidden in the UI.

### Actions and strikes

- **Approve** · **Reject** (reason code to the author's in-app inbox) · **Shadow-mute** 7 days, for trolls who escalate when told `[LEGAL — check notice duties]` · **Strike** · **Suspend** rooms, reflections and game for 24 h or 7 days (solo features keep working) · **Ban device** (Owner only; Apple DeviceCheck bits + Play Integrity, since vendor IDs reset on reinstall) · **Escalate**.
- **Strike policy:** 1 = warning + removal; 2 = 24 h reflection mute; 3 = 7-day room suspension; 4 = permanent ban. Strikes expire after 90 days. **Immediate ban:** sexual content involving or aimed at minors, grooming, credible threats, doxxing. **Self-harm expression is never a strike.**
- **Audit log:** every staff action, config or lexicon change, break-glass and login goes to an append-only, hash-chained table, exported nightly. Retention 3 years `[LEGAL]`.

### Crisis escalation workflow

**Aura is not an emergency service `[LEGAL]`.** The moderator confirms the item is held, the support sheet was shown and the next-day in-app check is queued; removes anything in the room that could harm others; records the outcome. The moderator **never** counsels, contacts the user off-platform, tries to identify or locate them, promises follow-up, or contacts family, at any age. **Exception:** a credible, specific threat to someone else, or a lawful order, goes to Owner, who decides with counsel what may be disclosed.

### Grievances and deletion `[LEGAL]`

Under the IT (Intermediary Guidelines) Rules, 2021 **as amended on 20 Feb 2026** (verified 23 Sep 2026; legal review still required):
- **Grievance Officer** (AK) published in-app and on the website; the in-app form and email both open a console ticket.
- **Acknowledge within 24 h; resolve within 7 days. Unlawful-content grievances: 36 h. Nudity / CSAM: 2 h. Non-consensual intimate imagery: 2 h** (both page 24×7). Replies state the right to appeal to the Grievance Appellate Committee.
- **Court or government takedown orders: 3 h.** Owner only; a dedicated L0-priority ticket type that pages AK 24×7.
- **Removed content preserved 180 days** in the restricted evidence store, overriding the 7-day room purge `[LEGAL: confirm period]`.

**Deletion:** self-serve in-app is the main route. Emailed or grievance requests are verified via a magic link to the account email; data deleted within 30 days `[ASSUMPTION]`, except records the law requires (hashed audit rows, evidence holds).

### Configuration

Room cap, lifetime, merge thresholds, timezone regions, Lantern Hour window (9–11 pm local) · gestures · pseudonym word lists per language plus an offensive-combination blocklist · **kill switches** (reflections per pool, Hindi + Hinglish pool, Breath Ripples, echoes, gifts, sign-ups, reduced mode) · **lexicons** per language and category incl. Tenglish and Hinglish variants: add, test on samples, publish signed, roll back · under-18 moderation thresholds. Removing a crisis term or loosening under-18 thresholds is Owner-only.

### First moderator hire at 5,000 DAU `[ASSUMPTION]`

Staffing follows **coverage hours, not volume**. The first hire is part-time, 6 pm–midnight IST (India's Lantern Hour), reads Telugu/Tenglish and ideally Hindi/Hinglish (which can open that pool), and is crisis-trained and background-checked before handling L1 `[LEGAL]`. Overnight pages stay with AK until a second person joins. Then one per further ~5,000 DAU, or sooner if p90 misses SLA two weeks running. Budget ₹15,000–₹25,000 per moderator per month.

### Requirements

| ID | Behaviour | Acceptance criteria | Pri |
|---|---|---|---|
| REQ-ADM-01 | Staff sign-in requires SSO + TOTP | SSO login without MFA is denied. Negative: an app user account cannot sign in | P0 |
| REQ-ADM-02 | Role permissions enforced in NestJS | A Moderator calling `POST /admin/devices/{id}/ban` gets 403, and the attempt is audited | P0 |
| REQ-ADM-03 | No private data reachable | CI grant test: `aura_admin` cannot select check-ins, notes, habits, capsules, Insights or `birth_date`; no admin endpoint returns them | P0 |
| REQ-ADM-04 | Priority lanes with SLA timers | A new L0 item sorts above all L1–L3 items and shows its timer | P0 |
| REQ-ADM-05 | Crisis phone alert | L0 item in India's Lantern Hour reaches Owner's phone within 60 s, repeats every 5 min until acknowledged; payload has no content | P0 |
| REQ-ADM-06 | Actions apply fast | Each action takes effect in the app within 10 s; a rejected author sees a reason code | P0 |
| REQ-ADM-07 | Strike automation | 4th active strike bans; 90-day-old strikes stop counting. Negative: a crisis-flagged item never adds a strike | P0 |
| REQ-ADM-08 | Immutable audit log | UPDATE/DELETE fails for every application role incl. `service_role` and `aura_admin` (grant revoked + blocking trigger) | P0 |
| REQ-ADM-09 | Grievance tickets and legal orders | Timers: acknowledge 24 h, resolve 7 days, unlawful content 36 h, nudity/CSAM/NCII 2 h, government/court order 3 h. 2 h and legal-order tickets page Owner immediately, 24×7. Replies include the appeal route `[LEGAL]` | P0 (grievances from Milestone A; UI polish at B) |
| REQ-ADM-10 | Evidence hold | Removed content retained 180 days despite room purge `[LEGAL]` | P0 |
| REQ-ADM-11 | Deletion cases | Owner can verify an emailed request and trigger deletion; audited. Negative: rows under evidence hold survive until `hold_until` | P0 |
| REQ-ADM-12 | Config, flags and lexicons | Flag changes reach clients within 5 min without a release; lexicon versions are signed and reversible | P0 |
| REQ-ADM-13 | Minors & grooming routing | A report where any involved account is under 18 by DOB lands in L1 with the "Under 18" flag; sexual or grooming category starts a 2 h timer and pages Owner. Negative: no console screen or API response shows a DOB | P0 |
| REQ-ADM-14 | Instant ban, evidence, mandatory report | One confirm action bans account and device, creates a 180-day `evidence_holds` row and opens a report task. Negative: the ticket cannot close without `report_ref` or an Owner legal reason | P0 `[LEGAL]` |
| REQ-ADM-15 | 24×7 on-call paging | Legal orders, 2 h grievances and L1 sexual/grooming items push within 60 s, voice-call at 5 min, repeat until acknowledged; weekly test page logged. Negative: no console setting can mute these types | P0 |
