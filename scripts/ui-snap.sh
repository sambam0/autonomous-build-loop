#!/usr/bin/env bash
# Screenshot routes of the running app at each viewport, for UI research and UI checks.
# Routes come from arguments or from the "## Screenshots" section of the active phase's UI-SPEC.md.
set -o pipefail
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: .loop/ui-snap.sh [--base URL] [--out DIR] [route ...]

Uses UI_BASE_URL, UI_START_CMD, UI_VIEWPORTS, and UI_STORAGE_STATE from .loop/config.sh.
Needs Playwright in the project (npm i -D @playwright/test && npx playwright install chromium).
Prints the path of every screenshot written.
USAGE
}

loop_load
OUT=""; ROUTES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) UI_BASE_URL="$2"; shift ;;
    --out) OUT="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) ROUTES="${ROUTES:+$ROUTES }$1" ;;
  esac
  shift
done

PHASE=""
resolve_phase "" 2>/dev/null || { PHASE=""; PHASE_DIR=""; }
if [ -z "$ROUTES" ] && [ -n "$PHASE" ] && [ -f "$PHASE_DIR/UI-SPEC.md" ]; then
  ROUTES="$(section_bullets "$PHASE_DIR/UI-SPEC.md" "Screenshots" | sed -e 's/^[[:space:]]*-[[:space:]]*//' -e 's/`//g' -e 's/[[:space:]].*$//' | grep '^/' | tr '\n' ' ')"
fi
[ -n "$(printf '%s' "$ROUTES" | tr -d ' ')" ] || { echo "ui-snap: no routes (pass them as arguments or list them under '## Screenshots' in UI-SPEC.md)" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "ui-snap: node is required" >&2; exit 1; }
[ -n "$OUT" ] || OUT="$LOOP_DIR/logs/screens/${PHASE:-project}/$(date '+%Y%m%d-%H%M%S')"
mkdir -p "$OUT"

up() { curl -s -o /dev/null -m 3 "$UI_BASE_URL"; }
SERVER_PID=""
if ! up; then
  if [ -z "$UI_START_CMD" ]; then
    echo "ui-snap: $UI_BASE_URL isn't responding. Start the app, or set UI_START_CMD in .loop/config.sh." >&2
    exit 4
  fi
  echo "ui-snap: starting app: $UI_START_CMD"
  set -m
  bash -c "$UI_START_CMD" > "$LOOP_DIR/logs/ui-server.log" 2>&1 &
  SERVER_PID=$!
  set +m
  waited=0
  until up; do
    sleep 2; waited=$((waited + 2))
    if [ "$waited" -ge 180 ] || ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "ui-snap: app didn't come up at $UI_BASE_URL; see $LOOP_DIR/logs/ui-server.log" >&2
      kill -- "-$SERVER_PID" 2>/dev/null || kill "$SERVER_PID" 2>/dev/null
      exit 4
    fi
  done
fi

# shellcheck disable=SC2086
UI_STORAGE_STATE="$UI_STORAGE_STATE" node "$LOOP_DIR/ui-snap.mjs" "$UI_BASE_URL" "$OUT" "$UI_VIEWPORTS" $ROUTES
status=$?

if [ -n "$SERVER_PID" ]; then
  kill -- "-$SERVER_PID" 2>/dev/null || kill "$SERVER_PID" 2>/dev/null
fi
exit "$status"
