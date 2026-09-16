# Loop iteration: verify phase

Every task in the active phase is checked off. Your job is to find out whether the phase goal was actually achieved, not whether tasks were completed. You have no memory of how the work was done; judge only what's in the repo.

The active phase directory is given in the harness context at the bottom. Below, `<phase>` means that directory.

## Procedure
1. Gather independent reports. If your tool supports subagents, run these in parallel:
   - Goal verification: follow `.loop/roles/goal-verifier.md` (Claude Code subagent `loop-goal-verifier`). It checks every must-have in `<phase>/SPEC.md`, every success criterion for this phase in `.loop/ROADMAP.md`, and every decision in `<phase>/CONTEXT.md`, against the code changed since the base commit in `<phase>/PROGRESS.md`.
   - UI audit, only if `<phase>/UI-SPEC.md` exists: follow `.loop/roles/ui-checker.md` (subagent `loop-ui-checker`).
   - Cross-model reports: if the harness context lists reports from another model, read each one.
2. Merge the reports. Reports from other models are independent evidence, not votes:
   - A truth, decision, or UI check counts as passing only if no report shows it failing with evidence you can confirm in the code.
   - Where reports disagree, open the cited files or run the cited test yourself and decide. Record each disagreement and your ruling under "## Reviewer disagreements".
   - If a listed cross-model report is missing or empty, say so in VERIFICATION.md and continue with the others.
3. Write `<phase>/VERIFICATION.md`. The first line must be `Status: passed`, `Status: gaps_found`, or `Status: human_needed`. Include the goal verifier's sections, a "## UI contract" section when UI-SPEC.md exists (each UI-xx with PASS, FAIL, or HUMAN and evidence), and "## Reviewer disagreements" when there were any.
   - `passed`: every truth VERIFIED, every UI check PASS, gate green, no blocker anti-patterns.
   - `gaps_found`: any truth FAILED, any decision not delivered, any UI check FAIL, or a stub or orphaned artifact on a must-have path.
   - `human_needed`: everything checkable passed, but some items can only be confirmed by a person (visual feel, real third-party flows).
4. If `gaps_found`, turn each gap into a gap-closure task:
   - Add `### G<n>: <title>` to `<phase>/SPEC.md` under Tasks, with Depends on, Covers, Files, Read first, Do, and Done when that target the specific failure (file paths, what's missing).
   - Add `- [ ] G<n> <title>` to the Tasks list in `<phase>/PROGRESS.md`.
   - Number gap tasks after any existing G tasks. Keep them small, one gap per task.
5. If `human_needed`, list each human check under "For the human" in `<phase>/PROGRESS.md` as a concrete step: what to do, and what should happen.
6. Update `.loop/STATE.md`: Stage (`execute` if gaps were added, otherwise `verify`), Next action, and a Log line with the status.
7. Commit: `P<phase number>-verify: <status>`.
8. Stop. Don't fix gaps yourself; the next iterations do that.
