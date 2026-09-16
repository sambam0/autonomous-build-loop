# Parallel waves and cross-model review

Both features are built on subagents: fresh-context sessions with one job each. Parallel waves run several executor subagents at once in isolated worktrees. Cross-model review runs the judging roles on a second model, so plans and results get checked by something that doesn't share the author's blind spots.

## Contents
- Parallel waves: how they work
- Planning for parallelism
- Running waves unattended (any agent)
- Running waves from a Claude Code session with subagents
- Slots, setup, and trust
- When waves go wrong
- Cross-model review: what it covers
- Configuring it
- Using it interactively
- Reading disagreements
- Cost

## Parallel waves: how they work

With `PARALLEL` above 1, each loop iteration picks a wave:
1. Collect open tasks whose dependencies are all done, in PROGRESS.md order.
2. Greedily add tasks whose `Files:` don't overlap any task already picked, where a directory overlaps everything inside it. Stop at `PARALLEL`.
3. A task with no `Files:` line, or one that conflicted in an earlier wave, only runs alone.
4. If fewer than two tasks qualify, the iteration runs sequentially as usual.

For a wave, the harness:
1. Requires a clean working tree, so the wave starts from a committed base.
2. Prepares one **slot** per task: a persistent git worktree outside the repo, reset to the base commit on branch `loop-slot-N`.
3. Starts one executor session per slot, all at once, each told its assigned task. Workers don't touch PROGRESS.md; each writes `<phase>/results/<task>.md` and commits.
4. Waits for all workers, then merges each branch into the phase branch. A merge conflict is aborted, and that task goes back to open to run alone next time.
5. Applies each results file: marks tasks done or blocked, and copies Notes, Deferred, and For the human bullets into PROGRESS.md. Then it commits.
6. Runs the gate on the merged result. Tasks can pass individually and fail together; a red gate sends the next iteration to fix it before any new wave.

A wave counts as one iteration toward `MAX_ITERS`.

## Planning for parallelism

Waves are only as safe as the `Files:` lines.
- Give every task a `Files:` line listing what it creates or modifies. Use directories when a task owns a whole folder.
- Watch for hidden shared files: database schema and migrations, route registries and barrel `index.ts` files, shared types, `package.json` and lockfiles, global CSS, translation catalogs, app-wide config. If two independent tasks both need one, make one depend on the other, or give the shared change its own earlier task.
- Tracer first still applies. T1 is sequential by nature, and waves open up once the skeleton exists.
- Keep 2 to 3 workers as the practical default. More workers means more merge risk, more concurrent spend, and more setup time, for diminishing returns on a single phase.

The plan-checker's parallel-safety dimension enforces this.

## Running waves unattended (any agent)

```bash
.loop/loop.sh --parallel 3      # or set PARALLEL=3 in config.sh
.loop/loop.sh --dry-run --parallel 3   # shows the next wave without running
```

Every worker uses the configured `AGENT`, so this works with Claude Code, Codex, Gemini CLI, OpenCode, or a custom CLI. Worker transcripts are in `.loop/logs/wave-<label>-<task>.agent.log`.

## Running waves from a Claude Code session with subagents

When you're orchestrating inside a Claude Code session rather than the headless loop, run waves with `loop-executor` subagents:

1. `.loop/wave.sh plan --parallel 3` shows what's ready.
2. `.loop/wave.sh prepare --parallel 3` prepares slots and prints one line per worker: `TASK<TAB>SLOT_PATH<TAB>PROMPT_FILE`.
3. For each line, spawn a `loop-executor` subagent in the same turn so they run concurrently. Set the Agent tool's `cwd` to SLOT_PATH, and use this prompt: `Execute the loop task in <PROMPT_FILE>. Your working directory is <SLOT_PATH>.` Wait for all of them to finish.
4. `.loop/wave.sh merge` merges, records results, and runs the gate. Exit code 3 means the gate failed after merging; fix that before the next wave.
5. Repeat, or hand the rest to `.loop/loop.sh`.

Don't use the Agent tool's `isolation: "worktree"` option for this. Claude Code's own agent worktrees branch from `origin/<default branch>` by default, not from your phase branch, so they'd miss earlier tasks' commits. The slots from `wave.sh` always start from the current phase branch HEAD.

Other agents with native subagents can follow the same prepare, spawn, merge pattern if their subagents can be pointed at a directory. Otherwise use `.loop/wave.sh run`, which runs the workers headless.

## Slots, setup, and trust

**Location.** Slots live in `<repo>/../.<repo>-loop-slots/slot-N` by default, or under `WORKTREE_ROOT`. They sit outside the repo on purpose: test runners, linters, and TypeScript scan subdirectories and would pick up duplicate copies of the code.

**Dependencies.** Slots are reused across waves, so installed dependencies survive. `WORKTREE_SETUP_CMD` (detected by init, for example `pnpm install --frozen-lockfile --prefer-offline`) runs in a slot only when its lockfiles change. If your gate needs generated code (Prisma client, GraphQL types), add the generate step: `WORKTREE_SETUP_CMD="pnpm install --frozen-lockfile && pnpm prisma generate"`.

**Env files.** `WORKTREE_COPY` lists untracked files to copy into each slot, `.env .env.local .env.test` by default. Point tests at a test database; parallel workers sharing one development database will interfere with each other.

**Claude Code trust.** Headless Claude Code ignores project settings, hooks, and subagents in untrusted directories, and every slot is a new directory. With `CLAUDE_TRUST_SLOTS=1` (the default), the harness copies your repo's existing trust to its slot paths in `~/.claude.json`. It does this only if you've already trusted the repo, and it makes a one-time backup at `~/.claude.json.loop-backup`. Set it to 0 to manage trust yourself.

**Cleanup.** `.loop/wave.sh clean` removes all slots and `loop-slot-*` branches. Slots are otherwise kept between runs to save setup time.

## When waves go wrong

- **Merge conflicts on most waves.** The `Files:` lines are missing shared files. Check which files conflicted with `git log --merges`, then add dependencies and rerun the plan-checker.
- **Gate red after nearly every wave.** Tasks are individually correct but incompatible: an interface changed in one and used in another. Add a dependency, or put the shared contract (types, API shape) in an earlier task.
- **"worker made no commit".** Read that worker's agent log. Usual causes are auth or trust problems in the slot, a failed setup, or a task too vague to act on.
- **Slot setup failed.** Read `.loop/logs/slot-N-setup.log`. The harness falls back to sequential for the rest of the run.
- **Ports in use.** Workers that start dev servers or bind fixed ports collide. Keep servers out of executor tasks and the gate, or give each slot a port via env.

## Cross-model review: what it covers

When `REVIEW_AGENT` is set, three judging roles get a second, independent run on the reviewer model:

| Role | When | How it's used |
|---|---|---|
| plan-checker | Before execution | Run beside the same-model checker; merge both issue lists |
| goal-verifier | Each verify iteration | The harness runs it before the iteration; the verify agent merges it with its own verifier's report |
| ui-checker | Verify iterations of phases with UI-SPEC.md | Same as goal-verifier |

Executors, explorers, and the per-task reviewer stay on the primary model. Cross-model review pays off on judgment, not typing, and running it per task would multiply cost for little gain.

## Configuring it

In `.loop/config.sh`:
```bash
REVIEW_AGENT="codex"          # claude | codex | gemini | opencode | custom
REVIEW_MODEL="gpt-5-codex"    # optional
REVIEW_EXTRA_ARGS=""
REVIEW_ROLES="plan-checker goal-verifier ui-checker"
```

Any pairing works: Claude executing with Codex reviewing, Codex executing with Claude reviewing, or an OpenCode-routed model (Kimi, Qwen, a local model) as the reviewer. Pick a reviewer from a different model family than the executor. Two models from the same family share more blind spots.

The reviewer CLI must be installed and authenticated. The harness preflights it too, including the Claude root and trust checks and the Gemini trust setting. Use `--no-review` to skip review for one run.

## Using it interactively

For plan checking, run both at once and merge:
- Claude Code: spawn `loop-plan-checker` and `loop-cross-reviewer` (asked to run role `plan-checker`) in the same turn.
- Any agent: run `.loop/role.sh plan-checker` and `.loop/role.sh plan-checker --reviewer` in separate terminals, or back to back.

Reports are saved under `.loop/logs/reviews/<phase>/`. Any role can get a second opinion on demand, for example `.loop/role.sh goal-verifier --reviewer` after manual changes, or `.loop/role.sh reviewer --reviewer` on a risky diff.

## Reading disagreements

Treat another model's report as independent evidence, not a vote:
- **One model finds a concrete failure with file:line evidence.** Check it. If it's real, it's a gap, no matter how confident the other report is.
- **Reports disagree on a judgment call** (is this task too big, is this state handled). Decide from the code, and record the ruling under "Reviewer disagreements" in VERIFICATION.md or in your plan-check notes.
- **The reviewer flags style or preferences outside the spec.** Not a gap. If the user agrees it matters, add it to RULES.md, CONTEXT.md, or UI-SPEC.md for the future.

Repeated disagreements about the same kind of thing usually point to an ambiguous decision or must-have. Fix the wording rather than adjudicating it every phase.

## Cost

- A wave of N workers runs N sessions concurrently. Total work is about the same as sequential, but it's spent faster, and merge conflicts cause some rework. Set per-session caps with `EXTRA_AGENT_ARGS` (for example Claude Code's `--max-budget-usd`).
- Cross-model review adds one plan check per phase and one to two role runs per verify iteration. That's small compared with execution, and it's the cheapest place to catch a wrong plan.
