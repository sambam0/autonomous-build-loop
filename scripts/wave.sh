#!/usr/bin/env bash
# Parallel waves by hand, for orchestrators that run executor subagents themselves
# (for example a Claude Code session spawning loop-executor subagents), or to inspect waves.
set -o pipefail
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: .loop/wave.sh <command> [--parallel N]

  plan      Show the next wave: ready tasks with disjoint Files, up to PARALLEL
  prepare   Create/refresh one worktree slot per task and write worker prompts.
            Prints one line per worker: TASK<TAB>SLOT_PATH<TAB>PROMPT_FILE
  run       Run the prepared workers headless with the configured agent, in parallel
  merge     Merge worker branches, record results in PROGRESS.md, commit, run the gate
  clean     Remove all slot worktrees and loop-slot-* branches

Typical subagent flow: plan -> prepare -> spawn one executor subagent per printed line
(working directory = SLOT_PATH, instruction = follow PROMPT_FILE) -> merge
USAGE
}

CMD_NAME="${1:-}"; [ -n "$CMD_NAME" ] || { usage; exit 1; }
shift
loop_load
while [ $# -gt 0 ]; do
  case "$1" in
    --parallel) PARALLEL="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "wave: unknown option $1" >&2; exit 1 ;;
  esac
  shift
done
[ "$PARALLEL" -ge 2 ] 2>/dev/null || PARALLEL=3
use_agent_profile primary

case "$CMD_NAME" in
  plan|prepare)
    resolve_phase "" || exit 1
    select_wave
    if [ -z "$WAVE_IDS" ]; then echo "wave: no ready tasks"; exit 2; fi
    if [ "$CMD_NAME" = "plan" ]; then
      tsv="$(spec_tasks)"
      echo "Next wave (max $PARALLEL):"
      for id in $WAVE_IDS; do
        printf '  %s  files: %s\n' "$id" "$(printf '%s\n' "$tsv" | awk -F'\t' -v id="$id" '$1 == id { print $3 }')"
      done
      [ "$(wave_size)" -lt 2 ] && echo "  (only one task is ready or safe to run; run it sequentially)"
      exit 0
    fi
    [ -z "$(git status --porcelain 2>/dev/null)" ] || { echo "wave: commit or stash changes before preparing a wave" >&2; exit 1; }
    [ -s "$WAVE_MANIFEST" ] && { echo "wave: a wave is already prepared; run 'merge' or 'clean' first" >&2; exit 1; }
    label="manual-$(date '+%Y%m%d-%H%M%S')"
    printf '%s\n' "$label" > "$LOOP_DIR/logs/wave-label"
    wave_prepare "$label" || exit 1
    cut -f2,3,5 "$WAVE_MANIFEST"
    ;;
  run)
    resolve_phase "" || exit 1
    [ -s "$WAVE_MANIFEST" ] || { echo "wave: nothing prepared" >&2; exit 1; }
    agent_preflight
    export LOOP_ACTIVE=1
    label="$(cat "$LOOP_DIR/logs/wave-label" 2>/dev/null || echo manual)"
    wave_run "$label"
    while IFS=$'\t' read -r _k id _rest; do
      echo "$id exit=$(cat "$LOOP_DIR/logs/wave-$label-$id.exit" 2>/dev/null || echo '?') log=$LOOP_DIR/logs/wave-$label-$id.agent.log"
    done < "$WAVE_MANIFEST"
    ;;
  merge)
    resolve_phase "" || exit 1
    label="$(cat "$LOOP_DIR/logs/wave-label" 2>/dev/null || echo manual)"
    wave_merge "$label" || exit 1
    echo "Merged:$WAVE_SUMMARY"
    if "$LOOP_DIR/verify.sh" > "$LOOP_DIR/logs/wave-$label.gate.log" 2>&1; then
      rm -f "$LOOP_DIR/LAST_VERIFY.txt"; echo "Gate: PASS"
    else
      cp "$LOOP_DIR/logs/wave-$label.gate.log" "$LOOP_DIR/LAST_VERIFY.txt"
      echo "Gate: FAIL after merge (see .loop/LAST_VERIFY.txt); fix it before the next wave"
      exit 3
    fi
    ;;
  clean)
    wave_clean; echo "wave: slots removed"
    ;;
  *) usage; exit 1 ;;
esac
