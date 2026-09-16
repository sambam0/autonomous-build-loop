---
name: autonomous-build-loop
description: Standalone spec-driven development system for coding agents. Takes work from idea to shipped code through roadmap, discuss, UI design, plan, execute, verify, and ship stages, with an unattended execution loop (fresh context per task, parallel subagent waves in isolated worktrees, a test gate, goal-backward verification, screenshot UI checks, optional cross-model review, automatic gap closure) that can run for hours or overnight. Works with Claude Code, Codex, Gemini CLI, OpenCode, or any headless agent CLI. Use whenever the user wants to plan or build a feature or project with an agent, break work into phases or tasks, write a spec or roadmap, lock decisions before coding, design or check UI against a spec, run agents in parallel, get a second model to review, run an agent unattended or "overnight", a "ralph loop", verify that agent-built work actually meets its goal, resume where a project left off ("what's next", "where were we"), or ship a finished phase, even if they don't mention loops or specs.
compatibility: Requires git and bash. Scripts are bash 3.2 compatible (macOS default). python3 is optional (used to merge Claude Code settings).
---

# Autonomous Build Loop

A complete spec-driven workflow for building software with coding agents. It prevents the three things that break long agent work: context rot (every task runs in a fresh session), lost state between sessions (everything lives in files), and false "done" (a test gate after every task, plus goal verification against the code at the end).

## The system

```
.loop/
  STATE.md          where the project is, what to do next (read first, always)
  ROADMAP.md        milestone goal, phases, success criteria, backlog
  RULES.md          standing rules, deviation rules, grows after every failure
  CODEBASE.md       map of an existing codebase (optional, generated)
  config.sh         agent, gate command, loop limits
  phases/NN-name/
    CONTEXT.md      locked decisions from discuss
    UI-SPEC.md      UI contract: tokens, states, copy, checkable UI criteria (UI phases only)
    SPEC.md         must-haves and tasks from plan
    PROGRESS.md     checklist the loop reads, notes, deferred items
    VERIFICATION.md goal verification report and status
    results/        per-task outcomes written by parallel workers
  roles/            subagents: explorer, test-runner, reviewer, plan-checker, goal-verifier,
                    codebase-mapper, executor, ui-researcher, ui-checker, cross-reviewer
  loop.sh           the unattended execution harness (sequential or parallel waves)
  wave.sh           prepare / run / merge parallel waves by hand (for subagent orchestration)
  role.sh           run any role in a fresh headless session, optionally on the reviewer model
  ui-snap.sh        screenshot routes at each viewport for UI research and checks
  new-phase.sh      create the next phase and make it active
  verify.sh         the gate
  status.sh         where things stand
```

Each phase moves through: **discuss → UI (if there's interface work) → plan → execute → verify → ship**. Execution and automated verification run unattended in the loop. Discuss, UI and plan approval, human verification, and ship happen with the user.

Judging always happens in a fresh context: plan-checker, goal-verifier, and ui-checker run as subagents or via `role.sh`, never in the session that wrote the work. When `REVIEW_AGENT` is configured, they also run on a second model and the reports are merged.

## Step 0: Orient (every time)

If `.loop/STATE.md` exists, read it and run `.loop/status.sh` before doing anything else, then continue at the stage it names. "What's next?" and "where were we?" are answered from STATE.md's Next action. If there's no `.loop/`, start at Setup.

Then pick the lightest track that fits the work:

| Track | When | What to do |
|---|---|---|
| **Direct** | A change of a few lines in known files | Just do it in the current session, run the gate, commit. No loop. |
| **Quick** | One focused change: a bug fix or small feature, roughly 1 to 4 tasks | Create one phase, write a brief CONTEXT.md from the request, plan, optionally skip the plan-checker, run the loop. |
| **Full** | Multi-file features, anything spanning sessions, new projects | Roadmap, then every stage for each phase. |

If you hesitate between Direct and Quick, use Quick.

## Stage: Setup

1. From the repo root, run `bash <skill-dir>/scripts/init.sh` (add `--agent codex|gemini|opencode|custom` if not Claude Code). It detects the gate command, scaffolds `.loop/`, and installs Claude Code subagents and a Stop hook when relevant. It never overwrites project files. Read its output for anything left to fill in.
2. Confirm `VERIFY_CMD` in `.loop/config.sh` and get `.loop/verify.sh` passing on the current code. A good gate covers typecheck, lint, and unit tests in under about 3 minutes.
3. If the repo already has meaningful code, map it: spawn `loop-codebase-mapper` (Claude Code) or run `.loop/role.sh codebase-mapper`. Review `.loop/CODEBASE.md` with the user.
4. Update STATE.md: Stage `roadmap` and a Next action.

## Stage: Roadmap

Write `.loop/ROADMAP.md` with the user: the milestone goal, what's out of scope, and phases in dependency order, each with a one-sentence goal and 2 to 7 observable success criteria. For a single feature, one phase is fine. Get approval, then create the first phase with `.loop/new-phase.sh "<name>"`. This sets it active and records the base commit.

Read `references/planning.md` (Roadmap section) for phase sizing and success-criteria examples.

## Stage: Discuss

Lock the implementation decisions the user cares about before anything is planned. Identify phase-specific gray areas (not generic categories like "UI"), then either interview the user one question at a time or, for pattern-heavy codebases, propose assumptions with evidence and let them correct. Keep scope fixed: new capabilities go to Deferred ideas and the roadmap backlog, never into the phase.

Write the phase's CONTEXT.md with numbered decisions (`D-01`...). Set STATE.md Stage to `ui` if the phase has user-visible interface work, otherwise `plan`.

Read `references/discuss.md` before starting. It covers gray-area examples, both modes, the scope guardrail, and shortcuts when the user already has a PRD.

## Stage: UI (phases with interface work)

1. **Research:** spawn `loop-ui-researcher` or run `.loop/role.sh ui-researcher` to extract the existing tokens, components and their missing states, patterns, and inconsistencies, with screenshots of related screens when possible.
2. **Contract:** create UI-SPEC.md (`.loop/new-phase.sh --ui` does this at phase creation) and fill it with the user: design direction with anti-references, tokens by name, screens, component states, interactions, exact copy, accessibility, and 5 to 12 acceptance checks (`UI-01`...) that can be verified from code or screenshots. Taste goes in the human-judged list.
3. **Approve:** once the user signs off, set `Status: approved`. The loop won't run an unapproved contract. Then set STATE.md Stage to `plan`.

Read `references/ui-design.md` first. It has checkable versus uncheckable criteria, and screenshot setup including dev server start and logged-in pages.

## Stage: Plan

1. **Research only if needed:** unfamiliar libraries or APIs, with bounded questions. Confirm every new package exists on its registry under the exact name before any task may install it.
2. **Must-haves, goal-backward:** truths that must be observable, artifacts that must exist, and key links that must be wired. Start from the roadmap success criteria.
3. **Tasks:** each with Depends on, Covers (must-haves, decisions, UI checks), Files, Read first, a concrete Do, Test first, and a verifiable Done when. T1 is a tracer, the thinnest end-to-end slice. Tasks run about 20 to 60 minutes of agent work each. For parallel waves, keep independent tasks' Files disjoint and put shared contracts early. Human-only work goes under "For the human" in PROGRESS.md.
4. **Check in fresh contexts:** spawn `loop-plan-checker`, plus `loop-cross-reviewer` for the plan-checker role in the same turn if cross-model review is configured (any agent: `.loop/role.sh plan-checker`, and `--reviewer`). Merge the issues, fix blockers, and re-check, for at most three rounds. Scope reduction of a locked decision is always a blocker.
5. Show the user the task list, then set STATE.md Stage to `execute`.

Read `references/planning.md` before planning. It has the task format, sizing rules, tracer and test-first guidance, parallel-safe planning, UI task rules, the plan-check dimensions, and a worked example.

## Stage: Execute

1. **Isolate:** `git switch -c loop/<phase>`, or a git worktree to keep working elsewhere. The loop refuses to run on `main`/`master`. For unattended runs, recommend a container, VM, or cloud dev box.
2. **Check agent gotchas** in `references/agents.md`. Claude Code ignores project settings in untrusted directories (each new worktree counts) and refuses full permissions as root unless `IS_SANDBOX=1`.
3. **Choose parallelism:** `PARALLEL=1` runs one task at a time. With 2 or 3, ready tasks with disjoint Files run at once as executor subagents in persistent worktree slots, then get merged and gated together. Confirm `WORKTREE_SETUP_CMD` installs what the gate needs in a fresh slot.
4. **Dry run:** `.loop/loop.sh --dry-run` prints the command and the next wave. `.loop/loop.sh --once` runs one iteration. Review the diff, PROGRESS.md notes, and the log with the user, and fix the plan or RULES.md now if anything looks off.
5. **Launch:** `.loop/loop.sh`, ideally inside `tmux`. Monitor with `.loop/status.sh` or `tail -f .loop/logs/run.log`. `touch .loop/STOP` stops gracefully after the current iteration.

Each iteration either does one task in a fresh session or runs a wave of workers in parallel. Workers follow RULES.md: they auto-fix bugs, missing critical pieces, and blockers in their path; stop for architectural changes, credentials, or unverifiable packages; and log out-of-scope issues as Deferred. The harness runs the gate after every iteration and hands failures to the next one. When all tasks are done, it runs a verification iteration (cross-model reports first, if configured), which adds gap tasks if the goal wasn't met and keeps going, up to `MAX_GAP_ROUNDS`.

**Orchestrating waves from a Claude Code session instead:** `.loop/wave.sh prepare`, then spawn one `loop-executor` subagent per printed line in a single turn (Agent `cwd` = the slot path, prompt = follow the printed prompt file), then `.loop/wave.sh merge`.

The exit reason is the last line of `run.log`: 0 verified, 2 blocked, 3 stalled, 4 gate failing, 5 max iterations, 6 stopped, 7 human verification needed, 8 gaps remain.

`references/parallel-and-review.md` covers wave selection, slots, trust, merge conflicts, and cross-model review setup.

## Stage: Verify

Open the phase's VERIFICATION.md with the user and check that the evidence is real (file:line references, passing tests, screenshots), not just "exists". Review the UI contract section and any reviewer disagreements.

- **Blocked tasks:** resolve each one with the user (decision, credentials, package check), record the outcome in CONTEXT.md or SPEC.md, reopen the task, and rerun the loop.
- **`human_needed`, or anything user-facing:** walk the user through the human checks one at a time, show screenshots where they help, record results in VERIFICATION.md, and turn issues into gap tasks.
- **Gaps that survived the loop:** diagnose with the user; usually a wrong must-have, an ambiguous decision, or an unclear UI check.
- **To re-check after manual changes:** run `.loop/loop.sh --reverify`, or run the goal-verifier or ui-checker role directly (add `--reviewer` for the second model).

Read `references/verification-and-ship.md` for the verification levels, the human walkthrough, and writing gap tasks.

## Stage: Ship

Ship only when all of these hold: status `passed`, gate green, no open or blocked tasks, a clean tree, and the user has reviewed the diff. Draft the PR body from the phase artifacts (goal, changes, decisions, verification, follow-ups). Ask before pushing or opening a PR. Then mark the phase shipped in ROADMAP.md, move deferred ideas to the backlog, do a short retro (every failure becomes a RULES.md line), update STATE.md, and create the next phase.

`references/verification-and-ship.md` has the preflight, PR template, and milestone wrap-up.

## Keeping state honest

- Update STATE.md after every meaningful step: Stage, Next action, and a Log line. Put project-wide decisions and blockers there, and phase decisions in CONTEXT.md.
- When the user pauses mid-stage, write the exact Next action so any session, in any agent, can resume cold.
- When something goes wrong, add one specific rule to RULES.md. `references/failure-modes.md` maps common symptoms to fixes.

## Adapters

Optional runtimes that **drive** this skill without replacing `.loop/` state or the bash harness:

- **Grok Bot / multi-agent crew** — `adapters/grok-bot/` (README, role map, STATE↔inflight, Mac↔box mirror, briefs, `COMPOSITION.md`, `BABYSIT.md`). Standing babysit routine only after a clean overnight dry-run.
- **Claude Code** — `adapters/claude-code/` (Stop hook used by `init.sh`)

Prefer composing with `wave.sh` / `role.sh` over forking harness logic.

## Guardrails

- One task per iteration, fresh context each time. Resist longer iterations.
- Never let agents weaken or delete existing tests to pass the gate.
- Locked decisions ship at full scope or the task blocks. No quiet "v1" versions.
- Plan-checker, goal-verifier, and ui-checker judge work in a fresh context, never the context that produced it. A concrete failure found by any model counts.
- The loop commits locally only. Pushing, PRs, and merges happen with the user's say-so.
- Parallel waves only run tasks with declared, disjoint Files, always start from a clean committed base, and are gated again after merging.

The phase loop, UI contract, goal-backward verification, deviation rules, wave execution, cross-AI review, and plan-checking in this skill are adapted from GSD Core (MIT, github.com/open-gsd/gsd-core) and condensed into a standalone form.
