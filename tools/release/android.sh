#!/usr/bin/env bash
# Build the signed Play App Bundle. Needs apps/mobile/android/key.properties (upload key; see
# docs/setup/android-release-signing.md). Upload the .aab in Play Console (or with the Play API later).
set -euo pipefail
cd "$(dirname "$0")/../../apps/mobile"
flutter build appbundle --release \
  --dart-define-from-file=config/public.json --dart-define-from-file=config/prod.json "$@"
ls -la build/app/outputs/bundle/release/app-release.aab
