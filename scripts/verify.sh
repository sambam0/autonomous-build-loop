#!/usr/bin/env bash
# Runs the project's verify gate defined as VERIFY_CMD in .loop/config.sh.
# Exit 0 = pass. Used by the harness, the verifier role, and the Claude Code Stop hook.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 1
VERIFY_CMD=""
# shellcheck disable=SC1091
. .loop/config.sh
if [ -z "$VERIFY_CMD" ]; then
  echo "verify: VERIFY_CMD is empty in .loop/config.sh" >&2
  exit 1
fi
echo "\$ $VERIFY_CMD"
bash -c "$VERIFY_CMD"
status=$?
if [ "$status" -eq 0 ]; then echo "verify: PASS"; else echo "verify: FAIL (exit $status)"; fi
exit "$status"
