# shellcheck shell=bash
# shellcheck disable=SC2034  # variables are consumed by the scripts that source this file
# Shared helpers for the autonomous-build-loop scripts. Sourced, not executed.
# Bash 3.2 compatible (macOS default).

loop_load() {
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "loop: not inside a git repository" >&2; exit 1; }
  cd "$ROOT" || exit 1
  LOOP_DIR=".loop"

  # Defaults; config.sh overrides these, CLI flags override config
  AGENT="claude"; MODEL=""; PERMISSIONS="yolo"; AGENT_CMD=""; EXTRA_AGENT_ARGS=""
  VERIFY_CMD=""
  MAX_ITERS=40; ITER_TIMEOUT="60m"; STALL_LIMIT=3; VERIFY_FAIL_LIMIT=4; ALLOW_MAIN=0
  AUTO_VERIFY=1; MAX_GAP_ROUNDS=2
  PARALLEL=1; WORKTREE_ROOT=""; WORKTREE_SETUP_CMD=""; WORKTREE_COPY=".env .env.local .env.test"; CLAUDE_TRUST_SLOTS=1
  REVIEW_AGENT=""; REVIEW_MODEL=""; REVIEW_EXTRA_ARGS=""; REVIEW_AGENT_CMD=""; REVIEW_ROLES="plan-checker goal-verifier ui-checker"
  UI_BASE_URL="http://localhost:3000"; UI_START_CMD=""; UI_VIEWPORTS="390x844 1440x900"; UI_STORAGE_STATE=""
  ON_FINISH=""

  [ -f "$LOOP_DIR/config.sh" ] || { echo "loop: $LOOP_DIR/config.sh not found. Run the skill's scripts/init.sh first." >&2; exit 1; }
  # shellcheck disable=SC1091
  . "$LOOP_DIR/config.sh"

  TIMEOUT_BIN=""
  if command -v timeout >/dev/null 2>&1; then TIMEOUT_BIN="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_BIN="gtimeout"
  fi
  mkdir -p "$LOOP_DIR/logs"
  PROFILE_SAVED=""
}

in_list() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }

abs_path() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$ROOT" "$1" ;; esac; }

# ---- state and phase ----------------------------------------------------------

state_field() {  # state_field "Active phase"
  sed -n "s/^$1:[[:space:]]*//p" "$LOOP_DIR/STATE.md" 2>/dev/null | head -n 1 | tr -d '\r' | sed 's/[[:space:]]*$//'
}

state_set() {  # state_set "Field" "value" (portable rewrite, no sed -i)
  f="$LOOP_DIR/STATE.md"; tmp="$f.tmp.$$"
  [ -f "$f" ] || return 0
  found=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$1:"*) printf '%s: %s\n' "$1" "$2"; found=1 ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$f" > "$tmp"
  [ "$found" = 1 ] || printf '%s: %s\n' "$1" "$2" >> "$tmp"
  mv "$tmp" "$f"
}

resolve_phase() {  # resolve_phase [phase-dir-name]; sets PHASE, PHASE_DIR, PHASE_NUM, PROGRESS
  PHASE="${1:-$(state_field "Active phase")}"
  if [ -z "$PHASE" ] || [ "$PHASE" = "none" ]; then
    echo "loop: no active phase. Create one with: .loop/new-phase.sh \"<phase name>\"" >&2
    return 1
  fi
  PHASE_DIR="$LOOP_DIR/phases/$PHASE"
  if [ ! -d "$PHASE_DIR" ]; then
    echo "loop: phase directory $PHASE_DIR not found (check 'Active phase' in .loop/STATE.md)" >&2
    return 1
  fi
  PHASE_NUM="${PHASE%%-*}"
  PROGRESS="$PHASE_DIR/PROGRESS.md"
}

count_matches() { grep -cE "$1" "$PROGRESS" 2>/dev/null || true; }
open_count()    { count_matches '^[[:space:]]*[-*] \[ \]'; }
done_count()    { count_matches '^[[:space:]]*[-*] \[[xX]\]'; }
blocked_count() { count_matches '^[[:space:]]*[-*] \[!\]'; }

verification_status() {
  sed -n 's/^Status:[[:space:]]*//p' "$PHASE_DIR/VERIFICATION.md" 2>/dev/null | head -n 1 | awk '{print $1}'
}

# ---- tasks: SPEC.md parsing and PROGRESS.md editing ------------------------------

spec_tasks() {  # one line per task: ID<TAB>DEPENDS<TAB>FILES
  awk '
    function flush() { if (id != "") printf "%s\t%s\t%s\n", id, (deps == "" ? "none" : deps), (files == "" ? "-" : files) }
    /^### [TG][0-9]+/ { flush(); id = $2; sub(/[^A-Za-z0-9].*$/, "", id); deps = ""; files = ""; next }
    /^## / { flush(); id = ""; next }
    id != "" && /^Depends on:/ { v = $0; sub(/^Depends on:[ \t]*/, "", v); deps = v }
    id != "" && /^Files:/ { v = $0; sub(/^Files:[ \t]*/, "", v); gsub(/`/, "", v); files = v }
    END { flush() }
  ' "$PHASE_DIR/SPEC.md" 2>/dev/null
}

open_ids() {
  awk '/^[ \t]*[-*] \[ \] / { l = $0; sub(/^[ \t]*[-*] \[ \] /, "", l); split(l, w, /[ \t]/); print w[1] }' "$PROGRESS"
}

task_marker() {  # prints x, !, space, or nothing if the task isn't listed
  ID="$1" awk '
    /^[ \t]*[-*] \[.\] / {
      l = $0; sub(/^[ \t]*[-*] /, "", l); m = substr(l, 2, 1); rest = substr(l, 4)
      sub(/^[ \t]+/, "", rest); split(rest, w, /[ \t]/)
      if (w[1] == ENVIRON["ID"]) { print m; exit }
    }' "$PROGRESS"
}

progress_mark() {  # progress_mark ID MARKER [SUFFIX]
  ID="$1" MK="$2" SUF="${3:-}" awk '
    !done && /^[ \t]*[-*] \[ \] / {
      l = $0; sub(/^[ \t]*[-*] \[ \] /, "", l); split(l, w, /[ \t]/)
      if (w[1] == ENVIRON["ID"]) { sub(/\[ \]/, "[" ENVIRON["MK"] "]"); if (ENVIRON["SUF"] != "") $0 = $0 " " ENVIRON["SUF"]; done = 1 }
    }
    { print }' "$PROGRESS" > "$PROGRESS.tmp" && mv "$PROGRESS.tmp" "$PROGRESS"
}

progress_append() {  # progress_append "Section title" "text (may be multi-line)"
  [ -n "$(printf '%s' "$2" | tr -d '[:space:]')" ] || return 0
  SEC="## $1" ADD="$2" awk '
    BEGIN { n = split(ENVIRON["ADD"], A, "\n") }
    function emit() { for (i = 1; i <= n; i++) if (A[i] != "") print A[i]; added = 1 }
    insec && /^## / { emit(); printf "%s", blanks; blanks = ""; insec = 0 }
    insec && /^[ \t]*$/ { blanks = blanks $0 "\n"; next }
    insec { printf "%s", blanks; blanks = "" }
    { print }
    $0 == ENVIRON["SEC"] { insec = 1 }
    END {
      if (insec) { emit(); printf "%s", blanks }
      else if (!added) { print ""; print ENVIRON["SEC"]; emit() }
    }' "$PROGRESS" > "$PROGRESS.tmp" && mv "$PROGRESS.tmp" "$PROGRESS"
}

section_bullets() {  # section_bullets FILE "Section title"
  SEC="## $2" awk '$0 == ENVIRON["SEC"] { f = 1; next } /^## / { f = 0 } f && /^[ \t]*- [^ \t]/' "$1" 2>/dev/null
}

# ---- agent profiles and commands ----------------------------------------------

use_agent_profile() {  # use_agent_profile primary|reviewer
  if [ -z "$PROFILE_SAVED" ]; then
    P_AGENT="$AGENT"; P_MODEL="$MODEL"; P_EXTRA="$EXTRA_AGENT_ARGS"; P_CMD="$AGENT_CMD"; PROFILE_SAVED=1
  fi
  case "$1" in
    primary) AGENT="$P_AGENT"; MODEL="$P_MODEL"; EXTRA_AGENT_ARGS="$P_EXTRA"; AGENT_CMD="$P_CMD" ;;
    reviewer)
      [ -n "$REVIEW_AGENT" ] || return 1
      AGENT="$REVIEW_AGENT"; MODEL="$REVIEW_MODEL"; EXTRA_AGENT_ARGS="$REVIEW_EXTRA_ARGS"; AGENT_CMD="${REVIEW_AGENT_CMD:-$P_CMD}" ;;
  esac
}

build_cmd() {  # build_cmd "<prompt text>"; sets global array CMD
  _prompt="$1"
  EXTRA=()
  if [ -n "$EXTRA_AGENT_ARGS" ]; then
    read -r -a EXTRA <<< "$EXTRA_AGENT_ARGS"
  fi
  case "$AGENT" in
    claude)
      CMD=(claude -p "$_prompt")
      if [ "$PERMISSIONS" = "safer" ]; then CMD+=(--permission-mode auto); else CMD+=(--dangerously-skip-permissions); fi
      if [ -n "$MODEL" ]; then CMD+=(--model "$MODEL"); fi
      ;;
    codex)
      CMD=(codex exec)
      if [ "$PERMISSIONS" = "safer" ]; then CMD+=(--sandbox workspace-write); else CMD+=(--dangerously-bypass-approvals-and-sandbox); fi
      if [ -n "$MODEL" ]; then CMD+=(-m "$MODEL"); fi
      if [ -n "${LAST_MESSAGE_FILE:-}" ]; then CMD+=(-o "$LAST_MESSAGE_FILE"); fi
      ;;
    gemini)
      CMD=(gemini --yolo)
      if [ "$PERMISSIONS" = "safer" ]; then CMD+=(--sandbox); fi
      if [ -n "$MODEL" ]; then CMD+=(-m "$MODEL"); fi
      ;;
    opencode)
      CMD=(opencode run)
      if [ "$PERMISSIONS" != "safer" ]; then CMD+=(--auto); fi
      if [ -n "$MODEL" ]; then CMD+=(-m "$MODEL"); fi
      ;;
    custom)
      if [ -z "$AGENT_CMD" ]; then echo "loop: AGENT=custom requires AGENT_CMD (or REVIEW_AGENT_CMD for reviews) in config.sh" >&2; exit 1; fi
      CMD=(bash -c "$AGENT_CMD")
      ;;
    *)
      echo "loop: unknown agent '$AGENT'" >&2; exit 1 ;;
  esac
  if [ ${#EXTRA[@]} -gt 0 ]; then CMD+=("${EXTRA[@]}"); fi
  case "$AGENT" in
    codex|opencode) CMD+=("$_prompt") ;;
    gemini) CMD+=(-p "$_prompt") ;;
  esac
}

print_cmd() {
  printf '  '
  for a in "${CMD[@]}"; do
    case "$a" in
      *$'\n'*) printf '"<prompt: %s lines>" ' "$(printf '%s\n' "$a" | wc -l | tr -d ' ')" ;;
      *" "*) printf '"%s" ' "$a" ;;
      *) printf '%s ' "$a" ;;
    esac
  done
  printf '\n'
}

# run_agent PROMPT_FILE LOG_FILE [CWD] [QUIET=0|1] -> sets AGENT_EXIT
run_agent() {
  _pfile="$(abs_path "$1")"; _log="$2"; _cwd="${3:-$ROOT}"; _quiet="${4:-0}"
  LOOP_PROMPT_FILE="$_pfile"; export LOOP_PROMPT_FILE
  LOOP_PROMPT="$(cat "$_pfile")"; export LOOP_PROMPT
  build_cmd "$LOOP_PROMPT"
  if [ "$_quiet" = 1 ]; then
    if [ -n "$TIMEOUT_BIN" ]; then
      ( cd "$_cwd" && "$TIMEOUT_BIN" "$ITER_TIMEOUT" "${CMD[@]}" ) < /dev/null > "$_log" 2>&1
    else
      ( cd "$_cwd" && "${CMD[@]}" ) < /dev/null > "$_log" 2>&1
    fi
    AGENT_EXIT=$?
  else
    if [ -n "$TIMEOUT_BIN" ]; then
      ( cd "$_cwd" && "$TIMEOUT_BIN" "$ITER_TIMEOUT" "${CMD[@]}" ) < /dev/null 2>&1 | tee "$_log"
      AGENT_EXIT="${PIPESTATUS[0]}"
    else
      ( cd "$_cwd" && "${CMD[@]}" ) < /dev/null 2>&1 | tee "$_log"
      AGENT_EXIT="${PIPESTATUS[0]}"
    fi
  fi
}

claude_trusted() {  # prints yes | no | unknown
  if ! command -v python3 >/dev/null 2>&1 || [ ! -f "$HOME/.claude.json" ]; then echo unknown; return; fi
  DIR="$1" python3 -c 'import json,os
try:
    d=json.load(open(os.path.expanduser("~/.claude.json")))
    print("yes" if d.get("projects",{}).get(os.environ["DIR"],{}).get("hasTrustDialogAccepted") else "no")
except Exception:
    print("unknown")' 2>/dev/null
}

# Checks for agent binaries and known first-run gotchas for the current profile.
agent_preflight() {
  if [ "$AGENT" != "custom" ]; then
    build_cmd "x"
    command -v "${CMD[0]}" >/dev/null 2>&1 || { echo "loop: '${CMD[0]}' not found on PATH" >&2; exit 1; }
  fi
  if [ "$AGENT" = "claude" ]; then
    if [ "$PERMISSIONS" != "safer" ] && [ "$(id -u)" = "0" ] && [ -z "${IS_SANDBOX:-}" ]; then
      echo "loop: Claude Code refuses --dangerously-skip-permissions as root." >&2
      echo "      Inside a container/VM: export IS_SANDBOX=1. Otherwise run as a non-root user." >&2
      exit 1
    fi
    if [ "$(claude_trusted "$ROOT")" = "no" ]; then
      echo "loop: warning: Claude Code hasn't trusted $ROOT, so project settings, subagents, and the Stop hook may be ignored in headless mode."
      echo "      Run 'claude' here once interactively and accept the trust prompt."
    fi
  fi
  if [ "$AGENT" = "gemini" ]; then
    # Headless Gemini CLI silently downgrades --yolo to default approvals in untrusted folders.
    export GEMINI_CLI_TRUST_WORKSPACE=true
  fi
}

fingerprint() {
  {
    git rev-parse HEAD 2>/dev/null
    cksum < "$PROGRESS"
    [ -f "$PHASE_DIR/VERIFICATION.md" ] && cksum < "$PHASE_DIR/VERIFICATION.md"
    git diff HEAD 2>/dev/null | cksum
    git status --porcelain 2>/dev/null | cksum
  } | cksum
}

# ---- roles (fresh-context one-shot sessions) ------------------------------------

# role_run ROLE ASSIGNMENT OUT_FILE [primary|reviewer]
# Writes the report to OUT_FILE and the full transcript to OUT_FILE.log. Sets AGENT_EXIT.
role_run() {
  _role="$1"; _assign="$2"; _out="$(abs_path "$3")"; _profile="${4:-primary}"
  _rf="$LOOP_DIR/roles/$_role.md"
  [ -f "$_rf" ] || { echo "role: $_rf not found" >&2; AGENT_EXIT=1; return 1; }
  use_agent_profile "$_profile" || { echo "role: REVIEW_AGENT is not set in .loop/config.sh" >&2; AGENT_EXIT=1; return 1; }
  mkdir -p "$(dirname "$_out")"
  _pf="$_out.prompt.md"
  {
    cat "$_rf"
    echo
    echo "---"
    echo "Context"
    echo "- One-shot role in a fresh session, launched from the repository root."
    if [ -n "${PHASE_DIR:-}" ]; then echo "- Active phase directory: $PHASE_DIR"; fi
    echo "- Assignment: $_assign"
    if [ "$_profile" = "reviewer" ]; then
      echo "- You are an independent reviewer running on a different model from the one that planned and built this work. Judge only from the code and documents; don't defer to claims in the repo about its own quality."
    fi
    echo "- End with your complete report as your final message."
  } > "$_pf"
  _la="${LOOP_ACTIVE:-}"; unset LOOP_ACTIVE
  rm -f "$_out"
  if [ "$AGENT" = "codex" ]; then LAST_MESSAGE_FILE="$_out"; fi
  run_agent "$_pf" "$_out.log" "$ROOT" "${ROLE_QUIET:-0}"
  LAST_MESSAGE_FILE=""
  [ -s "$_out" ] || cp "$_out.log" "$_out"
  if [ -n "$_la" ]; then LOOP_ACTIVE="$_la"; export LOOP_ACTIVE; fi
  use_agent_profile primary
}

# ---- parallel waves -------------------------------------------------------------

trim_path() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's#/*$##'; }

paths_overlap() {  # paths_overlap "a, b" "c, d" -> exit 0 if any path equals or contains another
  _hit=1
  _oldifs="$IFS"; IFS=','
  for _a in $1; do
    _a="$(trim_path "$_a")"; [ -n "$_a" ] || continue
    for _b in $2; do
      _b="$(trim_path "$_b")"; [ -n "$_b" ] || continue
      case "$_a" in "$_b"|"$_b"/*) _hit=0 ;; esac
      case "$_b" in "$_a"/*) _hit=0 ;; esac
    done
  done
  IFS="$_oldifs"
  return "$_hit"
}

# select_wave: sets WAVE_IDS to up to PARALLEL ready tasks with disjoint Files.
# Tasks without Files, or listed in SOLO_IDS, only ever run alone.
select_wave() {
  WAVE_IDS=""; _files_all=""; _n=0
  _tsv="$(spec_tasks)"
  for _id in $(open_ids); do
    [ "$_n" -ge "$PARALLEL" ] && break
    _row="$(printf '%s\n' "$_tsv" | awk -F'\t' -v id="$_id" '$1 == id')"
    [ -n "$_row" ] || continue
    _deps="$(printf '%s' "$_row" | cut -f2)"
    _files="$(printf '%s' "$_row" | cut -f3)"
    _ready=1
    for _d in $(printf '%s' "$_deps" | grep -oE '[TG][0-9]+'); do
      case "$(task_marker "$_d")" in x|X) ;; *) _ready=0 ;; esac
    done
    [ "$_ready" = 1 ] || continue
    if [ "$_files" = "-" ] || in_list "$_id" "${SOLO_IDS:-}"; then
      if [ "$_n" -eq 0 ]; then WAVE_IDS="$_id"; return 0; fi
      continue
    fi
    if [ -n "$_files_all" ] && paths_overlap "$_files" "$_files_all"; then continue; fi
    WAVE_IDS="${WAVE_IDS:+$WAVE_IDS }$_id"
    _files_all="${_files_all:+$_files_all, }$_files"
    _n=$((_n + 1))
  done
}

wave_size() {
  # shellcheck disable=SC2086
  set -- $WAVE_IDS
  echo $#
}

slot_root() {
  if [ -n "$WORKTREE_ROOT" ]; then printf '%s' "$WORKTREE_ROOT"
  else printf '%s/.%s-loop-slots' "$(dirname "$ROOT")" "$(basename "$ROOT")"
  fi
}

lock_hash() {
  for _lf in package-lock.json npm-shrinkwrap.json pnpm-lock.yaml yarn.lock bun.lock bun.lockb uv.lock poetry.lock Pipfile.lock requirements.txt Cargo.lock go.sum Gemfile.lock composer.lock; do
    if [ -f "$1/$_lf" ]; then printf '%s ' "$_lf"; cksum < "$1/$_lf"; fi
  done | cksum
}

# Mirror this repo's Claude Code trust to a slot so headless workers load settings, hooks, and subagents.
trust_mirror() {
  [ "$AGENT" = "claude" ] && [ "$CLAUDE_TRUST_SLOTS" = "1" ] || return 0
  command -v python3 >/dev/null 2>&1 && [ -f "$HOME/.claude.json" ] || return 0
  ROOT="$ROOT" SLOT="$1" python3 - <<'PY' 2>/dev/null || true
import json, os, shutil, tempfile
p = os.path.expanduser("~/.claude.json")
d = json.load(open(p))
projects = d.setdefault("projects", {})
if not projects.get(os.environ["ROOT"], {}).get("hasTrustDialogAccepted"):
    raise SystemExit(0)
entry = projects.setdefault(os.environ["SLOT"], {})
if entry.get("hasTrustDialogAccepted"):
    raise SystemExit(0)
if not os.path.exists(p + ".loop-backup"):
    shutil.copy2(p, p + ".loop-backup")
entry["hasTrustDialogAccepted"] = True
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(p))
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2)
os.replace(tmp, p)
PY
}

# slot_prepare K BASE_COMMIT -> sets SLOT_PATH. Slots are persistent worktrees reused across
# waves, so installed dependencies survive and setup only reruns when lockfiles change.
slot_prepare() {
  _k="$1"; _base="$2"; _sroot="$(slot_root)"
  mkdir -p "$_sroot" && _sroot="$(cd "$_sroot" && pwd -P)"
  SLOT_PATH="$_sroot/slot-$_k"; _br="loop-slot-$_k"
  if ! git worktree list --porcelain | grep -qxF "worktree $SLOT_PATH"; then
    git worktree prune
    if [ -e "$SLOT_PATH" ]; then
      echo "loop: $SLOT_PATH exists but isn't a worktree of this repo; remove it or set WORKTREE_ROOT" >&2
      return 1
    fi
    git worktree add -q --detach "$SLOT_PATH" "$_base" >/dev/null 2>&1 || { echo "loop: could not create worktree $SLOT_PATH" >&2; return 1; }
  fi
  git -C "$SLOT_PATH" reset -q --hard >/dev/null 2>&1
  git -C "$SLOT_PATH" clean -fdq >/dev/null 2>&1
  git -C "$SLOT_PATH" checkout -q -B "$_br" "$_base" >/dev/null 2>&1 || { echo "loop: could not check out $_base in $SLOT_PATH" >&2; return 1; }
  for _f in $WORKTREE_COPY; do
    if [ -f "$ROOT/$_f" ]; then mkdir -p "$(dirname "$SLOT_PATH/$_f")"; cp -p "$ROOT/$_f" "$SLOT_PATH/$_f"; fi
  done
  _gd="$(git -C "$SLOT_PATH" rev-parse --absolute-git-dir)"
  _h="$(lock_hash "$SLOT_PATH")"
  if [ -n "$WORKTREE_SETUP_CMD" ] && [ "$(cat "$_gd/loop-setup-hash" 2>/dev/null)" != "$_h" ]; then
    echo "loop: slot $_k: running setup ($WORKTREE_SETUP_CMD)" >&2
    if ( cd "$SLOT_PATH" && bash -c "$WORKTREE_SETUP_CMD" ) > "$LOOP_DIR/logs/slot-$_k-setup.log" 2>&1; then
      printf '%s' "$_h" > "$_gd/loop-setup-hash"
    else
      echo "loop: slot $_k setup failed; see $LOOP_DIR/logs/slot-$_k-setup.log" >&2
      return 1
    fi
  fi
  trust_mirror "$SLOT_PATH"
}

WAVE_MANIFEST=".loop/logs/wave-manifest.tsv"

# wave_prepare LABEL: prepares one slot per task in WAVE_IDS and writes worker prompts and a manifest.
wave_prepare() {
  _label="$1"; _base="$(git rev-parse HEAD)"; : > "$WAVE_MANIFEST"; _k=0
  for _id in $WAVE_IDS; do
    _k=$((_k + 1))
    slot_prepare "$_k" "$_base" || { rm -f "$WAVE_MANIFEST"; return 1; }
    _pf="$ROOT/$LOOP_DIR/logs/wave-$_label-$_id.prompt.md"
    {
      cat "$LOOP_DIR/PROMPT.md"
      echo
      echo "---"
      echo "Harness context"
      echo "- Mode: PARALLEL WORKER. Your assigned task is $_id. Do only this task."
      echo "- Active phase directory: $PHASE_DIR"
      echo "- Working directory: isolated git worktree $SLOT_PATH on branch loop-slot-$_k. Other workers are building other tasks at the same time; the harness merges your branch when all are done."
      echo "- Record your outcome in $PHASE_DIR/results/$_id.md as described under \"Parallel worker mode\". Do not edit PROGRESS.md or .loop/STATE.md."
    } > "$_pf"
    printf '%s\t%s\t%s\t%s\t%s\n' "$_k" "$_id" "$SLOT_PATH" "$_base" "$_pf" >> "$WAVE_MANIFEST"
  done
}

# wave_run LABEL: runs every prepared worker headless and in parallel, then waits for all.
wave_run() {
  _pids=""
  while IFS=$'\t' read -r _k _id _path _base _pf; do
    [ -n "$_id" ] || continue
    ( run_agent "$_pf" "$LOOP_DIR/logs/wave-$1-$_id.agent.log" "$_path" 1; echo "$AGENT_EXIT" > "$LOOP_DIR/logs/wave-$1-$_id.exit" ) &
    _pids="$_pids $!"
  done < "$WAVE_MANIFEST"
  for _p in $_pids; do wait "$_p"; done
}

# wave_merge LABEL: merges worker branches, applies results files to PROGRESS.md, commits.
# Sets WAVE_SUMMARY. Tasks that conflict are added to SOLO_IDS and stay open.
wave_merge() {
  _label="$1"; WAVE_SUMMARY=""; _merged=""; _pending=""
  [ -s "$WAVE_MANIFEST" ] || { echo "loop: no prepared wave (missing $WAVE_MANIFEST)" >&2; return 1; }
  while IFS=$'\t' read -r _k _id _path _base _pf; do
    [ -n "$_id" ] || continue
    _br="loop-slot-$_k"
    _ahead="$(git rev-list --count "$_base..$_br" 2>/dev/null || echo 0)"
    if [ "$_ahead" = "0" ]; then
      _pending="$_pending
- $_id (wave $_label): worker made no commit; left open. Log: .loop/logs/wave-$_label-$_id.agent.log"
      WAVE_SUMMARY="$WAVE_SUMMARY $_id:no-commit"
      continue
    fi
    if git merge -q --no-ff --no-edit -m "P$PHASE_NUM-wave: merge $_id" "$_br" >/dev/null 2>&1; then
      _merged="$_merged $_id"; WAVE_SUMMARY="$WAVE_SUMMARY $_id:merged"
    else
      git merge --abort >/dev/null 2>&1
      SOLO_IDS="${SOLO_IDS:-} $_id"
      _pending="$_pending
- $_id (wave $_label): merge conflict with another task in the wave; left open to rerun on its own"
      WAVE_SUMMARY="$WAVE_SUMMARY $_id:conflict"
    fi
  done < "$WAVE_MANIFEST"

  for _id in $_merged; do
    _rf="$PHASE_DIR/results/$_id.md"
    if [ ! -f "$_rf" ]; then
      _pending="$_pending
- $_id (wave $_label): merged, but the worker wrote no results file; left open for review"
      continue
    fi
    _res="$(sed -n 's/^Result:[[:space:]]*//p' "$_rf" | head -n 1)"
    case "$_res" in
      done*) progress_mark "$_id" x ;;
      blocked*) progress_mark "$_id" '!' "BLOCKED: $(printf '%s' "${_res#blocked}" | sed 's/^[[:space:]:]*//')" ;;
      *) _pending="$_pending
- $_id (wave $_label): results file has no valid Result line; left open for review" ;;
    esac
    progress_append "Notes" "$(section_bullets "$_rf" "Notes")"
    progress_append "Deferred" "$(section_bullets "$_rf" "Deferred")"
    progress_append "For the human" "$(section_bullets "$_rf" "For the human")"
  done
  progress_append "Notes" "$_pending"
  git add "$PROGRESS" >/dev/null 2>&1
  git commit -q -m "P$PHASE_NUM-wave: record results ($(printf '%s' "$WAVE_SUMMARY" | sed 's/^ //'))" >/dev/null 2>&1 || true
  rm -f "$WAVE_MANIFEST"
}

wave_clean() {
  _sroot="$(slot_root)"
  for _p in "$_sroot"/slot-*; do
    [ -d "$_p" ] || continue
    git worktree remove --force "$_p" >/dev/null 2>&1 || true
  done
  git worktree prune
  for _b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/loop-slot-*'); do
    git branch -D "$_b" >/dev/null 2>&1 || true
  done
  rmdir "$_sroot" 2>/dev/null || true
  rm -f "$WAVE_MANIFEST"
}
