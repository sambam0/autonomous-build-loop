# Agent reference

How `.loop/loop.sh` drives each coding agent, what differs between them, and how to add any other CLI.

These presets were checked against Claude Code 2.1.x, Codex CLI 0.154, Gemini CLI 0.59, and OpenCode 1.18 (September 2026). CLIs change fast, so if a flag errors, compare against `<agent> --help` and adjust `EXTRA_AGENT_ARGS` or use `AGENT=custom`.

## Contents
- Presets
- First-run gotchas
- Subagents and roles per agent
- Specialist orchestration
- Installing the skill per agent
- Custom agents and local models
- Cost control

## Presets

| AGENT | `PERMISSIONS=yolo` (default) | `PERMISSIONS=safer` | Model flag |
|---|---|---|---|
| `claude` | `claude -p "<prompt>" --dangerously-skip-permissions` | `--permission-mode auto` instead of skip | `--model` |
| `codex` | `codex exec --dangerously-bypass-approvals-and-sandbox "<prompt>"` | `--sandbox workspace-write` | `-m` |
| `gemini` | `gemini --yolo -p "<prompt>"` | adds `--sandbox` (needs a container runtime, or Seatbelt on macOS) | `-m` |
| `opencode` | `opencode run --auto "<prompt>"` | drops `--auto`; relies on permission rules in `opencode.json` | `-m provider/model` (list with `opencode models`) |

Tradeoffs of `safer`:
- **Claude `auto`** uses a classifier to approve or deny each action. It keeps the agent from doing obviously risky things, but it may deny some commands a task needs. Watch the first iteration's log for denials.
- **Codex `workspace-write`** confines writes to the repo and usually blocks network access, so installs and anything that fetches will fail. That's fine for pure code tasks and a problem for tasks that add dependencies.
- **Gemini `--sandbox`** runs tools in a container, so the gate command must work inside that container image.
- **OpenCode without `--auto`**: anything not explicitly allowed in your `opencode.json` permissions gets denied in headless mode. Allow your verify command, git, and edits there.

`yolo` gives the most reliable runs, so pair it with a branch plus a container, VM, or cloud dev box for anything unattended.

## First-run gotchas

**Claude Code**
- It refuses `--dangerously-skip-permissions` when running as root. Inside a container, `export IS_SANDBOX=1`, or run as a non-root user. The harness checks for this before starting.
- In an untrusted directory, headless runs ignore project settings, including the Stop hook and `permissions.allow`. Run `claude` interactively once in the repo and accept the trust prompt. Every new git worktree is a new path, so each one needs this. The harness warns when it can tell the directory isn't trusted.
- `CLAUDE.md` is what Claude Code reads. init creates one containing `@AGENTS.md` if missing, so both files stay in sync.

**Gemini CLI**
- In an untrusted folder, headless mode silently downgrades `--yolo` to default approvals, which stalls or denies every tool call. The harness exports `GEMINI_CLI_TRUST_WORKSPACE=true` for Gemini runs to prevent this.
- Auth has to be configured beforehand (`GEMINI_API_KEY` or a login).

**Codex CLI**
- It prints `Reading additional input from stdin...` at startup. The harness passes `/dev/null`, so this is harmless.
- Codex also has its own `--worktree` flag, but let the harness run in a worktree you created so the paths in `.loop/` stay stable.

**OpenCode**
- With no model configured, it falls back to its default free model. Set `MODEL` explicitly for real runs.

## Subagents and roles per agent

Every role in `.loop/roles/` is a subagent definition that also works as a plain prompt:

| Role | Job | Edits files? |
|---|---|---|
| explorer | Find files, patterns, and risks for a task | No |
| test-runner | Run the gate or one test, report failures briefly | No |
| reviewer | Check a task's diff before it's checked off | No |
| plan-checker | Check a phase plan before execution | No |
| goal-verifier | Verify a finished phase against its goal | No |
| ui-researcher | Survey the existing design system before a UI contract | No |
| ui-checker | Audit built UI against the UI contract, with screenshots | No |
| codebase-mapper | Write `.loop/CODEBASE.md` | Only that file |
| executor | Do one loop task from a prompt file, in a given directory | Yes |
| cross-reviewer | Fetch a second opinion from the reviewer model via `role.sh --reviewer` | No |

There are three ways to run them in a fresh context:

- **Native subagents.** For Claude Code, init copies all roles to `.claude/agents/loop-*.md`. Sessions spawn them by name, and several in one turn run concurrently. The Agent tool's `cwd` parameter points an executor at a worktree slot. Avoid its `isolation: "worktree"` option for loop work: those worktrees branch from `origin/<default branch>` by default, not your phase branch. For agents with their own subagent format (for example OpenCode's `opencode agent` definitions), port the role files and keep their read-only rules and short output formats.
- **`.loop/role.sh <role>`.** Runs the role as a one-shot headless session of any configured agent, optionally on the reviewer model (`--reviewer`) or another agent (`--agent`). Reports are saved under `.loop/logs/reviews/`. This works everywhere, including agents without subagents, and the script warns if a read-only role changed files.
- **Inline.** When neither is possible, the prompts tell the agent to follow the role instructions itself. That's weakest for plan-checker, goal-verifier, and ui-checker, because judging work in the context that produced it defeats the purpose, so prefer `role.sh` for those.

The harness runs the gate after every iteration and every wave for every agent, so the gate holds without hooks or subagents. The Claude Code Stop hook is an extra layer.

## Specialist orchestration

Sequential execute uses the executor role (or a wave of them). When a goal needs other specialists, follow SKILL.md **Orchestrate a goal** and `references/orchestrate.md`. Dispatch with the same three mechanisms as above (native subagent, `role.sh`, or inline). Write a self-contained brief (Goal, Your slice, Context, Constraints, Done means, Report back).

Do **not** depend on Grok Bot `SendToAgent` or `/home/box/orchestrator/inflight.md` to run this skill. Those exist only under `adapters/grok-bot/`. Standalone in-flight tracking is STATE.md Next action (Active) plus PROGRESS.md checkboxes (Queued / Blocked).

Plan-checker, goal-verifier, and ui-checker still judge in a fresh context. Orchestration does not replace `loop.sh`, weaken the gate, or skip those roles.

## Installing the skill per agent

The skill is a folder with a `SKILL.md`. Put the whole folder where your agent looks for skills:

| Agent | User-level | Project-level |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `.claude/skills/` |
| Codex CLI | `~/.agents/skills/` (older versions: `~/.codex/skills/`) | `.agents/skills/` |
| Gemini CLI | `~/.agents/skills/` or `~/.gemini/skills/` | `.agents/skills/` or `.gemini/skills/` |
| OpenCode | `~/.agents/skills/` or `~/.claude/skills/` | `.opencode/skills/` |

Each path above holds skill folders, so the skill itself lives at, for example, `~/.claude/skills/autonomous-build-loop/SKILL.md`. If an agent doesn't pick it up, check that version's docs, since discovery paths are still settling across tools.

`~/.agents/skills/` is the shared location most non-Claude agents read, so a symlink covers several at once:

```bash
ln -s ~/skills/autonomous-build-loop ~/.agents/skills/autonomous-build-loop
ln -s ~/skills/autonomous-build-loop ~/.claude/skills/autonomous-build-loop
```

Agents without skill support can still use everything. Run `scripts/init.sh` yourself and point the agent at `SKILL.md` when planning.

## Custom agents and local models

Set `AGENT=custom` and `AGENT_CMD` to any shell command. It runs from the repo root once per iteration with these variables:

- `$LOOP_PROMPT` holds the full prompt text
- `$LOOP_PROMPT_FILE` is the path to the same prompt as a file
- `$LOOP_ITERATION` is the iteration number

Examples (check flags against your version):

```bash
# Any CLI that reads a prompt from stdin
AGENT_CMD='my-agent --headless < "$LOOP_PROMPT_FILE"'

# Codex against a local Ollama model
AGENT=codex
EXTRA_AGENT_ARGS="--oss --local-provider ollama"
MODEL="<ollama model name>"

# OpenCode with any provider it's configured for (Kimi, Ollama Cloud, OpenRouter...)
AGENT=opencode
MODEL="<provider>/<model>"   # see: opencode models
```

Small local models struggle to follow the full procedure. If iterations keep ending without commits, make the tasks smaller before blaming the harness.

## Cost control

- Parallel waves spend concurrently (N workers at once) and cross-model review adds reviewer sessions. See `references/parallel-and-review.md`.

- `MAX_ITERS` caps a run. A reasonable default is task count × 2.
- `ITER_TIMEOUT` stops a single runaway session.
- Claude Code accepts a per-session spend cap: `EXTRA_AGENT_ARGS="--max-budget-usd 20"`.
- `STALL_LIMIT` and `VERIFY_FAIL_LIMIT` stop runs that are burning tokens without progress.
