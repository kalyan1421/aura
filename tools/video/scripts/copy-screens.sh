#!/usr/bin/env bash
# Copies the app screen captures and the Aura avatar art used by the videos
# into public/, downscaled to a height that is still sharper than anything the
# videos show (so Chrome never has to shrink a 2556 px capture on every frame).
#
# Source captures: docs/design/screens/*.png (regenerate them with
#   cd apps/mobile && flutter test --tags capture --run-skipped test/design_capture)
#
# Usage (from tools/video):  ./scripts/copy-screens.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
SRC="$REPO/docs/design/screens"
DST="$HERE/public/screens"
ART_SRC="$REPO/apps/mobile/assets/avatar/aura_base.png"
ART_DST="$HERE/public/art"

# Height the screens are stored at. The biggest phone in either video shows the
# screen about 1,100 px tall, so 1,600 px leaves room for push-ins.
SCREEN_HEIGHT=1600

SCREENS=(
  010 011 017 020 021 022 030 031 033 036 037
  050 054 055 056 057 058 060
  071 072 073 074 075 076
  080 085 086 087 089 098 100 101 106 107
  111 112 113 117 118 122
  125 126 127 128 129 130 131 132
  150 152 153
  200 201 203 205
)

mkdir -p "$DST" "$ART_DST"

resize() {
  # resize <in> <out> <height>
  if command -v sips >/dev/null 2>&1; then
    sips --resampleHeight "$3" "$1" --out "$2" >/dev/null
  else
    python3 - "$1" "$2" "$3" <<'PY'
import sys
from PIL import Image
src, dst, h = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src)
w = round(im.width * h / im.height)
im.resize((w, h), Image.LANCZOS).save(dst, optimize=True)
PY
  fi
}

count=0
for id in "${SCREENS[@]}"; do
  matches=("$SRC"/"${id}"_*.png)
  if [[ ! -e "${matches[0]}" ]]; then
    echo "missing capture for $id in $SRC" >&2
    exit 1
  fi
  f="${matches[0]}"
  # Stable short name: the numeric prefix (e.g. 030.png) so code refers to screens by id.
  resize "$f" "$DST/$id.png" "$SCREEN_HEIGHT"
  count=$((count + 1))
done

resize "$ART_SRC" "$ART_DST/aura.png" 1200

echo "Copied $count screens to $DST and the avatar to $ART_DST/aura.png"
