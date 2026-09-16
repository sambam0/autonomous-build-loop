# Failure modes and fixes

Run `.loop/status.sh` first, then read `.loop/logs/run.log`. Its last line says why the loop stopped, and each iteration line shows whether it was an execute or verify iteration, the agent exit code, gate result, task counts, and stall count. Per-iteration agent output is in `.loop/logs/<run>-iter<N>.<kind>.agent.log`. Task files live in the active phase directory, `.loop/phases/<NN-name>/`.

For each fix, prefer a specific line in `.loop/RULES.md` or a sharper task in `.loop/SPEC.md` over a vaguer prompt. Specific rules survive fresh context; general exhortations don't.

## The loop stopped

**"stalled: N iterations without progress"** (exit 3)
The agent ran but changed nothing: no commit, no PROGRESS change, no diff.
- The agent log shows it asking a question or waiting for approval. The permissions mode is blocking it. Check `references/agents.md` for trust and root gotchas, or use `PERMISSIONS=yolo` in an isolated environment.
- The agent log is almost empty or shows an auth error. Log in to the CLI, or set its API key in the environment the loop runs in.
- The agent explored and then gave up. The task is too big or too vague, so split it and sharpen "Done when".

**"verify failed N iterations in a row"** (exit 4)
- Iterations keep "fixing" and re-breaking the same thing. The task probably conflicts with an existing test or constraint, so read the verify logs and make the spec resolve the conflict.
- Verify fails for environmental reasons (missing env var, database not running, port in use). Fix the environment, then add a rule such as "Tests use `.env.test`; never require a running database".
- The gate is flaky. Fix or quarantine the flaky test before the next run, since a flaky gate poisons every iteration.

**"only blocked tasks remain"** (exit 2)
This is a normal stop. Read each `BLOCKED:` reason. `DECISION NEEDED` means an architectural choice: make it with the user, record it in CONTEXT.md, and adjust the task. `HUMAN ACTION` means credentials or setup only a person can do. `VERIFY PACKAGE` means confirm the dependency is real and correctly named, then add it to SPEC.md Constraints. Then flip the task back to `- [ ]`.

**"automated checks passed; human verification needed"** (exit 7)
Also normal. Walk the user through the human checks as described in `references/verification-and-ship.md`.

**"gaps remain after N gap-closure rounds"** (exit 8)
The verifier keeps finding problems the gap tasks don't fix. Read VERIFICATION.md and the gap tasks together. Usually a must-have is wrong or unachievable as written, a decision is ambiguous, or gap tasks are too broad. Fix the plan with the user; don't just raise `MAX_GAP_ROUNDS`.

**"gaps found but no gap tasks were added"** or **"verification did not record a status"** (exit 8)
The verify iteration didn't follow VERIFY_PROMPT.md. Check its agent log. Run `.loop/role.sh goal-verifier` to get the report, then add gap tasks by hand.

**"reached max iterations"** (exit 5)
If tasks were getting done, raise `MAX_ITERS`. If they weren't, look at why iterations took multiple rounds per task, usually oversized tasks or a red verify being repeatedly fixed.

## The loop finished, but the work is wrong

**Tests were weakened or deleted.** Check with `git log -p -- '*test*'`.
Keep the RULES.md test rule, and add a pointed rule naming what happened, e.g. "Don't replace assertions with `expect.anything()`". For Claude Code, you can also add a PreToolUse hook that rejects edits to existing test files.

**Checked-off tasks don't actually work.** Hardcoded returns, mocked-away logic, stubbed handlers.
Goal verification should catch this as gaps. If it passed anyway, the must-haves were too weak: add the missing truth or key link to SPEC.md and rerun with `--reverify`. For future phases, make "Done when" test behavior through a real path (call the route handler rather than a mocked service) and use `Test first: yes`.

**Decisions delivered as a smaller version.** "Static for now", "v1", placeholder data where the decision said real data.
The plan-checker should have blocked this. Rerun it on the next phase's plan before looping, and add the specific shortcut to RULES.md.

**Architecture changed mid-phase without asking.** New tables, swapped libraries.
The executor treated a Rule 4 change as Rule 1–3. Add a pointed example to the Deviations section of RULES.md ("Adding a Prisma model is Rule 4").

**Scope creep.** Reformatting unrelated files, "improving" nearby code, upgrading packages.
Add rules such as "Don't run formatters on files you didn't otherwise change" and "Never change package versions". Add the tempting area to Non-goals.

**Duplicate or re-done work.** The agent re-implements something an earlier iteration built.
Notes weren't useful. Add a rule like "Notes must name the files you created and any helpers future tasks should reuse". Also check that the previous iteration committed; the log line says `uncommitted-changes` when it didn't.

**Wrong tools or conventions.** npm instead of pnpm, wrong test runner, wrong import aliases.
One rule line each under "Project-specific" in RULES.md. These are the cheapest and highest-value rules.

**Several tasks done in one iteration.** The loop still works, but review gets harder and failures get muddier. Reinforce "Stop after one task" in RULES.md, and check that tasks aren't so small that the agent naturally rolls them together.

## Operational problems

**Iterations are slow.** Usually the verify gate. Time `.loop/verify.sh`. Move slow suites (full e2e, `next build`) out of the gate and into specific tasks' "Done when", or run a fast subset in the gate.

**Context overflow within one iteration.** The agent log shows compaction or truncation. The task is too large, or the agent is reading huge files and logs. Split the task, and add rules such as "Don't cat lockfiles or generated files" and "Use the verifier role instead of reading full test output".

**Costs higher than expected.** Set `EXTRA_AGENT_ARGS="--max-budget-usd N"` for Claude Code, lower `MAX_ITERS`, use a cheaper `MODEL` for simple task lists, and consider running explorer and verifier roles on a smaller model (`model:` in `.claude/agents/*.md`).

**Parallel waves: conflicts, red gates after merge, workers with no commit, slot setup failures.** See "When waves go wrong" in `references/parallel-and-review.md`.

**Separate loops on different phases collide.** Give each loop its own worktree and branch with non-overlapping phases, and merge one branch at a time. Each new worktree needs agent trust set up.

**UI checks can't take screenshots.** The ui-checker reports why: no Playwright in the project, the app isn't reachable (set `UI_START_CMD`), or pages redirect to login (set `UI_STORAGE_STATE`). See Screenshots setup in `references/ui-design.md`.

**Cross-model report missing.** Check `.loop/logs/reviews/<phase>/*.log` for the reviewer's transcript. Usually the reviewer CLI isn't authenticated, or its flags changed in a new version.

**Terminal closed and the loop died.** Run inside `tmux new -s loop` or `screen`, or on a remote box.
