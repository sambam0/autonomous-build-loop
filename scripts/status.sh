#!/usr/bin/env bash
# Where the project stands: active phase, stage, next action, tasks, verification.
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
loop_load

echo "Branch:        $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
echo "Active phase:  $(state_field "Active phase")"
echo "Stage:         $(state_field "Stage")"
next="$(awk '/^## Next action/{f=1;next} /^## /{f=0} f' "$LOOP_DIR/STATE.md" 2>/dev/null | grep -v '^[[:space:]]*$' | head -n 2)"
[ -n "$next" ] && { echo "Next action:"; printf '%s\n' "$next" | sed 's/^/  /'; }

if resolve_phase "" 2>/dev/null; then
  echo
  echo "Tasks:         done=$(done_count)  open=$(open_count)  blocked=$(blocked_count)"
  echo "Verification:  $(verification_status)"
  if [ -f "$LOOP_DIR/LAST_VERIFY.txt" ]; then echo "Gate:          FAILING (see .loop/LAST_VERIFY.txt)"; else echo "Gate:          passing as of last harness check"; fi
  [ -f "$LOOP_DIR/STOP" ] && echo "Stop:          STOP file present; loop exits after the current iteration"

  if [ "$(blocked_count)" -gt 0 ]; then
    echo; echo "Blocked:"
    grep -E '^[[:space:]]*[-*] \[!\]' "$PROGRESS" | sed 's/^[[:space:]]*/  /'
  fi
  if [ "$(open_count)" -gt 0 ]; then
    echo; echo "Next open tasks:"
    grep -E '^[[:space:]]*[-*] \[ \]' "$PROGRESS" | head -n 3 | sed 's/^[[:space:]]*/  /'
  fi
  human="$(awk '/^## For the human/{f=1;next} /^## /{f=0} f' "$PROGRESS" | grep -E '^[[:space:]]*- [^[:space:]]' | head -n 5)"
  [ -n "$human" ] && { echo; echo "For the human:"; printf '%s\n' "$human" | sed 's/^[[:space:]]*/  /'; }
  echo; echo "Latest notes:"
  awk '/^## Notes/{f=1;next} /^## /{f=0} f' "$PROGRESS" | grep -E '^[[:space:]]*- ' | tail -n 4 | sed 's/^[[:space:]]*/  /'
fi

if [ -f "$LOOP_DIR/logs/run.log" ]; then
  echo; echo "Recent harness log:"
  tail -n 5 "$LOOP_DIR/logs/run.log" | sed 's/^/  /'
fi
echo; echo "Recent commits:"
git log --oneline -n 5 2>/dev/null | sed 's/^/  /'
