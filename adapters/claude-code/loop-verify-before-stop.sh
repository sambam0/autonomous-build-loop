#!/usr/bin/env bash
# Claude Code Stop hook: while the build loop is running (LOOP_ACTIVE=1),
# block the agent from finishing if .loop/verify.sh fails, and feed back the errors.
# In normal interactive sessions it does nothing.
[ "${LOOP_ACTIVE:-0}" = "1" ] || exit 0

input="$(cat)"
case "$input" in
  *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
[ -x .loop/verify.sh ] || exit 0

# If the agent marked a task blocked in this iteration, let it stop.
if git diff HEAD~1 -- .loop/phases 2>/dev/null | grep -qE '^\+([[:space:]]*[-*] \[!\]|Result:[[:space:]]*blocked)'; then
  exit 0
fi

tmp="$(mktemp)"
if ! .loop/verify.sh > "$tmp" 2>&1; then
  {
    echo "The gate (.loop/verify.sh) is failing, so this iteration is not done. Fix it, or if you truly cannot, block the task in the phase's PROGRESS.md as RULES.md describes."
    tail -n 40 "$tmp"
  } >&2
  rm -f "$tmp"
  exit 2
fi
rm -f "$tmp"
exit 0
