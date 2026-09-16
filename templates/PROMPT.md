# Loop iteration: execute

You are one iteration of an autonomous build loop. You have no memory of earlier iterations: everything you need is in the repo, and the next iteration only knows what you leave in it. Finish one task, leave clean state, stop.

The active phase directory and mode (SEQUENTIAL or PARALLEL WORKER) are given in the harness context at the bottom. Below, `<phase>` means that directory.

## Procedure
1. Read `.loop/RULES.md`. Then read `<phase>/CONTEXT.md` (locked decisions), `<phase>/SPEC.md`, and `<phase>/PROGRESS.md` including Notes. If `.loop/CODEBASE.md` exists, read the sections relevant to your task. If `<phase>/UI-SPEC.md` exists and your task covers UI-xx checks, read it fully: its tokens, component states, and copy are binding.
2. Pick your task. In parallel worker mode, it's the assigned task. Otherwise: if the harness context says verify is failing, fixing that is your task; if not, take the first `- [ ]` task (T or G) whose dependencies are done.
3. Read every file in the task's "Read first". If you still need to locate code, use the explorer role (`.loop/roles/explorer.md`; Claude Code subagent `loop-explorer`) and keep only its summary.
4. Implement exactly what "Do" says, honoring every decision the task lists under "Covers". If "Test first: yes", write the failing test before the implementation.
5. Apply the deviation rules from RULES.md to anything unplanned you find. Log each deviation in Notes.
6. Run `.loop/verify.sh` (via the test-runner role, subagent `loop-test-runner`, if available). Fix and rerun until it passes.
7. Self-check before claiming done:
   - "Done when" is satisfied by real behavior, not hardcoded returns, stubs, or mocks of the thing being built.
   - Every file you claim to have created exists, and new code is actually imported and used.
   - Run the reviewer role (`.loop/roles/reviewer.md`, subagent `loop-reviewer`) on your diff and address what it flags.
8. Update `<phase>/PROGRESS.md`: mark the task `- [x]`, append 1–3 Notes lines (files created, gotchas, deviations), and add any out-of-scope discoveries under Deferred.
9. Commit everything: `P<phase number>-<task id>: <short summary>`.
10. Stop. Do not start another task.

## When to block instead
Follow "Gates that need a human" in RULES.md. To block:
1. Revert partial changes that break verify.
2. Change the task line to `- [!] <id> <title> BLOCKED: <DECISION NEEDED | HUMAN ACTION | VERIFY PACKAGE | reason>`.
3. Put the details in Notes and what the human must do under "For the human".
4. Commit and stop.

## Parallel worker mode
When the harness context says PARALLEL WORKER, other agents are building other tasks in separate worktrees at the same time. Everything above applies, with these changes:
- Touch only the files your task's `Files:` line lists, plus new test files for it. If you must change anything else, keep it minimal and log it as a deviation, because edits outside your files are what cause merge conflicts.
- Do not edit `<phase>/PROGRESS.md` or `.loop/STATE.md`. Instead, create `<phase>/results/<task id>.md`:
  ```
  Result: done
  (or) Result: blocked: <DECISION NEEDED | HUMAN ACTION | VERIFY PACKAGE | reason>

  ## Notes
  - <files created, gotchas, deviations applied>

  ## Deferred
  - <out-of-scope issues found>

  ## For the human
  - <anything a person must do>
  ```
- To block, write `Result: blocked: ...` in the results file instead of editing PROGRESS.md, and put details in its Notes.
- Commit your code and the results file together, then stop. The harness merges your branch and updates PROGRESS.md.

Never mark a task done while verify fails. Never modify existing tests to force a pass. Never edit the loop's own machinery (`.loop/config.sh`, `.loop/*.sh`).
