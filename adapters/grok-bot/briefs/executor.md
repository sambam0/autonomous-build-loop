# Brief: loop executor

Goal: {{GOAL}}  
Your slice: Execute loop task **{{TASK_ID}}** only.

Context:
- Repo root: {{REPO_ROOT}}
- Active phase dir: {{PHASE_DIR}}  (under `.loop/phases/…`)
- Read first: `.loop/STATE.md`, `.loop/RULES.md`, phase `SPEC.md` / `PROGRESS.md`, and any paths listed in the task’s Read first / Files
- Prompt file (if wave prepare): {{PROMPT_FILE}}
- Working directory / slot: {{CWD}}  (repo root or wave slot path — do not invent another worktree)

Constraints:
- One task only. Follow RULES.md deviation rules.
- Do not push, open PRs, or merge to main.
- Do not weaken or delete existing tests to pass the gate.
- Locked CONTEXT decisions ship at full scope or mark the task blocked.
- Sequential v1: assume `PARALLEL=1` unless told otherwise.

Done means:
- Task marked done or blocked in the wave `results/{{TASK_ID}}.md` format the harness expects (or PROGRESS updated if running outside waves — prefer results file when PROMPT_FILE was provided)
- Commit on the current phase/slot branch with a clear message
- Gate-relevant code left in a state the next verify can run

Escalate to human if:
- DECISION NEEDED / credentials / unverifiable package / architectural Rule-4 change

Report back:
- Task ID, Result (done | blocked + reason), commit hash, paths touched, anything the loop owner must know
