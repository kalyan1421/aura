# Export compliance (App Store Connect "Encryption" questions)

**Setting:** `ITSAppUsesNonExemptEncryption = NO` in `apps/mobile/ios/Runner/Info.plist` (and the widget extension's
`AuraWidget/Info.plist`), so App Store Connect stops asking per build. **AK must confirm this is right before
submitting** — it is a legal declaration by the publisher (AKVega), and the answers below are the engineering basis
for it, not legal advice.

## What encryption Aura uses

| Where | What | Algorithm / source |
|---|---|---|
| All network traffic | HTTPS / TLS to the Aura API, Supabase, stores, Firebase | OS-provided TLS (`URLSession` / BoringSSL in Dart's `HttpClient`) |
| Local database | Drift over SQLite3MultipleCiphers (`hooks.user_defines.sqlite3.source: sqlite3mc` in `apps/mobile/pubspec.yaml`) | Standard cipher (AES-256 / ChaCha20 family) protecting the user's own data at rest |
| Private notes, capsules, voice, photos (DS-1 envelope) | `package:cryptography` (`lib/src/core/security/note_cipher.dart`) | AES-256-GCM, keys wrapped by the server; HKDF / SHA-256 |
| Signed config bundles (lexicon, helplines) | Signature check only (`lib/src/core/remote_config/signed_bundle.dart`) | Ed25519 verification |
| Sign in with Apple / Google | Nonce hashing | SHA-256 |
| Keychain / Keystore | OS secure storage (`flutter_secure_storage`) | OS-provided |

No proprietary or non-standard algorithms, no VPN / end-to-end messaging between users, no encryption offered as a
feature to encrypt arbitrary user files for other parties.

## Basis for "exempt" (why `NO` is the expected answer)

Apple's export compliance guidance (App Store Connect → "Complying with encryption export regulations") treats an app
as **exempt** when it only uses encryption that is:

- **(a)** limited to authentication, digital signatures or the protection of the user's own data, or intellectual
  property / copy protection — Aura's local database encryption, the DS-1 envelope and the Ed25519 checks all fall
  here (they protect the user's own content and verify Aura's own bundles); and/or
- **(b)** standard encryption provided by the operating system or used over HTTPS / TLS — every network call.

Aura implements only **standard** algorithms (AES-GCM, ChaCha20, SHA-2, HKDF, Ed25519) from well-known open-source
libraries, for those purposes. That is why the key is set to `NO` ("does not use non-exempt encryption"). Under US EAR
this corresponds to the mass-market / 5A992 exclusions that Apple's questionnaire summarises; **no annual self-
classification report is expected for exempt-only use, but AK should confirm** (and, if distributing in France,
check whether a French encryption declaration is needed — the v1.0 plan excludes the EU, so this is not relevant now).

If a future version adds anything else (e.g. user-to-user end-to-end encrypted messaging, or a proprietary cipher),
set the key to `YES` and answer the App Store Connect questionnaire again.
