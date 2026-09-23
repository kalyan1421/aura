#!/usr/bin/env bash
# Release-config guard: fails when a release build would ship without its legal/support links
# (Env.missingLegalConfig) or with local/placeholder backend values.
#
#   .github/scripts/check-release-config.sh apps/mobile/env/alpha.json
#
# The argument is the exact file the release build gets via --dart-define-from-file (JSON object, or KEY=VALUE
# lines). Run `dart pub get` at the repo root first. Used by .github/workflows/release.yml before any build.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"

file="${1:-}"
if [ -z "$file" ]; then
  echo "usage: $0 <dart-define file>" >&2
  exit 2
fi
case "$file" in /*) ;; *) file="$root/$file" ;; esac
if [ ! -f "$file" ]; then
  echo "::error::Define file not found: $file (see docs/setup/ci-and-deploy.md, 'Release builds')."
  exit 1
fi
if [[ "$file" == *.json ]] && ! jq -e 'type == "object"' "$file" >/dev/null; then
  echo "::error::$file is not a JSON object of define names to values."
  exit 1
fi

cd "$root/apps/mobile"
flutter test --no-pub --reporter expanded --dart-define-from-file="$file" \
  "$root/.github/release-guard/release_config_test.dart"
