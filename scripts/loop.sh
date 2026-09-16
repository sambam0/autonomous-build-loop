#!/usr/bin/env bash
# autonomous-build-loop harness
# Executes the active phase with fresh agent sessions (one task each, or a parallel wave of
# independent tasks in isolated worktrees), runs the gate after every iteration, verifies the
# phase goal (optionally with a second model) when tasks are done, turns gaps into new tasks,
# and stops safely. Bash 3.2 compatible.
set -o pipefail
# shellcheck disable=SC1091
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  cat <<'USAGE'
Usage: .loop/loop.sh [options]

  --once          Run a single iteration (supervised dry run)
  --max N         Override MAX_ITERS for this run
  --phase NAME    Run a phase other than the active one (directory name under .loop/phases)
  --agent NAME    Override AGENT (claude | codex | gemini | opencode | custom)
  --model NAME    Override MODEL
  --parallel N    Override PARALLEL (max tasks per wave; 1 = sequential)
  --no-review     Skip cross-model review for this run
  --no-verify     Skip goal verification when tasks finish (same as AUTO_VERIFY=0)
  --reverify      Verify again even if VERIFICATION.md already says passed
  --dry-run       Print the plan for the next iteration and the agent command, then exit
  --allow-red     Start even if the gate fails before the first iteration
  -h, --help      Show this help

Exit codes: 0 phase verified (or all tasks done with --no-verify) | 1 setup error |
            2 only blocked tasks left | 3 stalled | 4 gate failed too often |
            5 hit max iterations | 6 stopped via .loop/STOP |
            7 human verification needed | 8 gaps remain after max gap rounds
USAGE
}

loop_load

PHASE_ARG=""; DRY_RUN=0; ALLOW_RED=0; REVERIFY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --once) MAX_ITERS=1 ;;
    --max) MAX_ITERS="$2"; shift ;;
    --phase) PHASE_ARG="$2"; shift ;;
    --agent) AGENT="$2"; shift ;;
    --model) MODEL="$2"; shift ;;
    --parallel) PARALLEL="$2"; shift ;;
    --no-review) REVIEW_AGENT="" ;;
    --no-verify) AUTO_VERIFY=0 ;;
    --reverify) REVERIFY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --allow-red) ALLOW_RED=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "loop: unknown option $1" >&2; usage; exit 1 ;;
  esac
  shift
done

use_agent_profile primary
resolve_phase "$PHASE_ARG" || exit 1

LOGS="$LOOP_DIR/logs"
RUNLOG="$LOGS/run.log"
LAST_VERIFY="$LOOP_DIR/LAST_VERIFY.txt"
SOLO_IDS=""

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$RUNLOG"; }

finish() {
  code="$1"; reason="$2"
  log "LOOP END [$PHASE] ($reason) | done=$(done_count) open=$(open_count) blocked=$(blocked_count) verification=$(verification_status)"
  if [ -n "$ON_FINISH" ]; then
    LOOP_RESULT="$PHASE: $reason" LOOP_EXIT="$code" bash -c "$ON_FINISH" || true
  fi
  exit "$code"
}

tree_clean() { [ -z "$(git status --porcelain 2>/dev/null)" ]; }

# ---- preflight ------------------------------------------------------------------

[ -f "$PROGRESS" ] || { echo "loop: $PROGRESS not found" >&2; exit 1; }
if grep -qE '<short title>' "$PROGRESS" || grep -qE '<title>|<phase goal' "$PHASE_DIR/SPEC.md" 2>/dev/null; then
  echo "loop: $PHASE_DIR still has template placeholders in SPEC.md or PROGRESS.md. Finish planning first." >&2
  exit 1
fi
if [ -f "$PHASE_DIR/UI-SPEC.md" ] && ! grep -qE '^Status:[[:space:]]*approved' "$PHASE_DIR/UI-SPEC.md"; then
  echo "loop: $PHASE_DIR/UI-SPEC.md isn't approved yet (set 'Status: approved' once the user signs off)." >&2
  exit 1
fi
if [ "$(open_count)" -eq 0 ] && [ "$(done_count)" -eq 0 ] && [ "$(blocked_count)" -eq 0 ]; then
  echo "loop: no tasks in $PROGRESS (expected lines like '- [ ] T1 title')." >&2
  exit 1
fi

if [ "$DRY_RUN" = 1 ]; then
  build_cmd "$(cat "$LOOP_DIR/PROMPT.md")"
  echo "Phase: $PHASE   Agent: $AGENT   Permissions: $PERMISSIONS   Model: ${MODEL:-default}"
  echo "Gate: ${VERIFY_CMD:-<not set>}"
  echo "Auto verify: $AUTO_VERIFY (max gap rounds: $MAX_GAP_ROUNDS)   Current verification: $(verification_status)"
  echo "Cross-model review: ${REVIEW_AGENT:-off}${REVIEW_AGENT:+ (model ${REVIEW_MODEL:-default}; roles: $REVIEW_ROLES)}"
  if [ -n "$TIMEOUT_BIN" ]; then echo "Timeout per iteration: $ITER_TIMEOUT"; else echo "Timeout per iteration: none (brew install coreutils for gtimeout)"; fi
  echo "Tasks: open=$(open_count) done=$(done_count) blocked=$(blocked_count)"
  if [ "$PARALLEL" -gt 1 ]; then
    select_wave
    echo "Parallel: up to $PARALLEL. Next wave: ${WAVE_IDS:-none ready} (slots in $(slot_root))"
  fi
  [ -f "$PHASE_DIR/UI-SPEC.md" ] && echo "UI contract: $PHASE_DIR/UI-SPEC.md (ui-checker runs during verification)"
  echo "Command:"
  print_cmd
  exit 0
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [ "$ALLOW_MAIN" != "1" ] && { [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; }; then
  echo "loop: refusing to run on '$BRANCH'. Create a branch first: git switch -c loop/$PHASE" >&2
  echo "      (set ALLOW_MAIN=1 in config.sh to override)" >&2
  exit 1
fi

[ -n "$VERIFY_CMD" ] || { echo "loop: VERIFY_CMD is empty in $LOOP_DIR/config.sh" >&2; exit 1; }
agent_preflight
if [ -n "$REVIEW_AGENT" ]; then
  use_agent_profile reviewer; agent_preflight; use_agent_profile primary
fi
[ -z "$TIMEOUT_BIN" ] && echo "loop: warning: no 'timeout'/'gtimeout' found; iterations have no time limit (brew install coreutils)"

log "LOOP START [$PHASE] | agent=$AGENT perms=$PERMISSIONS model=${MODEL:-default} branch=$BRANCH max=$MAX_ITERS parallel=$PARALLEL review=${REVIEW_AGENT:-off} auto_verify=$AUTO_VERIFY"
if [ "$PERMISSIONS" != "safer" ] && [ "$AGENT" != "custom" ]; then
  echo "loop: agents run with full permissions. Prefer a container/VM for unattended runs. Starting in 5s (Ctrl-C to abort)."
  sleep 5
fi

log "baseline gate..."
if "$LOOP_DIR/verify.sh" > "$LOGS/verify-baseline.log" 2>&1; then
  rm -f "$LAST_VERIFY"
  log "baseline gate: PASS"
elif [ "$ALLOW_RED" = 1 ]; then
  cp "$LOGS/verify-baseline.log" "$LAST_VERIFY"
  log "baseline gate: FAIL (continuing with --allow-red; iteration 1 will be asked to fix it)"
else
  log "baseline gate: FAIL. Fix it first or pass --allow-red. See $LOGS/verify-baseline.log"
  exit 1
fi

export LOOP_ACTIVE=1

NEED_VERIFY=1
if [ "$REVERIFY" != 1 ] && [ "$(open_count)" -eq 0 ] && [ "$(verification_status)" = "passed" ]; then
  NEED_VERIFY=0
fi

# ---- main loop ------------------------------------------------------------------

i=1
stalls=0
vfails=0
verify_rounds=0
wave_n=0
RUN_ID="$(date '+%Y%m%d-%H%M%S')"

while [ "$i" -le "$MAX_ITERS" ]; do
  if [ -f "$LOOP_DIR/STOP" ]; then
    rm -f "$LOOP_DIR/STOP"
    finish 6 "stop file"
  fi

  open="$(open_count)"; blocked="$(blocked_count)"
  KIND="execute"
  if [ "$open" -eq 0 ] && [ ! -f "$LAST_VERIFY" ]; then
    if [ "$blocked" -gt 0 ]; then finish 2 "only blocked tasks remain"; fi
    if [ "$AUTO_VERIFY" != 1 ]; then finish 0 "all tasks complete (goal verification skipped)"; fi
    if [ "$NEED_VERIFY" = 0 ]; then
      case "$(verification_status)" in
        passed) finish 0 "phase verified" ;;
        human_needed) finish 7 "automated checks passed; human verification needed" ;;
        gaps_found) finish 8 "gaps found but no gap tasks were added" ;;
        *) finish 8 "verification did not record a status" ;;
      esac
    fi
    KIND="verify"
  elif [ "$PARALLEL" -gt 1 ] && [ ! -f "$LAST_VERIFY" ]; then
    select_wave
    if [ "$(wave_size)" -ge 2 ]; then
      if tree_clean; then KIND="wave"; else log "iter $i: working tree has uncommitted changes; running sequentially instead of a wave"; fi
    fi
  fi

  before="$(fingerprint)"
  AGENT_EXIT=0

  if [ "$KIND" = "wave" ]; then
    wave_n=$((wave_n + 1))
    label="$RUN_ID-w$wave_n"
    log "iter $i: wave $wave_n start: $WAVE_IDS"
    if ! wave_prepare "$label"; then
      log "iter $i: could not prepare worktree slots; falling back to sequential for the rest of this run"
      PARALLEL=1
      continue
    fi
    wave_run "$label"
    for wid in $WAVE_IDS; do
      log "iter $i:   $wid worker exit=$(cat "$LOGS/wave-$label-$wid.exit" 2>/dev/null || echo '?')"
    done
    wave_merge "$label"
    log "iter $i: wave $wave_n merged:$WAVE_SUMMARY"
  else
    pfile="$LOGS/$RUN_ID-iter$i.$KIND.prompt.md"
    review_reports=""
    if [ "$KIND" = "verify" ] && [ -n "$REVIEW_AGENT" ]; then
      rdir="$LOGS/reviews/$PHASE"
      review_pids=""
      if in_list goal-verifier "$REVIEW_ROLES"; then
        rf="$rdir/goal-verifier-$REVIEW_AGENT-$RUN_ID-$i.md"
        ( ROLE_QUIET=1 role_run goal-verifier "Verify the active phase against its must-haves, roadmap success criteria, and decisions." "$rf" reviewer ) &
        review_pids="$review_pids $!"; review_reports="$review_reports $rf"
      fi
      if [ -f "$PHASE_DIR/UI-SPEC.md" ] && in_list ui-checker "$REVIEW_ROLES"; then
        rf="$rdir/ui-checker-$REVIEW_AGENT-$RUN_ID-$i.md"
        ( ROLE_QUIET=1 role_run ui-checker "Audit the active phase's UI against its UI-SPEC.md." "$rf" reviewer ) &
        review_pids="$review_pids $!"; review_reports="$review_reports $rf"
      fi
      if [ -n "$review_pids" ]; then
        log "iter $i: cross-model review by $REVIEW_AGENT running:$review_reports"
        for p in $review_pids; do wait "$p"; done
      fi
    fi
    {
      if [ "$KIND" = "verify" ]; then cat "$LOOP_DIR/VERIFY_PROMPT.md"; else cat "$LOOP_DIR/PROMPT.md"; fi
      echo
      echo "---"
      echo "Harness context"
      echo "- Mode: SEQUENTIAL. Active phase directory: $PHASE_DIR"
      echo "- Iteration $i of $MAX_ITERS ($KIND). Open tasks: $open. Blocked: $blocked. Verification rounds so far: $verify_rounds."
      if [ -f "$PHASE_DIR/UI-SPEC.md" ]; then echo "- This phase has a UI contract: $PHASE_DIR/UI-SPEC.md"; fi
      for rf in $review_reports; do
        if [ -s "$rf" ]; then echo "- Cross-model report to merge ($REVIEW_AGENT): $rf"; else echo "- Cross-model review ($REVIEW_AGENT) produced no report at $rf; note this in VERIFICATION.md"; fi
      done
      if [ -n "$SOLO_IDS" ]; then echo "- Tasks that conflicted in a parallel wave and must be rebased onto current code:$SOLO_IDS"; fi
      if [ -f "$LAST_VERIFY" ]; then
        echo
        echo "The harness ran .loop/verify.sh after the previous iteration and it FAILED."
        echo "Fixing this is your task for this iteration; do not start a new task until verify passes."
        echo '```'
        tail -n 60 "$LAST_VERIFY"
        echo '```'
      fi
    } > "$pfile"

    LOOP_ITERATION="$i"; export LOOP_ITERATION
    log "iter $i: $KIND start (open=$open blocked=$blocked)"
    run_agent "$pfile" "$LOGS/$RUN_ID-iter$i.$KIND.agent.log"
    [ "$AGENT_EXIT" = "124" ] && log "iter $i: agent timed out after $ITER_TIMEOUT"
  fi

  vlog="$LOGS/$RUN_ID-iter$i.gate.log"
  if "$LOOP_DIR/verify.sh" > "$vlog" 2>&1; then
    gate="PASS"; vfails=0; rm -f "$LAST_VERIFY"
  else
    gate="FAIL"; vfails=$((vfails + 1)); cp "$vlog" "$LAST_VERIFY"
  fi

  after="$(fingerprint)"
  if [ "$before" = "$after" ]; then stalls=$((stalls + 1)); else stalls=0; fi

  if [ "$KIND" = "verify" ]; then
    verify_rounds=$((verify_rounds + 1))
    NEED_VERIFY=0
    vstatus="$(verification_status)"
    log "iter $i: verification status=${vstatus:-none} (round $verify_rounds)"
    if [ "$vstatus" = "gaps_found" ] && [ "$(open_count)" -gt 0 ]; then
      if [ "$verify_rounds" -gt "$MAX_GAP_ROUNDS" ]; then
        finish 8 "gaps remain after $MAX_GAP_ROUNDS gap-closure rounds (new gap tasks left open for review)"
      fi
      NEED_VERIFY=1
    fi
  elif [ "$before" != "$after" ]; then
    NEED_VERIFY=1
  fi

  dirty=""
  tree_clean || dirty=" uncommitted-changes"
  log "iter $i: $KIND agent_exit=$AGENT_EXIT gate=$gate done=$(done_count) open=$(open_count) blocked=$(blocked_count) stalls=$stalls$dirty"

  if [ "$stalls" -ge "$STALL_LIMIT" ]; then finish 3 "stalled: $stalls iterations without progress"; fi
  if [ "$vfails" -ge "$VERIFY_FAIL_LIMIT" ]; then finish 4 "gate failed $vfails iterations in a row"; fi

  i=$((i + 1))
done

finish 5 "reached max iterations ($MAX_ITERS)"
