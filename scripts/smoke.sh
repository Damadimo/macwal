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

MACWAL_HOME="$TMP_HOME" "$BIN" list-targets --json >"$OUT_DIR/list-targets.json"
MACWAL_HOME="$TMP_HOME" "$BIN" palette --image "$IMAGE" --json >"$OUT_DIR/palette.json"
MACWAL_HOME="$TMP_HOME" "$BIN" preview --image "$IMAGE" --targets all --json >"$OUT_DIR/preview.json"
MACWAL_HOME="$TMP_HOME" "$BIN" apply --image "$IMAGE" --targets shell,terminal,chrome --dry-run --json >"$OUT_DIR/apply-dry-run.json"
MACWAL_HOME="$TMP_HOME" "$BIN" apply --image "$IMAGE" --targets shell,terminal,chrome --json >"$OUT_DIR/apply.json"
MACWAL_HOME="$TMP_HOME" "$BIN" restore --targets shell,terminal,chrome --json >"$OUT_DIR/restore.json"
MACWAL_HOME="$TMP_HOME" "$BIN" doctor --json >"$OUT_DIR/doctor.json"
MACWAL_HOME="$TMP_HOME" MACWAL_SKIP_LAUNCHCTL=1 MACWAL_EXECUTABLE=/tmp/macwal "$BIN" watch install --targets shell --json >"$OUT_DIR/watch-install.json"
MACWAL_HOME="$TMP_HOME" MACWAL_SKIP_LAUNCHCTL=1 "$BIN" watch uninstall --json >"$OUT_DIR/watch-uninstall.json"

set +e
MACWAL_HOME="$TMP_HOME" "$BIN" apply --image "$IMAGE" --targets system --json >"$OUT_DIR/system-block.json"
SYSTEM_EXIT=$?
MACWAL_HOME="$TMP_HOME" "$BIN" apply --image "$IMAGE" --targets finder --json >"$OUT_DIR/finder-block.json"
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

MACWAL_HOME="$TMP_HOME" "$BIN" apply --image "$IMAGE" --targets system --dry-run --json >"$OUT_DIR/system-dry-run.json"

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

echo "smoke ok"
echo "image=$IMAGE"
echo "tmp_home=$TMP_HOME"
echo "outputs=$OUT_DIR"
