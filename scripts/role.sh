#!/usr/bin/env bash
# shellcheck disable=SC2034  # MODEL and PHASE_DIR are read by lib.sh
# Run one loop role in a fresh headless agent session. Output streams to stdout; the clean report
# is saved to .loop/logs/reviews/. Gives fresh-context subagents (and cross-model review) to any agent CLI.
set -o pipefail
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: .loop/role.sh <role> [options] [assignment...]

Roles: explorer | test-runner | reviewer | plan-checker | goal-verifier | codebase-mapper |
       ui-researcher | ui-checker

Options:
  --reviewer      Run on the cross-model reviewer (REVIEW_AGENT / REVIEW_MODEL in config.sh)
  --agent NAME    Run on a specific agent CLI for this call
  --model NAME    Model override for this call
  --out FILE      Where to save the report (default .loop/logs/reviews/<phase>/<role>-<agent>-<time>.md)
  --quiet         Don't stream the session; print only the saved report

Examples:
  .loop/role.sh plan-checker --reviewer
  .loop/role.sh goal-verifier --agent codex --model gpt-5-codex
  .loop/role.sh explorer "Find where margin notes hook into the Craft page"
USAGE
}

[ $# -ge 1 ] || { usage; exit 1; }
case "$1" in -h|--help) usage; exit 0 ;; esac
ROLE="$1"; shift

loop_load
PROFILE="primary"; OUT=""; QUIET=0; ASSIGNMENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --reviewer) PROFILE="reviewer" ;;
    --agent) AGENT="$2"; shift ;;
    --model) MODEL="$2"; shift ;;
    --out) OUT="$2"; shift ;;
    --quiet) QUIET=1 ;;
    -h|--help) usage; exit 0 ;;
    *) ASSIGNMENT="${ASSIGNMENT:+$ASSIGNMENT }$1" ;;
  esac
  shift
done

[ -f "$LOOP_DIR/roles/$ROLE.md" ] || { echo "role: $LOOP_DIR/roles/$ROLE.md not found" >&2; usage; exit 1; }
use_agent_profile primary
if [ "$PROFILE" = "reviewer" ] && [ -z "$REVIEW_AGENT" ]; then
  echo "role: --reviewer needs REVIEW_AGENT set in .loop/config.sh" >&2; exit 1
fi

PHASE_DIR=""
resolve_phase "" 2>/dev/null || { PHASE=""; PHASE_DIR=""; }

if [ -z "$ASSIGNMENT" ]; then
  case "$ROLE" in
    plan-checker) ASSIGNMENT="Check the active phase's plan." ;;
    goal-verifier) ASSIGNMENT="Verify the active phase against its must-haves, roadmap success criteria, and decisions." ;;
    codebase-mapper) ASSIGNMENT="Map this repository into .loop/CODEBASE.md." ;;
    reviewer) ASSIGNMENT="Review the current uncommitted change." ;;
    test-runner) ASSIGNMENT="Run the gate and report." ;;
    ui-researcher) ASSIGNMENT="Survey the existing design system and UI patterns relevant to the active phase." ;;
    ui-checker) ASSIGNMENT="Audit the active phase's UI against its UI-SPEC.md." ;;
    *) echo "role: '$ROLE' needs an assignment" >&2; exit 1 ;;
  esac
fi

use_agent_profile "$PROFILE"
agent_preflight
RUN_AGENT_NAME="$AGENT"
use_agent_profile primary

if [ -z "$OUT" ]; then
  OUT="$LOOP_DIR/logs/reviews/${PHASE:-project}/$ROLE-$RUN_AGENT_NAME-$(date '+%Y%m%d-%H%M%S').md"
fi

before="$(git status --porcelain 2>/dev/null | cksum)"
ROLE_QUIET="$QUIET" role_run "$ROLE" "$ASSIGNMENT" "$OUT" "$PROFILE"
after="$(git status --porcelain 2>/dev/null | cksum)"

[ "$QUIET" = 1 ] && cat "$(abs_path "$OUT")"
echo
echo "role: report saved to $OUT"
if [ "$before" != "$after" ] && [ "$ROLE" != "codebase-mapper" ]; then
  echo "role: warning: the working tree changed while running read-only role '$ROLE'. Review with: git status" >&2
fi
exit "$AGENT_EXIT"
