#!/usr/bin/env bash
# Regenerates everything derived in apps/mobile (apps/mobile/tool/gen.sh: ARB files, gen-l10n output, the crisis
# lexicon data, build_runner code) and fails when the result differs from what is committed — i.e. a copy, contract
# or model change was committed without its regenerated files.
#
#   .github/scripts/check-generated.sh        # CI (mobile job) and locally; needs git, Flutter and Python 3.10
#
# Python must be 3.10: gen_lexicon.py embeds Python's unicodedata tables (3.10 = Unicode 13.0.0, what the committed
# lexicon was generated with). Another version changes the file header and the Telugu combining-class table.
set -euo pipefail
cd "$(dirname "$0")/../.."

want_unicode="13.0.0"
have_unicode="$(python3 -c 'import unicodedata; print(unicodedata.unidata_version)')"
if [ "$have_unicode" != "$want_unicode" ]; then
  echo "::error::python3 is $(python3 --version 2>&1) (unicodedata $have_unicode); the committed crisis lexicon needs unicodedata $want_unicode (Python 3.10). See docs/setup/ci-and-deploy.md."
  exit 1
fi

# gen-l10n writes build/untranslated_messages.json (l10n.yaml) and aborts before formatting its output when
# apps/mobile/build/ does not exist yet — which is the case on every fresh checkout.
mkdir -p apps/mobile/build

bash apps/mobile/tool/gen.sh

changes="$(git status --porcelain --untracked-files=all -- apps/mobile packages)"
if [ -n "$changes" ]; then
  echo "::error::Generated files are out of date. Run 'bash apps/mobile/tool/gen.sh' (with Python 3.10) and commit the result."
  printf '%s\n' "$changes"
  git --no-pager diff --stat -- apps/mobile packages
  git --no-pager diff -- apps/mobile packages | head -n 300
  exit 1
fi
echo "Generated files are up to date."
