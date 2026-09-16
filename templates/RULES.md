# Standing rules

These apply to every session, in the loop or not. When a run goes wrong, add a specific rule here so it can't happen twice.

## Scope
- Do exactly one task per loop iteration, then stop.
- Locked decisions in the phase's CONTEXT.md are binding. Deliver them at full scope. Never ship a "v1", "static for now", or "placeholder" version of a decision; if full scope doesn't fit, mark the task BLOCKED and say so.
- Follow the existing pattern named in SPEC.md Constraints over inventing a new one.

## Deviations
You will find work the plan didn't mention. Handle it by these rules and log every deviation in PROGRESS Notes as `[Rule N] what you did`.
1. **Bugs in code you're touching** (wrong logic, type errors, broken queries): fix inline, add a test if practical.
2. **Missing critical pieces** for correctness or security (input validation, error handling, auth checks on the route you're building): add them.
3. **Blockers to the current task** (broken import, wrong type, missing config file): fix the minimum needed.
4. **Architectural changes** (new table or service, switching libraries, changing auth, breaking API changes): stop. Mark the task `BLOCKED: DECISION NEEDED` with what you found, the proposed change, and alternatives.

When unsure whether it's Rule 1–3 or Rule 4, treat it as Rule 4.

Out-of-scope problems (pre-existing lint errors, bugs in unrelated files) go under Deferred in PROGRESS.md. Log them; don't fix them.

## Gates that need a human
Mark the task blocked and stop, rather than working around it:
- **Auth or credentials** (401/403, "not logged in", missing API key): `BLOCKED: HUMAN ACTION` with the exact steps a human must take.
- **Package install fails or a package can't be found:** `BLOCKED: VERIFY PACKAGE`. Never substitute a similarly named package. Unknown names can be hallucinated or malicious.
- **Three genuine fix attempts** on the same failure: `BLOCKED` with what you tried.

## Staying productive
- If you've made five or more reads or searches in a row without editing anything, stop and either write code or block with the specific missing information.
- Don't read lockfiles, build output, or full test logs into context. Use the test-runner role for failures.

## Tests
- Never delete, skip, loosen, or rewrite existing tests to make verify pass. If a test seems wrong, block and explain.
- For tasks marked `Test first: yes`, write the failing test, confirm it fails for the right reason, then implement.

## Git
- Commit when the task is verified: `P<phase>-T<n>: <summary>` (gap tasks: `P<phase>-G<n>`).
- Never push, force-push, rebase, amend earlier commits, or switch branches.

## Safety
- Never commit secrets. Don't edit `.env*` files; document needed env vars under "For the human".
- Don't run destructive commands against databases, cloud resources, or anything outside this repo.
- Don't add dependencies unless SPEC.md Constraints allow them.

## Project-specific
<!-- Grows over time. Examples: "Use pnpm, never npm." "Run `pnpm prisma generate` after schema edits." -->
