## Offline Mode Behaviour

**Rule: your own things work offline; anything involving other people or money needs a connection.** Solo actions write locally first and never wait on the network. This is the same for every user 13+.

### What works offline
| Feature | Offline | Notes |
|---|---|---|
| Check-in incl. voice note (F1), widget check-in (F11) | Full | Saved locally, queued in outbox |
| Habits (F2) | Full | |
| Avatar progression (F2) | Full, provisional | Local projection with the same rules; server snapshot replaces it on sync |
| Glow streak and rest days (F3) | Full, provisional | Same rules as server |
| Capsule create and seal (F4) | Full | Media uploads when online |
| Date-capsule unlock when due | Full | Uses device time (see clock rules) |
| Mood-trigger capsule firing | Full | Fires on the matching offline check-in |
| Insights (F10) | Full | Computed from local data |
| Sanctuary: Breathe, grounding, Today's minute (F15); companion response and "A minute for you" | Full | Lines and scripts bundled; session records queue in the outbox |
| Sounds (F15) | Full after one download | Brown noise needs no download; Plus stems cached once picked |
| Look back (F10), keepsakes box (F13) | Full | Keepsakes cached; new ones awarded on sync |
| Crisis sheet (F9) | Full | Helplines and grounding exercise bundled in the app, list refreshed on sync |
| Aura Plus features | Cached | Honoured until the cached entitlement's expiry date `[ASSUMPTION]` |
| Rooms and gestures (F5), reflections (F6), Breath Ripples (F7), Quiet Together and the Lantern Hour wind-down (F16) | Online only | The shared sound itself plays from the local cache |
| Purchases, restore, gifts (F12) | Online only | |
| Sign-in (F8), data export, account deletion | Online only | |
| Server push (F14) | Online only | Local reminders still fire |

### Local store
- **Drift on SQLCipher.** The key is generated on first launch and kept in iOS Keychain / Android Keystore via `flutter_secure_storage`.
- Voice and photo files live in the app's private directory, encrypted at rest.
- The local database is excluded from OS cloud backup (see Technical Constraints); the server is the restore path.

### Write paths: NestJS writes, Supabase reads
One rule keeps this simple: **the app never writes personal tables directly.** Supabase RLS on personal tables allows *select own rows* only; there are no client insert, update or delete policies.

| What | Goes to | Why |
|---|---|---|
| All outbox mutations: check-ins, habit logs and definitions, content-free Sanctuary session records, capsule seal / unlock / delete (ciphertext + unlock metadata), settings, tombstones | **NestJS `POST /v1/sync/push`** (verifies the Supabase JWT) | Most of these earn Starlight or move a streak. NestJS upserts the rows and appends `starlight_ledger` entries in one Postgres transaction, so the server ledger is authoritative (DS-5). Settings use the same path so there is one write path to build and test |
| Voice and photo files (already encrypted on device, DS-1) | **Supabase Storage**, direct upload to a short-lived signed URL issued by NestJS | Keeps large files off the API; private bucket |
| Purchases, restores, gifts | **NestJS** (store validation, DS-9) | Online only; never queued |
| Sign-in and session refresh | **Supabase Auth** | |
| Pull of own data and the avatar / streak snapshot | **Supabase** (PostgREST, RLS select-own) | Cheap reads, no custom endpoint per entity |

### Sync model
- **Outbox:** every mutation writes the domain row and an outbox row in one Drift transaction.
- **Idempotent IDs:** client-generated UUIDv7 primary keys; NestJS upserts on ID and keys ledger entries by source record id, so retries never duplicate or double-credit.
- **Push:** outbox drained oldest-first in batches of 50 to `/v1/sync/push` on reconnect, foreground, 2 s after a write, and via WorkManager / BGTaskScheduler. The response returns a per-item result and the new avatar / streak snapshot.
- **Pull:** per-entity delta since a server sequence cursor, after each push and on foreground.
- **Retry:** network and 5xx errors back off exponentially up to 1 h; after 10 failures, or at once on a validation rejection (4xx), an item moves to a dead-letter table and is logged (no content) so it stops blocking the queue.
- **Timestamps:** each record carries `device_ts` (device time + UTC offset), `local_day`, and a monotonic stamp (`boot_id` + ms since boot) `[ASSUMPTION]`. The server adds `server_ts`. "Which day counts" uses `local_day`; server time is authority for everything shared (rooms, moderation, purchases).

### Conflict rules
| Entity | Rule |
|---|---|
| Check-ins | **Append-only, no conflicts.** Delete is a tombstone and always wins |
| Habit logs | One row per habit per `local_day`; last-write-wins on `device_ts`, ties broken by `server_ts` |
| Habit definitions, settings | Last-write-wins per field; delete tombstone wins |
| Avatar (Starlight, stage, traits), streak, rest days | **Derived by NestJS from the ledger, never trusted from the client.** Client shows a provisional projection and adopts the server snapshot on pull |
| Capsules | Content immutable once sealed; unlocked state is one-way; delete tombstone wins |
| Mood-trigger firing | At most once per capsule. If two devices fire offline, earliest `device_ts` wins; the 7-day cooldown starts from it |
| Entitlements, Stardust | NestJS only, from store-validated purchases (DS-9); never earned or spent offline |

### Clock tampering and Starlight farming
- **Daily caps** per account per `local_day`, enforced by NestJS on `starlight_ledger` (accepted defaults): Starlight from at most 3 check-ins, from each habit once, 60 a day in total. Moving the clock forward to create extra "days" is the main exploit.
- The server gives **no Starlight or streak credit** to events that are in the future (more than 10 min past server time), older than 30 days on receipt, or part of an impossible burst (monotonic stamps show 5 "days" of events created in 20 real minutes). The entries themselves are kept; they just earn nothing.
- A `local_day` can be credited only once, so time-zone travel cannot double a day.
- **Stages never regress.** If the server total is below the local projection, the stage shown stays; new Starlight fills the gap before counting toward the next stage.
- Opening a date capsule early by changing the clock only spoils the user's own surprise, so it is tolerated; the server records the real unlock time.

### Multi-device, reinstall, restore
- **Two phones, one account:** each has its own outbox; pulls merge with the rules above. Caps are per account, so a second device cannot double-earn.
- **Reinstall or new phone:** sign in, then a full pull of check-ins, habits, the avatar snapshot and capsule metadata. Capsule media downloads when opened. Under envelope encryption (Data Model DS-1) the per-user data key is re-issued to the new device after sign-in, so nothing is stranded on the old phone.
- Unsynced outbox items are lost if the app is deleted, so signing out with a non-empty outbox shows a warning.
