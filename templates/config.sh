# autonomous-build-loop configuration (sourced by the .loop/*.sh scripts)

# Which agent CLI runs each iteration: claude | codex | gemini | opencode | custom
AGENT="__AGENT__"
# Optional model override passed to the agent (e.g. opus, or provider/model for opencode)
MODEL=""
# yolo = full permissions (use a branch/container) | safer = agent's sandbox or classifier mode
PERMISSIONS="yolo"

# The gate. Must exit 0 when the code is healthy. Keep it under ~3 minutes if possible.
VERIFY_CMD="__VERIFY__"

MAX_ITERS=40          # hard cap on iterations per run (a parallel wave counts as one)
ITER_TIMEOUT="60m"    # per-iteration time limit (needs timeout, or gtimeout on macOS)
STALL_LIMIT=3         # stop after this many iterations with no commits or progress changes
VERIFY_FAIL_LIMIT=4   # stop after the gate fails this many iterations in a row
ALLOW_MAIN=0          # 1 = allow running on main/master (not recommended)

# Goal verification when all tasks are done: 1 = run a verify-phase iteration, add gap tasks, keep going
AUTO_VERIFY=1
MAX_GAP_ROUNDS=2      # how many rounds of gap-closure tasks before stopping for a human

# ---- Parallel waves ------------------------------------------------------------
# Max tasks per wave. Ready tasks with disjoint Files run at once, each in its own worktree slot.
PARALLEL=1
# Where slot worktrees live (default: a sibling directory, <repo>/../.<repo>-loop-slots)
WORKTREE_ROOT=""
# Runs inside a slot whenever lockfiles change, so each slot has its own dependencies installed
WORKTREE_SETUP_CMD="__SETUP__"
# Untracked files copied from the main checkout into every slot (if they exist)
WORKTREE_COPY=".env .env.local .env.test"
# Claude Code: mirror this repo's trust to slot directories so workers load hooks and subagents
CLAUDE_TRUST_SLOTS=1

# ---- Cross-model review ----------------------------------------------------------
# A second agent CLI/model that independently checks plans and verifies phases.
# Empty = off. Example: REVIEW_AGENT="codex"  REVIEW_MODEL="gpt-5-codex"
REVIEW_AGENT=""
REVIEW_MODEL=""
REVIEW_EXTRA_ARGS=""
REVIEW_AGENT_CMD=""   # only for REVIEW_AGENT=custom
REVIEW_ROLES="plan-checker goal-verifier ui-checker"

# ---- UI checks ---------------------------------------------------------------------
UI_BASE_URL="http://localhost:3000"
UI_START_CMD=""                      # e.g. "pnpm dev"; started for screenshots if the URL isn't up
UI_VIEWPORTS="390x844 1440x900"
UI_STORAGE_STATE=""                  # Playwright storage state for logged-in pages, e.g. .loop/ui-auth.json

# AGENT=custom: a shell command run once per iteration. It receives:
#   $LOOP_PROMPT       full prompt text
#   $LOOP_PROMPT_FILE  path to the prompt file
#   $LOOP_ITERATION    iteration number
# Example: AGENT_CMD='my-agent --non-interactive --prompt-file "$LOOP_PROMPT_FILE"'
AGENT_CMD=""

# Extra flags appended to the agent command (space-separated, no quoting support)
# e.g. Claude Code spend cap: EXTRA_AGENT_ARGS="--max-budget-usd 20"
EXTRA_AGENT_ARGS=""

# Command run when the loop ends. Receives $LOOP_RESULT and $LOOP_EXIT.
# macOS notification: ON_FINISH='osascript -e "display notification \"$LOOP_RESULT\" with title \"Build loop\""'
# Phone push via ntfy: ON_FINISH='curl -s -d "$LOOP_RESULT" ntfy.sh/<your-topic>'
ON_FINISH=""
