#!/bin/sh
# MASVS F-4 (docs/security/masvs-l1.md): the ATS local-networking exception
# (plain http to localhost / *.local / unqualified hosts, used by the local dev
# stack on :3310 and :55521) exists ONLY in Debug builds.
#
# Runner/Info.plist has no NSAppTransportSecurity dictionary at all, so ATS is
# fully on by default. This "ATS (Debug only)" build phase runs after the
# Info.plist is processed (its input path is the built Info.plist) and:
#   - Debug*:            adds NSAppTransportSecurity:NSAllowsLocalNetworking = YES
#   - Release / Profile: fails the build if any ATS relaxation is present
#
# Test: test/masvs_hardening_test.dart "iOS". Check a build:
#   plutil -p build/ios/iphonesimulator/Runner.app/Info.plist | grep -i allows
set -eu

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
BUDDY=/usr/libexec/PlistBuddy

case "${CONFIGURATION}" in
  Debug*)
    "$BUDDY" -c "Print :NSAppTransportSecurity" "$PLIST" >/dev/null 2>&1 ||
      "$BUDDY" -c "Add :NSAppTransportSecurity dict" "$PLIST"
    "$BUDDY" -c "Delete :NSAppTransportSecurity:NSAllowsLocalNetworking" "$PLIST" >/dev/null 2>&1 || true
    "$BUDDY" -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$PLIST"
    echo "ATS: NSAllowsLocalNetworking added for ${CONFIGURATION} (local dev stack)."
    ;;
  *)
    for key in NSAllowsLocalNetworking NSAllowsArbitraryLoads NSAllowsArbitraryLoadsInWebContent \
      NSAllowsArbitraryLoadsForMedia NSExceptionDomains; do
      if "$BUDDY" -c "Print :NSAppTransportSecurity:${key}" "$PLIST" >/dev/null 2>&1; then
        echo "error: ATS exception ${key} is in the ${CONFIGURATION} Info.plist. It must be Debug-only (MASVS F-4, ios/scripts/ats_debug_only.sh)." >&2
        exit 1
      fi
    done
    ;;
esac
