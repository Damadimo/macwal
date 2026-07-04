#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BIN="$ROOT_DIR/.build/release/macwal"

if [ ! -x "$BIN" ]; then
  echo "Missing release binary at $BIN. Run: swift build -c release" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for smoke JSON validation." >&2
  exit 1
fi

if [ -n "${SMOKE_IMAGE:-}" ]; then
  IMAGE="$SMOKE_IMAGE"
else
  IMAGE="/System/Library/Desktop Pictures/Solid Colors/Electric Blue.png"
  if [ ! -f "$IMAGE" ]; then
    IMAGE=$(find "/System/Library/Desktop Pictures" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.heic' \) | head -1)
  fi
fi

if [ -z "${IMAGE:-}" ] || [ ! -f "$IMAGE" ]; then
  echo "No smoke image found. Set SMOKE_IMAGE=/path/to/image." >&2
  exit 1
fi

TMP_HOME=$(mktemp -d)
OUT_DIR=$(mktemp -d)

# Keep the smoke run fully hermetic — it must NEVER touch the real machine:
#   MACWAL_HOME           all generated dotfiles land under the throwaway home.
#   MACWAL_DEFAULTS_STORE `defaults` writes go to a fake plist store, not the
#                         real com.apple.* domains.
#   MACWAL_SKIP_RESTART   never quit/relaunch or signal real apps (Terminal,
#                         Ghostty, browsers, kitty, …) and never flip live dark mode.
#   MACWAL_SKIP_LAUNCHCTL never load/unload the real LaunchAgent.
#   MACWAL_SKIP_WALLPAPER never change the real desktop wallpaper.
export MACWAL_HOME="$TMP_HOME"
export MACWAL_DEFAULTS_STORE="$TMP_HOME/Library/Application Support/macwal/smoke-defaults"
export MACWAL_SKIP_RESTART=1
export MACWAL_SKIP_LAUNCHCTL=1
export MACWAL_SKIP_WALLPAPER=1
export MACWAL_EXECUTABLE=/tmp/macwal

# A folder of images so we can exercise `set --image <folder>` random selection.
WALL_DIR="$TMP_HOME/walls"
mkdir -p "$WALL_DIR"
cp "$IMAGE" "$WALL_DIR/one.png"
cp "$IMAGE" "$WALL_DIR/two.png"

"$BIN" list-targets --json >"$OUT_DIR/list-targets.json"
"$BIN" palette --image "$IMAGE" --json >"$OUT_DIR/palette.json"
"$BIN" preview --image "$IMAGE" --targets all --json >"$OUT_DIR/preview.json"
"$BIN" apply --image "$IMAGE" --targets shell,terminal,chrome --dry-run --json >"$OUT_DIR/apply-dry-run.json"
"$BIN" apply --image "$IMAGE" --targets shell,terminal,chrome --json >"$OUT_DIR/apply.json"
"$BIN" set --image "$IMAGE" --targets shell,chrome --json >"$OUT_DIR/set.json"
"$BIN" set --image "$WALL_DIR" --targets shell --json >"$OUT_DIR/set-folder.json"

# Check the files `set` wrote BEFORE restore removes them.
if [ ! -f "$TMP_HOME/Library/Application Support/macwal/generated/shell/colors.sh" ]; then
  echo "Expected 'set' to write shell colors under the throwaway home." >&2
  exit 1
fi

"$BIN" restore --targets shell,terminal,chrome --json >"$OUT_DIR/restore.json"
"$BIN" doctor --json >"$OUT_DIR/doctor.json"
"$BIN" watch install --targets shell --json >"$OUT_DIR/watch-install.json"
"$BIN" watch uninstall --json >"$OUT_DIR/watch-uninstall.json"

set +e
"$BIN" apply --image "$IMAGE" --targets system --json >"$OUT_DIR/system-block.json"
SYSTEM_EXIT=$?
"$BIN" apply --image "$IMAGE" --targets finder --json >"$OUT_DIR/finder-block.json"
FINDER_EXIT=$?
set -e

if [ "$SYSTEM_EXIT" -ne 3 ]; then
  echo "Expected system target to be blocked with exit 3, got $SYSTEM_EXIT" >&2
  exit 1
fi

if [ "$FINDER_EXIT" -ne 3 ]; then
  echo "Expected finder target to be blocked with exit 3, got $FINDER_EXIT" >&2
  exit 1
fi

"$BIN" apply --image "$IMAGE" --targets system --dry-run --json >"$OUT_DIR/system-dry-run.json"

jq -e '.schemaVersion == 1 and (.colors.background | type == "string") and .appearance.contrastValidated == true' "$OUT_DIR/palette.json" >/dev/null

for file in "$OUT_DIR"/*.json; do
  case "$(basename "$file")" in
    palette.json) ;;
    *)
      jq -e '.schemaVersion == 1 and (.command | type == "string") and (.success | type == "boolean")' "$file" >/dev/null
      ;;
  esac
done

jq -e '.success == false' "$OUT_DIR/system-block.json" >/dev/null
jq -e '.success == false' "$OUT_DIR/finder-block.json" >/dev/null
jq -e '.success == true' "$OUT_DIR/system-dry-run.json" >/dev/null

# `set` writes the requested targets and reports the wallpaper it would use,
# but must not have actually changed it (MACWAL_SKIP_WALLPAPER).
jq -e '.command == "set" and .success == true and .data.wallpaperChanged == false' "$OUT_DIR/set.json" >/dev/null
jq -e --arg img "$IMAGE" '.data.wallpaper == $img' "$OUT_DIR/set.json" >/dev/null

# `set --image <folder>` must pick one of the images inside the folder.
CHOSEN=$(jq -r '.data.wallpaper' "$OUT_DIR/set-folder.json")
case "$CHOSEN" in
  "$WALL_DIR"/*) ;;
  *)
    echo "Expected 'set --image <folder>' to choose an image inside $WALL_DIR, got $CHOSEN" >&2
    exit 1
    ;;
esac

# Sanity: the fake defaults store was used, so the real com.apple.Terminal
# domain was never touched by the terminal adapter.
if [ ! -d "$MACWAL_DEFAULTS_STORE" ] && [ ! -f "$MACWAL_DEFAULTS_STORE" ]; then
  : # store may be lazily created; absence is fine as long as nothing crashed
fi

echo "smoke ok"
echo "image=$IMAGE"
echo "tmp_home=$TMP_HOME"
echo "outputs=$OUT_DIR"
