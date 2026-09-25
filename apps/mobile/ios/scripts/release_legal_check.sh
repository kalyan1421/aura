#!/bin/sh
# Release guard (design critique, "before release"): a Release build fails
# when the Grievance Officer, support or legal values it was given are
# missing or still placeholders ("example.com", "(placeholder)"). Debug and
# Profile builds are untouched (they show obvious local placeholders on
# purpose, lib/src/core/env/env.dart).
#
# Reads Flutter's DART_DEFINES (comma-separated base64 KEY=VALUE entries,
# from Generated.xcconfig). The same rules run on Android
# (android/app/build.gradle.kts "verifyReleaseLegal") and in
# test/release_legal_guard_test.dart.
#
# For an internal, never-distributed release build only:
#   AURA_ALLOW_PLACEHOLDER_LEGAL=1 flutter build ios --release
set -eu

case "${CONFIGURATION:-Release}" in
  Debug* | Profile*) exit 0 ;;
esac

REQUIRED="AURA_GRIEVANCE_NAME AURA_GRIEVANCE_EMAIL AURA_SUPPORT_EMAIL AURA_PRIVACY_URL AURA_TERMS_URL"

decoded=""
OLDIFS=$IFS
IFS=','
for entry in ${DART_DEFINES:-}; do
  [ -z "$entry" ] && continue
  line=$(printf '%s' "$entry" | base64 --decode 2>/dev/null || true)
  decoded="${decoded}${line}
"
done
IFS=$OLDIFS

problems=""
for key in $REQUIRED; do
  value=$(printf '%s' "$decoded" | sed -n "s/^${key}=//p" | tail -n 1)
  if [ -z "$value" ]; then
    problems="${problems} ${key} (missing)"
    continue
  fi
  lower=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    *example.com* | *example.org* | *example.net* | *placeholder*)
      problems="${problems} ${key} (placeholder: ${value})"
      ;;
  esac
done

if [ -n "$problems" ]; then
  if [ "${AURA_ALLOW_PLACEHOLDER_LEGAL:-}" = "1" ]; then
    echo "warning: AURA_ALLOW_PLACEHOLDER_LEGAL=1: release legal/support values are not final:${problems}. Do not distribute this build."
    exit 0
  fi
  echo "error: release build has missing or placeholder legal/support values:${problems}. Pass real values with --dart-define (docs: lib/src/core/env/env.dart)." >&2
  exit 1
fi
echo "Release legal/support values: OK."
