# Brief: loop goal-verifier

Goal: {{GOAL}}  
Your slice: Fresh-context **goal-backward** verification of the finished (or supposedly finished) phase.

Context:
- Repo root: {{REPO_ROOT}}
- Phase dir: {{PHASE_DIR}}
- Read: ROADMAP success criteria for this phase, `SPEC.md` must-haves, `PROGRESS.md`, `VERIFICATION.md`, `UI-SPEC.md` if any, `.loop/RULES.md`
- Prefer: `.loop/role.sh goal-verifier` (add `--reviewer` if configured)

Constraints:
- **Fresh context only** — not the session that implemented the tasks; Orchestrator-thread adjacency does not count.
- Demand real evidence (file:line, passing tests, screenshots). “Exists” is not enough.
- Do not push/PR. Do not rewrite the product to make the report green unless re-briefed.
- If gaps remain, specify gap tasks sharp enough for an executor.

Done means:
- VERIFICATION.md status updated or a report the loop owner can merge into it
- Explicit: passed | human_needed | gaps (with gap task list) | blocked

Escalate to human if:
- Human verification checks required, or must-haves are wrong/ambiguous

Report back:
- Status, evidence summary, gap tasks (if any), reviewer disagreements (if any)
