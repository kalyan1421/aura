# Build-time values (`--dart-define-from-file`)

None of these are secrets: they ship inside every app build.

- `public.json` — legal and support values (privacy, terms, Grievance Officer, support email).
- `prod.json` — production endpoints: API (Render), Supabase URL and publishable (anon) key, Google OAuth client IDs,
  and the public key that verifies signed crisis-lexicon / helpline bundles.

Release builds:

```bash
flutter build appbundle --release --dart-define-from-file=config/public.json --dart-define-from-file=config/prod.json
flutter build ipa       --release --dart-define-from-file=config/public.json --dart-define-from-file=config/prod.json
```
