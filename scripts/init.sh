#!/usr/bin/env bash
# Scaffold an autonomous build loop into the current git repository.
# Safe to re-run: existing files are kept unless --force is given. Bash 3.2 compatible.
set -o pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="$SKILL_DIR/templates"

usage() {
  cat <<'EOF'
Usage: bash <skill-dir>/scripts/init.sh [options]   (run from inside the target repo)

  --agent NAME      claude | codex | gemini | opencode | custom  (default: first one found on PATH)
  --verify "CMD"    Verify gate command (default: auto-detected from the project)
  --claude-code     Install Claude Code adapters even if AGENT isn't claude
  --no-claude-code  Skip Claude Code adapters
  --force           Overwrite existing .loop files (SPEC/PROGRESS/RULES are never overwritten)
  -h, --help        Show this help
EOF
}

AGENT=""
VERIFY=""
CLAUDE_ADAPTER="auto"
FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift ;;
    --verify) VERIFY="$2"; shift ;;
    --claude-code) CLAUDE_ADAPTER="yes" ;;
    --no-claude-code) CLAUDE_ADAPTER="no" ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "init: unknown option $1" >&2; usage; exit 1 ;;
  esac
  shift
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "init: run this inside a git repository (git init && git commit --allow-empty -m init)" >&2; exit 1; }
cd "$ROOT" || exit 1

CREATED=()
KEPT=()
NOTES=()

# copy_file SRC DEST [always-keep]
copy_file() {
  src="$1"; dest="$2"; keep="${3:-0}"
  if [ -e "$dest" ] && { [ "$FORCE" != 1 ] || [ "$keep" = 1 ]; }; then
    KEPT+=("$dest"); return
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  CREATED+=("$dest")
}

shell_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# ---- reuse values from an existing config ----------------------------------------
if [ -f .loop/config.sh ]; then
  # shellcheck disable=SC1091
  existing="$(AGENT=""; VERIFY_CMD=""; . .loop/config.sh >/dev/null 2>&1; printf '%s\n%s' "$AGENT" "$VERIFY_CMD")"
  [ -z "$AGENT" ] && AGENT="$(printf '%s\n' "$existing" | sed -n 1p)"
  [ -z "$VERIFY" ] && VERIFY="$(printf '%s\n' "$existing" | sed -n '2,$p')"
fi

# ---- detect agent -----------------------------------------------------------
if [ -z "$AGENT" ]; then
  for candidate in claude codex gemini opencode; do
    if command -v "$candidate" >/dev/null 2>&1; then AGENT="$candidate"; break; fi
  done
  if [ -z "$AGENT" ]; then
    AGENT="claude"
    NOTES+=("No agent CLI found on PATH; defaulted AGENT to claude. Change it in .loop/config.sh.")
  fi
fi
case "$AGENT" in claude|codex|gemini|opencode|custom) ;; *) echo "init: unknown agent '$AGENT'" >&2; exit 1 ;; esac

# ---- detect verify command --------------------------------------------------
has_script() { grep -qE "\"$1\"[[:space:]]*:" package.json 2>/dev/null; }

detect_verify() {
  parts=()
  if [ -f package.json ]; then
    pm="npm"; x="npx"
    if [ -f pnpm-lock.yaml ]; then pm="pnpm"; x="pnpm exec"
    elif [ -f yarn.lock ]; then pm="yarn"; x="yarn"
    elif [ -f bun.lockb ] || [ -f bun.lock ]; then pm="bun"; x="bunx"
    fi
    if has_script verify; then echo "$pm run verify"; return; fi
    if has_script typecheck; then parts+=("$pm run typecheck")
    elif has_script type-check; then parts+=("$pm run type-check")
    elif [ -f tsconfig.json ]; then parts+=("$x tsc --noEmit")
    fi
    has_script lint && parts+=("$pm run lint")
    # CI=true keeps watch-mode runners (vitest, jest --watch) to a single run
    if has_script test && ! grep -q 'no test specified' package.json; then parts+=("CI=true $pm run test"); fi
  elif [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then
    run=""; [ -f uv.lock ] && run="uv run "
    if grep -qs 'ruff' pyproject.toml requirements*.txt 2>/dev/null || [ -f ruff.toml ]; then parts+=("${run}ruff check ."); fi
    if grep -qs 'mypy' pyproject.toml requirements*.txt 2>/dev/null; then parts+=("${run}mypy ."); fi
    if [ -d tests ] || [ -d test ] || grep -qs 'pytest' pyproject.toml requirements*.txt 2>/dev/null; then parts+=("${run}pytest -q"); fi
  elif [ -f Cargo.toml ]; then
    parts+=("cargo clippy --all-targets -- -D warnings" "cargo test")
  elif [ -f go.mod ]; then
    parts+=("go vet ./..." "go test ./...")
  fi
  out=""
  for p in "${parts[@]}"; do
    if [ -z "$out" ]; then out="$p"; else out="$out && $p"; fi
  done
  echo "$out"
}

detect_setup() {
  if [ -f pnpm-lock.yaml ]; then echo "pnpm install --frozen-lockfile --prefer-offline"
  elif [ -f yarn.lock ]; then echo "yarn install --immutable || yarn install --frozen-lockfile"
  elif [ -f bun.lock ] || [ -f bun.lockb ]; then echo "bun install --frozen-lockfile"
  elif [ -f package-lock.json ]; then echo "npm ci --prefer-offline --no-audit --no-fund"
  elif [ -f package.json ]; then echo "npm install --no-audit --no-fund"
  elif [ -f uv.lock ]; then echo "uv sync --frozen"
  elif [ -f poetry.lock ]; then echo "poetry install --no-interaction"
  fi
}
SETUP=""
if [ -f .loop/config.sh ]; then
  SETUP="$(WORKTREE_SETUP_CMD=""; . .loop/config.sh >/dev/null 2>&1; printf '%s' "$WORKTREE_SETUP_CMD")"
  grep -q '^PARALLEL=' .loop/config.sh || NOTES+=("config.sh predates parallel waves, cross-model review, and UI checks. Re-run init with --force to add those settings (your agent and gate command are kept).")
fi
[ -n "$SETUP" ] || SETUP="$(detect_setup)"

if [ -z "$VERIFY" ]; then
  VERIFY="$(detect_verify)"
  if [ -z "$VERIFY" ]; then
    NOTES+=("Could not detect a verify command. Set VERIFY_CMD in .loop/config.sh before running the loop.")
  else
    NOTES+=("Detected verify command: $VERIFY  (edit VERIFY_CMD in .loop/config.sh if it's wrong)")
  fi
fi

# ---- .loop directory --------------------------------------------------------
mkdir -p .loop/logs .loop/roles

ROLES="explorer test-runner reviewer plan-checker goal-verifier codebase-mapper executor ui-researcher ui-checker cross-reviewer"

if [ -f .loop/SPEC.md ] && [ ! -d .loop/phases ]; then
  NOTES+=("Found a v1 layout (.loop/SPEC.md at the top level). Create a phase with .loop/new-phase.sh and move SPEC.md/PROGRESS.md content into it.")
fi

# Project files: created once, never overwritten
copy_file "$TEMPLATES/STATE.md" .loop/STATE.md 1
copy_file "$TEMPLATES/ROADMAP.md" .loop/ROADMAP.md 1
copy_file "$TEMPLATES/RULES.md" .loop/RULES.md 1

# Machinery: refreshed with --force
copy_file "$TEMPLATES/PROMPT.md" .loop/PROMPT.md
copy_file "$TEMPLATES/VERIFY_PROMPT.md" .loop/VERIFY_PROMPT.md
for f in CONTEXT UI-SPEC SPEC PROGRESS VERIFICATION; do
  copy_file "$TEMPLATES/phase/$f.md" ".loop/templates/phase/$f.md"
done
for r in $ROLES; do
  copy_file "$TEMPLATES/roles/$r.md" ".loop/roles/$r.md"
done
copy_file "$SKILL_DIR/scripts/lib.sh" .loop/lib.sh
for s in loop verify status role new-phase wave ui-snap; do
  copy_file "$SKILL_DIR/scripts/$s.sh" ".loop/$s.sh"
  chmod +x ".loop/$s.sh"
done
copy_file "$SKILL_DIR/scripts/ui-snap.mjs" .loop/ui-snap.mjs
mkdir -p .loop/phases

if [ ! -e .loop/config.sh ] || [ "$FORCE" = 1 ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      AGENT=*) printf 'AGENT=%s\n' "$(shell_quote "$AGENT")" ;;
      VERIFY_CMD=*) printf 'VERIFY_CMD=%s\n' "$(shell_quote "$VERIFY")" ;;
      WORKTREE_SETUP_CMD=*) printf 'WORKTREE_SETUP_CMD=%s\n' "$(shell_quote "$SETUP")" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$TEMPLATES/config.sh" > .loop/config.sh
  CREATED+=(".loop/config.sh")
else
  KEPT+=(".loop/config.sh")
fi

# ---- .gitignore ---------------------------------------------------------------
touch .gitignore
for pattern in ".loop/logs/" ".loop/LAST_VERIFY.txt" ".loop/STOP" ".loop/STATE.md.tmp.*" ".loop/ui-auth.json"; do
  grep -qxF "$pattern" .gitignore || { printf '%s\n' "$pattern" >> .gitignore; CREATED+=(".gitignore: $pattern"); }
done

# ---- AGENTS.md / CLAUDE.md pointer block ---------------------------------------
add_block() {
  f="$1"
  if [ -f "$f" ] && grep -q 'autonomous-build-loop:start' "$f"; then KEPT+=("$f (loop block)"); return; fi
  if [ -s "$f" ]; then printf '\n' >> "$f"; fi
  cat "$TEMPLATES/AGENTS-block.md" >> "$f"
  CREATED+=("$f (loop block)")
}
add_block AGENTS.md
# CLAUDE.md gets the block only if it doesn't already import AGENTS.md
if [ -f CLAUDE.md ] && ! grep -q '@AGENTS.md' CLAUDE.md; then add_block CLAUDE.md; fi

# ---- Claude Code adapter ------------------------------------------------------
if [ "$CLAUDE_ADAPTER" = "auto" ]; then
  if [ "$AGENT" = "claude" ] || [ -d .claude ]; then CLAUDE_ADAPTER="yes"; else CLAUDE_ADAPTER="no"; fi
fi

if [ "$CLAUDE_ADAPTER" = "yes" ]; then
  if [ ! -f CLAUDE.md ]; then
    printf '@AGENTS.md\n' > CLAUDE.md
    CREATED+=("CLAUDE.md (imports AGENTS.md)")
  fi
  for r in $ROLES; do
    copy_file "$TEMPLATES/roles/$r.md" ".claude/agents/loop-$r.md"
  done
  copy_file "$SKILL_DIR/adapters/claude-code/loop-verify-before-stop.sh" .claude/hooks/loop-verify-before-stop.sh
  chmod +x .claude/hooks/loop-verify-before-stop.sh

  HOOK_CMD='"$CLAUDE_PROJECT_DIR"/.claude/hooks/loop-verify-before-stop.sh'
  if command -v python3 >/dev/null 2>&1; then
    if HOOK_CMD="$HOOK_CMD" python3 - <<'PY'
import json, os, sys
p = ".claude/settings.json"
cmd = os.environ["HOOK_CMD"]
try:
    data = json.load(open(p)) if os.path.exists(p) else {}
except Exception:
    sys.exit(2)
stop = data.setdefault("hooks", {}).setdefault("Stop", [])
if any(h.get("command") == cmd for g in stop for h in g.get("hooks", [])):
    sys.exit(3)
stop.append({"hooks": [{"type": "command", "command": cmd}]})
os.makedirs(".claude", exist_ok=True)
with open(p, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    then CREATED+=(".claude/settings.json (Stop hook)")
    else
      rc=$?
      if [ "$rc" = 3 ]; then KEPT+=(".claude/settings.json (Stop hook already present)")
      else NOTES+=("Couldn't parse .claude/settings.json. Add a Stop hook running: $HOOK_CMD")
      fi
    fi
  else
    NOTES+=("python3 not found. Add a Stop hook to .claude/settings.json running: $HOOK_CMD")
  fi
fi

# ---- report ---------------------------------------------------------------------
echo "autonomous-build-loop initialized in $ROOT"
echo "Agent: $AGENT"
echo
if [ ${#CREATED[@]} -gt 0 ]; then echo "Created/updated:"; for f in "${CREATED[@]}"; do echo "  + $f"; done; fi
if [ ${#KEPT[@]} -gt 0 ]; then echo "Kept existing:"; for f in "${KEPT[@]}"; do echo "  = $f"; done; fi
if [ ${#NOTES[@]} -gt 0 ]; then echo; echo "Notes:"; for n in "${NOTES[@]}"; do echo "  ! $n"; done; fi
cat <<'EOF'

Next (the skill walks you through these):
  1. Existing code? Map it:        .loop/role.sh codebase-mapper
  2. Write .loop/ROADMAP.md (milestone goal, phases, success criteria)
  3. Start a phase:                .loop/new-phase.sh "<phase name>"
  4. Discuss -> CONTEXT.md, UI work? -> UI-SPEC.md, plan -> SPEC.md + PROGRESS.md, check: .loop/role.sh plan-checker
  5. Get the gate green:           .loop/verify.sh
  6. git switch -c loop/<phase>, then .loop/loop.sh --once, review, then .loop/loop.sh
  7. Review VERIFICATION.md, do human checks, ship, and start the next phase
Options: PARALLEL waves, REVIEW_AGENT cross-model review, and UI_* screenshot settings live in .loop/config.sh
EOF
