# Verify and ship

A phase is done when what was built is what was planned, and what was planned is what was decided. The gate proves the code compiles and tests pass. Goal verification proves the goal was met. Human checks cover what neither can see. Only then ship. Orchestrating specialists does not skip this path or count a chat "looks good" as verification.

## Contents
- Goal verification
- Reading VERIFICATION.md
- Human verification walkthrough
- Closing gaps
- Ship
- Moving to the next phase

## Goal verification

When the loop finishes every task in a phase (and `AUTO_VERIFY=1`), it runs a verify iteration using `.loop/VERIFY_PROMPT.md` and the goal-verifier role. You can also run it manually:
- Claude Code: spawn `loop-goal-verifier`
- Any agent: `.loop/role.sh goal-verifier`

The verifier is adversarial on purpose. It assumes tasks were completed and the goal was missed, then looks for evidence in the code. For each must-have truth it checks four levels:

1. **Exists:** the file or symbol is present.
2. **Substantive:** not a stub. Common stub signs are empty bodies, `return null`, `[]`, or `{}` placeholders, handlers that only log, components rendering hardcoded sample data, and debt markers in the core path.
3. **Wired:** imported and used where the goal needs it, with every key link connected.
4. **Data flows:** values the user sees trace back to a real source rather than a literal or mock.

Behavioral truths (state changes, error handling, ordering) also need a test that exercises them and passes. It also checks every locked decision was delivered at full scope, scans changed files for anti-patterns, and runs the gate.

When the phase has UI-SPEC.md, the ui-checker runs alongside it and audits tokens, component states, copy, accessibility, and screenshots against the contract (see `references/ui-design.md`). When cross-model review is on, the harness also runs the goal-verifier (and ui-checker) on the reviewer model first, and the verify iteration merges all reports. A failure backed by evidence in any report counts.

Statuses:
- `passed`: all truths verified, gate green, no blocker anti-patterns
- `gaps_found`: anything failed. Gap tasks are added and the loop continues, up to `MAX_GAP_ROUNDS`.
- `human_needed`: everything checkable passed, but some truths need a person

## Reading VERIFICATION.md

When a loop ends, open the phase's VERIFICATION.md with the user:

- **Truths table:** skim the evidence column. "Exists" alone is not evidence; look for file:line references and test names.
- **Decisions table:** any "partial" is a gap, even if the verifier passed it.
- **Anti-patterns:** blockers should have become gap tasks. Warnings are worth a look.
- **UI contract:** each UI-xx with PASS, FAIL, or HUMAN. Open a few screenshots from `.loop/logs/screens/<phase>/` yourself before trusting a PASS on anything visual.
- **Reviewer disagreements:** when models disagreed, check that the ruling cites code or a test, not just which report sounded more confident.
- **Human checks:** these drive the walkthrough below.

If the verifier's judgment looks wrong in either direction, say so and fix the must-haves or the verifier's evidence. Don't just flip the status.

## Human verification walkthrough

When status is `human_needed`, or before shipping anything user-facing, walk the user through acceptance testing conversationally:

1. Collect the checks from VERIFICATION.md "Human checks" and PROGRESS.md "For the human", plus the human-judged items in UI-SPEC.md. Add one check per success criterion that has a visible outcome. For visual checks, show the matching screenshots from `.loop/logs/screens/` where you can, and still ask the user to try the real thing.
2. Present one check at a time: what to do, and what should happen. Example: "Open a piece with at least three paragraphs and go to Craft. You should see a note next to at least one paragraph within a few seconds."
3. Ask whether reality matched. A yes (or empty reply) passes. Anything else is an issue: record the user's words and infer severity yourself (crash or data loss is a blocker, "doesn't work" is major, "looks off" is cosmetic). Don't make the user categorize.
4. Record results in a "Human verification" section at the bottom of VERIFICATION.md as you go, so an interrupted session can resume.
5. When all checks are done:
   - No issues: set `Status: passed`.
   - Issues: diagnose each one by reading the relevant code (use the explorer role for anything non-obvious), write gap tasks for them (see below), set `Status: gaps_found`, and run the loop again.

## Closing gaps

Gap tasks use the normal task format, one gap per task:
- `### G<n>: <title>` in SPEC.md, and `- [ ] G<n> <title>` in PROGRESS.md
- "Read first" names the exact files from the verification report or diagnosis
- "Do" targets the specific failure, not a rewrite
- "Done when" includes a test that would have caught the gap

For more than a few gaps, run the plan-checker on the gap tasks before looping. If the same gap survives two rounds, stop looping. The cause is usually a wrong must-have, an ambiguous decision, or a task too big for one iteration, and it needs a human conversation.

## Ship

Preflight, all of which must hold before shipping:
- VERIFICATION.md says `Status: passed`
- `.loop/verify.sh` passes
- no open or blocked tasks in the phase
- working tree clean, on the phase branch
- the user has reviewed the diff (`git diff <base commit>..HEAD --stat`, then anything surprising)

Then prepare the pull request body from the phase artifacts:

```markdown
## <Phase name>
<Goal from ROADMAP.md>

### What changed
- <one line per task, from SPEC.md titles and PROGRESS.md notes>

### Decisions implemented
- D-01: <decision> 

### Verification
- Goal verification: passed (<n>/<n> truths)
- Human checks: <summary>
- Gate: `<VERIFY_CMD>`

### Follow-ups
- <Deferred items and backlog ideas from this phase>
```

Pushing and opening a PR are actions on the user's behalf, so ask before doing either. With permission and GitHub's CLI available, `gh pr create --draft --title "<phase name>" --body-file <file>` works. Otherwise give the user the body to paste.

If the team doesn't want `.loop/` planning files in the PR, suggest keeping them on a separate branch or adding `.loop/phases/` to the repo's export-ignore rules. Ask what they prefer rather than deciding.

## Moving to the next phase

After shipping, or after merge if the user prefers:
1. In ROADMAP.md, set the phase `Status: shipped`.
2. Move Deferred ideas from the phase's CONTEXT.md into the ROADMAP backlog if they aren't there already.
3. In STATE.md, add a Log line, set Next action, and set Stage to `discuss` for the next phase once it's created with `.loop/new-phase.sh`.
4. Do a short retro with the user: anything that went wrong in this phase becomes a specific line in RULES.md.

When the last phase of a milestone ships, check every milestone success criterion is covered by some verified phase, then ask the user whether to tag a release and plan the next milestone.
