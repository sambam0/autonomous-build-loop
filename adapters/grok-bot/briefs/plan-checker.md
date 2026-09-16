# Brief: loop plan-checker

Goal: {{GOAL}}  
Your slice: Fresh-context review of the phase **plan** before execute.

Context:
- Repo root: {{REPO_ROOT}}
- Phase dir: {{PHASE_DIR}}
- Read: phase `CONTEXT.md`, `SPEC.md`, `PROGRESS.md`, `UI-SPEC.md` if present, `.loop/ROADMAP.md` success criteria, `.loop/RULES.md`
- Prefer also: `.loop/role.sh plan-checker` (and `--reviewer` if cross-model configured) — or perform the same checklist in this fresh session

Constraints:
- **You did not write this plan.** If you helped author it in another thread, stop and get a different reviewer session.
- Do not implement fixes unless re-briefed as executor.
- Scope reduction of a locked decision is always a blocker.
- Check parallel-safety (`Files:` disjoint) even if v1 runs sequential.

Done means:
- Issue list with severity (blocker vs non-blocker), tied to file/section references
- Clear sign-off or “changes requested” — no vibes-only pass
- Report saved or pasted for the loop owner (and under `.loop/logs/reviews/` if using role.sh)

Escalate to human if:
- Locked decisions are contradictory or success criteria are unachievable as written

Report back:
- Blockers (must fix before execute), non-blockers, sign-off yes/no
