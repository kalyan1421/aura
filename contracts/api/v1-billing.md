# Aura API v1 — Billing (F12 Monetization, Milestone B)

Store billing validated in NestJS (DS-9; **no RevenueCat, no Razorpay / UPI direct checkout**). The app buys through
`in_app_purchase` (StoreKit 2 / Play Billing Library 8); NestJS confirms every purchase with the store and owns the
entitlement. Implementation: `server/aura-api/src/billing`, migration `20261005000020_billing.sql`, app
`apps/mobile/lib/src/features/plus`. Common rules from `v1.md` apply (Supabase JWT, `{ code, message }` errors,
`403 account_deletion_pending`, `Cache-Control: no-store`).

**Never granted from a client receipt alone (REQ-PAY-10).** A StoreKit 2 JWS must chain to Apple's root *and* be
confirmed by the App Store Server API; a Google purchase token is always re-read from the Play Developer API. Store
notifications (App Store Server Notifications V2, Play RTDN) grant too — they come from the store. Nothing is ever
granted offline (16-offline: purchases, restores and gifts are online only).

## 1. Catalogue

Same product ids in App Store Connect and Play Console. The app always shows the **store's localized price string**
(never the INR numbers below, which are the India tiers, GST-inclusive).

| Product id | Type | India price | Grants |
|---|---|---|---|
| `aura_plus_monthly` | Auto-renewable subscription, group "Aura Plus"; introductory offer **1 month free** (Play: base plan `monthly`, offer `first-month-free`) | ₹49 / month | Aura Plus |
| `aura_plus_annual` | Same group; 1 month free (Play: base plan `annual`, offer `first-month-free`) | ₹399 / year | Aura Plus |
| `sky_first_light` · `sky_lantern_festival` · `sky_deep_ocean` · `sky_meteor_shower` | Non-consumable (restorable) | ₹10 · ₹29 · ₹49 · ₹99 | Personal sky theme (also 10 · 30 · 50 · 100 Stardust) |
| `gift_warm_tea` · `gift_comfort_lantern` · `gift_encouragement_bouquet` | Consumable | ₹10 · ₹29 · ₹49 | Recipient gets 10 · 30 · 50 Stardust |

Sky themes (personal: Home, Sanctuary, Insights; never shown to strangers): `night` (free), `aurora`, `monsoon_dusk`
(included with Plus), and the four cosmetics above. Each can be paired with a soundscape preset — base stems only, so a
pairing never needs Plus: `night_air` (night insects + wind), `high_wind` (wind + chimes), `monsoon` (rain + brown
noise), `bells` (singing bowl + chimes), `shore` (ocean + wind), or none.

Nothing sold grants Starlight, a rest day or a keepsake (REQ-AVA-03, REQ-STK-04, REQ-SHR-05). Stardust is only earned
from gifts and only spent on skies — never sold, cashed, transferred or expired.

## 2. Entitlement and purchases

### 2.1 `GET /v1/billing/entitlement` → 200
```json
{ "accountToken": "3f1c…-uuid",
  "plus": { "active": true, "status": "trial", "store": "apple", "productId": "aura_plus_monthly", "autoRenew": true,
            "trialEndsAt": "2026-11-03T06:30:00Z", "expiresAt": "2026-11-03T06:30:00Z", "graceEndsAt": null,
            "validUntil": "2026-11-03T06:30:00Z" },
  "notices": [ { "kind": "trial_ending", "date": "2026-11-03T06:30:00Z", "price": "₹49.00", "key": "<sub>:trial_ending:2026-11-03" } ],
  "cosmetics": { "owned": ["deep_ocean"], "available": ["night", "aurora", "monsoon_dusk", "deep_ocean"] },
  "sky": { "theme": "deep_ocean", "soundscape": "shore" },
  "stardust": { "balance": 30 },
  "gifting": { "state": "ok", "until": null, "sentToday": 1, "dailyLimit": 5 },
  "giftsUnseen": 0,
  "paywall": { "allowedFrom": "2026-10-06T10:00:00Z" },
  "serverTime": "2026-11-01T06:30:00Z" }
```
- `accountToken`: the account's store token — HMAC of the user id under a key derived from `AURA_MASTER_KEY`, shaped as
  a UUID; never the user id. The app passes it as `applicationUserName` (Apple `appAccountToken`, Google
  `obfuscatedAccountId`) on every purchase, so a store notification finds the account even when the app never reports
  the purchase (Ask to Buy / UPI mandate approved while the app is closed, REQ-PAY-07).
- `plus.status`: `none` · `pending` · `trial` · `active` · `cancelled` (trial/active with auto-renew off — Plus stays on
  until `expiresAt`) · `grace` (renewal failed, Plus on until `graceEndsAt`) · `billing_retry` (after grace: off until the
  store renews) · `paused` · `expired` · `refunded` · `revoked`.
- `plus.validUntil`: the app honours a cached `active` until this instant offline (16-offline), then treats Plus as off
  until it can ask again. `plusActiveProvider` in the app reads exactly this.
- `notices` (in-app only, PRD 12 / 14-states): `trial_ending` (last 48 h of a trial with auto-renew on; card at most once
  a day), `trial_cancelled` (auto-renew off in the trial: "Plus stays on until {date}. You won't be charged." — once),
  `billing_issue` (grace), `billing_paused` (billing retry), `refunded`, `plus_continues` (trial converted — once).
  `key` is stable per event so the app can show a one-time note once.
- `cosmetics.available`: skies this account may use now (free + Plus skies while Plus is on + owned).
- `sky`: the equipped sky; a Plus sky after Plus ends (or a refunded cosmetic) falls back to `night`.
- `paywall.allowedFrom`: profile creation + 24 h (PRD F12: never within 24 h of onboarding). `null` without a profile.

### 2.2 `POST /v1/billing/purchases` (verify one purchase)
```json
{ "store": "apple", "productId": "aura_plus_monthly", "signedTransaction": "<StoreKit 2 jwsRepresentation>",
  "priceDisplay": "₹49.00", "giftId": null }
{ "store": "google", "productId": "aura_plus_monthly", "purchaseToken": "<Play purchase token>", "priceDisplay": "₹49.00" }
```
- `priceDisplay` (≤ 32 chars): the store's localized price string the paywall showed; kept for the trial reminder.
- `giftId`: for a gift, the id from `POST /v1/billing/gifts`.
- **200** `{ "status", "gift"?, "entitlement" }` — `status`:
  `granted` (confirmed and on) · `pending` (the store says pending: nothing granted; the store notification finishes it)
  · `not_active` (confirmed but lapsed / cancelled before completing) · `refunded` · `owned_elsewhere` (this store
  purchase belongs to another live Aura account: nothing moves). `gift`: `delivered` · `already` · `unmatched`.
- **202** `{ "status": "confirming", "entitlement" }`: the store couldn't be asked right now. Nothing granted; the server
  keeps confirming (billing worker, every 10 min) and the store notification also settles it. The app says "The store
  has your request. Plus unlocks the moment it's confirmed." and retries in the background (never asks to pay again).
- **422** `invalid_purchase` (signature, bundle, environment, product, family sharing) · `purchase_not_found` (the
  store doesn't know it). **400** `invalid_request`.
- Idempotent: the same purchase twice changes nothing and delivers a gift once.
- Google: the server acknowledges subscriptions and cosmetics and consumes delivered gifts (within Google's 3-day
  window; the daily reconcile retries). The app then calls `completePurchase` (iOS `finishTransaction`).

### 2.3 `POST /v1/billing/restore`
`{ "apple"?: { "signedTransactions": ["<jws>", …≤50] }, "google"?: { "purchases": [{ "productId", "purchaseToken" }, …≤50] } }`
→ **200** `{ "restored", "ownedElsewhere", "confirming", "invalid", "entitlement" }`. Each item is verified exactly like
§2.2; one bad item never fails the rest. Plus follows the account across platforms (REQ-PAY-08).

### 2.4 Ownership
A store purchase belongs to (1) the Aura account it is already linked to, else (2) the account whose `accountToken` the
store recorded, else (3) the account that verifies it. A purchase linked to another **live** account is never moved by a
verify or restore (`owned_elsewhere`: one Plus, one Aura account — shared phones, one Apple ID). A purchase whose account
was deleted (or is being deleted) is claimed by the next account that restores it.

## 3. Personal sky and Stardust

- `PUT /v1/billing/sky` `{ "theme": "deep_ocean", "soundscape": "shore" | null }` → 200 entitlement. `409 not_owned` /
  `409 plus_required`; `400` unknown theme / soundscape.
- `POST /v1/billing/stardust/redeem` `{ "cosmeticId": "lantern_festival", "redemptionId": "<uuid v7>" }` → 200
  entitlement. Idempotent on `redemptionId` (and on already owning the sky). `409 not_enough_stardust`; `400` for skies
  not sold for Stardust. The balance can never go below zero (DB trigger).

## 4. Gifts (PRD F12 "Gifts", 06b "Send a gift")

### 4.1 `POST /v1/billing/gifts` — the pre-check, **before** the store sheet
`{ "giftId": "<uuid v7>", "roomId", "memberId", "kind": "warm_tea" | "comfort_lantern" | "encouragement_bouquet" }`
→ **200** `{ "giftId", "productId", "kind", "expiresAt", "accountToken" }`. Idempotent on `giftId`.
Refusals (nothing is charged — the app never opens the store sheet):
- `409 gift_unavailable` — not both in this live room, yourself, or a block in **either** direction (never says which);
- `403 gifting_unavailable` — the sender has an active sanction (anything but a warning);
- `403 gifting_paused` (2 refunded gifts within 90 days: paused 90 days) · `403 gifting_disabled` (a 3rd refund);
- `429 gift_daily_limit` — 5 checks / deliveries on the sender's Aura day;
- `503 gifts_paused` — kill switch `gifts_enabled` off (PRD 19).
A check reserves one of the day's 5 slots for 7 days (Ask to Buy / UPI approval). `DELETE /v1/billing/gifts/:giftId`
(204) frees it when the store sheet is dismissed or fails.

### 4.2 Delivery
The gift is delivered when its purchase is confirmed (§2.2 with `giftId`, or a store notification — then the sender's
oldest open check for that product): the recipient gets the Stardust once. "Pending gifts deliver into the room memory":
a room that became a memory meanwhile still gets it. **No message; the recipient never learns who sent it**
(REQ-PAY-04).
- `GET /v1/billing/gifts/received` → `{ "gifts": [{ "giftId", "kind", "stardust", "roomId", "deliveredAt" }] }` (unseen;
  never a sender id or pseudonym). The app shows "Someone here sent you a Comfort Lantern."
- `POST /v1/billing/gifts/received/seen` `{ "giftIds": [...] }` → `{ "marked" }`.

### 4.3 Refunds and the minors signal
Apple refunds a gift only to its purchaser. A refunded gift: **the recipient keeps the Stardust** (never told); the
sender's refund count grows (REQ-PAY-05). 3+ gifts in 7 days from one adult to the same under-18 account open one
Minors & grooming review item (`reports.auto_signal = 'gift_pattern'`, reason 9); the gifts still go through. Nothing of
this is ever shown to either person.

## 5. Store webhooks (public, no Supabase JWT)

### 5.1 `POST /v1/billing/webhooks/apple` — App Store Server Notifications V2
Body `{ "signedPayload": "<JWS>" }`. The JWS (and the `signedTransactionInfo` / `signedRenewalInfo` inside) must chain to
Apple Root CA G3/G2 bundled in `src/billing/apple/certs` (leaf OID 1.2.840.113635.100.6.11.1, intermediate OID
1.2.840.113635.100.6.2.1, validity at `signedDate`, ES256 signature). Forged → **401 invalid_signature** (nothing
logged). Another bundle id (or, in production, another `appAppleId`) → 200 `ignored`. Otherwise the payload is logged in
`store_notifications` once per `notificationUUID` and handled: **200** `{ "status": "processed" | "ignored" | "failed" |
"duplicate" }`. `failed` is still 200: the billing worker retries from the log (every 10 min, up to 20 times).
Handled: `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `DID_CHANGE_RENEWAL_PREF`, `DID_FAIL_TO_RENEW`,
`GRACE_PERIOD_EXPIRED`, `EXPIRED`, `OFFER_REDEEMED`, `REFUND`, `REFUND_REVERSED`, `REVOKE`, `RENEWAL_EXTENDED`,
`ONE_TIME_CHARGE`, `TEST` — all by re-deriving state from the signed transaction + renewal info + `data.status`, with an
ordering guard (a snapshot older than the one applied never wins). `CONSUMPTION_REQUEST`, `REFUND_DECLINED` → ignored.

### 5.2 `POST /v1/billing/webhooks/google` — Play RTDN via authenticated Pub/Sub push
Pub/Sub push body `{ "message": { "data": "<base64 DeveloperNotification>", "messageId" }, "subscription" }` with
`Authorization: Bearer <Google OIDC token>`: verified against Google's keys, `aud` = `GOOGLE_RTDN_AUDIENCE`, `email` =
`GOOGLE_RTDN_SERVICE_ACCOUNT` (verified). Else **401 invalid_push_token**; not configured → **503
rtdn_not_configured**. Accepted → **204** (logged once per `messageId`). The notification is only a hint: the server
re-reads the purchase from the Play Developer API (`subscriptionsv2`, `products`), acknowledges / consumes, and applies
`voidedPurchaseNotification` refunds. Another package name or malformed data → 204 ignored.

## 6. Background (billing worker, `billing` queue)
- every 10 min: trial-ending reminders (§6.1); retry of failed / unhandled notifications; a rolling reconcile of live
  subscriptions not confirmed with their store in 20 h (every one re-read at least daily — "reconciliation repairs a
  dropped notification"); `pending` rows the store never confirms within 3 days → `expired`; entitlements whose period
  ran out; gift checks past 7 days → `expired`.
- daily 03:41 UTC: Play Voided Purchases API (last 3 days, idempotent); Google one-time purchases still to acknowledge /
  consume; `store_notifications` older than 400 days deleted `[ASSUMPTION]`.

### 6.1 Trial-ending reminder (PRD 12, REQ-NTF-03)
48 h before the free month ends, **once per account** (`billing_accounts.trial_reminder_at`), only while auto-renew is
on: push type `trial_ending` (opaque id = subscription id; Android channel `account`; cap-exempt; deferred out of quiet
hours; discreet mode → the discreet line). Copy (en / te / te-Latn, PRD's lines): "Your free month of Aura Plus ends on
{date}. After that it's {price}/month. Keep it or cancel anytime." — `{price}` is the store's localized string the
paywall showed. Delivery re-checks: converted, lapsed, auto-renew off or moved → skipped (`trial_changed`). Tapping it
opens the store's own subscription page (no retention screen; on iOS StoreKit's in-app "Manage subscriptions" sheet,
`AppStore.showManageSubscriptions(in:)`, falling back to the App Store web page). The in-app card comes from `notices`.

**Email twin** (PRD 12: "Push + in-app card + email"; "only if the account has a verified email"; `src/user-mail`,
migration `20261005000025`): the same sweep queues one `user-mail` job per claimed trial (job id
`trial-email-<subscription>`). The worker re-reads the facts and sends through the console's SMTP transport
(`SMTP_URL`, `MAIL_FROM`; Mailpit locally) to `auth.users.email` (never copied anywhere; Apple private-relay addresses
are real, verified addresses) in the account's `ui_locale` (en / te / te-Latn / hi / hi-Latn,
`src/admin/mail/copy.ts`): the push line word for word (end date in the person's zone, the store's price string and
period), the store's own subscription page (`https://apps.apple.com/account/subscriptions` or the Play deep link) and
a one-time note — no offers, no unsubscribe link (transactional, once). Skipped (recorded, never retried): auto-renew
already off, trial converted / lapsed / moved, account pending deletion or gone, account closed (`account_ban`), no
address or not verified, under an hour left. Quiet hours (the person's own window, else 23:00–08:00) delay it like
the push unless that would leave under an hour. **At most once per trial**: the `trial_ending_emails` ledger (state +
reason code only — no address, no copy) is claimed before sending; transport failures retry up to 5 times with
backoff; a crash after the claim never resends. SMTP not configured → skipped `mail_not_configured`.

## 7. Store setup (AK)
- **App Store Connect:** subscription group "Aura Plus" with `aura_plus_monthly` (₹49) and `aura_plus_annual` (₹399),
  each with a 1-month free introductory offer; non-consumables `sky_*`; consumables `gift_*`; Family Sharing **off**.
  App Store Server Notifications **V2** URL `https://<api>/v1/billing/webhooks/apple` for production and sandbox. An
  In-App Purchase key → `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_KEY_ID`, `APPLE_IAP_PRIVATE_KEY`; `APPLE_IAP_APP_APPLE_ID`.
  No shared secret is needed (it belongs to the deprecated verifyReceipt flow). Small Business Program.
- **Play Console:** subscriptions `aura_plus_monthly` (base plan `monthly`) and `aura_plus_annual` (base plan `annual`),
  each with offer `first-month-free` (free trial 1 month, eligibility "new customer acquisition", tag `free-month`);
  one-time products `sky_*`, `gift_*`. A service account (Users and permissions: view financial data, manage orders and
  subscriptions) → `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. **RTDN:** a Pub/Sub topic (grant
  `google-play-developer-notifications@system.gserviceaccount.com` Publisher), a **push** subscription to
  `https://<api>/v1/billing/webhooks/google` with authentication on (service account → `GOOGLE_RTDN_SERVICE_ACCOUNT`,
  audience → `GOOGLE_RTDN_AUDIENCE`); set the topic in Play Console → Monetization setup and send a test notification.
- Server env: `.env.example` (F12 block). `BILLING_ACCEPT_SANDBOX=true` lets TestFlight / App Review / licence testers buy.

## 8. Data
`billing_accounts`, `entitlements`, `user_cosmetics`, `sky_preferences`, `stardust_ledger` are personal (purged with the
account). `subscriptions`, `purchases` and `gifts` are purchase records kept **de-identified** after a purge (the account
link is nulled) as "purchase / tax records kept only as law requires" `[LEGAL]` (PRD 06c F8); `store_notifications`
hold the raw signed payloads (the derived account token, never the user id), pruned after 400 days. The app may read
its own `entitlements`, `user_cosmetics`, `sky_preferences` and `stardust_ledger` (RLS select-own) and writes none.
