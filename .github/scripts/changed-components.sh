#!/usr/bin/env bash
# Decides which CI jobs a change needs (.github/workflows/ci.yml, job `changes`).
#
#   git diff --name-only --no-renames A...B | .github/scripts/changed-components.sh
#   .github/scripts/changed-components.sh --all          # workflow_dispatch, schedule, unknown base
#
# Reads repo-relative paths on stdin, prints `<component>=true|false` lines for $GITHUB_OUTPUT.
# Keep the table in step with docs/setup/ci-and-deploy.md ("What runs when").
set -euo pipefail

# component|extended regex matched against each changed path
RULES='
mobile|^(apps/mobile/|packages/|contracts/(rules/|safety/|moods\.json$)|pubspec\.(yaml|lock)$)
goldens|^(apps/mobile/(lib/src/features/avatar/|test/goldens/|test/avatar_painter_test\.dart$|test/helpers\.dart$|shaders/|assets/avatar/)|packages/aura_domain/lib/src/avatar/|pubspec\.lock$)
server|^(server/aura-api/|contracts/(rules/|moods\.json$)|apps/mobile/lib/l10n/)
e2e|^(server/aura-api/|supabase/|contracts/(rules/|moods\.json$))
admin|^apps/admin/
vectors|^contracts/(rules/|moods\.json$)
workflows|^(\.github/|scripts/)
'
# Changing CI itself (the workflow or its scripts) re-runs every job.
EVERYTHING='^\.github/(workflows/ci\.yml$|scripts/)'

all=false
if [ "${1:-}" = "--all" ]; then
  all=true
  files=''
else
  files="$(cat)"
  # Here-strings, not pipes: `grep -q` exiting early must not turn into SIGPIPE under pipefail.
  if grep -Eq "$EVERYTHING" <<<"$files"; then all=true; fi
fi

while IFS='|' read -r name regex; do
  [ -n "$name" ] || continue
  if [ "$all" = true ] || grep -Eq "$regex" <<<"$files"; then
    echo "$name=true"
  else
    echo "$name=false"
  fi
done <<<"$RULES"
