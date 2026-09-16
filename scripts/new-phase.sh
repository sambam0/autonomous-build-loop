#!/usr/bin/env bash
# Create the next phase directory from templates and make it the active phase.
set -o pipefail
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: .loop/new-phase.sh "<phase name>" [--ui] [--no-activate]

Creates .loop/phases/<NN>-<slug>/ with CONTEXT.md, SPEC.md, PROGRESS.md, VERIFICATION.md,
records the base commit, and sets it as the active phase in .loop/STATE.md.
--ui also adds UI-SPEC.md for phases with user-visible interface work.
USAGE
}

NAME=""; ACTIVATE=1; UI=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-activate) ACTIVATE=0 ;;
    --ui) UI=1 ;;
    -h|--help) usage; exit 0 ;;
    *) if [ -z "$NAME" ]; then NAME="$1"; else NAME="$NAME $1"; fi ;;
  esac
  shift
done
[ -n "$NAME" ] || { usage; exit 1; }

loop_load
TPL="$LOOP_DIR/templates/phase"
[ -d "$TPL" ] || { echo "new-phase: $TPL not found. Re-run the skill's init.sh." >&2; exit 1; }
mkdir -p "$LOOP_DIR/phases"

max=0
for d in "$LOOP_DIR"/phases/[0-9]*; do
  [ -d "$d" ] || continue
  n="$(basename "$d")"; n="${n%%-*}"; n="$(printf '%s' "$n" | sed 's/^0*//')"
  [ -n "$n" ] && [ "$n" -gt "$max" ] && max="$n"
done
NUM="$(printf '%02d' $((max + 1)))"
SLUG="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-40 | sed 's/-$//')"
[ -n "$SLUG" ] || SLUG="phase"
PHASE="$NUM-$SLUG"
DIR="$LOOP_DIR/phases/$PHASE"
mkdir -p "$DIR"

BASE="$(git rev-parse --short HEAD 2>/dev/null || echo none)"

{ printf '# Context: %s\n\n' "$NAME"; cat "$TPL/CONTEXT.md"; } > "$DIR/CONTEXT.md"
{ printf '# Spec: %s\n\n' "$NAME"; cat "$TPL/SPEC.md"; } > "$DIR/SPEC.md"
{ printf '# Progress: %s\n\nBase commit: %s\n\n' "$NAME" "$BASE"; cat "$TPL/PROGRESS.md"; } > "$DIR/PROGRESS.md"
{ cat "$TPL/VERIFICATION.md"; printf '\nPhase: %s\n' "$NAME"; } > "$DIR/VERIFICATION.md"
if [ "$UI" = 1 ]; then
  { printf '# UI contract: %s\n\n' "$NAME"; cat "$TPL/UI-SPEC.md"; } > "$DIR/UI-SPEC.md"
fi

if [ "$ACTIVATE" = 1 ]; then
  state_set "Active phase" "$PHASE"
  state_set "Stage" "discuss"
  state_set "Updated" "$(date '+%Y-%m-%d')"
  printf -- '- %s: created phase %s\n' "$(date '+%Y-%m-%d')" "$PHASE" >> "$LOOP_DIR/STATE.md"
fi

echo "Created $DIR (base commit $BASE)"
[ "$UI" = 1 ] && echo "Added UI contract: $DIR/UI-SPEC.md"
[ "$ACTIVATE" = 1 ] && echo "Active phase: $PHASE (stage: discuss)"
exit 0
