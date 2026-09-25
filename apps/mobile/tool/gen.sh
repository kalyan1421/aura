#!/usr/bin/env bash
# Regenerates everything derived in apps/mobile: ARB files (tool/l10n_source.py
# + tool/l10n/*.py), gen-l10n output, the crisis lexicon and helpline data
# (contracts/safety → tool/gen_lexicon.py, tool/gen_helplines.py) and
# build_runner code (Riverpod, Freezed, JSON, Drift).
#
# Serialized with a lock directory so parallel workers never run two
# build_runner / gen-l10n passes on the same package at once.
#
#   bash tool/gen.sh            # full: l10n + lexicon + build_runner
#   bash tool/gen.sh l10n       # copy only
set -euo pipefail

cd "$(dirname "$0")/.."
LOCK="${TMPDIR:-/tmp}/aura-mobile-gen.lock"

waited=0
until mkdir "$LOCK" 2>/dev/null; do
  # A lock older than 15 minutes is left over from a killed run.
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +15 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null || true
    continue
  fi
  if [ "$waited" -eq 0 ]; then echo "gen.sh: waiting for another run to finish…"; fi
  waited=1
  sleep 2
done
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

python3 tool/l10n_source.py
flutter gen-l10n
# Native home-screen widget fallback copy (F11) from the ARB files.
if [ -f tool/gen_widget_strings.py ]; then python3 tool/gen_widget_strings.py; fi
# Test-only pseudo-localized catalogue (PRD 18; test/pseudo_localization_test.dart).
if [ -f tool/gen_pseudo_l10n.py ]; then python3 tool/gen_pseudo_l10n.py; fi
if [ "${1:-}" != "l10n" ]; then
  if [ -f tool/gen_lexicon.py ]; then python3 tool/gen_lexicon.py; fi
  if [ -f tool/gen_helplines.py ]; then python3 tool/gen_helplines.py; fi
  dart run build_runner build
fi
