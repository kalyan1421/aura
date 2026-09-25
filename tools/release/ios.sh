#!/usr/bin/env bash
# Build, sign and upload the iOS app to App Store Connect (TestFlight).
# Needs an App Store Connect API key with the Admin role (cloud signing creates the distribution
# certificate and profiles). Defaults to the keys kept in ~/aura-secrets; override with env vars.
set -euo pipefail
cd "$(dirname "$0")/../../apps/mobile"
KEY_ID="${ASC_KEY_ID:-76Z629C54U}"
ISSUER="${ASC_ISSUER_ID:-8b88c2be-32a7-4c78-92af-6eb6cc05baa8}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/aura-secrets/AuthKey_${KEY_ID}.p8}"
[ -f "$KEY_PATH" ] || { echo "API key not found: $KEY_PATH" >&2; exit 1; }
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER")

flutter build ios --release --no-codesign \
  --dart-define-from-file=config/public.json --dart-define-from-file=config/prod.json "$@"
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/ios/archive/Aura.xcarchive archive \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=AQLMTLP6PD "${AUTH[@]}"
xcodebuild -exportArchive -archivePath build/ios/archive/Aura.xcarchive \
  -exportOptionsPlist ../../tools/release/ExportOptions.plist -exportPath build/ios/export "${AUTH[@]}"
echo "Uploaded. Bump the build number (pubspec.yaml version +N) before the next upload."
